-- Tests for combat & AI pure logic: CombatRules, Posture, AttackDirector, AIScheduler, BossStateMachine.
local Logic = game:GetService("ServerScriptService").Logic
local Config = game:GetService("ReplicatedStorage").Config

local CombatRules = require(Logic.CombatRules)
local Posture = require(Logic.Posture)
local AttackDirector = require(Logic.AttackDirector)
local AIScheduler = require(Logic.AIScheduler)
local BossStateMachine = require(Logic.BossStateMachine)
local CombatConfig = require(Config.CombatConfig)
local WeaponConfig = require(Config.WeaponConfig)
local BossConfig = require(Config.BossConfig)

local W = "jian_wanderer"
local cases = {}

cases["Combat: seq must increase"] = function()
	local s = CombatRules.NewState()
	expectTrue(CombatRules.Validate(s, W, "LightAttack", 1, 0).ok)
	expectEq(CombatRules.Validate(s, W, "LightAttack", 1, 5).reason, "Seq")
	expectEq(CombatRules.Validate(s, W, "LightAttack", 0, 5).reason, "Seq")
end

cases["Combat: light combo advances, then resets after idle"] = function()
	local s = CombatRules.NewState()
	local t = 0
	local seq = 0
	local seen = {}
	for _ = 1, 5 do
		seq += 1
		local d = CombatRules.Validate(s, W, "LightAttack", seq, t)
		expectTrue(d.ok, d.reason)
		table.insert(seen, d.moveId)
		t += CombatRules.Commit(s, d, t) + 0.01
	end
	expectEq(seen[1], "jian_light_1")
	expectEq(seen[4], "jian_light_4")
	expectEq(seen[5], "jian_light_1") -- combo wraps
	seq += 1
	t += 5
	expectEq(CombatRules.Validate(s, W, "LightAttack", seq, t).moveId, "jian_light_1")
end

cases["Combat: busy blocks attacks, dodge cancels only cancelable moves"] = function()
	local s = CombatRules.NewState()
	local d = CombatRules.Validate(s, W, "LightAttack", 1, 0)
	CombatRules.Commit(s, d, 0)
	expectEq(CombatRules.Validate(s, W, "HeavyAttack", 2, 0.05).reason, "Busy")
	expectTrue(CombatRules.Validate(s, W, "Dodge", 3, 0.05).ok)
	local s2 = CombatRules.NewState()
	CombatRules.Commit(s2, CombatRules.Validate(s2, W, "HeavyAttack", 1, 0), 0)
	expectEq(CombatRules.Validate(s2, W, "Dodge", 2, 0.1).reason, "Busy")
end

cases["Combat: skill cooldown and ultimate charge"] = function()
	local s = CombatRules.NewState()
	local d = CombatRules.Validate(s, W, "Skill1", 1, 0)
	expectTrue(d.ok)
	local dur = CombatRules.Commit(s, d, 0)
	expectEq(CombatRules.Validate(s, W, "Skill1", 2, dur + 0.1).reason, "Cooldown")
	expectTrue(CombatRules.Validate(s, W, "Skill1", 3, 100).ok)
	expectEq(CombatRules.Validate(s, W, "Ultimate", 4, 100).reason, "NoCharge")
	s.ultimateCharge = WeaponConfig.UltimateChargeMax
	expectTrue(CombatRules.Validate(s, W, "Ultimate", 5, 100).ok)
end

cases["Combat: stunned and rate limit"] = function()
	local s = CombatRules.NewState()
	s.stunnedUntil = 10
	expectEq(CombatRules.Validate(s, W, "Dodge", 1, 5).reason, "Stunned")
	local s2 = CombatRules.NewState()
	for i = 1, CombatConfig.Validation.MaxActionsPerSecond do
		table.insert(s2.recentActions, 0.01 * i)
	end
	expectEq(CombatRules.Validate(s2, W, "Parry", 1, 0.5).reason, "Rate")
end

cases["Combat: parry window, block, perilous and iframes"] = function()
	local s = CombatRules.NewState()
	CombatRules.Commit(s, CombatRules.Validate(s, W, "Parry", 1, 0), 0)
	local hit = { damage = 10, postureDamage = 20 }
	expectEq(CombatRules.ResolveIncoming(s, hit, 0.1).outcome, "Parried")
	expectEq(s.whiffStreak, 0)
	expectEq(CombatRules.ResolveIncoming(s, hit, 0.5).outcome, "Blocked")
	expectEq(CombatRules.ResolveIncoming(s, hit, 2).outcome, "Blocked") -- still holding guard
	CombatRules.Commit(s, CombatRules.Validate(s, W, "GuardRelease", 2, 2), 2)
	expectEq(CombatRules.ResolveIncoming(s, hit, 3).outcome, "Hit")
	expectEq(CombatRules.ResolveIncoming(s, { damage = 10, postureDamage = 20, perilous = true }, 0.5).outcome, "Hit") -- guard can't block perilous
	local s2 = CombatRules.NewState()
	CombatRules.Commit(s2, CombatRules.Validate(s2, W, "Dodge", 1, 0), 0)
	expectEq(CombatRules.ResolveIncoming(s2, { damage = 10, postureDamage = 20, perilous = true }, 0.1).outcome, "Dodged")
end

cases["Combat: guard release always allowed, attacking drops guard"] = function()
	local s = CombatRules.NewState()
	CombatRules.Commit(s, CombatRules.Validate(s, W, "Parry", 1, 0), 0)
	s.stunnedUntil = 5
	expectEq(CombatRules.Validate(s, W, "GuardRelease", 2, 1).ok, true)
	local s2 = CombatRules.NewState()
	CombatRules.Commit(s2, CombatRules.Validate(s2, W, "Parry", 1, 0), 0)
	CombatRules.Commit(s2, CombatRules.Validate(s2, W, "LightAttack", 2, 1), 1)
	expectEq(CombatRules.IsGuarding(s2, 1.1), false)
end

cases["Combat: perilous answers - Needle Counter, Crane Leap, Grasp needs a dodge"] = function()
	local s = CombatRules.NewState()
	local pierce = { damage = 30, postureDamage = 20, perilous = true, perilousKind = "Pierce" }
	local r = CombatRules.ResolveIncoming(s, pierce, 1, { dashedToward = true })
	expectEq(r.outcome, "Countered")
	expectEq(r.damage, 0)
	expectTrue(r.reflectPosture > 20, "counter crushes attacker posture")
	expectTrue(s.riposteUntil > 1, "counter opens a riposte")
	expectEq(CombatRules.ResolveIncoming(CombatRules.NewState(), pierce, 1, {}).outcome, "Hit")
	local sweep = { damage = 30, postureDamage = 20, perilous = true, perilousKind = "Sweep" }
	expectEq(CombatRules.ResolveIncoming(CombatRules.NewState(), sweep, 1, { airborne = true }).outcome, "Jumped")
	expectEq(CombatRules.ResolveIncoming(CombatRules.NewState(), sweep, 1, { airborne = false }).outcome, "Hit")
	local grasp = { damage = 30, postureDamage = 20, perilous = true, perilousKind = "Grasp" }
	expectEq(CombatRules.ResolveIncoming(CombatRules.NewState(), grasp, 1, { airborne = true, dashedToward = true }).outcome, "Hit")
	-- A perfect deflect stops even perilous attacks (and reflects extra posture)...
	local p = CombatRules.NewState()
	CombatRules.Commit(p, CombatRules.Validate(p, W, "Parry", 1, 0), 0)
	local pr = CombatRules.ResolveIncoming(p, grasp, 0.05, {})
	expectEq(pr.outcome, "Parried")
	expectTrue(pr.reflectPosture > 20 * 0.6, "perilous deflect reflects extra posture")
	-- ...but holding guard does not block them.
	expectEq(CombatRules.ResolveIncoming(p, grasp, 0.5, {}).outcome, "Hit")
end

cases["Combat: parry spam increases cooldown"] = function()
	local s = CombatRules.NewState()
	CombatRules.Commit(s, CombatRules.Validate(s, W, "Parry", 1, 0), 0)
	local first = s.parryReadyAt
	CombatRules.Commit(s, CombatRules.Validate(s, W, "Parry", 2, first), first)
	expectTrue(s.parryReadyAt - first > first - 0, "second whiff should cost more")
end

cases["Combat: arc and range checks"] = function()
	expectTrue(CombatRules.InArc(0, 0, 0, -1, 0, -5, 7, 90))
	expectTrue(not CombatRules.InArc(0, 0, 0, -1, 0, 5, 7, 90)) -- behind
	expectTrue(not CombatRules.InArc(0, 0, 0, -1, 0, -20, 7, 90)) -- too far
	expectTrue(CombatRules.InArc(0, 0, 0, -1, 0, -9.5, 7, 90)) -- within tolerance
	expectTrue(CombatRules.InArc(0, 0, 0, -1, 0, 5, 7, 360))
end

cases["Posture breaks at max, then regenerates"] = function()
	local p = Posture.new(100, 10, 1)
	expectTrue(not Posture.Add(p, 60, 0, 2))
	expectTrue(Posture.Add(p, 50, 0.1, 2))
	expectTrue(Posture.IsBroken(p, 1))
	expectTrue(not Posture.Add(p, 50, 1, 2)) -- no damage while broken
	expectTrue(not Posture.IsBroken(p, 3))
	Posture.Add(p, 50, 3, 2)
	Posture.Update(p, 3.5, 0.5)
	expectEq(p.value, 50) -- still in regen delay
	Posture.Update(p, 4.5, 1)
	expectEq(p.value, 40)
end

cases["AttackDirector caps attackers per target and cools down"] = function()
	local d = AttackDirector.new(2, 2.5, 0.6)
	expectTrue(d:Request("e1", "p1", 0))
	expectTrue(d:Request("e2", "p1", 0))
	expectTrue(not d:Request("e3", "p1", 0))
	expectTrue(d:Request("e1", "p1", 0.1)) -- re-request while holding
	d:Release("e1", 1)
	expectTrue(not d:Request("e3", "p1", 1.2)) -- slot cooling down
	expectTrue(d:Request("e3", "p1", 1.7))
	expectTrue(d:Request("e4", "p2", 0))
	expectEq(d:HolderCount("p1", 1.7), 2)
	expectEq(d:HolderCount("p1", 10), 0) -- expired
end

cases["AIScheduler runs each agent at tick rate, capped per step"] = function()
	local s = AIScheduler.new(10, 3)
	local runs = {}
	for i = 1, 5 do
		local id = "e" .. i
		runs[id] = 0
		s:Add(id, function()
			runs[id] += 1
		end, 0)
	end
	-- simulate 1 second at 60 fps
	for f = 1, 60 do
		s:Step(f / 60)
	end
	for id, n in runs do
		expectTrue(n >= 8 and n <= 11, id .. " ran " .. n)
	end
	s:Remove("e3")
	expectEq(s:Count(), 4)
	-- erroring agent does not stop others
	s:Add("bad", function()
		error("x")
	end, 2)
	expectTrue(s:Step(5) >= 1)
end

cases["Sable Crane: chase -> move -> recovery -> chase, phase 2 at 50%"] = function()
	local events = {}
	local m = BossStateMachine.new("sable_crane", function()
		return 0
	end, function(e, ...)
		table.insert(events, e)
	end)
	local ctx = { hasTarget = true, targetDistance = 5, hpFraction = 1 }
	m:Update(0, ctx)
	expectEq(m.state, "Chase")
	m:Update(0.1, ctx)
	expectEq(m.state, "Windup")
	expectEq(m.move, "quick_cut") -- first in-range move at distance 5 with rng 0
	m:Update(1, ctx)
	expectEq(m.state, "Active")
	m:Update(1.2, ctx)
	expectEq(m.state, "Recovery")
	m:Update(2, ctx)
	expectEq(m.state, "Chase")
	ctx.hpFraction = 0.49
	m:Update(2.1, ctx)
	expectEq(m.state, "Transition")
	expectEq(m.phase, 2)
	expectTrue(m.invulnerable)
	m:Update(10, ctx)
	expectEq(m.state, "Chase")
	ctx.hpFraction = 0
	m:Update(11, ctx)
	expectEq(m.state, "Dead")
	expectTrue(table.find(events, "Died") ~= nil)
end

cases["Sable Crane: ranged move at range, break interrupts"] = function()
	local m = BossStateMachine.new("sable_crane", function()
		return 0
	end, function() end)
	m:Update(0, { hasTarget = true, targetDistance = 20, hpFraction = 1 })
	m:Update(0.1, { hasTarget = true, targetDistance = 20, hpFraction = 1 })
	expectEq(m.move, "gate_thrust") -- melee is out of reach at 20 studs; the long thrust is not
	m:Break(0.2)
	expectEq(m.state, "Broken")
	expectEq(m.move, nil)
	m:Update(0.3 + BossConfig.Bosses.sable_crane.postureBrokenSeconds, { hasTarget = true, targetDistance = 20, hpFraction = 1 })
	expectEq(m.state, "Chase")
	local def = BossConfig.Bosses.sable_crane
	expectEq(BossStateMachine.ScaledHealth("sable_crane", 1), def.maxHealth)
	expectEq(BossStateMachine.ScaledHealth("sable_crane", 4), math.floor(def.maxHealth * (1 + 3 * def.healthPerExtraPlayer) + 0.5))
end

cases["Combat routes: air attack once per jump, dash strike, combo finisher"] = function()
	local s = CombatRules.NewState()
	local w = WeaponConfig.Weapons[W]
	local d = CombatRules.Validate(s, W, "LightAttack", 1, 0, { airborne = true })
	expectEq(d.moveId, w.air)
	expectEq(d.kind, "Air")
	local t = CombatRules.Commit(s, d, 0)
	d = CombatRules.Validate(s, W, "LightAttack", 2, t + 0.01, { airborne = true })
	expectEq(d.moveId, w.lightCombo[1]) -- second air press: normal combo
	-- dash strike
	local s2 = CombatRules.NewState()
	CombatRules.Commit(s2, CombatRules.Validate(s2, W, "Dodge", 1, 0), 0)
	d = CombatRules.Validate(s2, W, "LightAttack", 2, 0.4)
	expectEq(d.kind, "Dash")
	CombatRules.Commit(s2, d, 0.4)
	-- finisher after two lights
	local s3 = CombatRules.NewState()
	local now = 0
	for i = 1, 2 do
		local x = CombatRules.Validate(s3, W, "LightAttack", i, now)
		now += CombatRules.Commit(s3, x, now) + 0.01
	end
	d = CombatRules.Validate(s3, W, "HeavyAttack", 3, now)
	expectEq(d.moveId, w.finisher)
	CombatRules.Commit(s3, d, now)
	expectEq(s3.comboIndex, 0)
end

cases["Combat: perfect parry opens riposte window; style speed shortens moves"] = function()
	local s = CombatRules.NewState()
	CombatRules.Commit(s, CombatRules.Validate(s, W, "Parry", 1, 0), 0, nil, { parryWindowBonus = 0.1 })
	expectEq(CombatRules.ResolveIncoming(s, { damage = 5, postureDamage = 5 }, 0.25).outcome, "Parried") -- 0.2 + 0.1 bonus
	expectTrue(s.riposteUntil > 0.25)
	local a, b = CombatRules.NewState(), CombatRules.NewState()
	local slow = CombatRules.Commit(a, CombatRules.Validate(a, W, "HeavyAttack", 1, 0), 0, nil, { speed = 1 })
	local fast = CombatRules.Commit(b, CombatRules.Validate(b, W, "HeavyAttack", 1, 0), 0, nil, { speed = 1.25 })
	expectTrue(fast < slow)
end

cases["Every class has finisher, air and dash moves"] = function()
	for id, w in WeaponConfig.Weapons do
		for _, m in { w.finisher, w.air, w.dash } do
			expectTrue(WeaponConfig.Moves[m] ~= nil, id .. " " .. tostring(m))
		end
	end
end

return cases
