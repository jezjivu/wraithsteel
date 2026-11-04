-- Tests for Logic/RaidLogic: lobbies, eligibility, launch rules, manifest checks, rewards.
local RS = game:GetService("ReplicatedStorage")
local RaidLogic = require(game:GetService("ServerScriptService").Logic.RaidLogic)
local RaidConfig = require(RS.Config.RaidConfig)
local ChapterConfig = require(RS.Config.ChapterConfig)
local BossConfig = require(RS.Config.BossConfig)

local cases = {}
local RAID = RaidConfig.RaidOrder[1]

cases["Raid: config is consistent"] = function()
	expectEq(RaidConfig.RaidSize, ChapterConfig.RaidSize)
	for _, id in RaidConfig.RaidOrder do
		local def = RaidConfig.Raids[id]
		expectTrue(def ~= nil, id)
		expectTrue(BossConfig.Bosses[def.bossId] ~= nil, id .. " boss exists")
		expectTrue(def.minPlayers >= 1 and def.minPlayers <= RaidConfig.RaidSize, id)
		expectTrue(def.healthMultiplier >= 1 and def.timeLimitSeconds > 0, id)
	end
end

cases["Raid: lobby join/leave/leader handoff and size cap"] = function()
	local l = RaidLogic.New("L1", RAID, 1, 0)
	for id = 2, RaidConfig.RaidSize do
		expectTrue(RaidLogic.Join(l, id))
	end
	expectEq(select(2, RaidLogic.Join(l, 99)), "The raid is full")
	expectEq(select(2, RaidLogic.Join(l, 2)), "Already in this raid")
	expectTrue(not RaidLogic.Leave(l, 1))
	expectEq(l.leader, 2)
	for id = 2, RaidConfig.RaidSize - 1 do
		RaidLogic.Leave(l, id)
	end
	expectTrue(RaidLogic.Leave(l, RaidConfig.RaidSize), "last member leaving empties the lobby")
end

cases["Raid: eligibility and launch rules"] = function()
	local def = RaidConfig.Raids[RAID]
	expectEq(select(2, RaidLogic.CheckEligible("nope", { chapter = 5, level = 99 })), "Unknown raid")
	expectEq(select(2, RaidLogic.CheckEligible(RAID, { chapter = 5, level = def.minLevel - 1 })), "Reach level " .. def.minLevel .. " first")
	expectTrue(RaidLogic.CheckEligible(RAID, { chapter = def.chapter, level = def.minLevel }))
	local l = RaidLogic.New("L2", RAID, 1, 0)
	expectEq(select(2, RaidLogic.CanLaunch(l, 2)), "Only the raid leader can begin")
	if def.minPlayers > 1 then
		expectTrue(not RaidLogic.CanLaunch(l, 1))
	end
	expectTrue(RaidLogic.CanLaunch(l, 1, true), "Studio ignores the minimum")
	for id = 2, def.minPlayers do
		RaidLogic.Join(l, id)
	end
	expectTrue(RaidLogic.CanLaunch(l, 1))
	l.launching = true
	expectEq(select(2, RaidLogic.Join(l, 50)), "The raid is already leaving")
	expectTrue(not RaidLogic.Expired(l, 1e9), "launching lobbies never expire")
	l.launching = false
	expectTrue(RaidLogic.Expired(l, RaidConfig.LobbySeconds + 1))
end

cases["Raid: manifest round trip and validation"] = function()
	local l = RaidLogic.New("L3", RAID, 10, 0)
	RaidLogic.Join(l, 11)
	local m = RaidLogic.BuildManifest(l, 1000)
	expectTrue(RaidLogic.ValidManifest(m, 1000))
	expectTrue(RaidLogic.IsMember(m, 11) and not RaidLogic.IsMember(m, 12))
	-- the manifest is a copy: later lobby changes do not leak in
	RaidLogic.Join(l, 12)
	expectTrue(not RaidLogic.IsMember(m, 12))
	expectTrue(not RaidLogic.ValidManifest(m, 1000 + RaidConfig.ManifestSeconds + 1), "expired")
	expectTrue(not RaidLogic.ValidManifest({ raidId = "x", members = { 1 }, issuedAt = 0 }, 0))
	expectTrue(not RaidLogic.ValidManifest({ raidId = RAID, members = { "1" }, issuedAt = 0 }, 0))
	expectTrue(not RaidLogic.ValidManifest(nil, 0))
	local big = {}
	for i = 1, RaidConfig.RaidSize + 1 do
		big[i] = i
	end
	expectTrue(not RaidLogic.ValidManifest({ raidId = RAID, members = big, issuedAt = 0 }, 0))
end

cases["Raid: rewards add the first-clear Jade once"] = function()
	local def = RaidConfig.Raids[RAID]
	local first = RaidLogic.Reward(RAID, 0)
	local again = RaidLogic.Reward(RAID, 1)
	expectEq(first.jade, def.rewards.jade + def.firstClearJade)
	expectEq(again.jade, def.rewards.jade)
	expectEq(first.ember, def.rewards.ember)
end

return cases
