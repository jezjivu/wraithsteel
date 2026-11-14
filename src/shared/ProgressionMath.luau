--!strict
-- ProgressionMath: pure formulas for levels, Power and multipliers.
-- Shared so the HUD previews exactly what the server computes.

local Config = script.Parent.Parent:WaitForChild("Config")
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))

local ProgressionMath = {}

-- Applies `xp` gained to (level, xp). Returns newLevel, newXp, levelsGained.
function ProgressionMath.ApplyXp(level: number, xp: number, gained: number): (number, number, number)
	local l, x = level, xp + math.max(0, gained)
	local start = level
	while l < EconomyConfig.MaxLevel do
		local need = EconomyConfig.XpToNext(l)
		if x < need then
			break
		end
		x -= need
		l += 1
	end
	if l >= EconomyConfig.MaxLevel then
		l = EconomyConfig.MaxLevel
		x = 0
	end
	return l, x, l - start
end

-- Combines multiplier sources. `active` maps source name -> true for sources that apply.
-- Returns 1 + sum(values of active sources) for the given category.
function ProgressionMath.CategoryMultiplier(category: string, active: { [string]: boolean }, extra: number?): number
	local defs = (EconomyConfig.Multipliers :: any)[category]
	local sum = 1 + (extra or 0)
	if defs then
		for source, value in defs do
			if active[source] then
				sum += value
			end
		end
	end
	return sum
end

function ProgressionMath.PowerCap(chapter: number): number
	local caps = EconomyConfig.PowerCapByChapter
	return caps[chapter] or caps[#caps]
end

-- Total Power before the chapter cap, and after.
function ProgressionMath.Power(level: number, weaponPower: number, spiritPower: number, chapter: number): (number, number)
	local raw = EconomyConfig.BasePower + level * EconomyConfig.PowerPerLevel + weaponPower + spiritPower
	raw = math.floor(raw)
	return raw, math.min(raw, ProgressionMath.PowerCap(chapter))
end

return ProgressionMath
