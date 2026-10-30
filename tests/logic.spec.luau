-- Tests for server pure logic: ReceiptLedger, Migrations, SpiritLogic (fusion), LanternRoll,
-- RewardLogic, ProgressionMath.
local Logic = game:GetService("ServerScriptService").Logic
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = game:GetService("ReplicatedStorage").Config

local ReceiptLedger = require(Logic.ReceiptLedger)
local Migrations = require(Logic.Migrations)
local ProfileTemplate = require(Logic.ProfileTemplate)
local SpiritLogic = require(Logic.SpiritLogic)
local LanternRoll = require(Logic.LanternRoll)
local RewardLogic = require(Logic.RewardLogic)
local ProgressionMath = require(Shared.ProgressionMath)
local LanternOdds = require(Shared.LanternOdds)
local EconomyConfig = require(Config.EconomyConfig)
local SpiritConfig = require(Config.SpiritConfig)
local LanternConfig = require(Config.LanternConfig)

local cases = {}

-- ReceiptLedger ------------------------------------------------------------------------------
local function ledger()
	return { receipts = {}, receiptOrder = {}, robuxSpent = 0 }
end

cases["Receipt: grants once, retries are no-ops"] = function()
	local l = ledger()
	local jade = 0
	local grant = function()
		jade += 80
		return true
	end
	expectEq(ReceiptLedger.Apply(l, "p1", 25, 10, grant), "Granted")
	expectEq(ReceiptLedger.Apply(l, "p1", 25, 10, grant), "AlreadyGranted")
	expectEq(ReceiptLedger.Apply(l, "p1", 25, 10, grant), "AlreadyGranted")
	expectEq(jade, 80)
	expectEq(l.robuxSpent, 25)
end

cases["Receipt: failed grant records nothing so Roblox retries"] = function()
	local l = ledger()
	expectEq(ReceiptLedger.Apply(l, "p2", 25, 10, function()
		return false
	end), "GrantFailed")
	expectEq(ReceiptLedger.Apply(l, "p2", 25, 10, function()
		error("boom")
	end), "GrantFailed")
	expectTrue(not ReceiptLedger.HasReceipt(l, "p2"))
	expectEq(ReceiptLedger.Apply(l, "p2", 25, 10, function()
		return true
	end), "Granted")
	expectEq(l.robuxSpent, 25)
end

cases["Receipt: history is capped FIFO"] = function()
	local l = ledger()
	for i = 1, 5 do
		ReceiptLedger.Apply(l, "p" .. i, 1, 3, function()
			return true
		end)
	end
	expectEq(#l.receiptOrder, 3)
	expectTrue(not ReceiptLedger.HasReceipt(l, "p1"))
	expectTrue(not ReceiptLedger.HasReceipt(l, "p2"))
	expectTrue(ReceiptLedger.HasReceipt(l, "p5"))
end

-- Migrations ---------------------------------------------------------------------------------
cases["Migrations: template is current, legacy upgrades, newer refuses"] = function()
	local t = ProfileTemplate.New()
	expectEq(t.dataVersion, EconomyConfig.DataVersion)
	expectEq(Migrations.Run(t), false)
	local legacy = { ember = 5 }
	expectEq(Migrations.Run(legacy), true)
	expectEq(legacy.dataVersion, EconomyConfig.DataVersion)
	expectTrue(type(legacy.receipts) == "table")
	expectError(function()
		Migrations.Run({ dataVersion = EconomyConfig.DataVersion + 1 })
	end)
end

-- Fusion -------------------------------------------------------------------------------------
local function spiritData()
	local d = ProfileTemplate.New()
	d.ember = 10000
	return d
end

cases["Fusion: 3 commons -> 1 uncommon, deterministic best mutation & level"] = function()
	local d = spiritData()
	local a = SpiritLogic.Create(d, "lantern_moth", "Common", "None", 0)
	local b = SpiritLogic.Create(d, "lantern_moth", "Common", "Gilded", 0)
	local c = SpiritLogic.Create(d, "lantern_moth", "Common", "Ashen", 0)
	b.level = 7
	local plan, err = SpiritLogic.PlanFusion(d, { a.uid, b.uid, c.uid })
	expectTrue(plan ~= nil, err)
	expectEq(plan.toRarity, "Uncommon")
	expectEq(plan.mutation, "Gilded")
	expectEq(plan.level, 7)
	local out = SpiritLogic.ApplyFusion(d, plan, 1)
	expectEq(SpiritLogic.Count(d), 1)
	expectEq(out.rarity, "Uncommon")
	expectEq(out.fusedCount, 1)
	expectEq(d.ember, 10000 - SpiritConfig.Rarities.Common.fuseCostEmber)
end

cases["Fusion: same input always gives same output"] = function()
	local results = {}
	for run = 1, 2 do
		local d = spiritData()
		local u = {}
		for _, m in { "Moonlit", "None", "Hollow" } do
			table.insert(u, SpiritLogic.Create(d, "reed_fox", "Uncommon", m, 0).uid)
		end
		local plan = SpiritLogic.PlanFusion(d, u)
		results[run] = plan.toRarity .. plan.mutation .. plan.level
	end
	expectEq(results[1], results[2])
	expectEq(results[1], "RareHollow1")
end

cases["Fusion: rejects mixed, locked, equipped, wrong count, broke, mythic, duplicates"] = function()
	local d = spiritData()
	local a = SpiritLogic.Create(d, "lantern_moth", "Common", "None", 0).uid
	local b = SpiritLogic.Create(d, "lantern_moth", "Common", "None", 0).uid
	local c = SpiritLogic.Create(d, "ember_sparrow", "Common", "None", 0).uid
	local e = SpiritLogic.Create(d, "lantern_moth", "Common", "None", 0).uid
	expectEq(select(2, SpiritLogic.PlanFusion(d, { a, b, c })), "Spirits must be the same species and rarity")
	expectEq(select(2, SpiritLogic.PlanFusion(d, { a, b })), "Fusion needs exactly 3 Spirits")
	expectEq(select(2, SpiritLogic.PlanFusion(d, { a, a, b })), "Invalid selection")
	d.spirits[e].locked = true
	expectEq(select(2, SpiritLogic.PlanFusion(d, { a, b, e })), "A selected Spirit is locked")
	d.spirits[e].locked = false
	SpiritLogic.Equip(d, e, 0)
	expectEq(select(2, SpiritLogic.PlanFusion(d, { a, b, e })), "Unequip Spirits before fusing")
	SpiritLogic.Unequip(d, e)
	d.ember = 0
	expectEq(select(2, SpiritLogic.PlanFusion(d, { a, b, e })), "Not enough Ember")
	local m = SpiritLogic.Create(d, "ninth_bell_wraith", "Mythic", "None", 0).uid
	expectEq(select(2, SpiritLogic.PlanFusion(d, { m })), "This rarity cannot be fused")
	expectEq(SpiritLogic.Count(d), 5)
end

cases["Spirits: equip respects slots, release refunds and skips locked"] = function()
	local d = spiritData()
	local uids = {}
	for _ = 1, 5 do
		table.insert(uids, SpiritLogic.Create(d, "lantern_moth", "Common", "None", 0).uid)
	end
	for i = 1, 3 do
		expectTrue(SpiritLogic.Equip(d, uids[i], 0))
	end
	expectTrue(not SpiritLogic.Equip(d, uids[4], 0))
	expectTrue(SpiritLogic.Equip(d, uids[4], 2))
	d.spirits[uids[5]].locked = true
	expectEq(SpiritLogic.Release(d, { uids[1], uids[5] }), nil)
	local before = d.ember
	expectEq(SpiritLogic.Release(d, { uids[1], uids[2] }), 4)
	expectEq(d.ember, before + 4)
	expectEq(#d.equippedSpirits, 2)
end

-- Lanterns -----------------------------------------------------------------------------------
cases["Lantern sheet: displayed odds sum to 100 and match roll entries"] = function()
	for id in LanternConfig.Lanterns do
		for _, luck in { 1, 1.25, 2 } do
			local sheet = LanternOdds.Sheet(id, luck, 0)
			local s = 0
			for _, r in sheet.spirits do
				s += math.floor(r.percent * 100 + 0.5)
			end
			expectEq(s, 10000, id)
			s = 0
			for _, r in sheet.mutations do
				s += math.floor(r.percent * 100 + 0.5)
			end
			expectEq(s, 10000, id .. " mutations")
		end
	end
end

cases["Lantern pity guarantees minRarity within N opens"] = function()
	local pity = {}
	local rng = function()
		return 0 -- always the first (most common) entry
	end
	local def = LanternConfig.Lanterns.jade_lantern
	local minOrder = SpiritConfig.Rarities[def.pity.minRarity].order
	for i = 1, def.pity.rolls do
		local r = LanternRoll.Roll("jade_lantern", 1, pity, rng)
		if i < def.pity.rolls then
			expectTrue(not r.pityTriggered, "early pity at " .. i)
		else
			expectTrue(r.pityTriggered, "pity should trigger")
			expectTrue(SpiritConfig.Rarities[r.rarity].order >= minOrder)
		end
	end
	expectEq(pity.jade_lantern, 0)
end

cases["Lantern roll distribution matches sheet"] = function()
	local rng = __rng(7)
	local counts = {}
	local N = 100000
	for _ = 1, N do
		local r = LanternRoll.Roll("paper_lantern", 1, {}, rng)
		counts[r.spirit] = (counts[r.spirit] or 0) + 1
	end
	for _, r in LanternOdds.Sheet("paper_lantern", 1).spirits do
		expectNear((counts[r.id] or 0) / N, r.chance, 0.01, r.id)
	end
end

-- Rewards ------------------------------------------------------------------------------------
cases["Daily streak continues, resets, cycles"] = function()
	local DAY = 86400
	local ok, streak, idx = RewardLogic.Daily(-1, 0, 10 * DAY)
	expectTrue(ok)
	expectEq(streak, 1)
	expectEq(idx, 1)
	ok = RewardLogic.Daily(10, 1, 10 * DAY + 50)
	expectTrue(not ok)
	ok, streak, idx = RewardLogic.Daily(10, 1, 11 * DAY)
	expectEq(streak, 2)
	ok, streak = RewardLogic.Daily(10, 5, 13 * DAY)
	expectEq(streak, 1)
	ok, streak, idx = RewardLogic.Daily(10, 7, 11 * DAY)
	expectEq(streak, 8)
	expectEq(idx, 1)
end

cases["Offline earnings respect min, cap and pass"] = function()
	expectEq(select(2, RewardLogic.Offline(0, 1000, 100, false)), 0)
	expectEq(select(2, RewardLogic.Offline(1000, 1100, 100, false)), 0)
	local secs = RewardLogic.Offline(1000, 1000 + 100 * 3600, 100, false)
	expectEq(secs, EconomyConfig.OfflineCapSeconds)
	secs = RewardLogic.Offline(1000, 1000 + 100 * 3600, 100, true)
	expectEq(secs, EconomyConfig.OfflineCapSecondsWithPass)
	expectEq(select(2, RewardLogic.Offline(5000, 1000, 100, true)), 0)
end

cases["Daily quests are deterministic per user/day"] = function()
	local a = RewardLogic.PickDailyQuests(123, 500)
	local b = RewardLogic.PickDailyQuests(123, 500)
	expectEq(#a, 3)
	expectEq(table.concat(a, ","), table.concat(b, ","))
end

-- Progression --------------------------------------------------------------------------------
cases["XP levels up across multiple levels and caps"] = function()
	local need = EconomyConfig.XpToNext(1) + EconomyConfig.XpToNext(2)
	local l, x, gained = ProgressionMath.ApplyXp(1, 0, need + 5)
	expectEq(l, 3)
	expectEq(x, 5)
	expectEq(gained, 2)
	l, x = ProgressionMath.ApplyXp(EconomyConfig.MaxLevel - 1, 0, 1e12)
	expectEq(l, EconomyConfig.MaxLevel)
	expectEq(x, 0)
end

cases["Power is capped by chapter; multipliers add within category"] = function()
	local raw, capped = ProgressionMath.Power(100, 50, 5000, 0)
	expectTrue(raw > capped)
	expectEq(capped, EconomyConfig.PowerCapByChapter[0])
	expectEq(ProgressionMath.CategoryMultiplier("Ember", { DoubleEmberPass = true, EmberBoost = true }), 3)
	expectEq(ProgressionMath.CategoryMultiplier("Ember", {}), 1)
end

return cases
