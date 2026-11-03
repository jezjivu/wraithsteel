--!strict
-- MapConfig: Ashen Valley, the first realm (feudal Japan). Laid out like a Souls-style level:
-- WIDE and interconnected instead of one long line. World/ValleyBuilder builds it.
--
--                 [Gate of the Cracked Bell] (plateau, y 50)
--                  /            |  shortcut          \
--   (cliff stair) /             | (descent)           \ (temple road)
--   [Ashen Village]             |               [Temple of the Silent Bell] (y 50)
--         |                     |                      | (Thousand-Step Stair)
--  [Springs]-[Lantern Graveyard]-[Whispering Bamboo]-[Red Maple Gorge]
--                               |  (crossroads)
--                          [Torii Road]
--                         [Ninefold Crossing] (hub)
--
-- Rock ridges wall every road, so the regions read as separate places joined by passes; the
-- two climbs and the central shortcut make loops back to earlier areas.
-- Everything is placed by raycasting the finished terrain, so nothing ends up in the ground.

export type XZ = { number } -- {x, z}
export type RoutePoint = { at: XZ, half: number, y: number } -- corridor half-width, ground height
export type AreaDef = { id: string, name: string, subtitle: string, center: XZ, radius: number, theme: string, y: number }

local MapConfig = {}

MapConfig.Seed = 9

-- Roads (each a polyline; ground height is linear between points - a rise = a stone stair).
MapConfig.Roads = {
	{ -- hub -> Torii Road -> crossroads
		{ at = { 0, 80 }, half = 26, y = 0 },
		{ at = { 0, -150 }, half = 24, y = 0 },
		{ at = { 0, -330 }, half = 30, y = 0 },
	},
	{ -- crossroads -> graveyard -> springs
		{ at = { 0, -330 }, half = 26, y = 0 },
		{ at = { -220, -310 }, half = 24, y = 0 },
		{ at = { -420, -300 }, half = 28, y = 0 },
		{ at = { -560, -440 }, half = 18, y = 0 },
	},
	{ -- graveyard -> village
		{ at = { -420, -300 }, half = 24, y = 0 },
		{ at = { -470, -520 }, half = 22, y = 0 },
		{ at = { -380, -760 }, half = 28, y = 0 },
	},
	{ -- village -> cliff stair -> gate
		{ at = { -380, -760 }, half = 24, y = 0 },
		{ at = { -330, -880 }, half = 22, y = 0 },
		{ at = { -220, -1000 }, half = 22, y = 50 },
		{ at = { 0, -1050 }, half = 30, y = 50 },
	},
	{ -- crossroads -> gorge
		{ at = { 0, -330 }, half = 26, y = 0 },
		{ at = { 220, -360 }, half = 24, y = 0 },
		{ at = { 420, -360 }, half = 30, y = 0 },
	},
	{ -- gorge -> Thousand-Step Stair -> temple
		{ at = { 420, -360 }, half = 24, y = 0 },
		{ at = { 470, -560 }, half = 24, y = 0 },
		{ at = { 470, -760 }, half = 24, y = 50 },
		{ at = { 300, -1000 }, half = 28, y = 50 },
	},
	{ -- temple -> gate
		{ at = { 300, -1000 }, half = 26, y = 50 },
		{ at = { 0, -1050 }, half = 30, y = 50 },
	},
	{ -- shortcut: gate -> mountain pass -> crossroads (a long descent)
		{ at = { 0, -1050 }, half = 20, y = 50 },
		{ at = { 0, -880 }, half = 18, y = 50 },
		{ at = { 0, -640 }, half = 18, y = 0 },
		{ at = { 0, -330 }, half = 20, y = 0 },
	},
} :: { { RoutePoint } }

MapConfig.PlateauY = 50

-- Zones (clearings). `y` = ground height there.
MapConfig.Areas = {
	{ id = "torii_road", name = "Torii Road", subtitle = "A hundred gates, one way forward", center = { 0, -60 }, radius = 40, theme = "ToriiRoad", y = 0 },
	{ id = "bamboo", name = "Whispering Bamboo", subtitle = "Every road in the valley meets here", center = { 0, -330 }, radius = 105, theme = "Bamboo", y = 0 },
	{ id = "graves", name = "Lantern Graveyard", subtitle = "The dead still carry their lights", center = { -420, -300 }, radius = 95, theme = "Graves", y = 0 },
	{ id = "springs", name = "Steaming Springs", subtitle = "Rest here: wounds close fast", center = { -560, -440 }, radius = 38, theme = "Springs", y = 0 },
	{ id = "village", name = "Ashen Village", subtitle = "Burned the night the bell cracked", center = { -380, -760 }, radius = 110, theme = "Village", y = 0 },
	{ id = "gorge", name = "Red Maple Gorge", subtitle = "A river born from the mountain", center = { 420, -360 }, radius = 105, theme = "Gorge", y = 0 },
	{ id = "stairs", name = "Thousand-Step Stair", subtitle = "Every step a prayer", center = { 470, -660 }, radius = 36, theme = "Stairs", y = 25 },
	{ id = "temple", name = "Temple of the Silent Bell", subtitle = "The abbot keeps his vow", center = { 300, -1000 }, radius = 110, theme = "Temple", y = 50 },
	{ id = "bell_gate", name = "Gate of the Cracked Bell", subtitle = "Where the great bell fell", center = { 0, -1050 }, radius = 100, theme = "BellGate", y = 50 },
} :: { AreaDef }

MapConfig.HealAreas = { springs = 0.15 }

-- Enemy spawns: few, small groups with lots of room between them.
MapConfig.EnemySpawns = {
	{ name = "ToriiBandits", enemyId = "rustbound_bandit", count = 2, respawn = 25, at = { 0, -180 } },
	{ name = "BambooBandits", enemyId = "rustbound_bandit", count = 2, respawn = 25, at = { 40, -300 } },
	{ name = "BambooShinobi", enemyId = "shadow_shinobi", count = 1, respawn = 30, at = { -50, -380 } },
	{ name = "BambooArcher", enemyId = "kite_archer", count = 1, respawn = 30, at = { 60, -400 } },
	{ name = "WestRoadHound", enemyId = "rust_hound", count = 2, respawn = 30, at = { -220, -310 } },
	{ name = "GraveGhouls", enemyId = "lantern_ghoul", count = 2, respawn = 25, at = { -400, -270 } },
	{ name = "GraveWisps", enemyId = "lantern_wisp", count = 2, respawn = 25, at = { -460, -330 } },
	{ name = "VillageRoadSpear", enemyId = "spear_ronin", count = 1, respawn = 30, at = { -470, -520 } },
	{ name = "VillageDuelists", enemyId = "ashen_duelist", count = 2, respawn = 30, at = { -350, -730 } },
	{ name = "VillageBandits", enemyId = "rustbound_bandit", count = 2, respawn = 25, at = { -420, -800 } },
	{ name = "CliffMonk", enemyId = "ash_monk", count = 1, respawn = 30, at = { -330, -880 } },
	{ name = "EastRoadArcher", enemyId = "kite_archer", count = 1, respawn = 30, at = { 220, -360 } },
	{ name = "GorgeStalkers", enemyId = "rustwood_stalker", count = 2, respawn = 30, at = { 400, -330 } },
	{ name = "GorgeHounds", enemyId = "rust_hound", count = 2, respawn = 30, at = { 450, -400 } },
	{ name = "StairSentinel", enemyId = "rust_eaten_sentinel", count = 1, respawn = 40, at = { 470, -560 } },
	{ name = "TempleMonks", enemyId = "ash_monk", count = 2, respawn = 30, at = { 280, -970 } },
	{ name = "TempleSpears", enemyId = "spear_ronin", count = 1, respawn = 30, at = { 330, -1030 } },
	{ name = "GateShinobi", enemyId = "shadow_shinobi", count = 2, respawn = 30, at = { -40, -1030 } },
	{ name = "PassBrute", enemyId = "mire_brute", count = 1, respawn = 45, at = { 0, -760 } },
	-- Elites (super enemies): one per wing, long respawn.
	{ name = "EliteGravelord", enemyId = "gravelord", count = 1, respawn = 180, at = { -440, -320 } },
	{ name = "EliteMatriarch", enemyId = "gorge_matriarch", count = 1, respawn = 180, at = { 440, -380 } },
	{ name = "EliteOniCaptain", enemyId = "oni_captain", count = 1, respawn = 180, at = { -380, -780 } },
	{ name = "EliteRetainer", enemyId = "masked_retainer", count = 1, respawn = 180, at = { 300, -1020 } },
}

-- Boss shrines (pads; the fight happens in an instanced arena).
MapConfig.BossArenas = {
	{ name = "SableCraneArena", bossId = "sable_crane", at = { -320, -800 } },
	{ name = "HollowAbbotArena", bossId = "hollow_abbot", at = { 330, -1060 } },
}

-- One-way shortcut gates (Souls-style): barred from one side; open them from `openFrom`'s
-- side and they stay open for you (saved). ExplorationService builds them across the road.
MapConfig.Shortcuts = {
	{ id = "pass_gate", name = "Mountain Pass Gate", at = { 0, -600 }, dir = { 0, 1 }, half = 18, openFrom = { 0, -700 } },
	{ id = "temple_gate", name = "Temple Road Gate", at = { 150, -1025 }, dir = { 1, 0.17 }, half = 26, openFrom = { 60, -1040 } },
}

-- Ashen Relics: hidden pickups, each worth one extra skill point.
MapConfig.Relics = {
	{ id = "relic_bamboo", at = { -60, -260 } },
	{ id = "relic_graves", at = { -470, -250 } },
	{ id = "relic_springs", at = { -575, -455 } },
	{ id = "relic_village", at = { -455, -820 } },
	{ id = "relic_gorge", at = { 360, -430 } },
	{ id = "relic_stair", at = { 470, -770 } },
	{ id = "relic_temple", at = { 360, -1060 } },
	{ id = "relic_gate", at = { 70, -1100 } },
}

-- Lookout towers: wooden platforms with a grappling-hook point on top (vertical routes,
-- ambush spots over the zones). {x, z, platform height}
MapConfig.Lookouts = {
	{ 75, -255, 22 }, { -85, -405, 22 },
	{ -350, -375, 20 }, { -505, -235, 18 },
	{ -300, -690, 24 }, { -470, -745, 20 }, { -395, -865, 22 },
	{ 345, -295, 22 }, { 500, -320, 24 },
	{ 225, -945, 20 }, { 375, -1050, 22 },
	{ -65, -995, 26 }, { 85, -995, 26 },
	{ 27, -560, 24 }, { -27, -800, 24 },
}

-- World boss spawn (open-world encounter in the gorge clearing).
MapConfig.WorldBossSpawn = { 440, -330 }

-- Compatibility: the hub -> crossroads road (some systems want "the" route).
MapConfig.Route = MapConfig.Roads[1]

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
	for _, R in MapConfig.Roads do
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
	end
	-- Plateau zones override (their whole clearing sits up there).
	for _, area in MapConfig.Areas do
		local d = math.sqrt((x - area.center[1]) ^ 2 + (z - area.center[2]) ^ 2)
		if d <= area.radius and d < best then
			return area.y
		end
	end
	return bestY
end

return MapConfig
