--!strict
-- SkillLogic: pure skill-tree rules (shared so the UI shows exactly what the server allows).
-- `skills` is the profile table skillId -> rank.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SkillConfig"))

local SkillLogic = {}

export type Skills = { [string]: number }

-- Points earned by reaching `level` (none at level 1).
function SkillLogic.PointsEarned(level: number): number
	local l = math.max(1, math.floor(level))
	return (l - 1) * SkillConfig.PointsPerLevel + math.floor(l / SkillConfig.BonusEvery)
end

function SkillLogic.Spent(skills: Skills): number
	local total = 0
	for id, rank in skills do
		local def = SkillConfig.Skills[id]
		if def then
			total += rank * (def.cost or 1)
		end
	end
	return total
end

function SkillLogic.Available(level: number, skills: Skills): number
	return SkillLogic.PointsEarned(level) - SkillLogic.Spent(skills)
end

function SkillLogic.Rank(skills: Skills?, id: string): number
	return if skills then skills[id] or 0 else 0
end

-- Is the path open to this skill (no requirement, or any one requirement learned)?
function SkillLogic.Reachable(skills: Skills, id: string): boolean
	local def = SkillConfig.Skills[id]
	if def == nil then
		return false
	end
	if def.requires == nil or #def.requires == 0 then
		return true
	end
	for _, r in def.requires do
		if (skills[r] or 0) > 0 then
			return true
		end
	end
	return false
end

function SkillLogic.CanLearn(skills: Skills, level: number, id: string): (boolean, string?)
	local def = SkillConfig.Skills[id]
	if def == nil then
		return false, "Unknown skill"
	end
	if (skills[id] or 0) >= def.maxRank then
		return false, "Already mastered"
	end
	if def.minLevel and level < def.minLevel then
		return false, "Reach level " .. def.minLevel
	end
	if not SkillLogic.Reachable(skills, id) then
		return false, "Learn a skill above it first"
	end
	if SkillLogic.Available(level, skills) < (def.cost or 1) then
		return false, "Not enough skill points"
	end
	return true, nil
end

function SkillLogic.Learn(skills: Skills, level: number, id: string): (boolean, string?)
	local ok, err = SkillLogic.CanLearn(skills, level, id)
	if ok then
		skills[id] = (skills[id] or 0) + 1
	end
	return ok, err
end

-- Stat totals from learned skills (same keys as spirit stats; see SkillConfig).
function SkillLogic.Stats(skills: Skills?): { [string]: number }
	local out: { [string]: number } = {}
	if skills == nil then
		return out
	end
	for id, rank in skills do
		local def = SkillConfig.Skills[id]
		if def and def.stats and rank > 0 then
			for stat, per in def.stats do
				out[stat] = (out[stat] or 0) + per * math.min(rank, def.maxRank)
			end
		end
	end
	return out
end

-- Can this art be slotted / cast? (Arts tied to a skill need that skill learned.)
function SkillLogic.HasArt(skills: Skills?, spellId: string): boolean
	local need = SkillConfig.ArtSkill(spellId)
	return need == nil or SkillLogic.Rank(skills, need) > 0
end

-- Drops unknown skills and clamps ranks (e.g. after a config change).
function SkillLogic.Sanitize(skills: Skills)
	for id, rank in skills do
		local def = SkillConfig.Skills[id]
		if def == nil or type(rank) ~= "number" or rank <= 0 then
			skills[id] = nil
		else
			skills[id] = math.min(math.floor(rank), def.maxRank)
		end
	end
end

return SkillLogic
