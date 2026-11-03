--!strict
-- BossConfig: story/world/raid bosses. Owner: Agent C (Warden).
-- Bosses run the shared BossStateMachine (ServerScriptService.Logic.BossStateMachine).
-- Prologue + Chapter 1 bosses are specified (5 of 21); the rest are listed in ChapterConfig
-- and get entries here as their chapters are built.

local EnemyConfig = require(script.Parent.EnemyConfig)

export type BossMove = {
	name: string,
	damage: number,
	postureDamage: number,
	windup: number,
	active: number,
	recovery: number,
	range: number,
	arcDegrees: number,
	weight: number,
	cooldown: number,
	perilous: boolean?,
	perilousKind: ("Pierce" | "Sweep" | "Grasp")?, -- answer: dash in / jump / dodge (CombatConfig)
	minRange: number?, -- only chosen when target is at least this far (gap closers)
	hits: number?, -- multi-hit flurries
	-- Non-melee moves (HazardService). Default "Melee" = sword/claw swing in an arc.
	--   Projectile: one orb at the target (deflectable = perfect deflect sends it back)
	--   Volley: `count` projectiles fanned over `spread` degrees
	--   Wave: shockwave ring from the boss along the ground (jump it)
	--   Rain: `count` eruptions marked around players, after `delay` (get out)
	--   Leap: jumps onto the target's spot (marked circle), crashes down with a ring
	--   Laser: red warning line at the target, then a beam along it; LaserSweep: `count` beams
	--   fanned over `spread` degrees, one after another
	kind: ("Melee" | "Projectile" | "Volley" | "Wave" | "Rain" | "Leap" | "Laser" | "LaserSweep")?,
	speed: number?, -- projectile / wave speed (studs/s)
	count: number?,
	spread: number?,
	radius: number?, -- projectile hit radius / eruption radius / wave max radius
	delay: number?,
	deflectable: boolean?,
	reflectDamage: number?,
	reflectPosture: number?,
	color: { number }?,
	style: string?, -- AnimationConfig style for humanoid bosses (default: alternating slashes)
	visual: string?, -- projectile look: "Rocket" | "Crescent" (default: glowing orb)
	special: boolean?, -- signature move: big gold name callout + flash when it starts
	pose: string?, -- creature pose (CreatureAnimator): Tiger Swipe/Pounce/Rear/Roar/Spit/Spin; Oni Swing/Slam/Throw/Grab/Leap/Spin/Roar
	animationId: string,
}

export type BossPhaseDef = {
	hpThreshold: number, -- phase becomes active when hp fraction <= threshold
	moves: { string },
	speedMultiplier: number,
	enrage: boolean?,
	transitionSeconds: number, -- invulnerable roar/cutscene between phases
}

export type BossDef = {
	name: string,
	title: string,
	chapter: number,
	kind: "Story" | "World" | "Raid",
	maxHealth: number,
	healthPerExtraPlayer: number, -- fraction added per additional player (co-op scaling)
	maxPosture: number,
	postureRegen: number,
	postureBrokenSeconds: number,
	walkSpeed: number,
	moves: { [string]: BossMove },
	phases: { BossPhaseDef },
	idleBetweenMoves: number,
	deflectChance: number?, -- chance to deflect your strikes while not attacking (default BossConfig.DefaultDeflect)
	rewards: { ember: number, xp: number, jadeFirstClear: number },
	modelId: number,
	look: EnemyConfig.RigLook?,
	creature: string?, -- part-built beast instead of a humanoid rig (World/CreatureBuilder): "Tiger"
}

local BossConfig = {}

-- Pushback (studs/s) when boss hits land on players.
BossConfig.StrikeStep = 5 -- studs a boss steps into regular strikes
BossConfig.StrikeStepSpeed = 2.5 -- walk speed multiplier while stepping
BossConfig.DefaultDeflect = 0.35
BossConfig.DamageMultiplier = 1.25 -- bosses hit harder than their listed numbers
BossConfig.PostureMultiplier = 1.2
BossConfig.Knockback = { normal = 16, wide = 30, perilous = 45, perilousLaunch = 18 }

local PLACEHOLDER_ANIM = "rbxassetid://0"

BossConfig.Bosses = {
	-- The Ashen Valley has no bosses (removed for good); only the other realms keep theirs.
	kagura_9 = {
		name = "Kagura-9",
		title = "Warden of the Static Spire",
		chapter = 0,
		kind = "Story",
		maxHealth = 1800,
		healthPerExtraPlayer = 0.6,
		maxPosture = 200,
		postureRegen = 10,
		postureBrokenSeconds = 3,
		walkSpeed = 22,
		deflectChance = 0.55,
		moves = {
			arc_cut = { name = "Arc Cut", style = "SlashRight", damage = 20, postureDamage = 22, windup = 0.35, active = 0.12, recovery = 0.4, range = 10, arcDegrees = 110, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			neon_flurry = { name = "Neon Flurry", style = "Spin", damage = 10, postureDamage = 14, windup = 0.45, active = 0.9, recovery = 0.6, range = 10, arcDegrees = 120, weight = 2, cooldown = 5, hits = 6, animationId = PLACEHOLDER_ANIM },
			rail_thrust = { name = "Railgun Thrust", style = "Thrust", damage = 36, postureDamage = 34, windup = 0.7, active = 0.25, recovery = 0.8, range = 26, minRange = 8, arcDegrees = 30, weight = 2, cooldown = 6, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
			plasma_orb = { name = "Plasma Orb", style = "CastPush", kind = "Projectile", damage = 28, postureDamage = 28, windup = 0.8, active = 0.2, recovery = 0.7, range = 70, arcDegrees = 360, weight = 3, cooldown = 5, speed = 46, radius = 2.2, deflectable = true, reflectDamage = 200, reflectPosture = 90, color = { 255, 60, 200 }, animationId = PLACEHOLDER_ANIM },
			laser_fan = { name = "Laser Fan", style = "CastPush", kind = "Volley", damage = 14, postureDamage = 12, windup = 0.7, active = 0.2, recovery = 0.7, range = 60, minRange = 10, arcDegrees = 360, weight = 2, cooldown = 7, speed = 95, count = 7, spread = 70, radius = 1.2, color = { 60, 230, 255 }, animationId = PLACEHOLDER_ANIM },
			emp_ring = { name = "EMP Ring", style = "CastSky", kind = "Wave", damage = 26, postureDamage = 18, windup = 0.9, active = 0.3, recovery = 0.9, range = 50, arcDegrees = 360, weight = 2, cooldown = 8, speed = 40, radius = 60, color = { 60, 230, 255 }, animationId = PLACEHOLDER_ANIM },
			orbital = { name = "Orbital Strike", style = "CastSky", kind = "Rain", damage = 34, postureDamage = 12, windup = 0.9, active = 0.3, recovery = 0.9, range = 70, arcDegrees = 360, weight = 2, cooldown = 11, count = 8, radius = 7, delay = 1.1, color = { 255, 60, 200 }, animationId = PLACEHOLDER_ANIM },
			sweep_kick = { name = "Ground Sweep", style = "Sweep", damage = 24, postureDamage = 14, windup = 0.55, active = 0.2, recovery = 0.6, range = 11, arcDegrees = 240, weight = 1, cooldown = 6, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "arc_cut", "neon_flurry", "rail_thrust", "plasma_orb", "emp_ring", "sweep_kick" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.5, moves = { "arc_cut", "neon_flurry", "rail_thrust", "plasma_orb", "emp_ring", "sweep_kick", "laser_fan", "orbital" }, speedMultiplier = 1.25, enrage = true, transitionSeconds = 2 },
		},
		idleBetweenMoves = 0.45,
		rewards = { ember = 1200, xp = 1400, jadeFirstClear = 40 },
		modelId = 0,
		look = { skin = { 220, 215, 225 }, body = { 30, 30, 40 }, legs = { 20, 20, 28 }, headwear = "Visor", accent = { 200, 200, 215 }, glow = { 255, 60, 200 }, weapon = "jian_ninth_bell", outfit = "Cyber", scale = 1.35 },
	},
	-- Aeloria boss: the bronze Sun-Archon. Slow, enormous, fights with the sun itself.
	archon_helion = {
		name = "Helion",
		title = "Sun-Archon of Aeloria",
		chapter = 0,
		kind = "Story",
		maxHealth = 3200,
		healthPerExtraPlayer = 0.6,
		maxPosture = 280,
		postureRegen = 8,
		postureBrokenSeconds = 3.5,
		walkSpeed = 16,
		deflectChance = 0.3,
		moves = {
			spear_sweep = { name = "Sun-Spear Sweep", style = "SlashRight", damage = 30, postureDamage = 28, windup = 0.6, active = 0.2, recovery = 0.7, range = 16, arcDegrees = 140, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			heaven_thrust = { name = "Heaven-Piercer", style = "Thrust", damage = 44, postureDamage = 40, windup = 0.9, active = 0.3, recovery = 0.9, range = 34, minRange = 10, arcDegrees = 30, weight = 2, cooldown = 7, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
			sun_orb = { name = "Captive Sun", style = "CastPush", kind = "Projectile", damage = 36, postureDamage = 32, windup = 1.0, active = 0.2, recovery = 0.8, range = 80, arcDegrees = 360, weight = 3, cooldown = 6, speed = 38, radius = 3, deflectable = true, reflectDamage = 320, reflectPosture = 110, color = { 255, 205, 90 }, animationId = PLACEHOLDER_ANIM },
			javelins = { name = "Javelin Storm", style = "CastPush", kind = "Volley", damage = 18, postureDamage = 14, windup = 0.8, active = 0.2, recovery = 0.8, range = 70, minRange = 12, arcDegrees = 360, weight = 2, cooldown = 8, speed = 90, count = 5, spread = 50, radius = 1.4, color = { 220, 170, 90 }, animationId = PLACEHOLDER_ANIM },
			solar_ring = { name = "Solar Flare Ring", style = "CastSky", kind = "Wave", damage = 32, postureDamage = 20, windup = 1.0, active = 0.3, recovery = 1.0, range = 60, arcDegrees = 360, weight = 2, cooldown = 9, speed = 36, radius = 65, color = { 255, 180, 60 }, animationId = PLACEHOLDER_ANIM },
			sunfall = { name = "Sunfall", style = "CastSky", kind = "Rain", damage = 42, postureDamage = 15, windup = 1.0, active = 0.3, recovery = 1.0, range = 80, arcDegrees = 360, weight = 2, cooldown = 12, count = 9, radius = 8, delay = 1.2, color = { 255, 140, 40 }, animationId = PLACEHOLDER_ANIM },
			stomp_sweep = { name = "Colossus Sweep", style = "Sweep", damage = 34, postureDamage = 18, windup = 0.7, active = 0.25, recovery = 0.8, range = 15, arcDegrees = 300, weight = 1, cooldown = 7, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
			sun_grasp = { name = "Grip of Noon", style = "Grasp", damage = 50, postureDamage = 0, windup = 0.9, active = 0.25, recovery = 1.1, range = 10, arcDegrees = 60, weight = 1, cooldown = 10, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "spear_sweep", "heaven_thrust", "sun_orb", "solar_ring", "stomp_sweep" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.6, moves = { "spear_sweep", "heaven_thrust", "sun_orb", "solar_ring", "stomp_sweep", "javelins", "sun_grasp" }, speedMultiplier = 1.15, transitionSeconds = 2.5 },
			{ hpThreshold = 0.3, moves = { "spear_sweep", "heaven_thrust", "sun_orb", "solar_ring", "stomp_sweep", "javelins", "sun_grasp", "sunfall" }, speedMultiplier = 1.3, enrage = true, transitionSeconds = 2.5 },
		},
		idleBetweenMoves = 0.6,
		rewards = { ember = 2500, xp = 2800, jadeFirstClear = 60 },
		modelId = 0,
		look = { skin = { 200, 150, 80 }, body = { 190, 130, 60 }, legs = { 170, 110, 50 }, headwear = "Laurel", accent = { 230, 200, 120 }, glow = { 255, 205, 90 }, weapon = "spear_skypiercer", outfit = "Hoplite", scale = 2.4 },
	},
	-- Raid boss (RaidConfig.sunken_bell_vigil): a drowned bell-keeper fought by up to eight.
	-- The fight teaches the raid: deflect the bell orbs back, jump the toll rings, scatter
	-- from brine rain, and break its posture together during the "Tide Turns" windows.
	kurozuma = {
		name = "Kurozuma",
		title = "Keeper of the Sunken Bell",
		chapter = 0,
		kind = "Raid",
		maxHealth = 9000,
		healthPerExtraPlayer = 0.45,
		maxPosture = 520,
		postureRegen = 6,
		postureBrokenSeconds = 4.5,
		walkSpeed = 15,
		deflectChance = 0.25,
		moves = {
			anchor_swing = { name = "Anchor Swing", style = "SlashRight", damage = 34, postureDamage = 30, windup = 0.7, active = 0.25, recovery = 0.8, range = 18, arcDegrees = 160, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			keel_thrust = { name = "Keel Thrust", style = "Thrust", damage = 48, postureDamage = 42, windup = 0.9, active = 0.3, recovery = 0.9, range = 32, minRange = 10, arcDegrees = 30, weight = 2, cooldown = 7, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
			bell_orb = { name = "Drowned Peal", style = "CastPush", kind = "Projectile", damage = 38, postureDamage = 34, windup = 1.0, active = 0.2, recovery = 0.8, range = 80, arcDegrees = 360, weight = 3, cooldown = 5, speed = 34, radius = 3.2, deflectable = true, reflectDamage = 420, reflectPosture = 140, color = { 90, 210, 200 }, animationId = PLACEHOLDER_ANIM },
			toll_ring = { name = "Toll of the Deep", style = "CastSky", kind = "Wave", damage = 34, postureDamage = 22, windup = 1.0, active = 0.3, recovery = 1.0, range = 70, arcDegrees = 360, weight = 3, cooldown = 8, speed = 34, radius = 75, color = { 70, 190, 210 }, animationId = PLACEHOLDER_ANIM },
			eel_darts = { name = "Eel Darts", style = "CastPush", kind = "Volley", damage = 18, postureDamage = 12, windup = 0.8, active = 0.2, recovery = 0.8, range = 70, minRange = 12, arcDegrees = 360, weight = 2, cooldown = 7, speed = 85, count = 9, spread = 90, radius = 1.3, color = { 120, 230, 210 }, animationId = PLACEHOLDER_ANIM },
			brine_rain = { name = "Brine Rain", style = "CastSky", kind = "Rain", damage = 40, postureDamage = 14, windup = 1.0, active = 0.3, recovery = 1.0, range = 90, arcDegrees = 360, weight = 2, cooldown = 10, count = 14, radius = 8, delay = 1.3, color = { 60, 170, 190 }, animationId = PLACEHOLDER_ANIM },
			undertow = { name = "Undertow", style = "Sweep", damage = 36, postureDamage = 20, windup = 0.75, active = 0.25, recovery = 0.8, range = 17, arcDegrees = 320, weight = 2, cooldown = 6, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
			drowning_grip = { name = "Drowning Grip", style = "Grasp", damage = 60, postureDamage = 0, windup = 0.95, active = 0.25, recovery = 1.1, range = 11, arcDegrees = 60, weight = 1, cooldown = 11, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
			maelstrom = { name = "Maelstrom", style = "Spin", damage = 14, postureDamage = 16, windup = 0.6, active = 1.2, recovery = 0.9, range = 16, arcDegrees = 360, weight = 1, cooldown = 9, hits = 7, special = true, animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "anchor_swing", "keel_thrust", "bell_orb", "toll_ring", "undertow" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.66, moves = { "anchor_swing", "keel_thrust", "bell_orb", "toll_ring", "undertow", "eel_darts", "drowning_grip" }, speedMultiplier = 1.12, transitionSeconds = 3 },
			{ hpThreshold = 0.33, moves = { "anchor_swing", "keel_thrust", "bell_orb", "toll_ring", "undertow", "eel_darts", "drowning_grip", "brine_rain", "maelstrom" }, speedMultiplier = 1.25, enrage = true, transitionSeconds = 3 },
		},
		idleBetweenMoves = 0.55,
		rewards = { ember = 3000, xp = 3200, jadeFirstClear = 40 },
		modelId = 0,
		look = { skin = { 70, 110, 120 }, body = { 30, 50, 60 }, legs = { 22, 36, 44 }, headwear = "Bell", accent = { 120, 200, 190 }, glow = { 90, 230, 210 }, weapon = "gb_gatebreaker", outfit = "Monk", mask = "Oni", face = "Glow", scale = 2.6 },
	},
} :: { [string]: BossDef }

return BossConfig
