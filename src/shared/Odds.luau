--!strict
-- Odds: the ONE function both the odds UI and server rolls use.
-- Compliance (guide §0): every paid random item shows these exact numbers before purchase.
-- The server never rolls with anything except Odds.Roll over the same entries the UI displays.

local Types = require(script.Parent.Types)

type OddsEntry = Types.OddsEntry
type OddsResult = Types.OddsResult

local Odds = {}

-- Effective weight for one entry given a luck multiplier (1 = no luck).
-- luck scales only the share of the weight given by luckAffinity, so commons stay put.
local function effectiveWeight(entry: OddsEntry, luck: number): number
	local affinity = math.clamp(entry.luckAffinity or 0, 0, 1)
	local l = math.max(luck, 1)
	return entry.weight * (1 + (l - 1) * affinity)
end

-- Computes exact chances and display percents. Display percents use the
-- largest-remainder method at 0.01% precision so they always sum to exactly 100.00.
function Odds.Compute(entries: { OddsEntry }, luck: number?): { OddsResult }
	local l = luck or 1
	local total = 0
	local weights = table.create(#entries, 0)
	for i, entry in entries do
		assert(entry.weight >= 0, "Odds: negative weight for " .. entry.id)
		local w = effectiveWeight(entry, l)
		weights[i] = w
		total += w
	end
	assert(total > 0, "Odds: total weight must be > 0")

	local results: { OddsResult } = table.create(#entries)
	local UNITS = 10000 -- 100.00% in hundredths of a percent
	local assigned = 0
	local remainders = {}
	for i, entry in entries do
		local chance = weights[i] / total
		local exactUnits = chance * UNITS
		local floorUnits = math.floor(exactUnits)
		assigned += floorUnits
		results[i] = { id = entry.id, chance = chance, percent = floorUnits }
		table.insert(remainders, { index = i, rem = exactUnits - floorUnits })
	end
	table.sort(remainders, function(a, b)
		if a.rem == b.rem then
			return a.index < b.index
		end
		return a.rem > b.rem
	end)
	local leftover = UNITS - assigned
	for k = 1, leftover do
		local r = results[remainders[k].index]
		r.percent += 1
	end
	for _, r in results do
		r.percent /= 100
	end
	return results
end

-- Picks an id. `rng` returns a float in [0, 1). Server passes a Random:NextNumber wrapper.
function Odds.Roll(entries: { OddsEntry }, luck: number?, rng: () -> number): string
	local results = Odds.Compute(entries, luck)
	local x = rng()
	local acc = 0
	for _, r in results do
		acc += r.chance
		if x < acc then
			return r.id
		end
	end
	-- Float error guard: return last entry with non-zero chance.
	for i = #results, 1, -1 do
		if results[i].chance > 0 then
			return results[i].id
		end
	end
	return results[#results].id
end

-- Returns a filtered copy of entries (used by pity to restrict the pool) keeping weights.
function Odds.Filter(entries: { OddsEntry }, keep: (OddsEntry) -> boolean): { OddsEntry }
	local out = {}
	for _, e in entries do
		if keep(e) then
			table.insert(out, e)
		end
	end
	return out
end

return Odds
