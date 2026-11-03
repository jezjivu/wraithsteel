-- Tests for Shared pure modules: Odds, FormatNumber, Time, Signal, RateLimiter, NetSchema checks.
local Shared = game:GetService("ReplicatedStorage").Shared
local Odds = require(Shared.Odds)
local FormatNumber = require(Shared.FormatNumber)
local Time = require(Shared.Time)
local Signal = require(Shared.Signal)
local RateLimiter = require(Shared.RateLimiter)
local NetValidate = require(Shared.NetValidate)
local NetSchema = require(Shared.NetSchema)

local cases = {}

local function sumPercent(results)
	local s = 0
	for _, r in results do
		s += math.floor(r.percent * 100 + 0.5)
	end
	return s
end

cases["Odds percents sum to exactly 100 for awkward thirds"] = function()
	local r = Odds.Compute({ { id = "a", weight = 1 }, { id = "b", weight = 1 }, { id = "c", weight = 1 } })
	expectEq(sumPercent(r), 10000)
	expectNear(r[1].chance, 1 / 3, 1e-12)
end

cases["Odds percents sum to 100 with tiny weights"] = function()
	local entries = {
		{ id = "common", weight = 7000 },
		{ id = "rare", weight = 2499.7, luckAffinity = 1 },
		{ id = "mythic", weight = 0.3, luckAffinity = 1 },
		{ id = "epic", weight = 500, luckAffinity = 1 },
	}
	for _, luck in { 1, 1.5, 2, 3.7 } do
		local r = Odds.Compute(entries, luck)
		expectEq(sumPercent(r), 10000, "luck " .. luck)
		local total = 0
		for _, x in r do
			total += x.chance
		end
		expectNear(total, 1, 1e-9)
	end
end

cases["Odds luck raises affine entries and lowers others"] = function()
	local entries = { { id = "c", weight = 90 }, { id = "r", weight = 10, luckAffinity = 1 } }
	local base = Odds.Compute(entries, 1)
	local lucky = Odds.Compute(entries, 2)
	expectNear(base[2].chance, 0.1, 1e-12)
	expectNear(lucky[2].chance, 20 / 110, 1e-12)
	expectTrue(lucky[1].chance < base[1].chance)
end

cases["Odds luck below 1 is treated as 1"] = function()
	local entries = { { id = "c", weight = 90 }, { id = "r", weight = 10, luckAffinity = 1 } }
	expectNear(Odds.Compute(entries, 0.2)[2].chance, 0.1, 1e-12)
end

cases["Odds.Roll matches Compute distribution"] = function()
	local entries = { { id = "a", weight = 70 }, { id = "b", weight = 25 }, { id = "c", weight = 5 } }
	local rng = __rng(42)
	local counts = { a = 0, b = 0, c = 0 }
	local N = 200000
	for _ = 1, N do
		local id = Odds.Roll(entries, 1, rng)
		counts[id] += 1
	end
	expectNear(counts.a / N, 0.70, 0.01)
	expectNear(counts.b / N, 0.25, 0.01)
	expectNear(counts.c / N, 0.05, 0.005)
end

cases["Odds.Roll edge rng values"] = function()
	local entries = { { id = "a", weight = 1 }, { id = "z", weight = 0 } }
	expectEq(Odds.Roll(entries, 1, function()
		return 0
	end), "a")
	expectEq(Odds.Roll(entries, 1, function()
		return 0.9999999999
	end), "a")
end

cases["Odds rejects zero/negative totals"] = function()
	expectError(function()
		Odds.Compute({ { id = "a", weight = 0 } })
	end)
	expectError(function()
		Odds.Compute({ { id = "a", weight = -1 }, { id = "b", weight = 5 } })
	end)
end

cases["FormatNumber.Short suffixes"] = function()
	expectEq(FormatNumber.Short(0), "0")
	expectEq(FormatNumber.Short(999), "999")
	expectEq(FormatNumber.Short(999.9), "999")
	expectEq(FormatNumber.Short(1000), "1K")
	expectEq(FormatNumber.Short(1234), "1.2K")
	expectEq(FormatNumber.Short(1299), "1.2K")
	expectEq(FormatNumber.Short(3456789), "3.4M")
	expectEq(FormatNumber.Short(5.6e9), "5.6B")
	expectEq(FormatNumber.Short(7.25e12), "7.2T")
	expectEq(FormatNumber.Short(999999), "999.9K")
	expectEq(FormatNumber.Short(-1500), "-1.5K")
	expectEq(FormatNumber.Short(1e15), "1Qa")
	expectEq(FormatNumber.Short(0 / 0), "0")
	expectEq(FormatNumber.Short(12345, 2), "12.34K")
end

cases["FormatNumber.Commas and Percent"] = function()
	expectEq(FormatNumber.Commas(0), "0")
	expectEq(FormatNumber.Commas(999), "999")
	expectEq(FormatNumber.Commas(1000), "1,000")
	expectEq(FormatNumber.Commas(1234567), "1,234,567")
	expectEq(FormatNumber.Commas(-1234567), "-1,234,567")
	expectEq(FormatNumber.Percent(12.5), "12.5%")
	expectEq(FormatNumber.Percent(100), "100%")
	expectEq(FormatNumber.Percent(0.05), "0.05%")
end

cases["Time day keys and durations"] = function()
	expectEq(Time.DayKey(0), 0)
	expectEq(Time.DayKey(86399), 0)
	expectEq(Time.DayKey(86400), 1)
	expectEq(Time.SecondsUntilNextDay(86400 - 10), 10)
	expectEq(Time.FormatDuration(9), "9s")
	expectEq(Time.FormatDuration(65), "1m 05s")
	expectEq(Time.FormatDuration(3725), "1h 02m")
	expectEq(Time.FormatDuration(90061), "1d 1h")
end

cases["Signal connect/fire/disconnect/once"] = function()
	local s = Signal.new()
	local got = 0
	local c = s:Connect(function(n)
		got += n
	end)
	s:Once(function(n)
		got += n * 100
	end)
	s:Fire(1)
	s:Fire(1)
	expectEq(got, 102)
	c:Disconnect()
	s:Fire(1)
	expectEq(got, 102)
end

cases["RateLimiter burst then refill"] = function()
	local now = 0
	local rl = RateLimiter.new(3, 1, function()
		return now
	end)
	expectTrue(rl:Allow("p"))
	expectTrue(rl:Allow("p"))
	expectTrue(rl:Allow("p"))
	expectTrue(not rl:Allow("p"))
	expectTrue(rl:Allow("other"))
	now = 1.01
	expectTrue(rl:Allow("p"))
	expectTrue(not rl:Allow("p"))
	now = 100
	for _ = 1, 3 do
		expectTrue(rl:Allow("p"))
	end
	expectTrue(not rl:Allow("p"))
end

cases["NetValidate accepts good and rejects bad args"] = function()
	expectTrue(NetValidate.Check({ "string", "integer" }, table.pack("lantern_ash", 3)))
	expectTrue(not NetValidate.Check({ "string", "integer" }, table.pack("x", 1.5)))
	expectTrue(not NetValidate.Check({ "string", "integer" }, table.pack("x", 0 / 0)))
	expectTrue(not NetValidate.Check({ "string" }, table.pack("x", "extra")))
	expectTrue(not NetValidate.Check({ "string" }, table.pack(string.rep("a", 65))))
	expectTrue(not NetValidate.Check({ "number" }, table.pack(math.huge)))
	expectTrue(NetValidate.Check({ "string", "integer?" }, table.pack("invite")))
	expectTrue(not NetValidate.Check({ "string" }, table.pack(nil)))
	expectTrue(NetValidate.Check({ "uidList" }, table.pack({ "a", "b" })))
	expectTrue(not NetValidate.Check({ "uidList" }, table.pack({ a = "x" })))
	expectTrue(not NetValidate.Check({ "uidList" }, table.pack({ "a", 5 })))
	expectTrue(not NetValidate.Check({ "table" }, table.pack(setmetatable({}, {}))))
end

cases["NetSchema entries are well formed"] = function()
	for name, def in NetSchema do
		expectTrue(def.kind == "Event" or def.kind == "Function", name)
		if def.direction == "ToServer" then
			expectTrue(def.args ~= nil, name .. " needs args spec")
			expectTrue(def.rate ~= nil, name .. " needs rate limit")
			for _, t in def.args do
				expectTrue(NetValidate.Check({ t }, table.pack(nil)) ~= nil, name)
			end
		else
			expectEq(def.direction, "ToClient", name)
		end
	end
end

cases["ValleyClock: hours wrap and night spans midnight"] = function()
	local ValleyClock = require(game:GetService("ReplicatedStorage").Shared.ValleyClock)
	for _, t in { 0, 100, 12345, 987654 } do
		local h = ValleyClock.HourAt(t)
		expectTrue(h >= 0 and h < 24, "hour in range")
	end
	expectEq(ValleyClock.IsNightAt(22), true)
	expectEq(ValleyClock.IsNightAt(2), true)
	expectEq(ValleyClock.IsNightAt(12), false)
	expectEq(ValleyClock.IsNightAt(17.4), false)
end

return cases
