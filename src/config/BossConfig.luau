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
	kind: ("Melee" | "Projectile" | "Volley" | "Wave" | "Rain" | "Leap")?,
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
	-- The Bell Oni: the first gate's warden. A towering demon with a bell for a hammer.
	-- Phase 1 teaches the basics (sweeps to deflect, a bell-orb to send back, a toll ring to
	-- jump, a grab to dodge). Phase 2 it starts leaping across the arena and hurling orbs in
	-- threes. Phase 3 it spins and rings the whole arena with falling bells.
	bell_oni = {
		name = "Bell Oni",
		title = "Warden of the Cracked Bell",
		chapter = 0,
		kind = "Story",
		creature = "Oni",
		maxHealth = 1300,
		healthPerExtraPlayer = 0.6,
		maxPosture = 200,
		postureRegen = 7,
		postureBrokenSeconds = 3.5,
		walkSpeed = 16,
		deflectChance = 0.2,
		moves = {
			hammer_sweep = { name = "Bell-Hammer Sweep", pose = "Swing", damage = 18, postureDamage = 22, windup = 0.65, active = 0.2, recovery = 0.6, range = 17, arcDegrees = 150, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			double_sweep = { name = "Back-Swing", pose = "Swing", damage = 14, postureDamage = 18, windup = 0.5, active = 0.7, recovery = 0.7, range = 17, arcDegrees = 150, weight = 2, cooldown = 4, hits = 2, animationId = PLACEHOLDER_ANIM },
			overhead = { name = "Temple Breaker", pose = "Slam", damage = 30, postureDamage = 34, windup = 0.9, active = 0.2, recovery = 0.9, range = 16, arcDegrees = 50, weight = 2, cooldown = 4, animationId = PLACEHOLDER_ANIM },
			bell_orb = { name = "Bell-Orb", kind = "Projectile", pose = "Throw", damage = 24, postureDamage = 26, windup = 0.85, active = 0.2, recovery = 0.7, range = 75, arcDegrees = 360, weight = 3, cooldown = 5, speed = 40, radius = 2.4, deflectable = true, reflectDamage = 110, reflectPosture = 85, color = { 255, 170, 70 }, animationId = PLACEHOLDER_ANIM },
			toll_ring = { name = "Toll of the Cracked Bell", kind = "Wave", pose = "Slam", damage = 22, postureDamage = 14, windup = 1.0, active = 0.3, recovery = 1.0, range = 55, arcDegrees = 360, weight = 2, cooldown = 8, speed = 34, radius = 62, color = { 255, 150, 60 }, animationId = PLACEHOLDER_ANIM },
			oni_grab = { name = "Oni's Grasp", pose = "Grab", damage = 36, postureDamage = 0, windup = 0.85, active = 0.25, recovery = 1.0, range = 11, arcDegrees = 70, weight = 1, cooldown = 9, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
			leap_crash = { name = "Heaven-Fall Leap", kind = "Leap", pose = "Leap", damage = 34, postureDamage = 24, windup = 0.7, active = 1.1, recovery = 1.1, range = 70, minRange = 14, arcDegrees = 360, weight = 3, cooldown = 7, radius = 13, delay = 1.1, color = { 255, 110, 50 }, animationId = PLACEHOLDER_ANIM },
			triple_orb = { name = "Three Tolls", kind = "Volley", pose = "Throw", damage = 20, postureDamage = 22, windup = 0.9, active = 0.2, recovery = 0.8, range = 75, minRange = 12, arcDegrees = 360, weight = 2, cooldown = 9, speed = 44, count = 3, spread = 34, radius = 2.2, deflectable = true, reflectDamage = 80, reflectPosture = 60, color = { 255, 170, 70 }, animationId = PLACEHOLDER_ANIM },
			spin_storm = { name = "Bell Cyclone", pose = "Spin", damage = 12, postureDamage = 12, windup = 0.7, active = 1.4, recovery = 1.0, range = 16, arcDegrees = 360, weight = 2, cooldown = 9, hits = 5, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
			bell_rain = { name = "Rain of Bells", kind = "Rain", pose = "Roar", damage = 30, postureDamage = 12, windup = 1.0, active = 0.3, recovery = 1.0, range = 80, arcDegrees = 360, weight = 2, cooldown = 11, count = 10, radius = 8, delay = 1.2, color = { 255, 120, 40 }, animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "hammer_sweep", "overhead", "bell_orb", "toll_ring", "oni_grab" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.6, moves = { "hammer_sweep", "double_sweep", "overhead", "bell_orb", "toll_ring", "oni_grab", "leap_crash", "triple_orb" }, speedMultiplier = 1.15, transitionSeconds = 2.5 },
			{ hpThreshold = 0.3, moves = { "hammer_sweep", "double_sweep", "bell_orb", "toll_ring", "leap_crash", "triple_orb", "spin_storm", "bell_rain" }, speedMultiplier = 1.3, enrage = true, transitionSeconds = 2.5 },
		},
		idleBetweenMoves = 0.6,
		rewards = { ember = 400, xp = 500, jadeFirstClear = 25 },
		modelId = 0,
		look = { skin = { 150, 45, 40 }, body = { 120, 75, 50 }, legs = { 60, 40, 60 }, accent = { 235, 225, 205 }, glow = { 255, 140, 50 }, scale = 2.4 },
	},
	-- Optional duel (Ashen Village): a pure posture fight. Deflects everything you mash.
	sable_crane = {
		name = "Sable Crane",
		title = "Duelist of the Ashen Gate",
		chapter = 0,
		kind = "Story",
		maxHealth = 900,
		healthPerExtraPlayer = 0.5,
		maxPosture = 140,
		postureRegen = 9,
		postureBrokenSeconds = 3,
		walkSpeed = 20,
		deflectChance = 0.6,
		moves = {
			ash_needles = { name = "Ash Needles", style = "CastPush", kind = "Volley", damage = 10, postureDamage = 12, windup = 0.55, active = 0.15, recovery = 0.6, range = 55, minRange = 8, arcDegrees = 360, weight = 2, cooldown = 7, speed = 85, count = 5, spread = 40, radius = 1.2, color = { 255, 90, 70 }, animationId = PLACEHOLDER_ANIM },
			cinder_orb = { name = "Cinder Pearl", style = "CastPush", kind = "Projectile", damage = 18, postureDamage = 22, windup = 0.8, active = 0.2, recovery = 0.7, range = 60, arcDegrees = 360, weight = 2, cooldown = 6, speed = 46, radius = 2, deflectable = true, reflectDamage = 120, reflectPosture = 70, color = { 255, 120, 90 }, animationId = PLACEHOLDER_ANIM },
			quick_cut = { name = "Ash Feather Cut", style = "SlashRight", damage = 12, postureDamage = 18, windup = 0.35, active = 0.12, recovery = 0.4, range = 9, arcDegrees = 100, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			crane_flurry = { name = "Crane Flurry", style = "Spin", damage = 8, postureDamage = 14, windup = 0.45, active = 0.8, recovery = 0.6, range = 9, arcDegrees = 100, weight = 2, cooldown = 5, hits = 5, animationId = PLACEHOLDER_ANIM },
			gate_thrust = { name = "Gate-Piercing Thrust", style = "Thrust", damage = 30, postureDamage = 30, windup = 0.7, active = 0.25, recovery = 0.8, range = 22, minRange = 6, arcDegrees = 30, weight = 2, cooldown = 6, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
			low_reap = { name = "Low Reaping Arc", style = "Sweep", damage = 24, postureDamage = 12, windup = 0.6, active = 0.2, recovery = 0.7, range = 11, arcDegrees = 220, weight = 1, cooldown = 7, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
			ash_throw = { name = "Ash-Choked Throw", style = "Grasp", damage = 36, postureDamage = 0, windup = 0.8, active = 0.25, recovery = 1.0, range = 8, arcDegrees = 60, weight = 1, cooldown = 9, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "quick_cut", "crane_flurry", "gate_thrust", "low_reap", "ash_needles", "cinder_orb" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.5, moves = { "quick_cut", "crane_flurry", "gate_thrust", "low_reap", "ash_throw", "ash_needles", "cinder_orb" }, speedMultiplier = 1.25, enrage = true, transitionSeconds = 2 },
		},
		idleBetweenMoves = 0.45,
		rewards = { ember = 450, xp = 500, jadeFirstClear = 20 },
		modelId = 0, -- TODO(Studio/Agent C): Sable Crane rig
		look = { skin = { 225, 200, 180 }, body = { 30, 28, 34 }, legs = { 25, 22, 28 }, headwear = "Hair", accent = { 230, 60, 50 }, glow = { 255, 120, 90 }, weapon = "jian_ninth_bell", scale = 1.15 },
	},
	-- Neon Verge boss: a cyber-samurai warden. Katana strings she deflects with, plasma orbs
	-- you can send back, EMP rings to jump, orbital strikes to outrun.
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
		look = { skin = { 220, 215, 225 }, body = { 30, 30, 40 }, legs = { 20, 20, 28 }, headwear = "Visor", accent = { 200, 200, 215 }, glow = { 255, 60, 200 }, weapon = "jian_ninth_bell", scale = 1.35 },
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
		look = { skin = { 200, 150, 80 }, body = { 190, 130, 60 }, legs = { 170, 110, 50 }, headwear = "Laurel", accent = { 230, 200, 120 }, glow = { 255, 205, 90 }, weapon = "spear_skypiercer", scale = 2.4 },
	},
	-- Chapter 1: Rustwood Pass
	hollow_abbot = {
		name = "Hollow Abbot",
		title = "Keeper of the Silent Bell",
		chapter = 1,
		kind = "Story",
		maxHealth = 2600,
		healthPerExtraPlayer = 0.6,
		maxPosture = 420,
		postureRegen = 8,
		postureBrokenSeconds = 4,
		walkSpeed = 16,
		moves = {
			bell_orb = { name = "Tolling Orb", style = "CastPush", kind = "Projectile", damage = 30, postureDamage = 30, windup = 0.9, active = 0.2, recovery = 0.8, range = 70, arcDegrees = 360, weight = 3, cooldown = 6, speed = 40, radius = 2.4, deflectable = true, reflectDamage = 220, reflectPosture = 90, color = { 255, 210, 120 }, animationId = PLACEHOLDER_ANIM },
			toll_wave = { name = "Silent Toll", style = "CastSky", kind = "Wave", damage = 34, postureDamage = 20, windup = 1.1, active = 0.3, recovery = 1.0, range = 50, arcDegrees = 360, weight = 2, cooldown = 9, speed = 32, radius = 55, color = { 255, 220, 150 }, animationId = PLACEHOLDER_ANIM },
			bell_rain = { name = "Falling Bells", style = "CastSky", kind = "Rain", damage = 40, postureDamage = 15, windup = 1.0, active = 0.3, recovery = 1.0, range = 70, arcDegrees = 360, weight = 1, cooldown = 13, count = 6, radius = 8, delay = 1.2, color = { 255, 200, 110 }, animationId = PLACEHOLDER_ANIM },
			staff_sweep = { name = "Rattan Sweep", damage = 40, postureDamage = 30, windup = 0.45, active = 0.15, recovery = 0.5, range = 11, arcDegrees = 140, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			bell_palm = { name = "Silent Bell Palm", damage = 55, postureDamage = 60, windup = 0.7, active = 0.15, recovery = 0.7, range = 8, arcDegrees = 50, weight = 2, cooldown = 6, animationId = PLACEHOLDER_ANIM },
			pilgrim_dash = { name = "Pilgrim's Dash", damage = 50, postureDamage = 35, windup = 0.6, active = 0.3, recovery = 0.8, range = 26, arcDegrees = 40, weight = 2, cooldown = 8, minRange = 12, animationId = PLACEHOLDER_ANIM },
			hollow_chant = { name = "Hollow Chant", damage = 45, postureDamage = 20, windup = 1.2, active = 0.5, recovery = 1.0, range = 16, arcDegrees = 360, weight = 1, cooldown = 14, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
			prayer_beads = { name = "Hundred Prayer Beads", damage = 14, postureDamage = 10, windup = 0.5, active = 1.0, recovery = 0.6, range = 12, arcDegrees = 90, weight = 2, cooldown = 10, hits = 5, animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "staff_sweep", "bell_palm", "pilgrim_dash", "prayer_beads", "bell_orb", "toll_wave" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.45, moves = { "staff_sweep", "bell_palm", "pilgrim_dash", "prayer_beads", "hollow_chant", "bell_orb", "toll_wave", "bell_rain" }, speedMultiplier = 1.15, enrage = true, transitionSeconds = 2.5 },
		},
		idleBetweenMoves = 0.7,
		rewards = { ember = 1200, xp = 1500, jadeFirstClear = 30 },
		modelId = 0, -- TODO(Studio/Agent C)
		look = { skin = { 170, 165, 160 }, body = { 90, 90, 100 }, legs = { 70, 70, 80 }, headwear = "Hood", accent = { 200, 190, 170 }, weapon = "staff_bellringer", scale = 1.9 },
	},
	twin_cinder_sisters = {
		name = "Twin Cinder Sisters",
		title = "Embers That Never Part",
		chapter = 1,
		kind = "Story",
		maxHealth = 3000,
		healthPerExtraPlayer = 0.6,
		maxPosture = 460,
		postureRegen = 7,
		postureBrokenSeconds = 3.5,
		walkSpeed = 20,
		moves = {
			cinder_fan = { name = "Cinder Fan", damage = 38, postureDamage = 26, windup = 0.4, active = 0.15, recovery = 0.45, range = 10, arcDegrees = 120, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			ember_crossing = { name = "Ember Crossing", damage = 16, postureDamage = 12, windup = 0.45, active = 0.9, recovery = 0.6, range = 10, arcDegrees = 100, weight = 2, cooldown = 7, hits = 4, animationId = PLACEHOLDER_ANIM },
			sister_swap = { name = "Sister Swap", damage = 48, postureDamage = 30, windup = 0.55, active = 0.25, recovery = 0.7, range = 24, arcDegrees = 40, weight = 2, cooldown = 8, minRange = 10, animationId = PLACEHOLDER_ANIM },
			ash_veil = { name = "Ash Veil", damage = 52, postureDamage = 15, windup = 1.0, active = 0.4, recovery = 1.0, range = 14, arcDegrees = 360, weight = 1, cooldown = 13, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "cinder_fan", "ember_crossing", "sister_swap" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.5, moves = { "cinder_fan", "ember_crossing", "sister_swap", "ash_veil" }, speedMultiplier = 1.2, enrage = true, transitionSeconds = 3 },
		},
		idleBetweenMoves = 0.7,
		rewards = { ember = 1400, xp = 1700, jadeFirstClear = 30 },
		modelId = 0, -- TODO(Studio/Agent C)
		look = { skin = { 230, 190, 160 }, body = { 170, 40, 35 }, legs = { 90, 25, 25 }, headwear = "Hair", accent = { 255, 140, 60 }, weapon = "fan_iron_lotus", glow = { 255, 120, 50 }, scale = 1.7 },
	},
	rustwood_matriarch = {
		name = "Rustwood Matriarch",
		title = "Mother of the Corroded Grove",
		chapter = 1,
		kind = "Story",
		maxHealth = 3600,
		healthPerExtraPlayer = 0.6,
		maxPosture = 560,
		postureRegen = 6,
		postureBrokenSeconds = 4,
		walkSpeed = 14,
		moves = {
			root_lash = { name = "Root Lash", damage = 44, postureDamage = 28, windup = 0.5, active = 0.2, recovery = 0.6, range = 14, arcDegrees = 120, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			thorn_volley = { name = "Thorn Volley", damage = 12, postureDamage = 8, windup = 0.6, active = 1.0, recovery = 0.6, range = 30, arcDegrees = 40, weight = 2, cooldown = 9, hits = 6, minRange = 10, animationId = PLACEHOLDER_ANIM },
			trampling_charge = { name = "Trampling Charge", damage = 70, postureDamage = 40, windup = 0.9, active = 0.6, recovery = 1.2, range = 40, arcDegrees = 30, weight = 2, cooldown = 11, minRange = 15, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
			sap_burst = { name = "Sap Burst", damage = 40, postureDamage = 45, windup = 1.0, active = 0.3, recovery = 0.9, range = 13, arcDegrees = 360, weight = 1, cooldown = 12, animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "root_lash", "thorn_volley", "trampling_charge" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.5, moves = { "root_lash", "thorn_volley", "trampling_charge", "sap_burst" }, speedMultiplier = 1.15, enrage = true, transitionSeconds = 3 },
		},
		idleBetweenMoves = 0.7,
		rewards = { ember = 1700, xp = 2000, jadeFirstClear = 35 },
		modelId = 0, -- TODO(Studio/Agent C)
		look = { skin = { 110, 130, 80 }, body = { 80, 70, 45 }, legs = { 60, 50, 35 }, headwear = "Horns", accent = { 140, 160, 90 }, weapon = "spear_crimson_tassel", scale = 2.5 },
	},
	gatekeeper_of_rust = {
		name = "Gatekeeper of Rust",
		title = "First of the Nine Gates",
		chapter = 1,
		kind = "Story",
		maxHealth = 5200,
		healthPerExtraPlayer = 0.6,
		maxPosture = 700,
		postureRegen = 6,
		postureBrokenSeconds = 4.5,
		walkSpeed = 16,
		moves = {
			gate_cleave = { name = "Gate Cleave", damage = 55, postureDamage = 38, windup = 0.55, active = 0.2, recovery = 0.6, range = 12, arcDegrees = 130, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			chain_whip = { name = "Chain Whip", damage = 40, postureDamage = 26, windup = 0.5, active = 0.2, recovery = 0.6, range = 20, arcDegrees = 60, weight = 2, cooldown = 6, minRange = 8, animationId = PLACEHOLDER_ANIM },
			rust_rush = { name = "Rust Rush", damage = 65, postureDamage = 40, windup = 0.75, active = 0.5, recovery = 1.0, range = 36, arcDegrees = 30, weight = 2, cooldown = 9, minRange = 14, animationId = PLACEHOLDER_ANIM },
			gate_slam = { name = "Gate Slam", damage = 80, postureDamage = 80, windup = 1.1, active = 0.2, recovery = 1.1, range = 10, arcDegrees = 70, weight = 1, cooldown = 10, animationId = PLACEHOLDER_ANIM },
			iron_toll = { name = "Iron Toll", damage = 60, postureDamage = 25, windup = 1.3, active = 0.5, recovery = 1.2, range = 20, arcDegrees = 360, weight = 1, cooldown = 15, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "gate_cleave", "chain_whip", "gate_slam" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.66, moves = { "gate_cleave", "chain_whip", "gate_slam", "rust_rush" }, speedMultiplier = 1.1, transitionSeconds = 2.5 },
			{ hpThreshold = 0.33, moves = { "gate_cleave", "chain_whip", "gate_slam", "rust_rush", "iron_toll" }, speedMultiplier = 1.25, enrage = true, transitionSeconds = 3 },
		},
		idleBetweenMoves = 0.7,
		rewards = { ember = 2600, xp = 3000, jadeFirstClear = 50 },
		modelId = 0, -- TODO(Studio/Agent C)
		look = { skin = { 90, 90, 100 }, body = { 60, 60, 70 }, legs = { 45, 45, 55 }, headwear = "Helm", accent = { 160, 80, 40 }, weapon = "gb_gatebreaker", scale = 2.7 },
	},
	-- World bosses (WorldBossService) ---------------------------------------------------------
	hollow_carillon = {
		name = "The Hollow Carillon",
		title = "A Bell That Rings Itself",
		chapter = 0,
		kind = "World",
		maxHealth = 6000,
		healthPerExtraPlayer = 0.5,
		maxPosture = 900,
		postureRegen = 10,
		postureBrokenSeconds = 5,
		walkSpeed = 10,
		moves = {
			clapper_sweep = { name = "Clapper Sweep", damage = 26, postureDamage = 24, windup = 0.6, active = 0.25, recovery = 0.6, range = 14, arcDegrees = 150, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			chain_lash = { name = "Rusted Chain Lash", damage = 22, postureDamage = 18, windup = 0.5, active = 0.3, recovery = 0.6, range = 26, minRange = 8, arcDegrees = 50, weight = 2, cooldown = 6, animationId = PLACEHOLDER_ANIM },
			resonance = { name = "Resonance", damage = 9, postureDamage = 14, windup = 0.6, active = 1.2, recovery = 0.8, range = 16, arcDegrees = 360, weight = 2, cooldown = 10, hits = 6, animationId = PLACEHOLDER_ANIM },
			toll_wave = { name = "Toll Wave", style = "CastSky", damage = 18, postureDamage = 45, windup = 1.0, active = 0.4, recovery = 1.0, range = 32, arcDegrees = 360, weight = 1, cooldown = 14, animationId = PLACEHOLDER_ANIM },
			bell_slam = { name = "Falling Bell", damage = 48, postureDamage = 20, windup = 1.4, active = 0.3, recovery = 1.4, range = 18, arcDegrees = 360, weight = 1, cooldown = 16, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "clapper_sweep", "chain_lash", "resonance" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.6, moves = { "clapper_sweep", "chain_lash", "resonance", "toll_wave" }, speedMultiplier = 1.1, transitionSeconds = 3 },
			{ hpThreshold = 0.3, moves = { "clapper_sweep", "chain_lash", "resonance", "toll_wave", "bell_slam" }, speedMultiplier = 1.25, enrage = true, transitionSeconds = 3 },
		},
		idleBetweenMoves = 0.9,
		rewards = { ember = 1500, xp = 1200, jadeFirstClear = 40 },
		modelId = 0, -- TODO(Studio/Agent C): giant bell construct rig
		look = { skin = { 150, 115, 60 }, body = { 130, 95, 45 }, legs = { 90, 65, 35 }, headwear = "Bell", accent = { 255, 200, 120 }, weapon = "staff_bellringer", glow = { 255, 190, 110 }, scale = 3.4 },
	},
} :: { [string]: BossDef }

return BossConfig
