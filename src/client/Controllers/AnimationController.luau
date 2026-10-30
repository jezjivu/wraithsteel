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
--   AnimationController.Play(model, action, moveId?, timing?, route?, speed?)
--   AnimationController.StyleFor(action, moveId?, route?) -> string
--   AnimationController.HitStop(seconds, scale)   -- freeze-frame feel on big impacts
-- Player characters also lean into their movement (momentum lean) every frame.

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

type Joints = {
	shoulder: Motor6D?,
	elbow: Motor6D?,
	leftShoulder: Motor6D?,
	waist: Motor6D?,
	root: Motor6D?,
	leftHip: Motor6D?,
	rightHip: Motor6D?,
	leftKnee: Motor6D?,
	rightKnee: Motor6D?,
}

type Playing = {
	style: AnimationConfig.Style,
	start: number,
	windup: number,
	active: number,
	recovery: number,
	joints: Joints,
	grip: Weld?, -- HeldWeapon grip weld (swung around its BaseC0)
	trail: Trail?,
}

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
		leftHip = findMotor(model, "LeftUpperLeg", "LeftHip"),
		rightHip = findMotor(model, "RightUpperLeg", "RightHip"),
		leftKnee = findMotor(model, "LeftLowerLeg", "LeftKnee"),
		rightKnee = findMotor(model, "RightLowerLeg", "RightKnee"),
	}
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
		windup = windup,
		active = active,
		recovery = recovery,
		joints = joints(model),
		grip = grip,
		trail = trail,
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

local JOINTS = { "shoulder", "elbow", "leftShoulder", "waist", "root", "leftHip", "rightHip", "leftKnee", "rightKnee" }

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
			restoreWeapon(p)
			return nil
		end
		fromPose, toPose, k = p.style.strike, empty, if r < hold then 0 else ease((r - hold) / out)
	end
	-- Weapon swing around the grip (works for any rig, even without arm joints).
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
		local offset = lerpAngles((fromPose :: any)[name], (toPose :: any)[name], k)
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

-- NPC rigs (code-built enemies/bosses) have no Animate script, so this controller owns their
-- joints completely: a procedural walk cycle plus any attack pose, written as absolute values.
type Npc = { motors: { [string]: Motor6D }, phase: number }
local npcs: { [Model]: Npc } = {}
local frame = 0

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

	local lean: { [Model]: CFrame } = {}
	RunService.Stepped:Connect(function(_, dt: number)
		if os.clock() >= stopUntil then
			timeScale = 1
		end
		vnow += dt * timeScale
		local now = vnow
		-- Momentum lean for every player character (forward lean when running, bank on turns).
		local L = MovementConfig.Lean
		for _, plr in Players:GetPlayers() do
			local ch = plr.Character
			local rootPart = ch and ch:FindFirstChild("HumanoidRootPart")
			local motor = ch and findMotor(ch, "LowerTorso", "Root")
			if ch and rootPart and rootPart:IsA("BasePart") and motor then
				local v = rootPart.CFrame:VectorToObjectSpace(rootPart.AssemblyLinearVelocity)
				local fwd = math.clamp(-v.Z / L.fullSpeed, -1, 1)
				local side = math.clamp(v.X / L.fullSpeed, -1, 1)
				local target = CFrame.Angles(math.rad(-L.forwardDegrees * fwd), 0, math.rad(-L.sideDegrees * side))
				local cur = (lean[ch] or CFrame.new()):Lerp(target, math.min(1, dt * L.smoothing))
				lean[ch] = cur
				motor.Transform = motor.Transform * cur
			end
		end
		for ch in lean do
			if ch.Parent == nil then
				lean[ch] = nil
			end
		end
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
		-- LOD: NPCs far from the camera are not animated at all (unless mid-attack), and
		-- mid-distance ones update every other frame.
		local cam = workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		frame += 1
		for model, npc in npcs do
			if model.Parent == nil then
				npcs[model] = nil
				playing[model] = nil
				continue
			end
			local root = model.PrimaryPart
			if root and playing[model] == nil then
				local d = (root.Position - camPos).Magnitude
				if d > AnimationConfig.Lod.far or (d > AnimationConfig.Lod.near and frame % 2 == 0) then
					continue
				end
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
