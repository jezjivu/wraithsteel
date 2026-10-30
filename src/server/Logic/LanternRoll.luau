--!strict
-- LanternRoll: server-side Spirit Lantern roll with pity. Uses Shared/LanternOdds + Shared/Odds,
-- the same functions the odds UI uses. Pity: if a lantern has `pity = {rolls, minRarity}`, the
-- open that would make `rolls` consecutive opens without minRarity+ instead rolls from the
-- minRarity+ pool (with the same relative weights). Pity counter is per lantern, per player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanternConfig = require(Config:WaitForChild("LanternConfig"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))
local LanternOdds = require(Shared:WaitForChild("LanternOdds"))
local Odds = require(Shared:WaitForChild("Odds"))

local LanternRoll = {}

export type RollResult = {
	spirit: string,
	rarity: string,
	mutation: string,
	pityTriggered: boolean,
}

-- pityState: lanternId -> rolls since last qualifying rarity (mutated in place).
function LanternRoll.Roll(lanternId: string, luck: number, pityState: { [string]: number }, rng: () -> number): RollResult
	local lantern = LanternConfig.Lanterns[lanternId]
	assert(lantern, "unknown lantern " .. lanternId)

	local pityTriggered = false
	local entries
	if lantern.pity and (pityState[lanternId] or 0) + 1 >= lantern.pity.rolls then
		entries = LanternOdds.SpiritEntries(lanternId, lantern.pity.minRarity)
		pityTriggered = true
	else
		entries = LanternOdds.SpiritEntries(lanternId)
	end

	local spiritId = Odds.Roll(entries, luck, rng)
	local rarity = SpiritConfig.Spirits[spiritId].rarity
	local mutation = Odds.Roll(LanternOdds.MutationEntries(), luck, rng)

	if lantern.pity then
		local qualifies = SpiritConfig.Rarities[rarity].order >= SpiritConfig.Rarities[lantern.pity.minRarity].order
		pityState[lanternId] = if qualifies then 0 else (pityState[lanternId] or 0) + 1
	end

	return { spirit = spiritId, rarity = rarity, mutation = mutation, pityTriggered = pityTriggered }
end

return LanternRoll
