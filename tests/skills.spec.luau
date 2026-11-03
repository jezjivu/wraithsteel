-- Tests for the skill tree (Shared/SkillLogic + SkillConfig) and skill-gated arts.
local Logic = game:GetService("ServerScriptService").Logic
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = game:GetService("ReplicatedStorage").Config

local SkillLogic = require(Shared.SkillLogic)
local SkillConfig = require(Config.SkillConfig)
local SpellConfig = require(Config.SpellConfig)
local SpellLogic = require(Logic.SpellLogic)

local cases = {}

cases["Skills: points come from level"] = function()
	expectEq(SkillLogic.PointsEarned(1), 0)
	expectEq(SkillLogic.PointsEarned(2), 1)
	expectEq(SkillLogic.PointsEarned(5), 5) -- 4 + bonus at 5
	expectEq(SkillLogic.PointsEarned(10), 11)
end

cases["Skills: learning needs points, the skill above, and respects max rank"] = function()
	local s = {}
	expectEq((SkillLogic.Learn(s, 1, "keen_edge")), false) -- no points at level 1
	expectEq((SkillLogic.Learn(s, 5, "heavy_hand")), false) -- needs keen_edge
	expectEq((SkillLogic.Learn(s, 5, "keen_edge")), true)
	expectEq((SkillLogic.Learn(s, 5, "heavy_hand")), true)
	expectEq(SkillLogic.Available(5, s), 3)
	for _ = 1, 3 do
		SkillLogic.Learn(s, 20, "keen_edge")
	end
	expectEq(s.keen_edge, SkillConfig.Skills.keen_edge.maxRank)
	local ok, why = SkillLogic.Learn(s, 20, "keen_edge")
	expectEq(ok, false)
	expectEq(why, "Already mastered")
end

cases["Skills: stats stack per rank"] = function()
	local s = { keen_edge = 2, iron_body = 1, deep_gourd = 1 }
	local st = SkillLogic.Stats(s)
	expectTrue(math.abs(st.Attack - 0.10) < 1e-9, "attack")
	expectTrue(math.abs(st.Health - 0.06) < 1e-9, "health")
	expectEq(st.Flask, 1)
end

cases["Skills: every skill is well formed and every art exists"] = function()
	local count = 0
	for id, def in SkillConfig.Skills do
		count += 1
		expectTrue(def.maxRank >= 1, id)
		expectTrue(def.tier >= 1 and def.tier <= 5, id .. " tier")
		local pathOk = false
		for _, p in SkillConfig.Paths do
			pathOk = pathOk or p.id == def.path
		end
		expectTrue(pathOk, id .. " path")
		for _, r in def.requires or {} do
			local rd = SkillConfig.Skills[r]
			expectTrue(rd ~= nil, id .. " requires unknown " .. r)
			expectTrue(rd.tier < def.tier and rd.path == def.path, id .. " requires " .. r .. " (must be above, same path)")
		end
		if def.art then
			expectTrue(SpellConfig.Spells[def.art] ~= nil, id .. " art " .. def.art)
			expectTrue(table.find(SpellConfig.Order, def.art) ~= nil, def.art .. " in Order")
		end
		expectTrue(def.stats ~= nil or def.art ~= nil, id .. " does nothing")
	end
	expectTrue(count >= 18, "tree size")
	-- The whole tree is affordable by a high level.
	local total = 0
	for _, def in SkillConfig.Skills do
		total += def.maxRank * (def.cost or 1)
	end
	expectTrue(SkillLogic.PointsEarned(60) >= total, "max level can finish the tree")
end

cases["Skills: skill arts need the skill to slot and cast"] = function()
	local loadout = { "thousand_cuts", "ghost_step", "" }
	expectEq((SpellLogic.SetLoadout(loadout, 3, "phantom_rush", 20, {})), false)
	expectEq((SpellLogic.SetLoadout(loadout, 3, "phantom_rush", 20, { phantom_rush = 1 })), true)
	local st = SpellLogic.NewState(100)
	expectEq((SpellLogic.CanCast(st, loadout, 20, "phantom_rush", 0, {})), false)
	expectEq((SpellLogic.CanCast(st, loadout, 20, "phantom_rush", 0, { phantom_rush = 1 })), true)
	-- Regular arts don't need skills.
	expectEq((SpellLogic.CanCast(st, loadout, 1, "thousand_cuts", 0, nil)), true)
end

cases["Skills: sanitize drops unknown skills and clamps ranks"] = function()
	local s = { keen_edge = 99, nope = 2, iron_body = 0 }
	SkillLogic.Sanitize(s)
	expectEq(s.keen_edge, SkillConfig.Skills.keen_edge.maxRank)
	expectEq(s.nope, nil)
	expectEq(s.iron_body, nil)
end

return cases
