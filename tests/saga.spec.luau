-- Tests for the main questline (Logic/SagaLogic + SagaConfig content).
local Logic = game:GetService("ServerScriptService").Logic
local Config = game:GetService("ReplicatedStorage").Config

local SagaLogic = require(Logic.SagaLogic)
local SagaConfig = require(Config.SagaConfig)
local EnemyConfig = require(Config.EnemyConfig)
local BossConfig = require(Config.BossConfig)
local RealmConfig = require(Config.RealmConfig)

local cases = {}

cases["Saga: start, kill, hand in, next quest"] = function()
	local s = SagaLogic.New()
	expectEq(SagaLogic.Kill(s, "rustbound_bandit"), false) -- not started yet
	expectEq(SagaLogic.Talk(s, "oto").kind, "Chatter") -- wrong npc
	local r = SagaLogic.Talk(s, "shirane")
	expectEq(r.kind, "Start")
	for _ = 1, 4 do
		expectEq(SagaLogic.Kill(s, "rustbound_bandit"), true)
	end
	expectEq(SagaLogic.Kill(s, "lantern_ghoul"), false) -- wrong enemy
	expectEq(s.progress, 4)
	SagaLogic.Kill(s, "rustbound_bandit")
	local _, step = SagaLogic.Current(s)
	expectEq(step, nil) -- all steps done: return to giver
	local fin = SagaLogic.Talk(s, "shirane")
	expectEq(fin.kind, "Finish")
	expectTrue(fin.rewards ~= nil, "rewards on finish")
	expectEq(s.quest, 2)
	expectEq(s.started, false)
end

cases["Saga: reach and boss steps"] = function()
	local s = SagaLogic.New()
	s.quest = 2
	SagaLogic.Talk(s, "oto")
	for _ = 1, 4 do
		SagaLogic.Kill(s, "lantern_ghoul")
	end
	expectEq(SagaLogic.Reach(s, "japan", 0, 0), false) -- too far
	expectEq(SagaLogic.Reach(s, "neon", 80, -80), false) -- wrong realm
	expectEq(SagaLogic.Reach(s, "japan", 85, -75), true)
	SagaLogic.Talk(s, "oto")
	expectEq(s.quest, 3)
	SagaLogic.Talk(s, "sabaki")
	for _ = 1, 3 do
		SagaLogic.Kill(s, "ashen_duelist")
	end
	expectEq(SagaLogic.Boss(s, "rust_tiger"), false)
	expectEq(SagaLogic.Boss(s, "sable_crane"), true)
end

cases["Saga: objective text follows progress, finishes cleanly"] = function()
	local s = SagaLogic.New()
	local text, kind = SagaLogic.Objective(s)
	expectEq(kind, "Npc")
	expectTrue(string.find(text, "Elder Shirane") ~= nil, text)
	s.quest = #SagaConfig.Quests + 1
	local _, done = SagaLogic.Objective(s)
	expectEq(done, "Done")
	expectEq(SagaLogic.Talk(s, "shirane").kind, "Chatter")
end

cases["Saga: every quest references real NPCs, enemies, bosses and realms"] = function()
	for _, q in SagaConfig.Quests do
		assert(SagaConfig.Npc(q.giver), q.id .. " giver")
		assert(RealmConfig.Realms[q.realm], q.id .. " realm")
		for _, st in q.steps do
			if st.kind == "Kill" then
				for _, e in st.enemies or {} do
					assert(EnemyConfig.Enemies[e], q.id .. " enemy " .. e)
				end
			elseif st.kind == "Boss" then
				assert(BossConfig.Bosses[st.bossId or ""], q.id .. " boss")
			elseif st.kind == "Reach" then
				assert(RealmConfig.Realms[st.realm or ""] and st.at, q.id .. " reach")
			elseif st.kind == "Talk" then
				assert(SagaConfig.Npc(st.npc or ""), q.id .. " talk npc")
			end
		end
	end
	for _, n in SagaConfig.Npcs do
		assert(RealmConfig.Realms[n.realm], n.id .. " realm")
		assert(#n.chatter > 0, n.id .. " chatter")
	end
	for id, r in RealmConfig.Realms do
		for _, sp in r.spawns do
			assert(EnemyConfig.Enemies[sp.enemyId], id .. " spawn " .. sp.enemyId)
		end
		for _, a in r.arenas do
			assert(BossConfig.Bosses[a.bossId], id .. " arena " .. a.bossId)
		end
	end
end

return cases
