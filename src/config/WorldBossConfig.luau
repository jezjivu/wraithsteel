--!strict
-- WorldBossConfig: timed open-world bosses anyone in the server can join. Owner: Agent C.
-- Rewards go to every player who dealt at least MinContribution of the boss's max health
-- (party members nearby count too), so late joiners and supports still get paid.

local WorldBossConfig = {}

WorldBossConfig.Rotation = {} :: { string } -- spawns cycle through this list (none: no world bosses for now)
WorldBossConfig.FirstSpawnSeconds = 120 -- after server start
WorldBossConfig.IntervalSeconds = 15 * 60 -- between the end of one and the next spawn
WorldBossConfig.WarningSeconds = 30 -- "awakens soon" announcement lead time
WorldBossConfig.DespawnSeconds = 10 * 60 -- leaves if not defeated in time
WorldBossConfig.JoinRadius = 90 -- players within this distance join the fight
WorldBossConfig.MinContribution = 0.01 -- fraction of max health dealt to earn rewards
WorldBossConfig.DefaultSpawn = { 0, 3, -150 } -- used when Workspace.WorldBossSpawns is missing
WorldBossConfig.SpawnFolderName = "WorldBossSpawns" -- TODO(Studio/Agent D): spawn Parts here

return WorldBossConfig
