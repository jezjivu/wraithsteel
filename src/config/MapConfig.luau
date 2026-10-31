--!strict
-- MapConfig: the generated Japanese-inspired world ("The Wilds of the Nine Gates") that
-- MapService builds when the place has no Studio map (Workspace.World missing and no existing
-- terrain). Layout (studs, x/z): the hub town sits south at z=150; the stone path runs north
-- through torii gates past every area. Owner: Agent D (replace with a hand-built map later;
-- keep the EnemySpawns / BossArenas folders and attributes).

export type XZ = { number } -- {x, z}

local MapConfig = {}

MapConfig.Seed = 9 -- deterministic prop scatter
MapConfig.GroundSize = { 640, 700 } -- terrain grass area (x, z), centered on GroundCenter
MapConfig.GroundCenter = { 0, -40 }

-- Main stone path from the hub gate north to the world-boss clearing.
MapConfig.Path = { from = { 0, 88 }, to = { 0, -205 }, width = 12 }
-- Side paths to each area (start, end).
MapConfig.SidePaths = {
	{ { 0, 40 }, { -45, 40 } },
	{ { 0, 50 }, { 55, 50 } },
	{ { 0, -10 }, { 45, -10 } },
	{ { 0, -60 }, { -60, -60 } },
	{ { 0, -80 }, { 80, -80 } },
	{ { 0, 15 }, { 116, 15 } },
	{ { -60, -60 }, { -122, -68 } },
	{ { 80, -80 }, { 118, -152 } },
	{ { 0, -165 }, { -88, -188 } },
}
MapConfig.SidePathWidth = 8

-- Single torii gates along the path, plus a dense tunnel of gates (senbon-style) further north.
MapConfig.Torii = { 70, 20, -30 } -- z positions on the main path
MapConfig.ToriiTunnel = { from = -95, to = -124, spacing = 6 }
MapConfig.LanternSpacing = 22 -- stone lanterns along both sides of the main path

-- Areas: name for the zone banner, center, radius, decoration theme.
MapConfig.Areas = {
	{ id = "bamboo", name = "Whispering Bamboo Path", subtitle = "Bandits lurk between the stalks", center = { 0, -45 }, radius = 40, theme = "Bamboo" },
	{ id = "graves", name = "Lantern Graveyard", subtitle = "The dead still carry their lights", center = { 45, -10 }, radius = 26, theme = "Graves" },
	{ id = "maples", name = "Red Maple Grove", subtitle = "Leaves like falling embers", center = { -45, 40 }, radius = 28, theme = "Maples" },
	{ id = "garden", name = "Garden of Still Stones", subtitle = "Raked sand, patient guardians", center = { 55, 50 }, radius = 24, theme = "Garden" },
	{ id = "tiger_shrine", name = "Shrine of the Rust Tiger", subtitle = "A warden that never sleeps", center = { -60, -60 }, radius = 26, theme = "Shrine" },
	{ id = "temple", name = "Temple of the Silent Bell", subtitle = "The abbot keeps his vow", center = { 80, -80 }, radius = 28, theme = "Temple" },
	{ id = "pond", name = "Koi Moon Pond", subtitle = "Still water, quiet bridge", center = { -85, -5 }, radius = 22, theme = "Pond" },
	{ id = "pagoda", name = "Five-Roof Pagoda", subtitle = "It watches the whole valley", center = { -40, -115 }, radius = 18, theme = "Pagoda" },
	{ id = "hollow", name = "Carillon Hollow", subtitle = "Something huge rings here", center = { 0, -165 }, radius = 34, theme = "Hollow" },
	{ id = "springs", name = "Steaming Springs", subtitle = "Rest here: wounds close fast", center = { 140, 15 }, radius = 26, theme = "Springs" },
	{ id = "village", name = "Ashen Village", subtitle = "Burned the night the bell cracked", center = { -150, -70 }, radius = 32, theme = "Village" },
	{ id = "gorge", name = "Falling Petal Gorge", subtitle = "A river born from the mountain", center = { 125, -180 }, radius = 30, theme = "Gorge" },
	{ id = "stairs", name = "Thousand-Step Stair", subtitle = "Every step a prayer", center = { -130, -190 }, radius = 30, theme = "Stairs" },
}

-- Areas where players heal quickly even in combat (fraction of max health per second).
MapConfig.HealAreas = { springs = 0.15 }

-- Enemy spawn points (created in Workspace.EnemySpawns if that folder does not exist).
MapConfig.EnemySpawns = {
	{ name = "BambooBandits", enemyId = "rustbound_bandit", count = 3, respawn = 15, at = { 0, -45 } },
	{ name = "BambooBandits2", enemyId = "rustbound_bandit", count = 2, respawn = 18, at = { -18, -70 } },
	{ name = "GraveGhouls", enemyId = "lantern_ghoul", count = 3, respawn = 20, at = { 45, -10 } },
	{ name = "MapleStalkers", enemyId = "rustwood_stalker", count = 2, respawn = 25, at = { -45, 40 } },
	{ name = "GardenSentinel", enemyId = "rust_eaten_sentinel", count = 1, respawn = 30, at = { 55, 50 } },
	{ name = "VillageGhouls", enemyId = "lantern_ghoul", count = 3, respawn = 20, at = { -150, -70 } },
	{ name = "VillageBandits", enemyId = "rustbound_bandit", count = 2, respawn = 18, at = { -138, -52 } },
	{ name = "GorgeStalkers", enemyId = "rustwood_stalker", count = 2, respawn = 25, at = { 120, -160 } },
	{ name = "StairSentinel", enemyId = "rust_eaten_sentinel", count = 1, respawn = 35, at = { -86, -188 } },
	{ name = "PagodaDuelists", enemyId = "ashen_duelist", count = 2, respawn = 25, at = { -40, -100 } },
	{ name = "VillageDuelist", enemyId = "ashen_duelist", count = 1, respawn = 25, at = { -160, -85 } },
	{ name = "PondBrute", enemyId = "mire_brute", count = 1, respawn = 35, at = { -95, 10 } },
	{ name = "GorgeBrute", enemyId = "mire_brute", count = 1, respawn = 35, at = { 135, -190 } },
}

-- Boss shrines (pad + prompt, created in Workspace.BossArenas if that folder does not exist).
MapConfig.BossArenas = {
	{ name = "RustTigerArena", bossId = "rust_tiger", at = { -60, -66 } },
	{ name = "HollowAbbotArena", bossId = "hollow_abbot", at = { 80, -88 } },
}

-- Mountains ringing the valley (terrain balls: x, z, radius); snow caps on the tallest.
MapConfig.Mountains = {
	{ -220, -300, 110 }, { -60, -330, 120 }, { 120, -320, 115 }, { 260, -230, 100 },
	{ -290, -120, 90 }, { 290, -40, 85 }, { -300, 80, 90 }, { 300, 140, 95 },
	{ -240, 260, 80 }, { 240, 300, 85 },
}
MapConfig.SnowAbove = 70 -- mountain radius above which a snow cap is added

-- Scattered trees outside the areas (count, ring of radii around the path).
MapConfig.SakuraCount = 55
MapConfig.MapleCount = 20
MapConfig.ScatterBounds = { -210, 210, -250, 110 } -- minX, maxX, minZ, maxZ for scattered trees/hills
MapConfig.HillCount = 14 -- low grassy mounds between areas
MapConfig.PetalRate = 25 -- ambient falling petals per second over the valley

-- Performance knobs (lower counts / fewer lights for weak devices).
-- Terrain material colors (Japanese palette: moss, earth, white gravel).
MapConfig.MaterialColors = {
	Grass = { 74, 104, 52 }, -- deep moss
	LeafyGrass = { 104, 112, 58 },
	Ground = { 120, 96, 70 }, -- warm packed earth (paths)
	Pavement = { 214, 208, 194 }, -- white temple gravel (shrines)
	Sand = { 226, 218, 196 }, -- raked garden sand
	Rock = { 112, 108, 104 },
	Mud = { 70, 58, 46 },
	Snow = { 245, 247, 250 },
	Limestone = { 200, 190, 170 },
	Basalt = { 60, 56, 60 },
} :: { [string]: { number } }

MapConfig.Perf = {
	FlagstoneSpacing = 3.6, -- studs between flagstones along paths
	ShadowMinSize = 3, -- parts smaller than this (largest side) cast no shadow
	LanternLightEvery = 2, -- every Nth stone lantern has a PointLight (the rest just glow)
	BambooNodeSpacing = 4.5, -- studs between bamboo node rings
}

MapConfig.Colors = {
	ToriiRed = { 190, 40, 30 },
	ToriiBlack = { 30, 25, 25 },
	Sakura = { 255, 183, 205 },
	SakuraDeep = { 240, 140, 175 },
	Maple = { 205, 60, 35 },
	MapleGold = { 230, 140, 40 },
	Bamboo = { 105, 150, 70 },
	BambooDark = { 70, 110, 50 },
	Stone = { 150, 148, 140 },
	DarkWood = { 70, 45, 35 },
	Wood = { 120, 85, 55 },
	Plaster = { 235, 228, 210 },
	Roof = { 55, 60, 70 },
	LanternGlow = { 255, 190, 110 },
	SpiritGlow = { 140, 200, 255 },
	Flagstone = { 150, 146, 138 },
	Charred = { 45, 35, 32 },
	Steam = { 240, 240, 240 },
	WaterFall = { 170, 215, 235 },
}

return MapConfig
