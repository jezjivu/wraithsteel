--!strict
-- LanternOdds: builds the exact Odds entries for a Spirit Lantern and its mutation roll.
-- The odds UI (client) and LanternService (server) both call these functions, so the numbers a
-- player sees are the numbers the server rolls with. Luck is per-player and included.

local Config = script.Parent.Parent:WaitForChild("Config")
local LanternConfig = require(Config:WaitForChild("LanternConfig"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Odds = require(script.Parent.Odds)
local Types = require(script.Parent.Types)

type OddsEntry = Types.OddsEntry
type OddsResult = Types.OddsResult

local LanternOdds = {}

-- Spirit entries for a lantern. If `minRarity` is given (pity), only spirits at or above it.
function LanternOdds.SpiritEntries(lanternId: string, minRarity: string?): { OddsEntry }
	local lantern = LanternConfig.Lanterns[lanternId]
	assert(lantern, "LanternOdds: unknown lantern " .. lanternId)
	local minOrder = if minRarity then SpiritConfig.Rarities[minRarity].order else 0
	local entries = {}
	for _, e in lantern.entries do
		local spirit = SpiritConfig.Spirits[e.spirit]
		assert(spirit, "LanternOdds: unknown spirit " .. e.spirit)
		local rarity = SpiritConfig.Rarities[spirit.rarity]
		if rarity.order >= minOrder then
			table.insert(entries, { id = e.spirit, weight = e.weight, luckAffinity = rarity.luckAffinity })
		end
	end
	return entries
end

function LanternOdds.MutationEntries(): { OddsEntry }
	local entries = {}
	for _, id in SpiritConfig.MutationOrder do
		local m = SpiritConfig.Mutations[id]
		table.insert(entries, { id = id, weight = m.weight, luckAffinity = m.luckAffinity })
	end
	return entries
end

-- True when `currency` can be bought with Robux (directly or in a bundle). Derived from
-- MonetizationConfig so adding e.g. an Ember product automatically re-classifies lanterns.
function LanternOdds.IsPurchasableCurrency(currency: string): boolean
	local key = string.lower(currency)
	for _, p in MonetizationConfig.Products do
		if p.kind == currency then
			return true
		end
		local b = p.bundle :: any
		if b and (b[key] or 0) > 0 then
			return true
		end
	end
	return false
end

-- A lantern is a PAID random item when it is flagged `paid` or its price is in a currency that
-- can be bought with Robux. Paid lanterns are refused (except free opens) when PolicyService
-- restricts paid random items, and Spirits bought from them carry `paid = true`.
function LanternOdds.IsPaid(lanternId: string): boolean
	local lantern = LanternConfig.Lanterns[lanternId]
	if lantern == nil then
		return true -- unknown = treat restrictively
	end
	return lantern.paid or LanternOdds.IsPurchasableCurrency(lantern.currency)
end

export type OddsSheet = {
	lanternId: string,
	luck: number,
	spirits: { OddsResult },
	mutations: { OddsResult },
	pity: { rolls: number, minRarity: string, progress: number }?,
	pityOdds: { OddsResult }?, -- odds used on the guaranteed (pity) open
}

-- Everything the odds panel shows before purchase.
function LanternOdds.Sheet(lanternId: string, luck: number, pityProgress: number?): OddsSheet
	local lantern = LanternConfig.Lanterns[lanternId]
	local sheet: OddsSheet = {
		lanternId = lanternId,
		luck = luck,
		spirits = Odds.Compute(LanternOdds.SpiritEntries(lanternId), luck),
		mutations = Odds.Compute(LanternOdds.MutationEntries(), luck),
		pity = nil,
		pityOdds = nil,
	}
	if lantern.pity then
		sheet.pity = { rolls = lantern.pity.rolls, minRarity = lantern.pity.minRarity, progress = pityProgress or 0 }
		sheet.pityOdds = Odds.Compute(LanternOdds.SpiritEntries(lanternId, lantern.pity.minRarity), luck)
	end
	return sheet
end

return LanternOdds
