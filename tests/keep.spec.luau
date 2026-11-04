-- Ironcrow Keep (castle realm): config integrity, spacing, bosses, story.
local RS = game:GetService("ReplicatedStorage")
local RealmConfig = require(RS.Config.RealmConfig)
local EnemyConfig = require(RS.Config.EnemyConfig)
local BossConfig = require(RS.Config.BossConfig)
local ArenaConfig = require(RS.Config.ArenaConfig)
local SagaConfig = require(RS.Config.SagaConfig)
local LightingConfig = require(RS.Config.LightingConfig)

local cases = {}

local function dist(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
end

cases["Keep: realm is wired (order, portals both ways, lighting, unlock)"] = function()
	local keep = RealmConfig.Realms.keep
	expectTrue(keep ~= nil)
	expectTrue(table.find(RealmConfig.Order, "keep") ~= nil)
	local into, out = false, false
	for _, p in RealmConfig.Portals do
		into = into or (p.to == "keep")
		out = out or (p.from == "keep")
	end
	expectTrue(into and out, "portals both ways")
	expectTrue(LightingConfig.Realms.keep ~= nil)
	expectTrue(BossConfig.Bosses[keep.unlockBoss :: string] ~= nil)
end

cases["Keep: everything inside the realm, enemies and bosses exist, groups spaced"] = function()
	local keep = RealmConfig.Realms.keep
	local function inside(at)
		return math.abs(at[1]) <= keep.half and math.abs(at[2]) <= keep.half
	end
	for _, a in keep.areas do
		expectTrue(inside(a.center), a.id)
	end
	for _, s in keep.spawns do
		expectTrue(inside(s.at), s.name)
		expectTrue(EnemyConfig.Enemies[s.enemyId] ~= nil, s.name .. " enemy " .. s.enemyId)
	end
	for i = 1, #keep.spawns do
		for j = i + 1, #keep.spawns do
			local d = dist(keep.spawns[i].at, keep.spawns[j].at)
			expectTrue(d >= 60, string.format("%s - %s %.0f apart", keep.spawns[i].name, keep.spawns[j].name, d))
		end
	end
	for _, a in keep.arenas do
		expectTrue(BossConfig.Bosses[a.bossId] ~= nil, a.bossId)
		local theme = ArenaConfig.Themes[a.bossId]
		expectTrue(theme ~= nil and theme.layout ~= nil, a.bossId .. " has an arena layout")
	end
	for _, w in keep.waystones do
		expectTrue(inside(w.at), w.id)
	end
	-- no realm overlaps another
	for id, r in RealmConfig.Realms do
		if id ~= "keep" and id ~= "japan" then
			local dx = math.abs(r.origin[1] - keep.origin[1])
			local dz = math.abs(r.origin[3] - keep.origin[3])
			expectTrue(dx > r.half + keep.half or dz > r.half + keep.half, id .. " overlaps the keep")
		end
	end
end

cases["Saga: every quest step points at real things"] = function()
	local npcs = {}
	for _, n in SagaConfig.Npcs do
		npcs[n.id] = n
		expectTrue(RealmConfig.Realms[n.realm] ~= nil, n.id .. " realm")
	end
	for _, q in SagaConfig.Quests do
		expectTrue(npcs[q.giver] ~= nil, q.id .. " giver")
		for _, st in q.steps do
			if st.kind == "Kill" then
				for _, e in st.enemies :: { string } do
					expectTrue(EnemyConfig.Enemies[e] ~= nil, q.id .. " enemy " .. e)
				end
			elseif st.kind == "Boss" then
				expectTrue(BossConfig.Bosses[st.bossId :: string] ~= nil, q.id .. " boss")
			elseif st.kind == "Reach" then
				expectTrue(RealmConfig.Realms[st.realm :: string] ~= nil, q.id .. " reach realm")
			end
		end
	end
	expectEq(SagaConfig.Quests[#SagaConfig.Quests].id, "ember_throne")
end

return cases
