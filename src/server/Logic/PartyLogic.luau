--!strict
-- PartyLogic: pure party rules (keyed by userId so it is testable without Players).
--   * max ChapterConfig.MaxPartySize members; the first member is the leader
--   * invites expire after PartyConfig.InviteSeconds; only the leader invites/kicks
--     (a solo player inviting someone becomes the leader of a new party)
--   * leaving passes leadership to the next member; a party of one dissolves

local PartyLogic = {}
PartyLogic.__index = PartyLogic

export type Party = { id: number, leader: number, members: { number } }

export type State = typeof(setmetatable(
	{} :: {
		maxSize: number,
		inviteSeconds: number,
		nextId: number,
		parties: { [number]: Party }, -- partyId -> party
		memberOf: { [number]: number }, -- userId -> partyId
		invites: { [number]: { [number]: number } }, -- invitee -> { partyId -> expiresAt }
	},
	PartyLogic
))

function PartyLogic.new(maxSize: number, inviteSeconds: number): State
	return setmetatable({ maxSize = maxSize, inviteSeconds = inviteSeconds, nextId = 1, parties = {}, memberOf = {}, invites = {} }, PartyLogic)
end

function PartyLogic.PartyOf(self: State, userId: number): Party?
	local id = self.memberOf[userId]
	return if id then self.parties[id] else nil
end

-- Members including the user themself ({ userId } when solo).
function PartyLogic.Members(self: State, userId: number): { number }
	local p = self:PartyOf(userId)
	return if p then table.clone(p.members) else { userId }
end

function PartyLogic.Invite(self: State, from: number, to: number, now: number): (boolean, string?)
	if from == to then
		return false, "You cannot invite yourself"
	end
	if self.memberOf[to] then
		return false, "That player is already in a party"
	end
	local party: Party
	local existing = self:PartyOf(from)
	if existing then
		party = existing
	else
		local id = self.nextId
		self.nextId += 1
		party = { id = id, leader = from, members = { from } }
		self.parties[id] = party
		self.memberOf[from] = id
	end
	if party.leader ~= from then
		return false, "Only the party leader can invite"
	end
	if #party.members >= self.maxSize then
		return false, "Your party is full"
	end
	self.invites[to] = self.invites[to] or {}
	self.invites[to][party.id] = now + self.inviteSeconds
	return true, nil
end

-- Pending, unexpired invites for a user: { partyId }.
function PartyLogic.PendingInvites(self: State, userId: number, now: number): { number }
	local out = {}
	local mine = self.invites[userId]
	if mine == nil then
		return out
	end
	for partyId, expires in mine do
		if expires > now and self.parties[partyId] then
			table.insert(out, partyId)
		end
	end
	table.sort(out)
	return out
end

function PartyLogic.Accept(self: State, userId: number, partyId: number, now: number): (boolean, string?)
	local expires = (self.invites[userId] or {})[partyId]
	local p = self.parties[partyId]
	if expires == nil or expires <= now or p == nil then
		return false, "That invite has expired"
	end
	if self.memberOf[userId] then
		return false, "Leave your current party first"
	end
	if #p.members >= self.maxSize then
		return false, "That party is full"
	end
	table.insert(p.members, userId)
	self.memberOf[userId] = partyId
	self.invites[userId] = nil
	return true, nil
end

function PartyLogic.Decline(self: State, userId: number, partyId: number)
	if self.invites[userId] then
		self.invites[userId][partyId] = nil
	end
end

local function remove(self: State, p: Party, userId: number)
	local i = table.find(p.members, userId)
	if i then
		table.remove(p.members, i)
	end
	self.memberOf[userId] = nil
	if #p.members <= 1 then
		for _, m in p.members do
			self.memberOf[m] = nil
		end
		self.parties[p.id] = nil
	elseif p.leader == userId then
		p.leader = p.members[1]
	end
end

-- Returns the party the user left (for notifying the others), if any.
function PartyLogic.Leave(self: State, userId: number): Party?
	local p = self:PartyOf(userId)
	if p then
		remove(self, p, userId)
	end
	self.invites[userId] = nil
	return p
end

function PartyLogic.Kick(self: State, leader: number, target: number): (boolean, string?)
	local p = self:PartyOf(leader)
	if p == nil or p.leader ~= leader then
		return false, "Only the party leader can kick"
	end
	if leader == target or table.find(p.members, target) == nil then
		return false, "That player is not in your party"
	end
	remove(self, p, target)
	return true, nil
end

return PartyLogic
