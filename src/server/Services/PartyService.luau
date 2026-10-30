--!strict
-- PartyService: 4-player co-op parties (rules in Logic/PartyLogic).
--   * invite / accept / decline / leave / kick through the PartyRequest remote
--   * party members get +EconomyConfig PartyBonusPerMember Ember each, share kill rewards when
--     nearby (EnemyService) and join boss fights together (BossService)
--
-- API:
--   PartyService.GetParty(player) -> { Player }              (solo = { player })
--   PartyService.MembersNear(player, radius) -> { Player }   party members within radius (incl. self)
--   PartyService.PartyChanged: Signal(members: { Player })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local ChapterConfig = require(Config:WaitForChild("ChapterConfig"))
local PartyConfig = require(Config:WaitForChild("PartyConfig"))
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))

local PartyLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("PartyLogic"))
local ProgressionService = require(script.Parent.ProgressionService)

local PartyService = {
	Name = "PartyService",
	Priority = 26,
	PartyChanged = Signal.new(),
}

local state = PartyLogic.new(ChapterConfig.MaxPartySize, PartyConfig.InviteSeconds)

local function toPlayers(userIds: { number }): { Player }
	local out = {}
	for _, id in userIds do
		local p = Players:GetPlayerByUserId(id)
		if p then
			table.insert(out, p)
		end
	end
	return out
end

function PartyService.GetParty(player: Player): { Player }
	return toPlayers(state:Members(player.UserId))
end

function PartyService.MembersNear(player: Player, radius: number): { Player }
	local origin = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local out = {}
	for _, p in PartyService.GetParty(player) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if p == player or (origin and root and origin:IsA("BasePart") and root:IsA("BasePart") and (root.Position - origin.Position).Magnitude <= radius) then
			table.insert(out, p)
		end
	end
	return out
end

-- Sends each affected player their party view and updates Ember bonuses.
local function push(userIds: { number })
	local now = os.time()
	for _, id in userIds do
		local player = Players:GetPlayerByUserId(id)
		if player then
			local party = state:PartyOf(id)
			local members = {}
			for _, m in state:Members(id) do
				local mp = Players:GetPlayerByUserId(m)
				table.insert(members, { userId = m, name = if mp then mp.DisplayName else tostring(m) })
			end
			local invites = {}
			for _, partyId in state:PendingInvites(id, now) do
				local p = state.parties[partyId]
				local leader = p and Players:GetPlayerByUserId(p.leader)
				table.insert(invites, { partyId = partyId, leaderName = if leader then leader.DisplayName else "?" })
			end
			Net.Server.Fire("PartyEvent", player, {
				inParty = party ~= nil,
				leader = if party then party.leader else id,
				members = members,
				invites = invites,
			})
			ProgressionService.SetSessionBonus(player, "Ember", EconomyConfig.Multipliers.Ember.PartyBonusPerMember * (#members - 1))
		end
	end
	PartyService.PartyChanged:Fire(toPlayers(userIds))
end

local function request(player: Player, action: string, arg: number?): (boolean, string?)
	local me = player.UserId
	local now = os.time()
	if action == "invite" then
		local target = arg and Players:GetPlayerByUserId(arg)
		if target == nil then
			return false, "That player is not in this server"
		end
		local ok, err = state:Invite(me, target.UserId, now)
		if ok then
			Net.Server.Fire("Notify", target, "Party", player.DisplayName .. " invited you to their party! Open Party to accept.")
			push(state:Members(me))
			push({ target.UserId })
		end
		return ok, if ok then "Invite sent to " .. target.DisplayName else err
	elseif action == "accept" then
		local ok, err = state:Accept(me, arg or -1, now)
		if ok then
			push(state:Members(me))
		end
		return ok, if ok then "You joined the party!" else err
	elseif action == "decline" then
		state:Decline(me, arg or -1)
		push({ me })
		return true, nil
	elseif action == "leave" then
		local before = state:Members(me)
		state:Leave(me)
		push(before)
		return true, "You left the party"
	elseif action == "kick" then
		local before = state:Members(me)
		local ok, err = state:Kick(me, arg or -1)
		if ok then
			push(before)
		end
		return ok, err
	elseif action == "refresh" then
		push({ me })
		return true, nil
	end
	return false, "Unknown action"
end

function PartyService.Init() end

function PartyService.Start()
	Net.Server.OnInvoke("PartyRequest", request)
	Players.PlayerRemoving:Connect(function(player)
		local before = state:Members(player.UserId)
		state:Leave(player.UserId)
		local others = {}
		for _, id in before do
			if id ~= player.UserId then
				table.insert(others, id)
			end
		end
		push(others)
	end)
end

return PartyService
