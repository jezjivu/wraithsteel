--!strict
-- AnimationController: procedural combat animation (no uploaded assets needed).
-- Every frame (RunService.Stepped, after the default Animate script has posed the rig) it
-- layers combat poses from AnimationConfig onto the R15 joints of any character that is
-- attacking, guarding or dodging, timed by the move's windup/active/recovery from WeaponConfig.
-- Runs on every client for every visible character, driven by local input (own character)
-- and CombatEvent "Action" broadcasts (everyone else).
-- If a move has a real uploaded animationId, CombatController plays that instead.
--
-- API:
--   AnimationController.Play(model, action, moveId?, timing?)
--   AnimationController.StyleFor(action, moveId?) -> string

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Config = ReplicatedStorage:WaitForChild("Config")
local AnimationConfig = require(Config:WaitForChild("AnimationConfig"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local CombatConfig = require(Config:WaitForChild("CombatConfig"))

local AnimationController = { Name = "AnimationController", Priority = 15 }

type Joints = {
	shoulder: Motor6D?,
	elbow: Motor6D?,
	leftShoulder: Motor6D?,
	waist: Motor6D?,
	root: Motor6D?,
}

type Playing = {
	style: AnimationConfig.Style,
	start: number,
	windup: number,
	active: number,
	recovery: number,
	joints: Joints,
}

local playing: { [Model]: Playing } = {}

local function findMotor(model: Model, partName: string, jointName: string): Motor6D?
	local part = model:FindFirstChild(partName)
	local j = part and part:FindFirstChild(jointName)
	if j and j:IsA("Motor6D") then
		return j
	end
	return nil
end

local function joints(model: Model): Joints
	return {
		shoulder = findMotor(model, "RightUpperArm", "RightShoulder"),
		elbow = findMotor(model, "RightLowerArm", "RightElbow"),
		leftShoulder = findMotor(model, "LeftUpperArm", "LeftShoulder"),
		waist = findMotor(model, "UpperTorso", "Waist"),
		root = findMotor(model, "LowerTorso", "Root"),
	}
end

function AnimationController.StyleFor(action: string, moveId: string?): string
	if action == "Parry" then
		return "Guard"
	elseif action == "Dodge" then
		return "Dodge"
	elseif action == "Ultimate" then
		return "Ultimate"
	elseif action == "HeavyAttack" and moveId == nil then
		return "Overhead" -- enemy heavy/perilous telegraphs
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
function AnimationController.Play(model: Model, action: string, moveId: string?, timing: Timing?)
	local styleName = AnimationController.StyleFor(action, moveId)
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
		windup, active, recovery = move.windup, math.max(move.active, 0.08), move.recovery
	end
	playing[model] = {
		style = style,
		start = os.clock(),
		windup = windup,
		active = active,
		recovery = recovery,
		joints = joints(model),
	}
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

local JOINTS = { "shoulder", "elbow", "leftShoulder", "waist", "root" }

-- Returns the attack/guard offsets for this frame, or nil when the animation has finished.
local function attackOffsets(p: Playing, now: number): { [string]: CFrame }?
	local t = now - p.start
	local fromPose: AnimationConfig.Pose, toPose: AnimationConfig.Pose, k: number
	local empty: AnimationConfig.Pose = {}
	local spinAngle = 0
	if t < p.windup then
		fromPose, toPose, k = empty, p.style.windup, ease(t / p.windup)
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
			return nil
		end
		fromPose, toPose, k = p.style.strike, empty, if r < hold then 0 else ease((r - hold) / out)
	end
	local offsets: { [string]: CFrame } = {}
	for _, name in JOINTS do
		local offset = lerpAngles((fromPose :: any)[name], (toPose :: any)[name], k)
		if name == "root" and spinAngle ~= 0 then
			offset = (offset or CFrame.new()) * CFrame.Angles(0, math.rad(spinAngle), 0)
		end
		if offset then
			offsets[name] = offset
		end
	end
	return offsets
end

-- NPC rigs (code-built enemies/bosses) have no Animate script, so this controller owns their
-- joints completely: a procedural walk cycle plus any attack pose, written as absolute values.
type Npc = { motors: { [string]: Motor6D }, phase: number }
local npcs: { [Model]: Npc } = {}

local NPC_JOINTS: { [string]: { string } } = {
	shoulder = { "RightUpperArm", "RightShoulder" },
	elbow = { "RightLowerArm", "RightElbow" },
	leftShoulder = { "LeftUpperArm", "LeftShoulder" },
	waist = { "UpperTorso", "Waist" },
	root = { "LowerTorso", "Root" },
	leftHip = { "LeftUpperLeg", "LeftHip" },
	rightHip = { "RightUpperLeg", "RightHip" },
	leftKnee = { "LeftLowerLeg", "LeftKnee" },
	rightKnee = { "RightLowerLeg", "RightKnee" },
}

local function trackNpc(model: Instance)
	if not model:IsA("Model") or Players:GetPlayerFromCharacter(model) then
		return
	end
	local motors: { [string]: Motor6D } = {}
	for key, path in NPC_JOINTS do
		local m = findMotor(model, path[1], path[2])
		if m then
			motors[key] = m
		end
	end
	if next(motors) then
		npcs[model] = { motors = motors, phase = 0 }
	end
end

local function walkOffsets(model: Model, npc: Npc, dt: number): { [string]: CFrame }
	local root = model:FindFirstChild("HumanoidRootPart")
	local speed = 0
	if root and root:IsA("BasePart") then
		local v = root.AssemblyLinearVelocity
		speed = Vector3.new(v.X, 0, v.Z).Magnitude
	end
	local cfg = AnimationConfig.Walk
	local amount = math.clamp(speed / cfg.fullSpeed, 0, 1)
	npc.phase += dt * cfg.cyclesPerSecond * math.pi * 2 * math.max(amount, 0.2)
	local swing = math.sin(npc.phase) * math.rad(cfg.legSwingDegrees) * amount
	local arm = math.sin(npc.phase) * math.rad(cfg.armSwingDegrees) * amount
	local bend = math.rad(cfg.kneeBendDegrees) * amount
	local breathe = math.sin(os.clock() * 2) * math.rad(cfg.idleBreathDegrees)
	return {
		leftHip = CFrame.Angles(swing, 0, 0),
		rightHip = CFrame.Angles(-swing, 0, 0),
		leftKnee = CFrame.Angles(-bend * math.max(0, math.sin(npc.phase)), 0, 0),
		rightKnee = CFrame.Angles(-bend * math.max(0, -math.sin(npc.phase)), 0, 0),
		leftShoulder = CFrame.Angles(-arm, 0, 0),
		shoulder = CFrame.Angles(arm, 0, 0),
		waist = CFrame.Angles(breathe, 0, 0),
	}
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
		npcs[m :: any] = nil
	end)

	RunService.Stepped:Connect(function(_, dt)
		local now = os.clock()
		-- Players: layer attack poses on top of the default Animate script's pose.
		for model, p in playing do
			if model.Parent == nil then
				playing[model] = nil
			elseif npcs[model] == nil then
				local offsets = attackOffsets(p, now)
				if offsets == nil then
					playing[model] = nil
				else
					for name, offset in offsets do
						local motor = (p.joints :: any)[name] :: Motor6D?
						if motor and motor.Parent then
							motor.Transform = motor.Transform * offset
						end
					end
				end
			end
		end
		-- NPCs: absolute pose = walk cycle combined with any attack pose.
		for model, npc in npcs do
			if model.Parent == nil then
				npcs[model] = nil
				playing[model] = nil
				continue
			end
			local pose = walkOffsets(model, npc, dt)
			local p = playing[model]
			if p then
				local attack = attackOffsets(p, now)
				if attack == nil then
					playing[model] = nil
				else
					for name, offset in attack do
						pose[name] = (pose[name] or CFrame.new()) * offset
					end
				end
			end
			for name, motor in npc.motors do
				if motor.Parent then
					motor.Transform = pose[name] or CFrame.new()
				end
			end
		end
	end)
end

return AnimationController
