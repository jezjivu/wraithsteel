--!strict
-- RaidLogic: pure raid lobby + manifest + reward rules (RaidService does the engine work).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RaidConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RaidConfig"))

local RaidLogic = {}

export type Lobby = {
	id: string,
	raidId: string,
	leader: number,
	members: { number }, -- userIds, leader first
	createdAt: number,
	launching: boolean,
}

export type Manifest = {
	raidId: string,
	lobbyId: string,
	members: { number },
	issuedAt: number,
}

export type Eligibility = { chapter: number, level: number }

function RaidLogic.CheckEligible(raidId: string, who: Eligibility): (boolean, string?)
	local def = RaidConfig.Raids[raidId]
	if def == nil then
		return false, "Unknown raid"
	end
	if who.chapter < def.chapter then
		return false, "Reach Chapter " .. def.chapter .. " first"
	end
	if who.level < def.minLevel then
		return false, "Reach level " .. def.minLevel .. " first"
	end
	return true, nil
end

function RaidLogic.New(id: string, raidId: string, leader: number, now: number): Lobby
	return { id = id, raidId = raidId, leader = leader, members = { leader }, createdAt = now, launching = false }
end

function RaidLogic.Join(lobby: Lobby, userId: number): (boolean, string?)
	if lobby.launching then
		return false, "The raid is already leaving"
	end
	if table.find(lobby.members, userId) then
		return false, "Already in this raid"
	end
	if #lobby.members >= RaidConfig.RaidSize then
		return false, "The raid is full"
	end
	table.insert(lobby.members, userId)
	return true, nil
end

-- Removes userId. Returns true if the lobby is now empty (close it). Leader leaving hands the
-- lead to the next member.
function RaidLogic.Leave(lobby: Lobby, userId: number): boolean
	local i = table.find(lobby.members, userId)
	if i then
		table.remove(lobby.members, i)
	end
	if #lobby.members == 0 then
		return true
	end
	if lobby.leader == userId then
		lobby.leader = lobby.members[1]
	end
	return false
end

function RaidLogic.CanLaunch(lobby: Lobby, userId: number, ignoreMinimum: boolean?): (boolean, string?)
	if lobby.leader ~= userId then
		return false, "Only the raid leader can begin"
	end
	if lobby.launching then
		return false, "Already leaving"
	end
	local def = RaidConfig.Raids[lobby.raidId]
	if not ignoreMinimum and #lobby.members < def.minPlayers then
		return false, string.format("Need at least %d blades (%d/%d)", def.minPlayers, #lobby.members, RaidConfig.RaidSize)
	end
	return true, nil
end

function RaidLogic.Expired(lobby: Lobby, now: number): boolean
	return not lobby.launching and now - lobby.createdAt > RaidConfig.LobbySeconds
end

function RaidLogic.BuildManifest(lobby: Lobby, now: number): Manifest
	return { raidId = lobby.raidId, lobbyId = lobby.id, members = table.clone(lobby.members), issuedAt = now }
end

-- Validates a manifest read back from MemoryStore (shape + not expired).
function RaidLogic.ValidManifest(m: any, now: number): boolean
	if type(m) ~= "table" or type(m.raidId) ~= "string" or RaidConfig.Raids[m.raidId] == nil then
		return false
	end
	if type(m.members) ~= "table" or #m.members == 0 or #m.members > RaidConfig.RaidSize then
		return false
	end
	for _, id in m.members do
		if type(id) ~= "number" then
			return false
		end
	end
	return type(m.issuedAt) == "number" and now - m.issuedAt <= RaidConfig.ManifestSeconds
end

function RaidLogic.IsMember(m: Manifest, userId: number): boolean
	return table.find(m.members, userId) ~= nil
end

-- Raid health multiplier on top of the boss's own co-op scaling.
function RaidLogic.HealthMultiplier(raidId: string): number
	return RaidConfig.Raids[raidId].healthMultiplier
end

export type Reward = { ember: number, xp: number, jade: number }

-- Rewards for one player on victory. `clears` = their previous clears of this raid.
function RaidLogic.Reward(raidId: string, clears: number): Reward
	local def = RaidConfig.Raids[raidId]
	local r = def.rewards
	return {
		ember = r.ember,
		xp = r.xp,
		jade = r.jade + (if clears == 0 then def.firstClearJade else 0),
	}
end

return RaidLogic
