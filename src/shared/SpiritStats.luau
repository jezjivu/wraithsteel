--!strict
-- SpiritStats: what each Spirit actually does for you, beyond Power. One pure module used by
-- the server (combat, Ember/Luck, cooldowns) and the UI (Spirits panel), so the numbers the
-- player reads are exactly the numbers the server applies.
--
-- API:
--   SpiritStats.Strength(id, rarity, mutation, level) -> number  -- ability/stat multiplier
--   SpiritStats.Of(id, rarity, mutation, level) -> { [stat]: number }
--   SpiritStats.Totals(list of {id, rarity, mutation, level}) -> { [stat]: number } (capped)
--   SpiritStats.Format(stat, value) -> "+5%"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpiritConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SpiritConfig"))

local SpiritStats = {}

export type SpiritRef = { id: string, rarity: string, mutation: string, level: number }

function SpiritStats.Strength(id: string, rarity: string, mutation: string, level: number): number
	local def = SpiritConfig.Spirits[id]
	local r = SpiritConfig.Rarities[rarity]
	if def == nil or r == nil then
		return 0
	end
	local base = SpiritConfig.Rarities[def.rarity]
	local rarityScale = math.sqrt(r.powerMultiplier / base.powerMultiplier)
	local m = SpiritConfig.MutationStatMultiplier[mutation] or 1
	return rarityScale * m * (1 + (math.max(level, 1) - 1) * SpiritConfig.StatPerLevel)
end

function SpiritStats.Of(id: string, rarity: string, mutation: string, level: number): { [string]: number }
	local out: { [string]: number } = {}
	local def = SpiritConfig.Spirits[id]
	if def == nil then
		return out
	end
	local k = SpiritStats.Strength(id, rarity, mutation, level)
	for stat, value in def.stats do
		out[stat] = value * k
	end
	local bonus = SpiritConfig.MutationBonus[mutation]
	if bonus then
		out[bonus.stat] = (out[bonus.stat] or 0) + bonus.value
	end
	return out
end

function SpiritStats.Totals(list: { SpiritRef }): { [string]: number }
	local total: { [string]: number } = {}
	for _, s in list do
		for stat, value in SpiritStats.Of(s.id, s.rarity, s.mutation, s.level) do
			total[stat] = (total[stat] or 0) + value
		end
	end
	for stat, value in total do
		local info = SpiritConfig.StatInfo[stat]
		if info then
			total[stat] = math.min(value, info.cap)
		end
	end
	return total
end

function SpiritStats.Format(stat: string, value: number): string
	local pct = value * 100
	if pct < 10 then
		return string.format("+%.1f%%", pct)
	end
	return string.format("+%d%%", math.floor(pct + 0.5))
end

function SpiritStats.Label(stat: string): string
	local info = SpiritConfig.StatInfo[stat]
	return if info then info.label else stat
end

return SpiritStats
