-- Tests for Logic/ExploitScore: decaying suspicion score and the sustained-speed check.
local SSS = game:GetService("ServerScriptService")
local ExploitScore = require(SSS.Logic.ExploitScore)
local SecurityConfig = require(SSS.ServerConfig.SecurityConfig)

local cases = {}

cases["Security: occasional rate hits never flag"] = function()
	local st = ExploitScore.New(0)
	-- one rate rejection every 5 seconds for an hour
	for t = 0, 3600, 5 do
		expectEq(ExploitScore.Add(st, "rate", t), "ok")
	end
	expectTrue(not st.flagged)
end

cases["Security: rate spam alone can flag but never kicks"] = function()
	local st = ExploitScore.New(0)
	for i = 1, 5000 do
		expectTrue(ExploitScore.Add(st, "rate", i * 0.02) ~= "kick")
	end
	expectTrue(st.flagged)
end

cases["Security: invalid-argument spam flags once, then kicks"] = function()
	local st = ExploitScore.New(0)
	local verdicts = {}
	for i = 1, 400 do
		local v = ExploitScore.Add(st, "type: expected string", i * 0.01)
		verdicts[v] = (verdicts[v] or 0) + 1
		if v == "kick" then
			break
		end
	end
	expectEq(verdicts.flag, 1, "flag is reported once")
	expectEq(verdicts.kick, if SecurityConfig.KickEnabled then 1 else nil)
	expectEq(ExploitScore.Category("rate"), "rate")
	expectEq(ExploitScore.Category("arg 1: not a number"), "invalid")
end

cases["Security: score halves every half-life"] = function()
	local st = ExploitScore.New(0)
	ExploitScore.Add(st, "invalid", 0)
	local w = SecurityConfig.Weights.invalid
	expectNear(ExploitScore.Decayed(st, SecurityConfig.HalfLifeSeconds), w / 2, 1e-9)
	expectNear(ExploitScore.Decayed(st, 2 * SecurityConfig.HalfLifeSeconds), w / 4, 1e-9)
end

cases["Security: single teleport jump is ignored, sustained speed is caught"] = function()
	local dt = SecurityConfig.MoveSampleSeconds
	local m, bad = ExploitScore.Move(nil, 0, 0, 0, 0)
	expectTrue(not bad)
	-- normal sprinting
	local t, x = 0, 0
	for _ = 1, 20 do
		t += dt
		x += 25 * dt
		m, bad = ExploitScore.Move(m, x, 0, 0, t)
		expectTrue(not bad)
	end
	-- one waystone teleport of 2,000 studs
	t += dt
	x += 2000
	m, bad = ExploitScore.Move(m, x, 0, 0, t)
	expectTrue(not bad)
	-- grapple pull at 120 studs/s for 2 seconds
	for _ = 1, math.floor(2 / dt) do
		t += dt
		x += 120 * dt
		m, bad = ExploitScore.Move(m, x, 0, 0, t)
		expectTrue(not bad, "grapple is legal")
	end
	-- speed hack at 400 studs/s
	local caught = false
	for _ = 1, SecurityConfig.SustainedSamples do
		t += dt
		x += 400 * dt
		m, bad = ExploitScore.Move(m, x, 0, 0, t)
		caught = caught or bad
	end
	expectTrue(caught)
	-- falling fast is fine, flying up fast is not
	local f = ExploitScore.Move(nil, 0, 1000, 0, 0)
	local any = false
	for i = 1, 5 do
		f, bad = ExploitScore.Move(f, 0, 1000 - i * 100, 0, i * dt)
		any = any or bad
	end
	expectTrue(not any, "falling is not limited")
	local u = ExploitScore.Move(nil, 0, 0, 0, 0)
	for i = 1, SecurityConfig.SustainedSamples do
		u, bad = ExploitScore.Move(u, 0, i * 300 * dt, 0, i * dt)
	end
	expectTrue(bad, "rising at 300 studs/s is caught")
end

return cases
