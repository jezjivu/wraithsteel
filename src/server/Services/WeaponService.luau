--!strict
-- WeaponService: buying and equipping weapons, and showing the equipped weapon in the
-- character's hand (built by Shared/WeaponModels, visible to everyone).
-- Prices are fixed (never random), so no odds/policy gating is needed.
--
-- API:
--   WeaponService.Buy(player, weaponId) -> (ok, message)
--   WeaponService.Equip(player, weaponId) -> boolean
--   WeaponService.CanBuy(data, weaponId) -> (ok, reason?)   pure check, used by Buy

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))

local WeaponLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("WeaponLogic"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local WeaponService = { Name = "WeaponService", Priority = 25 }

local HELD_NAME = "HeldWeapon"

WeaponService.CanBuy = WeaponLogic.CanBuy

local function attach(player: Player)
	local character = player.Character
	local data = DataService.GetData(player)
	if character == nil or data == nil then
		return
	end
	WeaponModels.AttachToHand(character, data.equippedWeapon, HELD_NAME)
end

function WeaponService.Equip(player: Player, weaponId: string): boolean
	local data = DataService.GetData(player)
	if data == nil or not data.weapons[weaponId] or WeaponConfig.Weapons[weaponId] == nil then
		return false
	end
	data.equippedWeapon = weaponId
	DataService.Changed(player, "equippedWeapon")
	ProgressionService.RefreshPower(player)
	attach(player)
	return true
end

function WeaponService.Buy(player: Player, weaponId: string): (boolean, string)
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	local ok, reason = WeaponService.CanBuy(data, weaponId)
	if not ok then
		return false, reason or "Cannot buy"
	end
	local def = WeaponConfig.Weapons[weaponId]
	local paid = if def.price == 0
		then true
		elseif def.currency == "Jade" then ProgressionService.SpendJade(player, def.price, "Weapon:" .. weaponId)
		else ProgressionService.SpendEmber(player, def.price, "Weapon:" .. weaponId)
	if not paid then
		return false, "Not enough " .. def.currency
	end
	data.weapons[weaponId] = true
	DataService.Changed(player, "weapons")
	WeaponService.Equip(player, weaponId)
	return true, def.name .. " is yours!"
end

function WeaponService.Init() end

function WeaponService.Start()
	Net.Server.OnInvoke("BuyWeapon", WeaponService.Buy)
	Net.Server.On("EquipWeapon", function(player, weaponId)
		WeaponService.Equip(player, weaponId)
	end)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			DataService.WaitForData(player, 20)
			task.wait(0.2) -- let the rig's hand attachments replicate in
			attach(player)
		end)
		if player.Character then
			task.spawn(attach, player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
end

return WeaponService
