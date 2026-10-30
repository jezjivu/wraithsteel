--!strict
-- CombatController: turns ActionPressed into CombatAction requests (with an increasing seq),
-- buffers presses during the local player's current move, predicts the combo move for instant
-- animation, dashes on dodge, and relays server CombatEvents to EffectsController.
-- The server decides everything; this is presentation + requests only.
-- Animations: uploaded animationIds play when present, otherwise AnimationController poses.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local InputConfig = require(Config:WaitForChild("InputConfig"))
local CombatConfig = require(Config:WaitForChild("CombatConfig"))

local InputController = require(script.Parent.InputController)
local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)
local DataController = require(script.Parent.DataController)

local PLACEHOLDER_ANIM = "rbxassetid://0"

local CombatController = {
	Name = "CombatController",
	Priority = 20,
	-- (payload) for UI: Damage / Telegraph / Action / Rejected
	EventReceived = Signal.new(),
	-- (action, moveId?) fired when the local player sends an action (sounds/effects)
	LocalAction = Signal.new(),
}

local localPlayer = Players.LocalPlayer
local seq = 0
local predictedBusyUntil = 0
local buffered: { action: string, at: number }? = nil
local tracks: { [string]: AnimationTrack } = {}

local function playAnimation(animationId: string?)
	if animationId == nil or animationId == PLACEHOLDER_ANIM then
		return -- no animation uploaded yet
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return
	end
	local track: AnimationTrack? = tracks[animationId]
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = animationId
		local loaded = animator:LoadAnimation(anim)
		tracks[animationId] = loaded
		track = loaded
	end
	(track :: AnimationTrack):Play(0.05)
end

-- Local prediction of which move the server will run (mirrors Logic/CombatRules combo rules).
-- Only used for animation/buffering; the server's decision is authoritative.
local comboIndex = 0
local lastLightAt = -math.huge

local function predictMove(action: string): string?
	local weapon = WeaponConfig.Weapons[DataController.Get("equippedWeapon") or ""]
	if weapon == nil then
		return nil
	end
	if action == "HeavyAttack" then
		return weapon.heavy
	elseif action == "LightAttack" then
		local now = os.clock()
		if now - lastLightAt <= CombatConfig.Validation.ComboResetSeconds and comboIndex < #weapon.lightCombo then
			comboIndex += 1
		else
			comboIndex = 1
		end
		lastLightAt = now
		return weapon.lightCombo[comboIndex]
	end
	return weapon.skills[action]
end

-- Dodge dash: the client owns its character's physics, so it moves itself; the server only
-- grants i-frames (and will sanity-check positions later, see PROGRESS risks).
local function dash()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = -root.CFrame.LookVector -- no input: hop backward
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local speed = CombatConfig.DodgeDistance / CombatConfig.DodgeDuration
	local untilT = os.clock() + CombatConfig.DodgeDuration
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if os.clock() >= untilT or root.Parent == nil then
			conn:Disconnect()
			return
		end
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
	end)
end

-- Soft lock-on: the nearest living enemy in front of the camera within AimAssist range,
-- otherwise the camera's horizontal look direction.
local function aimDirection(): Vector3?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if root == nil or not root:IsA("BasePart") or cam == nil then
		return nil
	end
	local look = cam.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 1e-3 then
		return nil
	end
	flatLook = flatLook.Unit
	-- A lock-on target always wins.
	local locked = CameraController.Target()
	local lockedRoot = locked and locked:FindFirstChild("HumanoidRootPart")
	if lockedRoot and lockedRoot:IsA("BasePart") then
		local d = lockedRoot.Position - root.Position
		local flat = Vector3.new(d.X, 0, d.Z)
		if flat.Magnitude > 0.1 then
			return flat.Unit
		end
	end
	local cfg = CombatConfig.AimAssist
	local best, bestScore = nil, math.huge
	local cosLimit = math.cos(math.rad(cfg.coneDegrees))
	for _, model in CollectionService:GetTagged("Combatant") do
		if model:IsA("Model") and model ~= character and Players:GetPlayerFromCharacter(model) == nil then
			local hum = model:FindFirstChildOfClass("Humanoid")
			local troot = model:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and troot and troot:IsA("BasePart") then
				local d = troot.Position - root.Position
				local flat = Vector3.new(d.X, 0, d.Z)
				local dist = flat.Magnitude
				if dist > 0.1 and dist <= cfg.range then
					local dir = flat / dist
					local dot = dir:Dot(flatLook)
					if dot >= cosLimit then
						local score = dist * (2 - dot)
						if score < bestScore then
							best, bestScore = dir, score
						end
					end
				end
			end
		end
	end
	return best or flatLook
end

local function faceToward(dir: Vector3)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local pos = root.Position
		root.CFrame = CFrame.lookAt(pos, pos + dir)
	end
end

local function send(action: string)
	seq += 1
	local aim = if action == "Dodge" or action == "Parry" then nil else aimDirection()
	if aim and CombatConfig.AimAssist.faceOnAttack then
		faceToward(aim)
	end
	Net.Client.Fire("CombatAction", { action = action, seq = seq, aim = aim })
	local character = localPlayer.Character
	if action == "Dodge" then
		dash()
	end
	local moveId = if action == "Dodge" or action == "Parry" then nil else predictMove(action)
	local move = moveId and WeaponConfig.Moves[moveId]
	if move then
		predictedBusyUntil = os.clock() + move.windup + move.active + move.recovery
	end
	if move and move.animationId ~= PLACEHOLDER_ANIM then
		playAnimation(move.animationId)
	elseif character then
		AnimationController.Play(character, action, moveId)
	end
	CombatController.LocalAction:Fire(action, moveId)
end

local function onAction(action: string)
	local now = os.clock()
	if now < predictedBusyUntil and action ~= "Dodge" then
		buffered = { action = action, at = now }
		return
	end
	send(action)
end

function CombatController.Init() end

function CombatController.Start()
	InputController.ActionPressed:Connect(onAction)

	-- Release buffered input when the predicted move ends.
	task.spawn(function()
		while true do
			task.wait(0.03)
			local b = buffered
			if b and os.clock() >= predictedBusyUntil then
				buffered = nil
				-- Only presses made shortly before the move ended are replayed.
				if predictedBusyUntil - b.at <= InputConfig.BufferSeconds then
					send(b.action)
				end
			end
		end
	end)

	Net.Client.On("CombatEvent", function(payload)
		if payload.kind == "Rejected" then
			predictedBusyUntil = 0
			comboIndex = 0
		end
		CombatController.EventReceived:Fire(payload)
	end)
end

return CombatController
