--!strict
-- SpiritLogic: pure operations on a profile's spirit collection (create, equip, release, fuse).
-- Fusion is fully deterministic (no randomness, so no odds disclosure needed):
--   * exactly Rarity.fuseCount spirits, all the same species and rarity, none locked or equipped
--   * result: same species, next rarity, best input mutation, highest input level,
--     fusedCount = max(input fusedCount) + 1, costs Rarity.fuseCostEmber Ember.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

type SpiritInstance = Types.SpiritInstance

-- Subset of ProfileData this module touches (keeps tests small).
export type SpiritData = {
	spirits: { [string]: SpiritInstance },
	equippedSpirits: { string },
	spiritSlots: number,
	spiritStorage: number,
	nextUid: number,
	ember: number,
	expeditions: { [string]: Types.ExpeditionState }?,
}

local SpiritLogic = {}

function SpiritLogic.Count(data: SpiritData): number
	local n = 0
	for _ in data.spirits do
		n += 1
	end
	return n
end

function SpiritLogic.FreeStorage(data: SpiritData): number
	return data.spiritStorage - SpiritLogic.Count(data)
end

function SpiritLogic.Create(data: SpiritData, id: string, rarity: string, mutation: string, now: number): SpiritInstance
	assert(SpiritConfig.Spirits[id], "unknown spirit " .. id)
	local uid = "s" .. tostring(data.nextUid)
	data.nextUid += 1
	local inst: SpiritInstance = {
		uid = uid,
		id = id,
		rarity = rarity :: any,
		mutation = mutation :: any,
		level = 1,
		xp = 0,
		fusedCount = 0,
		locked = false,
		obtainedAt = now,
	}
	data.spirits[uid] = inst
	return inst
end

function SpiritLogic.IsEquipped(data: SpiritData, uid: string): boolean
	return table.find(data.equippedSpirits, uid) ~= nil
end

-- True while the Spirit is away on an expedition (cannot be equipped, fused or released).
function SpiritLogic.IsAway(data: SpiritData, uid: string): boolean
	if data.expeditions == nil then
		return false
	end
	for _, e in data.expeditions do
		if table.find(e.spiritUids, uid) then
			return true
		end
	end
	return false
end

-- Adds Spirit XP, leveling up to SpiritConfig.LevelCap. Returns levels gained.
function SpiritLogic.AddXp(inst: SpiritInstance, xp: number): number
	local start = inst.level
	inst.xp += math.max(0, xp)
	while inst.level < SpiritConfig.LevelCap do
		local need = SpiritConfig.XpToNext(inst.level)
		if inst.xp < need then
			break
		end
		inst.xp -= need
		inst.level += 1
	end
	if inst.level >= SpiritConfig.LevelCap then
		inst.xp = 0
	end
	return inst.level - start
end

function SpiritLogic.Equip(data: SpiritData, uid: string, slotBonus: number): (boolean, string?)
	if data.spirits[uid] == nil then
		return false, "Spirit not found"
	end
	if SpiritLogic.IsAway(data, uid) then
		return false, "That Spirit is on an expedition"
	end
	if SpiritLogic.IsEquipped(data, uid) then
		return true, nil
	end
	local slots = math.min(data.spiritSlots + slotBonus, EconomyConfig.MaxSpiritSlots + slotBonus)
	if #data.equippedSpirits >= slots then
		return false, "All Spirit slots are full"
	end
	table.insert(data.equippedSpirits, uid)
	return true, nil
end

function SpiritLogic.Unequip(data: SpiritData, uid: string): boolean
	local i = table.find(data.equippedSpirits, uid)
	if i then
		table.remove(data.equippedSpirits, i)
		return true
	end
	return false
end

-- Releases spirits for an Ember refund. Returns refund or nil + reason (all-or-nothing).
function SpiritLogic.Release(data: SpiritData, uids: { string }): (number?, string?)
	local seen = {}
	local refund = 0
	for _, uid in uids do
		local s = data.spirits[uid]
		if s == nil or seen[uid] then
			return nil, "Invalid selection"
		end
		if s.locked then
			return nil, "A selected Spirit is locked"
		end
		if SpiritLogic.IsAway(data, uid) then
			return nil, "A selected Spirit is on an expedition"
		end
		seen[uid] = true
		refund += (EconomyConfig.ReleaseRefund :: any)[s.rarity] or 0
	end
	for _, uid in uids do
		SpiritLogic.Unequip(data, uid)
		data.spirits[uid] = nil
	end
	data.ember += refund
	return refund, nil
end

export type FusionPlan = {
	consume: { string },
	id: string,
	fromRarity: string,
	toRarity: string,
	mutation: string,
	level: number,
	fusedCount: number,
	cost: number,
}

local function nextRarity(rarity: string): string?
	local order = SpiritConfig.Rarities[rarity].order
	return SpiritConfig.RarityOrder[order + 1]
end

-- Validates a fusion request and describes the result without changing anything.
function SpiritLogic.PlanFusion(data: SpiritData, uids: { string }): (FusionPlan?, string?)
	if #uids == 0 then
		return nil, "Select Spirits to fuse"
	end
	local first = data.spirits[uids[1]]
	if first == nil then
		return nil, "Spirit not found"
	end
	local rarityDef = SpiritConfig.Rarities[first.rarity]
	local toRarity = nextRarity(first.rarity)
	if rarityDef.fuseCount == nil or toRarity == nil then
		return nil, "This rarity cannot be fused"
	end
	if #uids ~= rarityDef.fuseCount then
		return nil, string.format("Fusion needs exactly %d Spirits", rarityDef.fuseCount)
	end
	local seen = {}
	local bestMutation = "None"
	local bestOrder = 0
	local level = 1
	local fused = 0
	for _, uid in uids do
		local s = data.spirits[uid]
		if s == nil or seen[uid] then
			return nil, "Invalid selection"
		end
		seen[uid] = true
		if s.id ~= first.id or s.rarity ~= first.rarity then
			return nil, "Spirits must be the same species and rarity"
		end
		if s.locked then
			return nil, "A selected Spirit is locked"
		end
		if SpiritLogic.IsEquipped(data, uid) then
			return nil, "Unequip Spirits before fusing"
		end
		if SpiritLogic.IsAway(data, uid) then
			return nil, "A selected Spirit is on an expedition"
		end
		local mOrder = SpiritConfig.Mutations[s.mutation].order
		if mOrder > bestOrder then
			bestOrder = mOrder
			bestMutation = s.mutation
		end
		level = math.max(level, s.level)
		fused = math.max(fused, s.fusedCount)
	end
	local cost = rarityDef.fuseCostEmber or 0
	if data.ember < cost then
		return nil, "Not enough Ember"
	end
	return {
		consume = table.clone(uids),
		id = first.id,
		fromRarity = first.rarity :: string,
		toRarity = toRarity,
		mutation = bestMutation,
		level = level,
		fusedCount = fused + 1,
		cost = cost,
	},
		nil
end

function SpiritLogic.ApplyFusion(data: SpiritData, plan: FusionPlan, now: number): SpiritInstance
	data.ember -= plan.cost
	for _, uid in plan.consume do
		data.spirits[uid] = nil
	end
	local inst = SpiritLogic.Create(data, plan.id, plan.toRarity, plan.mutation, now)
	inst.level = plan.level
	inst.fusedCount = plan.fusedCount
	return inst
end

-- Sum of Power from equipped spirits.
function SpiritLogic.EquippedPower(data: SpiritData): number
	local total = 0
	for _, uid in data.equippedSpirits do
		local s = data.spirits[uid]
		if s then
			total += SpiritConfig.PowerOf(s.id, s.rarity, s.mutation, s.level)
		end
	end
	return total
end

-- Sum of passive values of a stat from equipped spirits.
function SpiritLogic.PassiveTotal(data: SpiritData, stat: string): number
	local total = 0
	for _, uid in data.equippedSpirits do
		local s = data.spirits[uid]
		local def = s and SpiritConfig.Spirits[s.id]
		local passive = def and def.passive and (SpiritConfig.Passives :: any)[def.passive]
		if passive and passive.stat == stat then
			total += passive.value
		end
	end
	return total
end

return SpiritLogic
