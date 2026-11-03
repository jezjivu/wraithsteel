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
	expectEq(SagaLogic.Reach(s, "neon", 420, -360), false) -- wrong realm
	expectEq(SagaLogic.Reach(s, "japan", 425, -355), true)
	SagaLogic.Talk(s, "oto")
	expectEq(s.quest, 3)
	SagaLogic.Talk(s, "sabaki")
	for _ = 1, 3 do
		SagaLogic.Kill(s, "ashen_duelist")
	end
	expectEq(SagaLogic.Kill(s, "rustbound_bandit"), false)
	expectEq(SagaLogic.Kill(s, "gravelord"), true)
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

cases["Valley: waystones are far apart, spawns and shrines sit on the route"] = function()
	local WaystoneConfig = require(Config.WaystoneConfig)
	local MapConfig = require(Config.MapConfig)
	local list = WaystoneConfig.Waystones
	for i = 2, #list do
		for j = i + 1, #list do
			local a, b = list[i].at, list[j].at
			local d = math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
			assert(d >= 450, list[i].id .. " and " .. list[j].id .. " are only " .. math.floor(d) .. " apart")
		end
	end
	-- Every spawn / boss shrine is within the road corridor or a zone (reachable).
	local function reachable(x, z)
		for _, a in MapConfig.Areas do
			if math.sqrt((x - a.center[1]) ^ 2 + (z - a.center[2]) ^ 2) <= a.radius then
				return true
			end
		end
		for _, R in MapConfig.Roads do
			for i = 1, #R - 1 do
				local ax, az, bx, bz = R[i].at[1], R[i].at[2], R[i + 1].at[1], R[i + 1].at[2]
				local dx, dz = bx - ax, bz - az
				local t = math.clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
				if math.sqrt((x - ax - dx * t) ^ 2 + (z - az - dz * t) ^ 2) <= R[i].half then
					return true
				end
			end
		end
		return false
	end
	for _, s in MapConfig.EnemySpawns do
		if s.lookout then
			-- Tower sentries stand on their lookout (off the road by design).
			local l = MapConfig.Lookouts[s.lookout]
			assert(l ~= nil and l[1] == s.at[1] and l[2] == s.at[2], "sentry not on its lookout: " .. s.name)
		else
			assert(reachable(s.at[1], s.at[2]), "spawn off the route: " .. s.name)
		end
	end
	for _, a in MapConfig.BossArenas do
		assert(reachable(a.at[1], a.at[2]), "shrine off the route: " .. a.name)
	end
	for _, w in list do
		if w.id ~= "hub" then
			assert(reachable(w.at[1], w.at[2]), "waystone off the route: " .. w.id)
		end
	end
end

return cases
