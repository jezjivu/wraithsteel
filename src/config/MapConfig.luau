--!strict
-- MapConfig: Ashen Valley, the first realm (feudal Japan), rebuilt as one long LINEAR journey.
-- World/ValleyBuilder builds it (MapService calls it) when the place has no Workspace.World.
--
-- The route runs from the hub's north gate (z = 80) far north through a chain of zones, each a
-- wide clearing joined to the next by a mountain-walled road. Steep rock ridges on both sides
-- keep you on the road; the last third climbs a long stair to a high plateau (y = 50).
--   Ninefold Crossing (hub) -> Torii Road -> Whispering Bamboo -> Lantern Graveyard ->
--   Red Maple Gorge (river + bridge) -> Ashen Village -> Thousand-Step Stair ->
--   Temple of the Silent Bell (plateau) -> Gate of the Cracked Bell (first boss)
-- Everything is placed by raycasting the finished terrain, so nothing ends up in the ground.

export type XZ = { number } -- {x, z}
export type RoutePoint = { at: XZ, half: number, y: number } -- corridor half-width, ground height
export type AreaDef = { id: string, name: string, subtitle: string, center: XZ, radius: number, theme: string, y: number }

local MapConfig = {}

MapConfig.Seed = 9

-- The road, as a polyline. Ground height is linear between points (the stair segment rises).
MapConfig.Route = {
	{ at = { 0, 80 }, half = 26, y = 0 }, -- hub north gate
	{ at = { 0, -120 }, half = 24, y = 0 }, -- Torii Road
	{ at = { 30, -420 }, half = 30, y = 0 }, -- Whispering Bamboo
	{ at = { 300, -700 }, half = 28, y = 0 }, -- Lantern Graveyard
	{ at = { 330, -1080 }, half = 32, y = 0 }, -- Red Maple Gorge
	{ at = { 20, -1380 }, half = 30, y = 0 }, -- Ashen Village
	{ at = { -300, -1560 }, half = 26, y = 0 }, -- stair foot
	{ at = { -300, -1780 }, half = 26, y = 50 }, -- stair top (the stair segment)
	{ at = { -330, -1960 }, half = 34, y = 50 }, -- Temple of the Silent Bell
	{ at = { -40, -2240 }, half = 30, y = 50 }, -- Bell Pass
	{ at = { 0, -2420 }, half = 40, y = 50 }, -- Gate of the Cracked Bell
} :: { RoutePoint }

MapConfig.StairSegment = 7 -- route segment index (7 -> 8) built as a stone stair
MapConfig.PlateauY = 50

-- Zones (clearings along the road). `y` = ground height there.
MapConfig.Areas = {
	{ id = "torii_road", name = "Torii Road", subtitle = "A hundred gates, one way forward", center = { 0, -60 }, radius = 40, theme = "ToriiRoad", y = 0 },
	{ id = "bamboo", name = "Whispering Bamboo", subtitle = "Bandits lurk between the stalks", center = { 30, -420 }, radius = 85, theme = "Bamboo", y = 0 },
	{ id = "graves", name = "Lantern Graveyard", subtitle = "The dead still carry their lights", center = { 300, -700 }, radius = 85, theme = "Graves", y = 0 },
	{ id = "springs", name = "Steaming Springs", subtitle = "Rest here: wounds close fast", center = { 360, -860 }, radius = 30, theme = "Springs", y = 0 },
	{ id = "gorge", name = "Red Maple Gorge", subtitle = "A river born from the mountain", center = { 330, -1080 }, radius = 100, theme = "Gorge", y = 0 },
	{ id = "village", name = "Ashen Village", subtitle = "Burned the night the bell cracked", center = { 20, -1380 }, radius = 100, theme = "Village", y = 0 },
	{ id = "stairs", name = "Thousand-Step Stair", subtitle = "Every step a prayer", center = { -300, -1660 }, radius = 40, theme = "Stairs", y = 25 },
	{ id = "temple", name = "Temple of the Silent Bell", subtitle = "The abbot keeps his vow", center = { -330, -1960 }, radius = 110, theme = "Temple", y = 50 },
	{ id = "bell_gate", name = "Gate of the Cracked Bell", subtitle = "Something iron waits where the bell fell", center = { 0, -2420 }, radius = 110, theme = "BellGate", y = 50 },
} :: { AreaDef }

MapConfig.HealAreas = { springs = 0.15 }

-- Enemy spawn points, spread along the journey (difficulty rises as you go).
MapConfig.EnemySpawns = {
	{ name = "ToriiBandits", enemyId = "rustbound_bandit", count = 2, respawn = 18, at = { 10, -200 } },
	{ name = "BambooBandits", enemyId = "rustbound_bandit", count = 3, respawn = 18, at = { 40, -400 } },
	{ name = "BambooBandits2", enemyId = "rustbound_bandit", count = 2, respawn = 18, at = { -10, -460 } },
	{ name = "RoadGhouls", enemyId = "lantern_ghoul", count = 2, respawn = 20, at = { 170, -570 } },
	{ name = "GraveGhouls", enemyId = "lantern_ghoul", count = 4, respawn = 20, at = { 300, -720 } },
	{ name = "GorgeStalkers", enemyId = "rustwood_stalker", count = 3, respawn = 25, at = { 330, -1040 } },
	{ name = "GorgeBrute", enemyId = "mire_brute", count = 1, respawn = 35, at = { 300, -1130 } },
	{ name = "VillageDuelists", enemyId = "ashen_duelist", count = 3, respawn = 25, at = { 30, -1360 } },
	{ name = "VillageBandits", enemyId = "rustbound_bandit", count = 3, respawn = 18, at = { -20, -1420 } },
	{ name = "StairSentinel", enemyId = "rust_eaten_sentinel", count = 1, respawn = 35, at = { -300, -1540 } },
	{ name = "TempleStalkers", enemyId = "rustwood_stalker", count = 3, respawn = 25, at = { -320, -1900 } },
	{ name = "TempleSentinel", enemyId = "rust_eaten_sentinel", count = 1, respawn = 35, at = { -350, -2010 } },
	{ name = "PassDuelists", enemyId = "ashen_duelist", count = 2, respawn = 25, at = { -160, -2120 } },
	-- More variety along the road.
	{ name = "ToriiHounds", enemyId = "rust_hound", count = 2, respawn = 22, at = { -5, -100 } },
	{ name = "BambooArchers", enemyId = "kite_archer", count = 2, respawn = 22, at = { 60, -450 } },
	{ name = "BambooShinobi", enemyId = "shadow_shinobi", count = 2, respawn = 25, at = { 0, -390 } },
	{ name = "GraveWisps", enemyId = "lantern_wisp", count = 3, respawn = 22, at = { 330, -680 } },
	{ name = "GorgeHounds", enemyId = "rust_hound", count = 3, respawn = 22, at = { 360, -1050 } },
	{ name = "GorgeArchers", enemyId = "kite_archer", count = 2, respawn = 22, at = { 300, -1010 } },
	{ name = "VillageSpears", enemyId = "spear_ronin", count = 2, respawn = 25, at = { -10, -1330 } },
	{ name = "VillageShinobi", enemyId = "shadow_shinobi", count = 2, respawn = 25, at = { 60, -1400 } },
	{ name = "StairMonks", enemyId = "ash_monk", count = 2, respawn = 25, at = { -300, -1600 } },
	{ name = "TempleMonks", enemyId = "ash_monk", count = 3, respawn = 25, at = { -360, -1940 } },
	{ name = "TempleSpears", enemyId = "spear_ronin", count = 2, respawn = 25, at = { -300, -1990 } },
	{ name = "PassShinobi", enemyId = "shadow_shinobi", count = 2, respawn = 25, at = { -100, -2180 } },
	-- Elites (super enemies): one per major zone, long respawn.
	{ name = "EliteGravelord", enemyId = "gravelord", count = 1, respawn = 180, at = { 300, -740 } },
	{ name = "EliteMatriarch", enemyId = "gorge_matriarch", count = 1, respawn = 180, at = { 350, -1120 } },
	{ name = "EliteOniCaptain", enemyId = "oni_captain", count = 1, respawn = 180, at = { 10, -1420 } },
	{ name = "EliteRetainer", enemyId = "masked_retainer", count = 1, respawn = 180, at = { -330, -1990 } },
	-- Lone ambushers on the road between zones (spread the fights out).
	{ name = "RoadBandit1", enemyId = "rustbound_bandit", count = 1, respawn = 25, at = { 15, -270 } },
	{ name = "RoadStalker1", enemyId = "rustwood_stalker", count = 1, respawn = 30, at = { 312, -880 } },
	{ name = "RoadBandits2", enemyId = "rustbound_bandit", count = 2, respawn = 25, at = { 175, -1230 } },
	{ name = "RoadDuelist1", enemyId = "ashen_duelist", count = 1, respawn = 30, at = { -140, -1470 } },
	{ name = "PlateauGhouls", enemyId = "lantern_ghoul", count = 2, respawn = 25, at = { -315, -1870 } },
}

-- Boss shrines (pads; the fight itself happens in an instanced arena).
MapConfig.BossArenas = {
	{ name = "SableCraneArena", bossId = "sable_crane", at = { 70, -1440 } },
	{ name = "HollowAbbotArena", bossId = "hollow_abbot", at = { -330, -2030 } },
}

-- World boss spawn (open-world encounter in the gorge clearing).
MapConfig.WorldBossSpawn = { 360, -1100 }

-- Ridges: rock mountains lining the road (radius range, spacing along the road).
MapConfig.Ridge = { minRadius = 55, maxRadius = 95, spacing = 55, snowAbove = 85 }

MapConfig.PetalRate = 25

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
	FlagstoneSpacing = 4.2, -- studs between flagstones along the road
	ShadowMinSize = 3,
	LanternLightEvery = 3,
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

-- Ground height of the road at a point (nearest route segment, linear between points).
function MapConfig.RoadY(x: number, z: number): number
	local best, bestY = math.huge, 0
	local R = MapConfig.Route
	for i = 1, #R - 1 do
		local a, b = R[i], R[i + 1]
		local ax, az, bx, bz = a.at[1], a.at[2], b.at[1], b.at[2]
		local dx, dz = bx - ax, bz - az
		local len2 = dx * dx + dz * dz
		local t = if len2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / len2, 0, 1) else 0
		local px, pz = ax + dx * t, az + dz * t
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < best then
			best, bestY = d, a.y + (b.y - a.y) * t
		end
	end
	return bestY
end

return MapConfig
