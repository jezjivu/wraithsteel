--!strict
-- CombatController: turns ActionPressed into CombatAction requests (with an increasing seq),
-- buffers presses during the local player's current move, plays local feedback and reacts to
-- server CombatEvents. The server decides everything; this is presentation + requests only.
-- TODO(Studio/Agent B): animations (WeaponConfig move animationId are placeholders "rbxassetid://0"),
-- swing VFX/SFX, hit-stop, camera shake, parry spark, perilous red flash UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local InputConfig = require(Config:WaitForChild("InputConfig"))

local InputController = require(script.Parent.InputController)
local DataController = require(script.Parent.DataController)

local PLACEHOLDER_ANIM = "rbxassetid://0"

local CombatController = {
	Name = "CombatController",
	Priority = 20,
	-- (payload) for UI: Damage / Telegraph / Action / Rejected
	EventReceived = Signal.new(),
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

-- Rough local estimate of move duration for buffering; the server's timing is authoritative.
local function estimateDuration(action: string): (number, string?)
	local weapon = WeaponConfig.Weapons[DataController.Get("equippedWeapon") or ""]
	if weapon == nil then
		return 0, nil
	end
	local moveId: string? = nil
	if action == "HeavyAttack" then
		moveId = weapon.heavy
	elseif action == "LightAttack" then
		moveId = weapon.lightCombo[1]
	else
		moveId = weapon.skills[action]
	end
	local move = moveId and WeaponConfig.Moves[moveId]
	if move == nil then
		return 0, nil
	end
	return move.windup + move.active + move.recovery, move.animationId
end

local function send(action: string)
	seq += 1
	Net.Client.Fire("CombatAction", { action = action, seq = seq })
	local duration, animationId = estimateDuration(action)
	if action ~= "Dodge" and action ~= "Parry" then
		predictedBusyUntil = os.clock() + duration
	end
	playAnimation(animationId)
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
		elseif payload.kind == "Telegraph" then
			-- TODO(Studio/Agent B): play enemy windup anim on payload.sourceId's model; red flash if perilous.
		end
		CombatController.EventReceived:Fire(payload)
	end)
end

return CombatController
