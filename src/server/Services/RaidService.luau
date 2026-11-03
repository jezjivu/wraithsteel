--!strict
-- RaidService (STUB, Phase 4): 8-player raid (ChapterConfig.RaidSize) in a reserved server.
-- Plan: lobby queue -> TeleportService:ReserveServer -> teleport party with TeleportData
-- {raidId}; raid server runs BossService encounters with kind = "Raid" bosses and role mechanics.
-- Planned API: RaidService.Queue(player), Leave(player)

local RaidService = { Name = "RaidService", Priority = 54 }

function RaidService.Init() end
function RaidService.Start() end

return RaidService
