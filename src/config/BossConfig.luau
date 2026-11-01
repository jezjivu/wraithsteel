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
	kind: ("Melee" | "Projectile" | "Volley" | "Wave" | "Rain")?,
	speed: number?, -- projectile / wave speed (studs/s)
	count: number?,
	spread: number?,
	radius: number?, -- projectile hit radius / eruption radius / wave max radius
	delay: number?,
	deflectable: boolean?,
	reflectDamage: number?,
	reflectPosture: number?,
	color: { number }?,
	pose: string?, -- creature pose for the windup (CreatureAnimator): Swipe, Pounce, Rear, Roar, Spit, Spin
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
BossConfig.Knockback = { normal = 16, wide = 30, perilous = 45, perilousLaunch = 18 }

local PLACEHOLDER_ANIM = "rbxassetid://0"

BossConfig.Bosses = {
	-- A rust-plated beast: claws and pounces up close, but mostly ranged and ground attacks.
	-- Deflect its Rust Orb back into its face to crush its posture.
	rust_tiger = {
		name = "Rust Tiger",
		title = "Warden of the Cracked Bell",
		chapter = 0,
		kind = "Story",
		creature = "Tiger",
		maxHealth = 900,
		healthPerExtraPlayer = 0.6,
		maxPosture = 180,
		postureRegen = 6,
		postureBrokenSeconds = 3.5,
		walkSpeed = 18,
		deflectChance = 0.15,
		moves = {
			claw_swipe = { name = "Corroded Swipe", damage = 14, postureDamage = 16, windup = 0.5, active = 0.15, recovery = 0.55, range = 14, arcDegrees = 120, weight = 3, cooldown = 0, pose = "Swipe", animationId = PLACEHOLDER_ANIM },
			pounce = { name = "Iron Pounce", damage = 24, postureDamage = 26, windup = 0.75, active = 0.35, recovery = 0.9, range = 34, minRange = 14, arcDegrees = 50, weight = 2, cooldown = 6, perilous = true, perilousKind = "Pierce", pose = "Pounce", animationId = PLACEHOLDER_ANIM },
			tail_sweep = { name = "Chain-Tail Sweep", damage = 18, postureDamage = 10, windup = 0.65, active = 0.25, recovery = 0.6, range = 15, arcDegrees = 360, weight = 2, cooldown = 7, perilous = true, perilousKind = "Sweep", pose = "Spin", animationId = PLACEHOLDER_ANIM },
			rust_orb = { name = "Rust Orb", kind = "Projectile", damage = 22, postureDamage = 24, windup = 0.9, active = 0.2, recovery = 0.8, range = 70, arcDegrees = 360, weight = 3, cooldown = 5, speed = 42, radius = 2.2, deflectable = true, reflectDamage = 90, reflectPosture = 80, color = { 255, 120, 40 }, pose = "Spit", animationId = PLACEHOLDER_ANIM },
			shard_volley = { name = "Shard Volley", kind = "Volley", damage = 12, postureDamage = 10, windup = 0.7, active = 0.2, recovery = 0.8, range = 60, minRange = 10, arcDegrees = 360, weight = 2, cooldown = 8, speed = 75, count = 5, spread = 60, radius = 1.2, color = { 230, 170, 110 }, pose = "Spit", animationId = PLACEHOLDER_ANIM },
			quake_ring = { name = "Rusting Quake", kind = "Wave", damage = 20, postureDamage = 14, windup = 1.0, active = 0.3, recovery = 1.0, range = 50, arcDegrees = 360, weight = 2, cooldown = 9, speed = 34, radius = 60, color = { 255, 140, 60 }, pose = "Rear", animationId = PLACEHOLDER_ANIM },
			rust_rain = { name = "Rust Rain", kind = "Rain", damage = 26, postureDamage = 10, windup = 0.9, active = 0.3, recovery = 0.9, range = 70, arcDegrees = 360, weight = 2, cooldown = 11, count = 7, radius = 7, delay = 1.2, color = { 255, 90, 40 }, pose = "Roar", animationId = PLACEHOLDER_ANIM },
			rust_roar = { name = "Rust Roar", damage = 10, postureDamage = 30, windup = 1.0, active = 0.4, recovery = 1.0, range = 18, arcDegrees = 360, weight = 1, cooldown = 14, pose = "Roar", animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "claw_swipe", "pounce", "tail_sweep", "rust_orb", "quake_ring" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.5, moves = { "claw_swipe", "pounce", "tail_sweep", "rust_orb", "quake_ring", "shard_volley", "rust_rain", "rust_roar" }, speedMultiplier = 1.2, enrage = true, transitionSeconds = 2.5 },
		},
		idleBetweenMoves = 0.7,
		rewards = { ember = 300, xp = 400, jadeFirstClear = 25 },
		modelId = 0, -- TODO(Studio/Agent C): sculpted Rust Tiger model
		look = { skin = { 235, 215, 180 }, body = { 205, 110, 45 }, legs = { 60, 40, 30 }, accent = { 30, 22, 20 }, glow = { 255, 120, 40 }, scale = 1.5 },
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
			ash_needles = { name = "Ash Needles", kind = "Volley", damage = 10, postureDamage = 12, windup = 0.55, active = 0.15, recovery = 0.6, range = 55, minRange = 8, arcDegrees = 360, weight = 2, cooldown = 7, speed = 85, count = 5, spread = 40, radius = 1.2, color = { 255, 90, 70 }, animationId = PLACEHOLDER_ANIM },
			cinder_orb = { name = "Cinder Pearl", kind = "Projectile", damage = 18, postureDamage = 22, windup = 0.8, active = 0.2, recovery = 0.7, range = 60, arcDegrees = 360, weight = 2, cooldown = 6, speed = 46, radius = 2, deflectable = true, reflectDamage = 120, reflectPosture = 70, color = { 255, 120, 90 }, animationId = PLACEHOLDER_ANIM },
			quick_cut = { name = "Ash Feather Cut", damage = 12, postureDamage = 18, windup = 0.35, active = 0.12, recovery = 0.4, range = 9, arcDegrees = 100, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			crane_flurry = { name = "Crane Flurry", damage = 8, postureDamage = 14, windup = 0.45, active = 0.8, recovery = 0.6, range = 9, arcDegrees = 100, weight = 2, cooldown = 5, hits = 5, animationId = PLACEHOLDER_ANIM },
			gate_thrust = { name = "Gate-Piercing Thrust", damage = 30, postureDamage = 30, windup = 0.7, active = 0.25, recovery = 0.8, range = 22, minRange = 6, arcDegrees = 30, weight = 2, cooldown = 6, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
			low_reap = { name = "Low Reaping Arc", damage = 24, postureDamage = 12, windup = 0.6, active = 0.2, recovery = 0.7, range = 11, arcDegrees = 220, weight = 1, cooldown = 7, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
			ash_throw = { name = "Ash-Choked Throw", damage = 36, postureDamage = 0, windup = 0.8, active = 0.25, recovery = 1.0, range = 8, arcDegrees = 60, weight = 1, cooldown = 9, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
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
			bell_orb = { name = "Tolling Orb", kind = "Projectile", damage = 30, postureDamage = 30, windup = 0.9, active = 0.2, recovery = 0.8, range = 70, arcDegrees = 360, weight = 3, cooldown = 6, speed = 40, radius = 2.4, deflectable = true, reflectDamage = 220, reflectPosture = 90, color = { 255, 210, 120 }, animationId = PLACEHOLDER_ANIM },
			toll_wave = { name = "Silent Toll", kind = "Wave", damage = 34, postureDamage = 20, windup = 1.1, active = 0.3, recovery = 1.0, range = 50, arcDegrees = 360, weight = 2, cooldown = 9, speed = 32, radius = 55, color = { 255, 220, 150 }, animationId = PLACEHOLDER_ANIM },
			bell_rain = { name = "Falling Bells", kind = "Rain", damage = 40, postureDamage = 15, windup = 1.0, active = 0.3, recovery = 1.0, range = 70, arcDegrees = 360, weight = 1, cooldown = 13, count = 6, radius = 8, delay = 1.2, color = { 255, 200, 110 }, animationId = PLACEHOLDER_ANIM },
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
			toll_wave = { name = "Toll Wave", damage = 18, postureDamage = 45, windup = 1.0, active = 0.4, recovery = 1.0, range = 32, arcDegrees = 360, weight = 1, cooldown = 14, animationId = PLACEHOLDER_ANIM },
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
