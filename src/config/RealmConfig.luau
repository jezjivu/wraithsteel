--!strict
-- RealmConfig: the three realms of WRAITHSTEEL and the portals between them.
--   1. Ashen Valley  - feudal Japan (the original map + hub, at the world origin)
--   2. Neon Verge    - a rain-soaked cyberpunk city
--   3. Aeloria       - an ancient Greek island of marble and sun
-- Every position inside a realm is LOCAL ({x, z} relative to the realm origin, ground y = 0).
-- RealmService builds Neon Verge and Aeloria at runtime (World/NeonBuilder, World/AeloriaBuilder).

export type AreaDef = { id: string, name: string, subtitle: string, center: { number }, radius: number }
export type SpawnDef = { name: string, enemyId: string, count: number, respawn: number, at: { number } }
export type PortalDef = { from: string, to: string, at: { number }, facing: number } -- facing in degrees
export type RealmDef = {
	name: string,
	subtitle: string,
	order: number,
	origin: { number }, -- world {x, y, z}
	half: number, -- realm half-size (studs) for "which realm am I in"
	unlockBoss: string?, -- boss that must be defeated before the portal INTO this realm opens
	color: { number }, -- portal / UI color
	areas: { AreaDef },
	spawns: { SpawnDef },
	arenas: { { name: string, bossId: string, at: { number } } },
	waystones: { { id: string, name: string, at: { number } } },
	arrival: { number }, -- where you appear when entering through a portal
}

local RealmConfig = {}

RealmConfig.Order = { "japan", "neon", "greek" }

RealmConfig.Realms = {
	japan = {
		name = "Ashen Valley",
		subtitle = "Where the Cracked Bell hums",
		order = 1,
		origin = { 0, 0, 0 },
		half = 450,
		color = { 255, 150, 90 },
		areas = {}, -- MapConfig.Areas
		spawns = {}, -- MapConfig.EnemySpawns
		arenas = {},
		waystones = {}, -- WaystoneConfig
		arrival = { 30, 130 },
	},
	neon = {
		name = "Neon Verge",
		subtitle = "The city that never let the bell stop ringing",
		order = 2,
		origin = { -4000, 0, 0 },
		half = 360,
		unlockBoss = "kagehisa",
		color = { 60, 230, 255 },
		areas = {
			{ id = "neon_square", name = "Circuit Square", subtitle = "Holograms where the stars should be", center = { 0, 0 }, radius = 50 },
			{ id = "neon_market", name = "Lantern Wire Market", subtitle = "Noodles, chrome and rumours", center = { -150, 40 }, radius = 50 },
			{ id = "neon_rails", name = "Mag-Rail Yards", subtitle = "Cargo, cranes and Chrome Ronin", center = { 150, 60 }, radius = 60 },
			{ id = "neon_overpass", name = "Skyline Overpass", subtitle = "Drones patrol the high road", center = { 0, -150 }, radius = 55 },
			{ id = "neon_spire", name = "Foot of the Static Spire", subtitle = "Kagura-9 keeps the gate", center = { 0, -270 }, radius = 50 },
		},
		spawns = {
			{ name = "NeonMarketRonin", enemyId = "chrome_ronin", count = 2, respawn = 22, at = { -150, 60 } },
			{ name = "NeonMarketDrones", enemyId = "drone_sentry", count = 2, respawn = 20, at = { -130, 20 } },
			{ name = "NeonRailsBrutes", enemyId = "rail_brute", count = 2, respawn = 30, at = { 160, 80 } },
			{ name = "NeonRailsRonin", enemyId = "chrome_ronin", count = 3, respawn = 22, at = { 140, 40 } },
			{ name = "NeonOverpassDrones", enemyId = "drone_sentry", count = 3, respawn = 20, at = { 0, -150 } },
			{ name = "NeonSpireRonin", enemyId = "chrome_ronin", count = 2, respawn = 25, at = { 20, -225 } },
		},
		arenas = { { name = "KaguraArena", bossId = "kagura_9", at = { 0, -285 } } },
		waystones = {
			{ id = "neon_square", name = "Circuit Square Waystone", at = { 22, 18 } },
			{ id = "neon_rails", name = "Mag-Rail Waystone", at = { 120, 100 } },
			{ id = "neon_spire", name = "Static Spire Waystone", at = { -25, -235 } },
		},
		arrival = { 0, 30 },
	},
	greek = {
		name = "Aeloria",
		subtitle = "An island where the sun is a god and the god is angry",
		order = 3,
		origin = { 4000, 0, 0 },
		half = 380,
		unlockBoss = "kagura_9",
		color = { 255, 215, 120 },
		areas = {
			{ id = "greek_agora", name = "Agora of Aeloria", subtitle = "Marble, olives and an Oracle", center = { 0, 0 }, radius = 55 },
			{ id = "greek_olives", name = "Olive Terraces", subtitle = "Old trees, older guardians", center = { -160, -40 }, radius = 60 },
			{ id = "greek_theatre", name = "Theatre of Echoes", subtitle = "Every word comes back sharper", center = { 150, -30 }, radius = 50 },
			{ id = "greek_harbor", name = "Sunken Harbor", subtitle = "Broken columns in green water", center = { 0, 170 }, radius = 60 },
			{ id = "greek_temple", name = "Temple of the Sun-Archon", subtitle = "Helion waits beneath the gold", center = { 0, -230 }, radius = 60 },
		},
		spawns = {
			{ name = "GreekOliveHoplites", enemyId = "bronze_hoplite", count = 3, respawn = 25, at = { -160, -40 } },
			{ name = "GreekOliveArchers", enemyId = "siren_archer", count = 2, respawn = 22, at = { -190, -80 } },
			{ name = "GreekTheatreSentinel", enemyId = "marble_sentinel", count = 1, respawn = 35, at = { 150, -40 } },
			{ name = "GreekTheatreArchers", enemyId = "siren_archer", count = 2, respawn = 22, at = { 170, 0 } },
			{ name = "GreekHarborHoplites", enemyId = "bronze_hoplite", count = 2, respawn = 25, at = { 65, 150 } },
			{ name = "GreekTempleSentinels", enemyId = "marble_sentinel", count = 2, respawn = 35, at = { 30, -185 } },
		},
		arenas = { { name = "HelionArena", bossId = "archon_helion", at = { 0, -245 } } },
		waystones = {
			{ id = "greek_agora", name = "Agora Waystone", at = { 24, 22 } },
			{ id = "greek_theatre", name = "Theatre Waystone", at = { 120, 20 } },
			{ id = "greek_temple", name = "Temple Stair Waystone", at = { -30, -180 } },
		},
		arrival = { 0, 35 },
	},
} :: { [string]: RealmDef }

-- Portals (local positions in their `from` realm). The gate into a realm stays sealed until
-- that realm's unlockBoss is defeated.
RealmConfig.Portals = {
	{ from = "japan", to = "neon", at = { 60, 0 }, facing = -90 }, -- Japan: relative to the hub center
	{ from = "neon", to = "japan", at = { 0, 55 }, facing = 0 },
	{ from = "neon", to = "greek", at = { 70, 40 }, facing = 90 },
	{ from = "greek", to = "neon", at = { 0, 55 }, facing = 0 },
} :: { PortalDef }

RealmConfig.PortalCooldown = 3

-- World position of a realm-local point.
function RealmConfig.World(realmId: string, at: { number }, y: number?): Vector3
	local r = RealmConfig.Realms[realmId]
	local o = r.origin
	return Vector3.new(o[1] + at[1], o[2] + (y or 0), o[3] + at[2])
end

-- Which realm a world position is in ("japan" by default).
function RealmConfig.At(pos: Vector3): string
	for id, r in RealmConfig.Realms do
		if id ~= "japan" then
			local o = r.origin
			if math.abs(pos.X - o[1]) <= r.half and math.abs(pos.Z - o[3]) <= r.half then
				return id
			end
		end
	end
	return "japan"
end

return RealmConfig
