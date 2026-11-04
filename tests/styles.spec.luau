-- Fighting styles: each style's signature mechanic (Shared/StyleLogic).
local RS = game:GetService("ReplicatedStorage")
local StyleLogic = require(RS.Shared.StyleLogic)
local StyleConfig = require(RS.Config.StyleConfig)
local CombatConfig = require(RS.Config.CombatConfig)
local CombatRules = require(game:GetService("ServerScriptService").Logic.CombatRules)

local cases = {}

cases["Styles: every style has a mechanic and the four are different"] = function()
	local kinds = {}
	for _, id in StyleConfig.Order do
		local def = StyleConfig.Styles[id]
		expectTrue(def.mechanic ~= nil, id)
		expectTrue(not kinds[def.mechanic.kind], "mechanics must differ")
		kinds[def.mechanic.kind] = true
		expectTrue(CombatConfig.ParryWindow + def.parryWindowBonus > 0.1, id .. " keeps a usable parry window")
	end
end

cases["River: deflects build Flow (capped), Flow speeds and weights attacks, fades"] = function()
	local st = StyleLogic.New()
	local base = StyleLogic.Attack("river", st, 0)
	for i = 1, 5 do
		StyleLogic.OnParry("river", st, i * 0.1)
	end
	expectEq(StyleLogic.Stacks("river", st, 0.6), StyleConfig.Styles.river.mechanic.maxStacks)
	local m = StyleLogic.Attack("river", st, 0.6)
	expectTrue(m.speed > base.speed and m.posture > base.posture)
	expectEq(StyleLogic.Stacks("river", st, 0.6 + StyleConfig.Styles.river.mechanic.stackSeconds + 0.01), 0)
	-- other styles do not gain Flow
	local o = StyleLogic.New()
	StyleLogic.OnParry("ember", o, 0)
	expectEq(o.stacks, 0)
end

cases["Ember: landing hits builds Heat, getting hit resets it"] = function()
	local st = StyleLogic.New()
	for i = 1, 8 do
		StyleLogic.OnLandHit("ember", st, i * 0.2)
	end
	expectEq(st.stacks, StyleConfig.Styles.ember.mechanic.maxStacks)
	local hot = StyleLogic.Attack("ember", st, 1.7)
	expectNear(hot.damage, StyleConfig.Styles.ember.damage * (1 + 5 * StyleConfig.Styles.ember.mechanic.damagePerStack), 1e-9)
	StyleLogic.OnHurt("ember", st)
	expectEq(st.stacks, 0)
end

cases["Wind: strikes right after a dash crit; longer dash-strike window"] = function()
	local st = StyleLogic.New()
	StyleLogic.OnDodge(st, 10)
	expectTrue(StyleLogic.Attack("wind", st, 10.5).crit)
	expectTrue(not StyleLogic.Attack("wind", st, 11).crit)
	expectTrue(not StyleLogic.Attack("river", st, 10.2).crit, "only Wind Step crits off a dash")
	expectNear(StyleLogic.DashWindow("wind"), CombatConfig.DashAttackWindow * 2, 1e-9)
	expectTrue(StyleLogic.DodgeRefund("wind") and not StyleLogic.DodgeRefund("river"))
	-- the dash window reaches CombatRules: a light attack 0.7s after a dash is a dash strike for Wind only
	local state = CombatRules.NewState()
	state.lastDodgeAt = 0
	local d = CombatRules.Validate(state, "jian_wanderer", "LightAttack", 1, 0.7, { dashWindow = StyleLogic.DashWindow("wind") })
	expectEq(d.kind, "Dash")
	local state2 = CombatRules.NewState()
	state2.lastDodgeAt = 0
	local d2 = CombatRules.Validate(state2, "jian_wanderer", "LightAttack", 1, 0.7, { dashWindow = StyleLogic.DashWindow("river") })
	expectEq(d2.kind, nil)
end

cases["Mountain: heavies are armored and crush guards"] = function()
	expectTrue(StyleLogic.Armored("mountain", "HeavyAttack", nil))
	expectTrue(StyleLogic.Armored("mountain", "LightAttack", "Finisher"))
	expectTrue(not StyleLogic.Armored("mountain", "LightAttack", nil))
	expectTrue(not StyleLogic.Armored("river", "HeavyAttack", nil))
	expectTrue(StyleLogic.GuardCrush("mountain", "HeavyAttack", nil) > 1)
	expectEq(StyleLogic.GuardCrush("wind", "HeavyAttack", nil), 1)
	expectTrue(StyleLogic.ArmorPostureTaken("mountain") < 1)
end

return cases
