--!strict
-- SpiritService: owns the player's Spirit collection (equip/lock/release) on top of SpiritLogic.
-- Spawning follower models is a Studio task (TODO(Studio/Agent B): Spirit follower models,
-- idle/follow animation; models will live in ServerStorage.Spirits/<spiritId>).
--
-- API:
--   SpiritService.Grant(player, spiritId, rarity, mutation) -> SpiritInstance?
--   SpiritService.Equip / Unequip / SetLocked / Release (also exposed as remotes)
--   SpiritService.SlotBonus(player) -> number
--   SpiritService.CollectionChanged: Signal(player)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))

local SpiritLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("SpiritLogic"))
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local ProgressionService = require(script.Parent.ProgressionService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local EXTRA_SLOTS_FROM_PASS = 2

local SpiritService = {
	Name = "SpiritService",
	Priority = 20,
	CollectionChanged = Signal.new(),
}

local function changed(player: Player)
	DataService.Changed(player, "spirits", "equippedSpirits", "ember")
	ProgressionService.RefreshPower(player)
	SpiritService.CollectionChanged:Fire(player)
end

function SpiritService.SlotBonus(player: Player): number
	return if MarketService.HasPass(player, "ExtraSpiritSlots") then EXTRA_SLOTS_FROM_PASS else 0
end

function SpiritService.FreeStorage(player: Player): number
	local data = DataService.GetData(player)
	return if data then SpiritLogic.FreeStorage(data :: any) else 0
end

function SpiritService.Grant(player: Player, spiritId: string, rarity: string, mutation: string): Types.SpiritInstance?
	local data = DataService.GetData(player)
	if data == nil then
		return nil
	end
	local inst = SpiritLogic.Create(data :: any, spiritId, rarity, mutation, os.time())
	changed(player)
	return inst
end

function SpiritService.Equip(player: Player, uid: string): (boolean, string?)
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	local ok, err = SpiritLogic.Equip(data :: any, uid, SpiritService.SlotBonus(player))
	if ok then
		changed(player)
		AnalyticsService.Onboarding(player, "FirstSpiritEquipped")
	end
	return ok, err
end

function SpiritService.Unequip(player: Player, uid: string): boolean
	local data = DataService.GetData(player)
	if data == nil then
		return false
	end
	local ok = SpiritLogic.Unequip(data :: any, uid)
	if ok then
		changed(player)
	end
	return ok
end

function SpiritService.SetLocked(player: Player, uid: string, locked: boolean): boolean
	local data = DataService.GetData(player)
	local s = data and data.spirits[uid]
	if s == nil then
		return false
	end
	s.locked = locked
	DataService.Changed(player, "spirits")
	return true
end

function SpiritService.Release(player: Player, uids: { string }): (number?, string?)
	local data = DataService.GetData(player)
	if data == nil then
		return nil, "Loading..."
	end
	local refund, err = SpiritLogic.Release(data :: any, uids)
	if refund then
		changed(player)
	end
	return refund, err
end

function SpiritService.Init() end

function SpiritService.Start()
	Net.Server.OnInvoke("EquipSpirit", SpiritService.Equip)
	Net.Server.OnInvoke("UnequipSpirit", SpiritService.Unequip)
	Net.Server.OnInvoke("LockSpirit", SpiritService.SetLocked)
	Net.Server.OnInvoke("ReleaseSpirits", SpiritService.Release)
end

return SpiritService
