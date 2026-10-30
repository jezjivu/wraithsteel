--!strict
-- WorldBossService (STUB, Phase 3): timed open-world bosses anyone in the server can join.
-- Plan: schedule from BossConfig entries with kind = "World"; spawn via
-- BossService.StartEncounter with participants = players within range, re-evaluated every few
-- seconds (late joiners added); rewards scale with contribution (Combatant.contributions).
-- Planned API: WorldBossService.NextSpawnAt() -> number, WorldBossService.Active() -> bossId?

local WorldBossService = { Name = "WorldBossService", Priority = 53 }

function WorldBossService.NextSpawnAt(): number
	return math.huge
end

function WorldBossService.Init() end
function WorldBossService.Start() end

return WorldBossService
