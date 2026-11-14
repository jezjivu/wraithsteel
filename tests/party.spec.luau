-- Tests for PartyLogic (invites, accept, leadership, kick, limits, expiry).
local PartyLogic = require(game:GetService("ServerScriptService").Logic.PartyLogic)

local cases = {}

cases["Party: invite -> accept forms a party led by the inviter"] = function()
	local s = PartyLogic.new(4, 60)
	expectTrue(s:Invite(1, 2, 0))
	local pending = s:PendingInvites(2, 10)
	expectEq(#pending, 1)
	expectTrue(s:Accept(2, pending[1], 10))
	local p = s:PartyOf(2)
	expectEq(p.leader, 1)
	expectEq(#s:Members(1), 2)
	expectEq(#s:PendingInvites(2, 10), 0)
end

cases["Party: rules - self, busy, non-leader, full, expiry"] = function()
	local s = PartyLogic.new(3, 60)
	expectEq(select(2, s:Invite(1, 1, 0)), "You cannot invite yourself")
	s:Invite(1, 2, 0)
	s:Accept(2, s:PendingInvites(2, 0)[1], 0)
	expectEq(select(2, s:Invite(2, 3, 0)), "Only the party leader can invite")
	expectEq(select(2, s:Invite(5, 2, 0)), "That player is already in a party")
	s:Invite(1, 3, 0)
	s:Accept(3, s:PendingInvites(3, 0)[1], 0)
	expectEq(select(2, s:Invite(1, 4, 0)), "Your party is full")
	local s2 = PartyLogic.new(4, 60)
	s2:Invite(1, 2, 0)
	local id = s2:PendingInvites(2, 0)[1]
	expectEq(#s2:PendingInvites(2, 61), 0)
	expectEq(select(2, s2:Accept(2, id, 61)), "That invite has expired")
end

cases["Party: leaving passes leadership; last member dissolves"] = function()
	local s = PartyLogic.new(4, 60)
	s:Invite(1, 2, 0)
	s:Accept(2, s:PendingInvites(2, 0)[1], 0)
	s:Invite(1, 3, 0)
	s:Accept(3, s:PendingInvites(3, 0)[1], 0)
	s:Leave(1)
	expectEq(s:PartyOf(2).leader, 2)
	expectEq(#s:Members(3), 2)
	expectEq(select(2, s:Kick(3, 2)), "Only the party leader can kick")
	expectTrue(s:Kick(2, 3))
	expectEq(s:PartyOf(2), nil) -- party of one dissolves
	expectEq(#s:Members(2), 1)
end

return cases
