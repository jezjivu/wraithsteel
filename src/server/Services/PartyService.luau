--!strict
-- PartyService (STUB, Phase 3): 4-player co-op parties for story chapters and boss fights.
-- Planned API (frozen names, implement bodies later):
--   PartyService.GetParty(player) -> { Player }        (solo = { player })
--   PartyService.Invite(player, targetUserId) / Accept / Leave / Kick
--   PartyService.PartyChanged: Signal(partyId, members)
-- Party Ember bonus: ProgressionService.SetSessionBonus(player, "Ember",
--   EconomyConfig.Multipliers.Ember.PartyBonusPerMember * (#members - 1)).
-- Max size: ChapterConfig.MaxPartySize.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local PartyService = {
	Name = "PartyService",
	Priority = 50,
	PartyChanged = Signal.new(),
}

function PartyService.GetParty(player: Player): { Player }
	return { player }
end

function PartyService.Init() end

function PartyService.Start()
	Net.Server.OnInvoke("PartyRequest", function(_player, _action, _targetUserId)
		return false, "Parties are coming soon."
	end)
end

return PartyService
