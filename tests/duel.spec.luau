-- Duels (Logic/DuelLogic): challenges, round flow, scoring, fair damage, reward cooldown.
local DuelLogic = require(game:GetService("ServerScriptService").Logic.DuelLogic)
local PvpConfig = require(game:GetService("ReplicatedStorage").Config.PvpConfig)

local cases = {}
local function free()
	return false
end

cases["Duel: challenge, mutual challenge accepts, expiry, self/busy"] = function()
	local ch = {}
	expectEq(select(2, DuelLogic.Challenge(ch, 1, 1, 0, free)), "You cannot duel yourself")
	expectEq(select(2, DuelLogic.Challenge(ch, 1, 2, 0, function(id) return id == 2 end)), "One of you is busy")
	expectTrue(DuelLogic.Challenge(ch, 1, 2, 0, free))
	expectEq(DuelLogic.Pending(ch, 2, 1)[1], 1)
	-- 2 challenging 1 back = accept
	expectEq(select(2, DuelLogic.Challenge(ch, 2, 1, 1, free)), "accept")
	local ch2 = {}
	DuelLogic.Challenge(ch2, 1, 2, 0, free)
	expectTrue(not DuelLogic.Accept(ch2, 2, 1, PvpConfig.ChallengeSeconds + 1), "expired")
	DuelLogic.Challenge(ch2, 1, 2, 100, free)
	expectTrue(DuelLogic.Accept(ch2, 2, 1, 101))
	expectTrue(not DuelLogic.Accept(ch2, 2, 1, 101), "only once")
end

cases["Duel: best of three via knockouts"] = function()
	local m = DuelLogic.NewMatch(1, 10, 20, 0)
	local hp = function() return 1 end
	expectTrue(not DuelLogic.Knockout(m, 20, 0), "no knockouts during the countdown")
	expectEq(DuelLogic.Advance(m, PvpConfig.CountdownSeconds, hp), "Fight")
	expectTrue(DuelLogic.Knockout(m, 20, 5))
	expectEq(m.wins[10], 1)
	expectEq(m.phase, "RoundEnd")
	expectTrue(not DuelLogic.Knockout(m, 10, 5.1), "a round ends once")
	expectEq(DuelLogic.Advance(m, m.endsAt, hp), "NextRound")
	expectEq(m.round, 2)
	DuelLogic.Advance(m, m.endsAt, hp)
	DuelLogic.Knockout(m, 20, m.endsAt - 10)
	expectEq(m.phase, "Over")
	expectEq(m.winner, 10)
	expectEq(DuelLogic.Advance(m, m.endsAt, hp), "Close")
end

cases["Duel: timeout goes to the healthier fighter, draws replay, forfeits end it"] = function()
	local m = DuelLogic.NewMatch(1, 10, 20, 0)
	DuelLogic.Advance(m, m.endsAt, function() return 1 end)
	local hp = { [10] = 0.4, [20] = 0.7 }
	DuelLogic.Advance(m, m.endsAt, function(id) return hp[id] end)
	expectEq(m.roundWinner, 20)
	DuelLogic.Advance(m, m.endsAt, function() return 1 end)
	DuelLogic.Advance(m, m.endsAt, function() return 1 end)
	DuelLogic.Advance(m, m.endsAt, function() return 0.5 end)
	expectEq(m.roundWinner, nil)
	expectEq(m.wins[10] + m.wins[20], 1, "a draw scores nothing")
	DuelLogic.Forfeit(m, 20, 1000, "left")
	expectEq(m.winner, 10)
	expectEq(m.reason, "left")
end

cases["Duel: fair damage ignores Power, deathblow on broken posture"] = function()
	local base = DuelLogic.HitDamage(20, 1, 1, 1, false, PvpConfig.Health)
	expectNear(base, 20 * PvpConfig.DamageScale, 1e-9)
	local broken = DuelLogic.HitDamage(20, 1, 1, 1, true, PvpConfig.Health)
	expectNear(broken - base, PvpConfig.Health * PvpConfig.DeathblowFraction, 1e-9)
	-- with real weapons a round takes 10-30 clean light hits (readable, not instant, not a slog)
	local Moves = require(game:GetService("ReplicatedStorage").Config.WeaponConfig).Moves
	for _, id in { "jian_light_1", "dao_light_1", "spear_light_1", "fan_light_1", "staff_light_1" } do
		local hits = PvpConfig.Health / DuelLogic.HitDamage(Moves[id].damage, 1, 1, 1, false, PvpConfig.Health)
		expectTrue(hits >= 10 and hits <= 30, string.format("%s: %.1f hits per round", id, hits))
	end
end

cases["Duel: rewards once per pair per cooldown"] = function()
	local last = {}
	local w, l = DuelLogic.Rewards(last, 1, 2, 0)
	expectEq(w, PvpConfig.WinEmber)
	expectEq(l, PvpConfig.LoseEmber)
	expectEq((DuelLogic.Rewards(last, 2, 1, 10)), 0, "same pair, either order")
	expectEq((DuelLogic.Rewards(last, 1, 2, PvpConfig.RewardCooldownSeconds + 1)), PvpConfig.WinEmber)
end

return cases
