--!strict
-- LostEmberService: Souls-style death penalty. When you die you drop part of your carried
-- Ember (EconomyConfig.DeathDrop) where you fell (profile.lostEmber). Walk back to it to recover
-- it; die again before that and the old pile is gone. Not in boss arenas, not in the hub.
-- The client (LostEmberController) shows the pile; the server checks the distance itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local HubConfig = require(Config:WaitForChild("HubConfig"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local LostEmberService = { Name = "LostEmberService", Priority = 36 }

local CFG = EconomyConfig.DeathDrop

local function lost(data: any): { amount: number, x: number, y: number, z: number }
	if type(data.lostEmber) ~= "table" then
		data.lostEmber = { amount = 0, x = 0, y = 0, z = 0 }
	end
	return data.lostEmber
end

local function inHub(pos: Vector3): boolean
	local o = HubConfig.Origin
	return (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(o[1], 0, o[3])).Magnitude <= CFG.hubSafeRadius
end

local function onDied(player: Player, root: BasePart)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local pile = lost(data)
	local pos = root.Position
	if pile.amount > 0 then
		Net.Server.Fire("Notify", player, "Error", string.format("Your lost %d Ember is gone.", pile.amount))
		pile.amount = 0
	end
	if player:GetAttribute("InArena") == true or inHub(pos) or pos.Y < -50 then
		DataService.Changed(player, "lostEmber")
		return
	end
	local amount = math.floor(data.ember * CFG.fraction)
	if amount >= CFG.minimum then
		data.ember -= amount
		pile.amount, pile.x, pile.y, pile.z = amount, pos.X, pos.Y, pos.Z
		DataService.Changed(player, "ember")
		Net.Server.Fire("Notify", player, "Error", string.format("You dropped %d Ember where you fell. Go back for it.", amount))
	end
	DataService.Changed(player, "lostEmber")
end

function LostEmberService.Init() end

function LostEmberService.Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			local hum = character:WaitForChild("Humanoid", 10)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if hum and hum:IsA("Humanoid") and root and root:IsA("BasePart") then
				hum.Died:Connect(function()
					onDied(player, root)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	-- Recovery check (2 Hz).
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		for _, player in Players:GetPlayers() do
			local data = DataService.GetData(player)
			local pile = data and lost(data)
			if data and pile and pile.amount > 0 then
				local ch = player.Character
				local root = ch and ch:FindFirstChild("HumanoidRootPart")
				local hum = ch and ch:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and hum and hum.Health > 0 and (root.Position - Vector3.new(pile.x, pile.y, pile.z)).Magnitude <= CFG.recoverRadius then
					local amount = pile.amount
					pile.amount = 0
					ProgressionService.AddEmber(player, amount, "Recovered", false)
					DataService.Changed(player, "lostEmber")
					Net.Server.Fire("Notify", player, "Info", string.format("Recovered %d Ember.", amount))
				end
			end
		end
	end)
end

return LostEmberService
