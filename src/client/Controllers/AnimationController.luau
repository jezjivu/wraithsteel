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

local function apply(p: Playing, now: number): boolean
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
			return false
		end
		fromPose, toPose, k = p.style.strike, empty, if r < hold then 0 else ease((r - hold) / out)
	end
	for _, name in JOINTS do
		local motor = (p.joints :: any)[name] :: Motor6D?
		if motor and motor.Parent then
			local offset = lerpAngles((fromPose :: any)[name], (toPose :: any)[name], k)
			if name == "root" and spinAngle ~= 0 then
				offset = (offset or CFrame.new()) * CFrame.Angles(0, math.rad(spinAngle), 0)
			end
			if offset then
				motor.Transform = motor.Transform * offset
			end
		end
	end
	return true
end

function AnimationController.Init() end

function AnimationController.Start()
	RunService.Stepped:Connect(function()
		local now = os.clock()
		for model, p in playing do
			if model.Parent == nil or not apply(p, now) then
				playing[model] = nil
			end
		end
	end)
end

return AnimationController
