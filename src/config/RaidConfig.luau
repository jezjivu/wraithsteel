--!strict
-- RaidConfig: 8-player raids in reserved servers. Owner: Agent C.
-- Flow: a leader opens a raid lobby in a normal server -> up to RaidSize players join ->
-- leader launches -> RaidService reserves a private server, writes a manifest (raid id + member
-- list) to MemoryStore under the reserved server's PrivateServerId and teleports everyone.
-- The raid server trusts only that manifest (never client TeleportData).

export type RaidDef = {
	name: string,
	description: string,
	bossId: string, -- BossConfig id fought in the raid
	chapter: number, -- profile.chapter required
	minLevel: number,
	minPlayers: number, -- launch needs at least this many members (Studio ignores it)
	healthMultiplier: number, -- on top of the boss's normal co-op scaling
	timeLimitSeconds: number,
	rewards: { ember: number, xp: number, jade: number },
	firstClearJade: number,
}

local RaidConfig = {}

RaidConfig.RaidSize = 8 -- keep equal to ChapterConfig.RaidSize
RaidConfig.LobbySeconds = 300 -- an idle lobby closes after this
RaidConfig.JoinRadius = 60 -- studs from the leader to join a lobby
RaidConfig.ManifestStore = "WraithsteelRaidManifest_v1" -- MemoryStore hash map
RaidConfig.ManifestSeconds = 1800 -- manifest expiry
RaidConfig.WaitForMembersSeconds = 45 -- raid server waits this long for everyone to arrive
RaidConfig.ReturnDelaySeconds = 12 -- after victory/defeat, players go back after this
RaidConfig.TeleportRetries = 3

RaidConfig.Raids = {
	-- TODO(Studio/Agent C): a dedicated raid boss (rig, arena, role mechanics). Until then the
	-- raid reuses Helion with raid-sized health so the whole flow can be playtested.
	sunken_bell_vigil = {
		name = "Vigil of the Sunken Bell",
		description = "Eight blades hold the line while the drowned bell tolls.",
		bossId = "archon_helion",
		chapter = 0,
		minLevel = 10,
		minPlayers = 4,
		healthMultiplier = 1.5,
		timeLimitSeconds = 900,
		rewards = { ember = 4000, xp = 2500, jade = 10 },
		firstClearJade = 60,
	},
} :: { [string]: RaidDef }

RaidConfig.RaidOrder = { "sunken_bell_vigil" }

return RaidConfig
