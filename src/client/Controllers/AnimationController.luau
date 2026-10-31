--!strict
-- AnimationController: procedural body animation (no uploaded assets needed).
--
-- Every character holding a weapon stands in a combat stance (sword ready, knees bent) and
-- every swing, guard, dodge, flip and cast moves the WHOLE body - arms, torso, hips, legs -
-- with the weapon, timed by the move's windup / active / recovery from WeaponConfig.
-- Runs on every client for every visible character (own input + CombatEvent broadcasts).
--
-- How joints are posed: each joint's anchor (Motor6D.C0, or Attachment0.CFrame for the newer
-- AnimationConstraint avatar joints) is rotated in the parent part's axes:
--     anchor = CFrame.new(base.Position) * offset * base.Rotation
-- The Animator owns Motor6D.Transform / AnimationConstraint.Transform and overwrites them
-- every frame, so the anchor is the only place a script pose reliably shows up. Works for
-- R15 and R6 rigs, with Motor6D or AnimationConstraint joints.
--
-- API:
--   AnimationController.Play(model, action, moveId?, timing?, route?, speed?)
--   AnimationController.StyleFor(action, moveId?, route?) -> string
--   AnimationController.HitStop(seconds, scale)   -- freeze-frame feel on big impacts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Config = ReplicatedStorage:WaitForChild("Config")
local AnimationConfig = require(Config:WaitForChild("AnimationConfig"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local CombatConfig = require(Config:WaitForChild("CombatConfig"))
local MovementConfig = require(Config:WaitForChild("MovementConfig"))

local AnimationController = { Name = "AnimationController", Priority = 15 }

-- Joints -------------------------------------------------------------------------------------
-- Pose key -> the moving part (Part1) on R15, then on R6.
local JOINT_PARTS: { [string]: { string } } = {
	shoulder = { "RightUpperArm", "Right Arm" },
	elbow = { "RightLowerArm" },
	leftShoulder = { "LeftUpperArm", "Left Arm" },
	leftElbow = { "LeftLowerArm" },
	waist = { "UpperTorso" },
	root = { "LowerTorso", "Torso" },
	leftHip = { "LeftUpperLeg", "Left Leg" },
	rightHip = { "RightUpperLeg", "Right Leg" },
	leftKnee = { "LeftLowerLeg" },
	rightKnee = { "RightLowerLeg" },
}
local JOINTS = { "shoulder", "elbow", "leftShoulder", "leftElbow", "waist", "root", "leftHip", "rightHip", "leftKnee", "rightKnee" }

-- The thing we write: a Motor6D (C0) or an AnimationConstraint's Attachment0 (CFrame).
type Joint = { anchor: Instance, prop: string }
type Rig = { joints: { [string]: Joint }, phase: number, npc: boolean, lean: CFrame, warned: boolean }

local rigs: { [Model]: Rig } = {}

local function findJoint(model: Model, partNames: { string }): Joint?
	for _, partName in partNames do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			-- Joints usually live inside the moving part; search the whole model as a fallback.
			for pass = 1, 2 do
				local list: { Instance } = if pass == 1 then part:GetChildren() else model:GetDescendants()
				for _, d in list do
					if d:IsA("Motor6D") and d.Part1 == part then
						return { anchor = d :: Instance, prop = "C0" }
					elseif d:IsA("AnimationConstraint") then
						local a0, a1 = d.Attachment0, d.Attachment1
						if a0 and a1 and a1.Parent == part then
							return { anchor = a0 :: Instance, prop = "CFrame" }
						end
					end
				end
			end
		end
	end
	return nil
end

local function rigOf(model: Model, npc: boolean): Rig?
	local rig = rigs[model]
	if rig then
		-- Rebuild if a joint was replaced (respawn, rig rebuild, scaling).
		local stale = false
		for _, j in rig.joints do
			if j.anchor.Parent == nil then
				stale = true
				break
			end
		end
		if not stale then
			return rig
		end
	end
	local joints: { [string]: Joint } = {}
	for key, parts in JOINT_PARTS do
		local j = findJoint(model, parts)
		if j then
			joints[key] = j
		end
	end
	if next(joints) == nil then
		if rig == nil or not rig.warned then
			local kinds = {}
			for _, d in model:GetDescendants() do
				if d:IsA("JointInstance") or d:IsA("Constraint") then
					kinds[d.ClassName] = true
				end
			end
			local list = {}
			for k in kinds do
				table.insert(list, k)
			end
			warn("[AnimationController] no posable joints on", model:GetFullName(), "joint types found:", table.concat(list, ", "))
		end
		rigs[model] = { joints = {}, phase = 0, npc = npc, lean = CFrame.new(), warned = true }
		return nil
	end
	local new: Rig = { joints = joints, phase = if rig then rig.phase else 0, npc = npc, lean = CFrame.new(), warned = false }
	rigs[model] = new
	return new
end

-- Base anchors (captured once per anchor, also saved as attribute BaseAnchor).
local baseOf: { [Instance]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local pending: { [Joint]: CFrame } = {}
local posedLast: { [Joint]: boolean } = {}

local function baseFor(j: Joint): CFrame
	local b = baseOf[j.anchor]
	if b then
		return b
	end
	local saved = j.anchor:GetAttribute("BaseAnchor")
	local base: CFrame = if typeof(saved) == "CFrame" then saved else (j.anchor :: any)[j.prop]
	baseOf[j.anchor] = base
	j.anchor:SetAttribute("BaseAnchor", base)
	return base
end

local function pose(j: Joint, offset: CFrame)
	baseFor(j)
	local cur = pending[j]
	pending[j] = if cur then cur * offset else offset
end

local lastOffset: { [Joint]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function flushPoses()
	for j, offset in pending do
		lastOffset[j] = offset
		if j.anchor.Parent then
			local base = baseOf[j.anchor]
			;(j.anchor :: any)[j.prop] = CFrame.new(base.Position) * offset * base.Rotation
		end
		posedLast[j] = true
	end
	for j in posedLast do
		if not pending[j] then
			posedLast[j] = nil
			local base = baseOf[j.anchor]
			if base and j.anchor.Parent then
				(j.anchor :: any)[j.prop] = base
			end
		end
	end
	table.clear(pending)
end

-- Playing moves --------------------------------------------------------------------------------
type Playing = {
	style: AnimationConfig.Style,
	start: number,
	windup: number,
	active: number,
	recovery: number,
	rest: AnimationConfig.Pose, -- stance the move starts from and returns to
	grip: Weld?, -- HeldWeapon grip weld (swung around its BaseC0)
	trail: Trail?,
}

local playing: { [Model]: Playing } = {}

-- Finds the held weapon's grip weld and trail on a rig (players and NPCs).
local function weaponParts(model: Model): (Weld?, Trail?)
	local held = model:FindFirstChild("HeldWeapon")
	local handle = held and held:FindFirstChild("Handle")
	if handle == nil then
		return nil, nil
	end
	local weld = handle:FindFirstChild("GripWeld")
	local trail = handle:FindFirstChild("SwingTrail")
	return (if weld and weld:IsA("Weld") then weld else nil), (if trail and trail:IsA("Trail") then trail else nil)
end

local function restoreWeapon(p: Playing)
	local grip = p.grip
	if grip and grip.Parent then
		local base = grip:GetAttribute("BaseC0")
		if typeof(base) == "CFrame" then
			grip.C0 = base
		end
	end
	if p.trail then
		p.trail.Enabled = false
	end
end

-- Combat stance for whatever the model holds (empty pose when unarmed).
local EMPTY: AnimationConfig.Pose = {}
local function stanceFor(model: Model): AnimationConfig.Pose
	local held = model:FindFirstChild("HeldWeapon")
	if held == nil then
		return EMPTY
	end
	local id = held:GetAttribute("WeaponId")
	local def = if type(id) == "string" then WeaponConfig.Weapons[id] else nil
	local name = if def then AnimationConfig.StanceByClass[def.class] else nil
	return AnimationConfig.Stances[name or "OneHanded"] or EMPTY
end

-- Virtual animation clock: advances slower during hit-stop.
local vnow = 0
local timeScale = 1
local stopUntil = 0

function AnimationController.HitStop(seconds: number, scale: number)
	stopUntil = math.max(stopUntil, os.clock() + seconds)
	timeScale = math.min(timeScale, scale)
end

function AnimationController.StyleFor(action: string, moveId: string?, route: string?): string
	if route == "Air" then
		return "AirSlam"
	elseif route == "Dash" then
		return "DashStrike"
	elseif route == "Finisher" then
		return "Finisher"
	elseif action == "Flip" or action == "Stagger" then
		return action
	elseif action == "Parry" then
		return "Guard"
	elseif action == "Dodge" then
		return "Dodge"
	elseif action == "Ultimate" then
		return "Ultimate"
	elseif action == "HeavyAttack" and moveId == nil then
		return "Overhead" -- enemy heavy/perilous telegraphs
	elseif action == "AltAttack" then
		return "SlashLeft" -- enemy alternate swing
	elseif action == "Flinch" then
		return "Flinch"
	elseif AnimationConfig.Styles[action] then
		return action -- explicit style name (casts, perilous telegraphs, ...)
	end
	if moveId then
		local explicit = AnimationConfig.MoveStyles[moveId]
		if explicit then
			return explicit
		end
		local move = WeaponConfig.Moves[moveId]
		if move then
			if move.damage == 0 then
				return "Guard"
			elseif move.arcDegrees >= 300 then
				return "Spin"
			elseif move.arcDegrees <= 45 then
				return "Thrust"
			elseif action == "HeavyAttack" then
				return "Overhead"
			end
		end
		local n = tonumber(string.match(moveId, "(%d+)$"))
		if n and n % 2 == 0 then
			return "SlashLeft"
		end
	end
	return "SlashRight"
end

export type Timing = { windup: number, active: number, recovery: number }

-- timing overrides the move's frame data (used for enemy telegraphs, which have no moveId here).
function AnimationController.Play(model: Model, action: string, moveId: string?, timing: Timing?, route: string?, speed: number?)
	local styleName = AnimationController.StyleFor(action, moveId, route)
	local style = AnimationConfig.Styles[styleName]
	if style == nil then
		return
	end
	local windup, active, recovery
	if timing then
		windup, active, recovery = timing.windup, timing.active, timing.recovery
	elseif action == "Parry" then
		windup, active, recovery = 0.05, AnimationConfig.GuardHold, 0.1
	elseif action == "Dodge" then
		windup, active, recovery = 0.05, CombatConfig.DodgeDuration, 0.1
	else
		local move = moveId and WeaponConfig.Moves[moveId]
		if move == nil then
			return
		end
		local sp = speed or 1
		windup, active, recovery = move.windup / sp, math.max(move.active, 0.08), move.recovery / sp
	end
	local previous = playing[model]
	if previous then
		restoreWeapon(previous)
	end
	local grip, trail = weaponParts(model)
	playing[model] = {
		style = style,
		start = vnow,
		windup = math.max(windup, 0.03),
		active = math.max(active, 0.03),
		recovery = recovery,
		rest = stanceFor(model),
		grip = grip,
		trail = trail,
	}
end

-- Keeps a guard pose up while the guard button is held (Sekiro-style hold-to-guard).
function AnimationController.HoldGuard(model: Model, held: boolean)
	local p = playing[model]
	if held then
		AnimationController.Play(model, "Parry", nil, { windup = 0.06, active = 30, recovery = 0.12 })
	elseif p and p.style == AnimationConfig.Styles.Guard then
		-- Jump straight to the recovery part of the guard.
		p.start = vnow - p.windup - p.active
	end
end

local function angles(a: { number }?): CFrame
	if a == nil then
		return CFrame.new()
	end
	return CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3]))
end

local function lerpAngles(a: { number }?, b: { number }?, t: number): CFrame?
	if a == nil and b == nil then
		return nil
	end
	local x = a or { 0, 0, 0 }
	local y = b or { 0, 0, 0 }
	return CFrame.Angles(
		math.rad(x[1] + (y[1] - x[1]) * t),
		math.rad(x[2] + (y[2] - x[2]) * t),
		math.rad(x[3] + (y[3] - x[3]) * t)
	)
end

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) * (1 - t)
end

-- Joint angles of a pose, falling back to the rest stance for joints the pose leaves out.
local function jointOf(pose: AnimationConfig.Pose, rest: AnimationConfig.Pose, name: string): { number }?
	return (pose :: any)[name] or (rest :: any)[name]
end

-- Returns the full-body offsets for this frame, or nil when the move has finished.
local function attackOffsets(p: Playing, now: number): { [string]: CFrame }?
	local t = now - p.start
	local rest = p.rest
	local fromPose: AnimationConfig.Pose, toPose: AnimationConfig.Pose, k: number
	local spinAngle = 0
	if t < p.windup then
		fromPose, toPose, k = rest, p.style.windup, ease(t / p.windup)
	elseif t < p.windup + p.active then
		local a = (t - p.windup) / p.active
		fromPose, toPose, k = p.style.windup, p.style.strike, ease(a)
		if p.style.spin then
			spinAngle = a * 360
		end
	else
		local r = t - p.windup - p.active
		local hold = p.recovery * 0.4
		local out = math.max(AnimationConfig.BlendOut, p.recovery - hold)
		if r > hold + out then
			restoreWeapon(p)
			return nil
		end
		fromPose, toPose, k = p.style.strike, rest, if r < hold then 0 else ease((r - hold) / out)
	end
	-- Weapon swing around the grip (on top of the arm motion).
	local grip = p.grip
	if grip and grip.Parent then
		local base = grip:GetAttribute("BaseC0")
		if typeof(base) == "CFrame" then
			local wFrom = if fromPose == p.style.windup then p.style.weaponWindup elseif fromPose == p.style.strike then p.style.weaponStrike else nil
			local wTo = if toPose == p.style.windup then p.style.weaponWindup elseif toPose == p.style.strike then p.style.weaponStrike else nil
			local a = wFrom or { 0, 0, 0, 0 }
			local b = wTo or { 0, 0, 0, 0 }
			local function lerp(i: number): number
				local x, y = a[i] or 0, b[i] or 0
				return x + (y - x) * k
			end
			grip.C0 = base * CFrame.new(0, lerp(4), 0) * CFrame.Angles(math.rad(lerp(1)), math.rad(lerp(2)), math.rad(lerp(3)))
		end
	end
	if p.trail then
		p.trail.Enabled = t >= p.windup - AnimationConfig.TrailLead and t <= p.windup + p.active + AnimationConfig.TrailLinger
	end

	local offsets: { [string]: CFrame } = {}
	for _, name in JOINTS do
		local offset = lerpAngles(jointOf(fromPose, rest, name), jointOf(toPose, rest, name), k)
		if name == "root" and spinAngle ~= 0 then
			local spin = if p.style.spinAxis == "X" then CFrame.Angles(math.rad(-spinAngle), 0, 0) else CFrame.Angles(0, math.rad(spinAngle), 0)
			offset = (offset or CFrame.new()) * spin
		end
		if offset then
			offsets[name] = offset
		end
	end
	return offsets
end

local function speedOf(model: Model): number
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local v = root.AssemblyLinearVelocity
		return Vector3.new(v.X, 0, v.Z).Magnitude
	end
	return 0
end

-- Idle stance: arms always; legs only while standing still (the walk cycle owns them when moving).
local LEG_JOINTS = { leftHip = true, rightHip = true, leftKnee = true, rightKnee = true, root = true }
local function stanceOffsets(model: Model, speed: number): { [string]: CFrame }
	local stance = stanceFor(model)
	local out: { [string]: CFrame } = {}
	local still = 1 - math.clamp(speed / 6, 0, 1)
	local breathe = math.sin(os.clock() * 2.2) * AnimationConfig.Walk.idleBreathDegrees
	for name, a in stance :: any do
		if LEG_JOINTS[name] then
			if still > 0.01 then
				out[name] = CFrame.Angles(math.rad(a[1] * still), math.rad(a[2] * still), math.rad(a[3] * still))
			end
		else
			out[name] = angles(a)
		end
	end
	if out.waist or next(stance) then
		out.waist = (out.waist or CFrame.new()) * CFrame.Angles(math.rad(breathe), 0, 0)
	end
	return out
end

-- Procedural walk cycle for NPC rigs (they have no Animate script).
local function walkOffsets(rig: Rig, speed: number, dt: number, armed: boolean): { [string]: CFrame }
	local cfg = AnimationConfig.Walk
	local amount = math.clamp(speed / cfg.fullSpeed, 0, 1)
	rig.phase += dt * cfg.cyclesPerSecond * math.pi * 2 * math.max(amount, 0.2)
	local swing = math.sin(rig.phase) * math.rad(cfg.legSwingDegrees) * amount
	local arm = math.sin(rig.phase) * math.rad(cfg.armSwingDegrees) * amount * (if armed then 0.35 else 1)
	local bend = math.rad(cfg.kneeBendDegrees) * amount
	return {
		leftHip = CFrame.Angles(swing, 0, 0),
		rightHip = CFrame.Angles(-swing, 0, 0),
		leftKnee = CFrame.Angles(-bend * math.max(0, math.sin(rig.phase)), 0, 0),
		rightKnee = CFrame.Angles(-bend * math.max(0, -math.sin(rig.phase)), 0, 0),
		leftShoulder = CFrame.Angles(-arm, 0, 0),
		shoulder = CFrame.Angles(arm, 0, 0),
	}
end

local function isPlayerCharacter(model: Model): boolean
	return Players:GetPlayerFromCharacter(model) ~= nil
end

local frame = 0
local npcSet: { [Model]: boolean } = {}

local function trackNpc(model: Instance)
	if model:IsA("Model") and not isPlayerCharacter(model) then
		npcSet[model] = true
	end
end

-- Poses one rig for this frame.
local function animate(model: Model, rig: Rig, now: number, dt: number)
	local speed = speedOf(model)
	local armed = model:FindFirstChild("HeldWeapon") ~= nil
	local offsets: { [string]: CFrame }
	local p = playing[model]
	local attack = if p then attackOffsets(p, now) else nil
	if p and attack == nil then
		playing[model] = nil
	end
	offsets = attack or stanceOffsets(model, speed)
	if rig.npc then
		for name, w in walkOffsets(rig, speed, dt, armed) do
			offsets[name] = w * (offsets[name] or CFrame.new())
		end
	else
		-- Momentum lean (forward when running, bank on turns).
		local L = MovementConfig.Lean
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local v = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
			local fwd = math.clamp(-v.Z / L.fullSpeed, -1, 1)
			local side = math.clamp(v.X / L.fullSpeed, -1, 1)
			local target = CFrame.Angles(math.rad(-L.forwardDegrees * fwd), 0, math.rad(-L.sideDegrees * side))
			rig.lean = rig.lean:Lerp(target, math.min(1, dt * L.smoothing))
			offsets.root = rig.lean * (offsets.root or CFrame.new())
		end
	end
	for name, offset in offsets do
		local j = rig.joints[name]
		if j then
			pose(j, offset)
		end
	end
end

function AnimationController.Init() end

function AnimationController.Start()
	for _, m in CollectionService:GetTagged("Combatant") do
		trackNpc(m)
	end
	CollectionService:GetInstanceAddedSignal("Combatant"):Connect(function(m)
		task.defer(trackNpc, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Combatant"):Connect(function(m)
		npcSet[m :: any] = nil
		rigs[m :: any] = nil
	end)

	-- PreSimulation (= Stepped) runs after the Animator has posed the rig this frame.
	RunService.PreSimulation:Connect(function(dt: number)
		if os.clock() >= stopUntil then
			timeScale = 1
		end
		vnow += dt * timeScale
		local now = vnow
		frame += 1
		local cam = workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero

		for _, plr in Players:GetPlayers() do
			local ch = plr.Character
			if ch and ch.Parent then
				local rig = rigOf(ch, false)
				if rig then
					animate(ch, rig, now, dt)
				end
			end
		end
		-- NPCs. LOD: far ones are not animated (unless mid-attack); mid-distance every other frame.
		for model in npcSet do
			if model.Parent == nil then
				npcSet[model] = nil
				rigs[model] = nil
				playing[model] = nil
				continue
			end
			local root = model.PrimaryPart
			if root and playing[model] == nil then
				local d = (root.Position - camPos).Magnitude
				if d > AnimationConfig.Lod.far or (d > AnimationConfig.Lod.near and frame % 2 == 0) then
					-- Hold the last pose instead of snapping back to neutral.
					local rig = rigs[model]
					if rig then
						for _, j in rig.joints do
							local last = lastOffset[j]
							if last and not pending[j] then
								pending[j] = last
							end
						end
					end
					continue
				end
			end
			local rig = rigOf(model, true)
			if rig then
				animate(model, rig, now, dt)
			end
		end
		for model in playing do
			if model.Parent == nil then
				playing[model] = nil
			end
		end
		for model in rigs do
			if model.Parent == nil then
				rigs[model] = nil
			end
		end
		flushPoses()
	end)
end

return AnimationController
