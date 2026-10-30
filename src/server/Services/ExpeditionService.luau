--!strict
-- ExpeditionService (STUB, Phase 2): send idle Spirits on timed expeditions for Ember/XP.
-- Data lives in ProfileData.expeditions (slotId -> ExpeditionState, see Types).
-- Planned rules: spirits on expedition cannot be equipped/fused/released; reward scales with the
-- sent spirits' Power and duration; claims validated against os.time() >= endsAt.
-- Planned API: ExpeditionService.Start(player, slotId, routeId, uids), Claim(player, slotId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local ExpeditionService = { Name = "ExpeditionService", Priority = 52 }

function ExpeditionService.Init() end

function ExpeditionService.Start()
	Net.Server.OnInvoke("StartExpedition", function()
		return false, "Expeditions are coming soon."
	end)
	Net.Server.OnInvoke("ClaimExpedition", function()
		return false, "Expeditions are coming soon."
	end)
end

return ExpeditionService
