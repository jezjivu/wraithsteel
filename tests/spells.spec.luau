-- Tests for Qi arts (Logic/SpellLogic) and Spirit stats (Shared/SpiritStats).
local Logic = game:GetService("ServerScriptService").Logic
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = game:GetService("ReplicatedStorage").Config

local SpellLogic = require(Logic.SpellLogic)
local SpiritStats = require(Shared.SpiritStats)
local SpellConfig = require(Config.SpellConfig)
local SpiritConfig = require(Config.SpiritConfig)

local cases = {}

cases["Spells: cast needs slot, level, Qi and cooldown"] = function()
	local st = SpellLogic.NewState(100)
	local loadout = { "thousand_cuts", "ghost_step", "" }
	expectEq((SpellLogic.CanCast(st, loadout, 1, "thousand_cuts", 0)), true)
	expectEq((SpellLogic.CanCast(st, loadout, 20, "heavens_fall", 0)), false) -- not slotted
	local cd = SpellLogic.Commit(st, "thousand_cuts", 0, 0)
	expectEq(cd, SpellConfig.Spells.thousand_cuts.cooldown)
	expectEq(st.qi, 100 - SpellConfig.Spells.thousand_cuts.qi)
	local ok, reason = SpellLogic.CanCast(st, loadout, 1, "thousand_cuts", 1)
	expectEq(ok, false)
	expectEq(reason, "Cooling down")
	expectEq((SpellLogic.CanCast(st, loadout, 1, "thousand_cuts", cd + 0.01)), true)
	st.qi = 1
	local ok2, reason2 = SpellLogic.CanCast(st, loadout, 1, "ghost_step", 0)
	expectEq(ok2, false)
	expectEq(reason2, "Not enough Qi")
end

cases["Spells: haste shortens cooldowns, Qi is clamped"] = function()
	local st = SpellLogic.NewState(100)
	expectEq(SpellLogic.Commit(st, "ghost_step", 0, 0.25), SpellConfig.Spells.ghost_step.cooldown * 0.75)
	SpellLogic.AddQi(st, 1000)
	expectEq(st.qi, SpellConfig.Qi.max)
	SpellLogic.AddQi(st, -1000)
	expectEq(st.qi, 0)
	SpellLogic.Regen(st, 1, 0.5)
	expectEq(st.qi, SpellConfig.Qi.regenPerSecond * 1.5)
end

cases["Spells: loadout respects level and moves duplicates"] = function()
	local loadout = { "thousand_cuts", "ghost_step", "" }
	local ok, err = SpellLogic.SetLoadout(loadout, 3, "heavens_fall", 1)
	expectEq(ok, false)
	expectEq(err, "Unlocks at level 12")
	expectEq((SpellLogic.SetLoadout(loadout, 3, "thousand_cuts", 1)), true)
	expectEq(loadout[1], "")
	expectEq(loadout[3], "thousand_cuts")
	expectEq((SpellLogic.SetLoadout(loadout, 4, "ghost_step", 1)), false)
	expectEq((SpellLogic.SetLoadout(loadout, 2, "", 1)), true)
	expectEq(loadout[2], "")
end

cases["Spells: corridor and clamp geometry"] = function()
	expectEq(SpellLogic.InCorridor(0, 0, 0, 1, 20, 3, 1, 10), true)
	expectEq(SpellLogic.InCorridor(0, 0, 0, 1, 20, 3, 5, 10), false)
	expectEq(SpellLogic.InCorridor(0, 0, 0, 1, 20, 3, 0, 25), false)
	expectEq(SpellLogic.InCorridor(0, 0, 0, 1, 20, 3, 0, -5), false)
	local x, z = SpellLogic.ClampPoint(0, 0, 0, 100, 40)
	expectEq(x, 0)
	expectEq(z, 40)
end

cases["Spells: every spell is well-formed"] = function()
	for _, id in SpellConfig.Order do
		local s = SpellConfig.Spells[id]
		assert(s, "missing spell " .. id)
		assert(s.qi > 0 and s.qi <= SpellConfig.Qi.max, id .. " qi")
		assert(s.cooldown > 0, id .. " cooldown")
	end
	for _, id in SpellConfig.DefaultLoadout do
		assert(SpellConfig.Spells[id], "default " .. id)
	end
end

cases["SpiritStats: rarity, mutation and level scale stats; totals are capped"] = function()
	local base = SpiritStats.Of("lantern_moth", "Common", "None", 1)
	expectEq(base.Attack, 0.04)
	local better = SpiritStats.Of("lantern_moth", "Rare", "Hollow", 10)
	assert(better.Attack > base.Attack * 2, "rare hollow lv10 should be much stronger")
	assert((better.Lifesteal or 0) > 0, "Hollow adds lifesteal")
	local many = {}
	for _ = 1, 30 do
		table.insert(many, { id = "ninth_bell_wraith", rarity = "Mythic", mutation = "Hollow", level = 50 })
	end
	local totals = SpiritStats.Totals(many)
	expectEq(totals.Attack, SpiritConfig.StatInfo.Attack.cap)
	expectEq(totals.Lifesteal, SpiritConfig.StatInfo.Lifesteal.cap)
end

cases["SpiritStats: every spirit has stats and a valid ability"] = function()
	for id, def in SpiritConfig.Spirits do
		assert(next(def.stats), id .. " has no stats")
		for stat in def.stats do
			assert(SpiritConfig.StatInfo[stat], id .. " unknown stat " .. stat)
		end
		assert(SpiritConfig.Abilities[def.ability], id .. " unknown ability " .. def.ability)
	end
end

return cases
