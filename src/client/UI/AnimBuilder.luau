--!strict
-- AnimBuilder: turns AnimationConfig poses into REAL Roblox animations at runtime.
-- A KeyframeSequence is built in code and registered with KeyframeSequenceProvider, which
-- returns a temporary animation id that the character's own Animator can play like any
-- uploaded animation. Because the engine plays it, it works with every joint type
-- (Motor6D or AnimationConstraint) and blends with the default Animate script by priority.
--
-- API:
--   AnimBuilder.Available() -> boolean        -- false if registration fails (fallback to C0)
--   AnimBuilder.Get(key, frames, opts, model) -> animationId?
--     frames: { { t: number, pose: { [jointKey]: {x, y, z} } } } (degrees, parent-part axes)
--     opts: { loop: boolean?, priority: Enum.AnimationPriority?, joints: { string }? }

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local AnimBuilder = {}

-- Pose key -> part name, per rig type.
local R15_PART = {
	root = "LowerTorso",
	waist = "UpperTorso",
	shoulder = "RightUpperArm",
	elbow = "RightLowerArm",
	leftShoulder = "LeftUpperArm",
	leftElbow = "LeftLowerArm",
	leftHip = "LeftUpperLeg",
	rightHip = "RightUpperLeg",
	leftKnee = "LeftLowerLeg",
	rightKnee = "RightLowerLeg",
}
local R15_PARENT = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
}
local R6_PART = {
	root = "Torso",
	shoulder = "Right Arm",
	leftShoulder = "Left Arm",
	leftHip = "Left Leg",
	rightHip = "Right Leg",
}
local R6_PARENT = {
	Torso = "HumanoidRootPart",
	["Right Arm"] = "Torso",
	["Left Arm"] = "Torso",
	["Right Leg"] = "Torso",
	["Left Leg"] = "Torso",
}

local cache: { [string]: string } = {}
local failed = false
local warnedFail = false

export type Frame = { t: number, pose: { [string]: { number } } }
export type Opts = { loop: boolean?, priority: Enum.AnimationPriority?, joints: { string }? }

function AnimBuilder.Available(): boolean
	return not failed
end

local function isR6(model: Model): boolean
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.RigType == Enum.HumanoidRigType.R6
end

-- Rotation of the joint's anchor (C0 or Attachment0) for a part, so poses written in the
-- parent part's axes become the joint's Transform: T = R^-1 * offset * R.
local function anchorRotation(model: Model, partName: string): CFrame
	local part = model:FindFirstChild(partName)
	if part and part:IsA("BasePart") then
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d.Part1 == part then
				local base = d:GetAttribute("BaseAnchor")
				local c0: CFrame = if typeof(base) == "CFrame" then base else d.C0
				return c0.Rotation
			elseif d:IsA("AnimationConstraint") then
				local a0, a1 = d.Attachment0, d.Attachment1
				if a0 and a1 and a1.Parent == part then
					return a0.CFrame.Rotation
				end
			end
		end
	end
	return CFrame.new()
end

-- {rx, ry, rz [, tx, ty, tz]}: degrees, plus an optional shift in studs (used on the root to
-- crouch, lunge and recoil the whole body).
local function angles(a: { number }): CFrame
	return CFrame.new(a[4] or 0, a[5] or 0, a[6] or 0) * CFrame.Angles(math.rad(a[1] or 0), math.rad(a[2] or 0), math.rad(a[3] or 0))
end

-- Builds (once per key + rig type) and registers an animation. Returns its id or nil.
function AnimBuilder.Get(key: string, frames: { Frame }, opts: Opts, model: Model): string?
	if failed then
		return nil
	end
	local r6 = isR6(model)
	local fullKey = (if r6 then "R6:" else "R15:") .. key
	local cached = cache[fullKey]
	if cached then
		return cached
	end
	local partOf = if r6 then R6_PART else R15_PART
	local parentOf: { [string]: string } = if r6 then R6_PARENT else R15_PARENT

	-- Joints this animation drives (only these override other animations).
	local used: { [string]: boolean } = {}
	if opts.joints then
		for _, k in opts.joints do
			used[k] = true
		end
	else
		for _, f in frames do
			for k in f.pose do
				used[k] = true
			end
		end
	end
	local partKey: { [string]: string } = {}
	local rot: { [string]: CFrame } = {}
	local needed: { [string]: boolean } = {}
	for k in used do
		local partName = partOf[k]
		if partName then
			partKey[partName] = k
			rot[partName] = anchorRotation(model, partName)
			local p: string? = partName
			while p and p ~= "HumanoidRootPart" do
				needed[p] = true
				p = parentOf[p]
			end
		end
	end

	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = key
	kfs.Loop = opts.loop == true
	kfs.Priority = opts.priority or Enum.AnimationPriority.Action
	for _, f in frames do
		local kf = Instance.new("Keyframe")
		kf.Time = f.t
		local posesByPart: { [string]: Pose } = {}
		local rootPose = Instance.new("Pose")
		rootPose.Name = "HumanoidRootPart"
		rootPose.Weight = 0
		rootPose.Parent = kf
		posesByPart.HumanoidRootPart = rootPose
		-- Create poses parent-first.
		local function ensure(partName: string): Pose
			local existing = posesByPart[partName]
			if existing then
				return existing
			end
			local parent = ensure(parentOf[partName])
			local pose = Instance.new("Pose")
			pose.Name = partName
			pose.EasingStyle = Enum.PoseEasingStyle.Cubic
			pose.EasingDirection = Enum.PoseEasingDirection.InOut
			local k = partKey[partName]
			if k then
				local a = f.pose[k] or { 0, 0, 0 }
				local r = rot[partName]
				local cf = angles(a)
				-- Rotation in the parent's axes; the shift stays in the parent's axes too.
				pose.CFrame = CFrame.new(r:Inverse() * cf.Position) * (r:Inverse() * cf.Rotation * r)
				pose.Weight = 1
			else
				pose.Weight = 0 -- hierarchy only
			end
			pose.Parent = parent
			posesByPart[partName] = pose
			return pose
		end
		for partName in needed do
			ensure(partName)
		end
		kf.Parent = kfs
	end

	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
	end)
	if not ok or type(id) ~= "string" then
		failed = true
		if not warnedFail then
			warnedFail = true
			warn("[AnimBuilder] could not register generated animations, falling back to joint posing:", id)
		end
		return nil
	end
	if next(cache) == nil then
		print("[AnimBuilder] generated body animations active (stances, swings, guards, walks)")
	end
	cache[fullKey] = id
	return id
end

return AnimBuilder
