--!strict
-- SpiritService: owns the player's Spirit collection (equip/lock/release) on top of SpiritLogic.
-- Equipped Spirits are published as the SpiritParty player attribute; every client renders them
-- as part-built companions (SpiritFollowerController + Shared/SpiritModels).
--
-- API:
--   SpiritService.Grant(player, spiritId, rarity, mutation) -> SpiritInstance?
--   SpiritService.Equip / Unequip / SetLocked / Release (also exposed as remotes)
--   SpiritService.SlotBonus(player) -> number
--   SpiritService.CollectionChanged: Signal(player)
--   SpiritService.PublishParty(player)  -- sets player attribute SpiritParty for companions

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))

local SpiritLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("SpiritLogic"))
local TradeLock = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("TradeLock"))
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

-- Publishes equipped Spirits as "id:mutation:rarity,..." so every client can render
-- everyone's companions (SpiritFollowerController).
function SpiritService.PublishParty(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local parts = {}
	for _, uid in data.equippedSpirits do
		local s = data.spirits[uid]
		if s then
			table.insert(parts, s.id .. ":" .. s.mutation .. ":" .. s.rarity)
		end
	end
	player:SetAttribute("SpiritParty", table.concat(parts, ","))
end

local function changed(player: Player)
	SpiritService.PublishParty(player)
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

function SpiritService.Grant(player: Player, spiritId: string, rarity: string, mutation: string, paid: boolean?): Types.SpiritInstance?
	local data = DataService.GetData(player)
	if data == nil then
		return nil
	end
	local inst = SpiritLogic.Create(data :: any, spiritId, rarity, mutation, os.time())
	if paid then
		inst.paid = true
	end
	changed(player)
	return inst
end

function SpiritService.Equip(player: Player, uid: string): (boolean, string?)
	if TradeLock.IsLocked(player.UserId) then
		return false, TradeLock.Message
	end
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
	if TradeLock.IsLocked(player.UserId) then
		return false
	end
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
	if TradeLock.IsLocked(player.UserId) then
		return false
	end
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
	if TradeLock.IsLocked(player.UserId) then
		return nil, TradeLock.Message
	end
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
	DataService.ProfileLoaded:Connect(SpiritService.PublishParty)
	Net.Server.OnInvoke("EquipSpirit", SpiritService.Equip)
	Net.Server.OnInvoke("UnequipSpirit", SpiritService.Unequip)
	Net.Server.OnInvoke("LockSpirit", SpiritService.SetLocked)
	Net.Server.OnInvoke("ReleaseSpirits", SpiritService.Release)
end

return SpiritService
