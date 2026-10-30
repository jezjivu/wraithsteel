-- Config integrity + Phase 2 logic: content references resolve, expeditions, Spirit leveling.
local Config = game:GetService("ReplicatedStorage").Config
local Logic = game:GetService("ServerScriptService").Logic

local BossConfig = require(Config.BossConfig)
local ChapterConfig = require(Config.ChapterConfig)
local EnemyConfig = require(Config.EnemyConfig)
local LanternConfig = require(Config.LanternConfig)
local SpiritConfig = require(Config.SpiritConfig)
local WeaponConfig = require(Config.WeaponConfig)
local RewardConfig = require(Config.RewardConfig)
local ExpeditionConfig = require(Config.ExpeditionConfig)
local ExpeditionLogic = require(Logic.ExpeditionLogic)
local SpiritLogic = require(Logic.SpiritLogic)
local ProfileTemplate = require(Logic.ProfileTemplate)

local cases = {}

cases["Content: Prologue and Chapter 1 bosses are fully defined"] = function()
	local count = 0
	for chapter = 0, ChapterConfig.FinalChapter do
		count += #ChapterConfig.Chapters[chapter].bosses
	end
	expectEq(count, 21, "total bosses")
	for chapter = 0, 1 do
		for _, bossId in ChapterConfig.Chapters[chapter].bosses do
			expectTrue(BossConfig.Bosses[bossId] ~= nil, "missing boss " .. bossId)
		end
	end
end

cases["Content: boss phases are ordered and every move exists"] = function()
	for id, def in BossConfig.Bosses do
		expectEq(def.phases[1].hpThreshold, 1, id .. " first phase")
		for i, phase in def.phases do
			if i > 1 then
				expectTrue(phase.hpThreshold < def.phases[i - 1].hpThreshold, id .. " phase order")
			end
			local hasMelee = false
			for _, moveId in phase.moves do
				local m = def.moves[moveId]
				expectTrue(m ~= nil, id .. " missing move " .. moveId)
				if (m.minRange or 0) == 0 then
					hasMelee = true
				end
			end
			expectTrue(hasMelee, id .. " phase " .. i .. " needs a close-range move")
		end
	end
end

cases["Content: lanterns, spirits, quests, weapons reference valid ids"] = function()
	for id, l in LanternConfig.Lanterns do
		for _, e in l.entries do
			expectTrue(SpiritConfig.Spirits[e.spirit] ~= nil, id .. " -> " .. e.spirit)
		end
		if l.pity then
			expectTrue(SpiritConfig.Rarities[l.pity.minRarity] ~= nil, id .. " pity rarity")
		end
		expectEq(l.paid, l.currency == "Jade", id .. " paid flag must match Jade currency")
	end
	for id, s in SpiritConfig.Spirits do
		expectTrue(SpiritConfig.Rarities[s.rarity] ~= nil, id)
		if s.passive then
			expectTrue(SpiritConfig.Passives[s.passive] ~= nil, id .. " passive")
		end
	end
	for _, w in WeaponConfig.Weapons do
		for _, m in w.lightCombo do
			expectTrue(WeaponConfig.Moves[m] ~= nil, m)
		end
		expectTrue(WeaponConfig.Moves[w.heavy] ~= nil, w.heavy)
		for _, m in w.skills do
			expectTrue(WeaponConfig.Moves[m] ~= nil, m)
		end
	end
	for id, q in RewardConfig.Quests do
		local boss = string.match(q.stat, "^Boss:(.+)$")
		if boss then
			expectTrue(BossConfig.Bosses[boss] ~= nil, id)
		end
	end
	for id, r in ExpeditionConfig.Routes do
		expectTrue(r.durationSeconds > 0 and r.maxSpirits > 0, id)
	end
	for id, e in EnemyConfig.Enemies do
		local n = 0
		for _ in e.attacks do
			n += 1
		end
		expectTrue(n > 0, id .. " has attacks")
	end
end

local function expData()
	local d = ProfileTemplate.New()
	d.ember = 0
	return d
end

cases["Expedition: start validates, claim pays after duration"] = function()
	local d = expData()
	local a = SpiritLogic.Create(d, "brass_carp", "Rare", "None", 0).uid
	local b = SpiritLogic.Create(d, "reed_fox", "Uncommon", "None", 0).uid
	local eq = SpiritLogic.Create(d, "lantern_moth", "Common", "None", 0).uid
	SpiritLogic.Equip(d, eq, 0)
	expectEq(select(2, ExpeditionLogic.Start(d, "slot1", "rustwood_trail", { a }, 0, false)), "Route not unlocked yet")
	expectEq(select(2, ExpeditionLogic.Start(d, "slot3", "reed_marsh", { a }, 0, false)), "Slot not available")
	expectEq(select(2, ExpeditionLogic.Start(d, "slot1", "reed_marsh", { eq }, 0, false)), "Unequip Spirits before sending them")
	expectEq(select(2, ExpeditionLogic.Start(d, "slot1", "reed_marsh", {}, 0, false)), "Send 1 to 3 Spirits")
	expectTrue(ExpeditionLogic.Start(d, "slot1", "reed_marsh", { a, b }, 100, false))
	expectEq(select(2, ExpeditionLogic.Start(d, "slot2", "reed_marsh", { a }, 100, false)), "A Spirit is already away")
	expectTrue(ExpeditionLogic.Start(d, "slot3", "reed_marsh", { eq == a and a or SpiritLogic.Create(d, "ember_sparrow", "Common", "None", 0).uid }, 100, true))
	-- away spirits are protected
	expectEq(select(2, SpiritLogic.Equip(d, a, 5)), "That Spirit is on an expedition")
	expectEq(select(2, SpiritLogic.Release(d, { a })), "A selected Spirit is on an expedition")
	expectEq(select(2, ExpeditionLogic.Claim(d, "slot1", 100 + 60)), "Still exploring")
	local res = ExpeditionLogic.Claim(d, "slot1", 100 + ExpeditionConfig.Routes.reed_marsh.durationSeconds)
	expectTrue(res ~= nil)
	local route = ExpeditionConfig.Routes.reed_marsh
	local power = SpiritConfig.PowerOf("brass_carp", "Rare", "None", 1) + SpiritConfig.PowerOf("reed_fox", "Uncommon", "None", 1)
	expectEq(res.ember, math.floor(power * route.emberPerPowerHour * route.durationSeconds / 3600))
	expectEq(d.ember, res.ember)
	expectEq(d.expeditions.slot1, nil)
	expectTrue(SpiritLogic.Equip(d, a, 5))
	expectEq(select(2, ExpeditionLogic.Claim(d, "slot1", 1e9)), "Nothing to claim")
end

cases["Spirit XP levels up and caps"] = function()
	local d = expData()
	local s = SpiritLogic.Create(d, "lantern_moth", "Common", "None", 0)
	local need = SpiritConfig.XpToNext(1) + SpiritConfig.XpToNext(2)
	expectEq(SpiritLogic.AddXp(s, need + 3), 2)
	expectEq(s.level, 3)
	expectEq(s.xp, 3)
	SpiritLogic.AddXp(s, 1e12)
	expectEq(s.level, SpiritConfig.LevelCap)
	expectEq(s.xp, 0)
	expectTrue(SpiritConfig.PowerOf("lantern_moth", "Common", "None", 10) > SpiritConfig.PowerOf("lantern_moth", "Common", "None", 1))
end

return cases
