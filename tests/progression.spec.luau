-- A fresh player must be able to progress through the whole story: every gate (realm, raid,
-- chapter-gated lanterns / weapons / expeditions / market items, style levels) has to be
-- reachable from the rewards of the story itself (quest XP + the XP of the enemies and bosses
-- the quests make you kill), without grinding.
local RS = game:GetService("ReplicatedStorage")
local SagaConfig = require(RS.Config.SagaConfig)
local EnemyConfig = require(RS.Config.EnemyConfig)
local BossConfig = require(RS.Config.BossConfig)
local RealmConfig = require(RS.Config.RealmConfig)
local RaidConfig = require(RS.Config.RaidConfig)
local StyleConfig = require(RS.Config.StyleConfig)
local LanternConfig = require(RS.Config.LanternConfig)
local WeaponConfig = require(RS.Config.WeaponConfig)
local ExpeditionConfig = require(RS.Config.ExpeditionConfig)
local NightMarketConfig = require(RS.Config.NightMarketConfig)
local ChapterConfig = require(RS.Config.ChapterConfig)
local EconomyConfig = require(RS.Config.EconomyConfig)
local ProgressionMath = require(RS.Shared.ProgressionMath)
local ProfileTemplate = require(game:GetService("ServerScriptService").Logic.ProfileTemplate)

local cases = {}

-- Walks the questline in order. Returns a list of { quest, level, chapter, bossesDefeated }
-- snapshots taken AFTER each quest is handed in.
local function walk()
	local p = ProfileTemplate.New()
	local level, xp, chapter = p.level, p.xp, p.chapter
	local defeated: { [string]: boolean } = {}
	local out = {}
	for _, q in SagaConfig.Quests do
		local gained = q.rewards.xp
		for _, step in q.steps do
			if step.kind == "Kill" then
				-- every kill step is done on the cheapest listed enemy (worst case)
				local cheapest = math.huge
				for _, id in step.enemies :: { string } do
					cheapest = math.min(cheapest, EnemyConfig.Enemies[id].xpReward)
				end
				gained += cheapest * (step.count :: number)
			elseif step.kind == "Boss" then
				gained += BossConfig.Bosses[step.bossId :: string].rewards.xp
				defeated[step.bossId :: string] = true
			end
		end
		level, xp = ProgressionMath.ApplyXp(level, xp, gained)
		if q.unlocksChapter then
			chapter = math.max(chapter, q.unlocksChapter)
		end
		table.insert(out, { quest = q, level = level, chapter = chapter, defeated = table.clone(defeated) })
	end
	return out, p
end

cases["Progression: chapters rise with the story and never skip"] = function()
	local snaps = walk()
	local last = 0
	for _, s in snaps do
		expectTrue(s.chapter >= last and s.chapter <= last + 1, s.quest.id .. " chapter jumps")
		last = s.chapter
	end
	expectEq(last, 4, "the questline ends in chapter 4")
	expectTrue(last <= ChapterConfig.FinalChapter)
	-- an unlocksChapter quest exists for every chapter 1..4
	local seen = {}
	for _, q in SagaConfig.Quests do
		if q.unlocksChapter then
			seen[q.unlocksChapter] = true
		end
	end
	for c = 1, 4 do
		expectTrue(seen[c], "no quest unlocks chapter " .. c)
	end
end

cases["Progression: every realm gate is reachable before you need it"] = function()
	local snaps = walk()
	-- level at the moment you are told to go to the next realm
	local function after(id: string)
		for _, s in snaps do
			if s.quest.id == id then
				return s
			end
		end
		error("no quest " .. id)
	end
	local neon = RealmConfig.Realms.neon
	expectTrue(after("warden").level >= (neon.unlockLevel or 0), "Neon gate level after the Ashen Valley questline")
	-- boss-gated realms: the gating boss is a step of the quest line that leads there
	for _, id in { "greek", "keep" } do
		local r = RealmConfig.Realms[id]
		expectTrue(r.unlockBoss ~= nil and BossConfig.Bosses[r.unlockBoss] ~= nil, id .. " gate boss exists")
		local found = false
		for _, s in snaps do
			found = found or s.defeated[r.unlockBoss :: string] == true
		end
		expectTrue(found, id .. " gate boss (" .. tostring(r.unlockBoss) .. ") is part of the story")
		if r.unlockLevel then
			expectTrue(after("noon").level >= r.unlockLevel)
		end
	end
	-- the quests that live in a realm come after you can enter it
	local firstIn = { japan = 1 }
	for i, s in snaps do
		firstIn[s.quest.realm] = firstIn[s.quest.realm] or i
	end
	expectTrue(firstIn.neon > firstIn.japan and firstIn.greek > firstIn.neon and firstIn.keep > firstIn.greek, "realm order")
end

cases["Progression: raid, styles and chapter gates are all reachable"] = function()
	local snaps = walk()
	local final = snaps[#snaps]
	for _, id in RaidConfig.RaidOrder do
		local r = RaidConfig.Raids[id]
		expectTrue(final.chapter >= r.chapter and final.level >= r.minLevel, id .. " reachable")
	end
	for id, st in StyleConfig.Styles do
		expectTrue(st.unlockLevel <= final.level, id .. " style level " .. st.unlockLevel)
	end
	local maxChapter = final.chapter
	for id, l in LanternConfig.Lanterns do
		expectTrue(l.chapter <= maxChapter, id .. " lantern chapter")
	end
	for id, w in WeaponConfig.Weapons do
		expectTrue(w.unlockChapter <= maxChapter, id .. " weapon chapter")
	end
	for id, r in ExpeditionConfig.Routes do
		expectTrue(r.chapter <= maxChapter, id .. " expedition chapter")
	end
	for id, it in NightMarketConfig.Items do
		expectTrue(it.chapter <= maxChapter, id .. " market chapter")
	end
end

cases["Progression: the first lantern is free and the start is playable"] = function()
	local p = ProfileTemplate.New()
	expectEq(p.freeLanterns.paper_lantern, 1)
	expectTrue(p.ember < LanternConfig.Lanterns.paper_lantern.price, "the free open is what makes lantern one possible")
	expectEq(p.chapter, 0)
	expectTrue(EconomyConfig.PowerCapByChapter[p.chapter] > 0)
	-- the cheapest chapter-0 Ember weapon is affordable from the Ember the first quests pay out
	local cheapest = math.huge
	for _, w in WeaponConfig.Weapons do
		if w.unlockChapter == 0 and w.price > 0 and w.currency == "Ember" then
			cheapest = math.min(cheapest, w.price)
		end
	end
	expectTrue(cheapest < math.huge, "there is a chapter-0 Ember weapon to buy")
	local ember = p.ember
	local quests = 0
	for _, q in SagaConfig.Quests do
		if q.realm ~= "japan" then
			break
		end
		ember += q.rewards.ember
		quests += 1
		if ember >= cheapest then
			break
		end
	end
	expectTrue(ember >= cheapest, "cheapest weapon (" .. cheapest .. " Ember) affordable within the Ashen Valley quests")
	expectTrue(quests <= 2, "affordable after at most two quests (" .. quests .. ")")
end

return cases
