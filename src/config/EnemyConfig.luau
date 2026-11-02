--!strict
-- EnemyConfig: regular enemies. Owner: Agent C (Warden).
-- TODO(Studio/Agent C): modelId/animation ids are placeholders until rigs are built.

export type EnemyAttack = {
	name: string,
	damage: number,
	postureDamage: number,
	windup: number,
	active: number,
	recovery: number,
	range: number,
	arcDegrees: number,
	weight: number, -- chance weight when choosing an attack in range
	perilous: boolean?,
	perilousKind: ("Pierce" | "Sweep" | "Grasp")?, -- answer: dash in / jump / dodge (CombatConfig)
	lunge: number?, -- studs the enemy surges forward during the active frames
	style: string?, -- AnimationConfig style for the body (default: alternating slashes)
	-- Ranged / ground attacks through HazardService instead of a melee arc:
	kind: ("Melee" | "Projectile" | "Volley" | "Wave" | "Rain")?,
	delay: number?, -- Rain: seconds before the eruptions
	radius: number?, -- Rain: eruption radius
	pose: string?, -- creature pose (CreatureAnimator) for creature enemies
	special: boolean?, -- signature move: gold name callout + flash + flashier VFX
	lingerHits: number?, -- melee: extra slash hits during the active window (afterimage flurries)
	visual: string?, -- projectile look: "Crescent" | "Rocket" | nil (orb)
	speed: number?,
	count: number?,
	spread: number?,
	deflectable: boolean?,
	color: { number }?,
	animationId: string,
}

-- Procedural rig look (RigBuilder) used until a Studio rig exists in ServerStorage.
-- Colors are {r, g, b}; weapon is a WeaponConfig id held in the right hand.
export type RigLook = {
	skin: { number },
	body: { number },
	legs: { number },
	headwear: ("Hood" | "Helm" | "Horns" | "Lantern" | "Sack" | "Hair" | "Bell" | "Visor" | "Crest" | "Laurel")?,
	accent: { number }?,
	glow: { number }?,
	weapon: string?,
	scale: number,
}

export type EnemyDef = {
	name: string,
	chapter: number,
	maxHealth: number,
	maxPosture: number,
	postureRegen: number,
	walkSpeed: number,
	aggroRange: number,
	leashRange: number, -- returns home beyond this distance from spawn
	preferredRange: number, -- circles at this distance while waiting for an attack token
	attackCooldown: number,
	attacks: { [string]: EnemyAttack },
	emberReward: number,
	xpReward: number,
	modelId: number,
	training: boolean?, -- training dummy: never attacks, gives no rewards or quest progress
	combos: { { string } }?, -- attack strings performed back-to-back
	comboChance: number?, -- chance to use a combo instead of a single attack
	flinch: boolean?, -- hits outside its active frames interrupt it (light enemies)
	guardChance: number?, -- chance to raise its guard after being hit (blocks until posture breaks)
	deflectChance: number?, -- while guarding: chance to deflect a strike outright and counter
	look: RigLook?,
	elite: boolean?, -- super enemy: gold name + aura, much tougher, bigger rewards
	creature: string?, -- part-built body instead of a humanoid rig (World/CreatureBuilder): "Drone" | "Tiger"
}

local EnemyConfig = {}

-- AI scheduler / director ------------------------------------------------------------------
EnemyConfig.AITickRate = 10 -- Hz, batched across all enemies
EnemyConfig.MaxEnemiesPerTickSlice = 40 -- spread work over frames if more are alive
EnemyConfig.AttackTokensPerPlayer = 3 -- at most N enemies attack the same player at once
EnemyConfig.AttackTokenDuration = 2.5 -- seconds a token is held before it must be returned
EnemyConfig.AttackTokenCooldown = 0.6 -- seconds before a returned token can be re-granted
EnemyConfig.StateReplicationRate = 10 -- Hz, batched EnemyState remote
EnemyConfig.DespawnAfterDeath = 4
EnemyConfig.DefaultRespawnSeconds = 20
EnemyConfig.DefaultSpawnScatter = 22 -- studs; enemies spread out around their spawn (attribute Scatter overrides)
EnemyConfig.PostureBrokenSeconds = 2.5
EnemyConfig.DefaultStep = 2.5 -- studs every enemy strike steps forward
EnemyConfig.HitKnockback = 10 -- studs/s pushback when an enemy hit lands
EnemyConfig.PerilousKnockback = 38
-- Challenge: enemies hit harder than their listed numbers, attack sooner, and deflect you.
EnemyConfig.DamageMultiplier = 1.35 -- applied to every enemy hit on a player
EnemyConfig.PostureMultiplier = 1.25
EnemyConfig.CooldownMultiplier = 0.8 -- shorter pauses between attacks
EnemyConfig.ExtraComboChance = 0.15 -- strings of attacks more often
-- Sekiro-style deflects: any aware enemy that isn't mid-swing may deflect your strike. Every
-- hit you land in a quick string makes the next deflect likelier - stop mashing, read them.
EnemyConfig.BaseDeflect = 0.18
EnemyConfig.StringDeflectStep = 0.22 -- added per recent hit
EnemyConfig.StringWindow = 1.6 -- seconds
EnemyConfig.MaxDeflect = 0.85
EnemyConfig.ComboGap = 0.12 -- seconds between strikes in a combo (instead of full recovery)
EnemyConfig.FlinchSeconds = 0.35
EnemyConfig.FlinchCooldown = 1.4 -- an enemy cannot be flinch-locked
EnemyConfig.GuardSeconds = 1.4
EnemyConfig.GuardDamageMultiplier = 0.2 -- health damage taken through guard
EnemyConfig.GuardPostureMultiplier = 1.4 -- guard soaks more posture (break it!)
-- Stealth (Shadow Strike): unaware enemies only see you within viewDegrees in front of them,
-- or within closeRange. A strike on an unaware enemy is an instant Shadow Strike.
EnemyConfig.Stealth = { viewDegrees = 120, closeRange = 7 }
EnemyConfig.SpawnFolderName = "EnemySpawns" -- TODO(Studio/Agent D): Workspace folder of spawn Parts
EnemyConfig.TemplateFolderName = "Enemies" -- TODO(Studio/Agent C): ServerStorage folder of rigs

local PLACEHOLDER_ANIM = "rbxassetid://0"

EnemyConfig.Enemies = {
	training_dummy = {
		name = "Training Dummy",
		chapter = 0,
		maxHealth = 400,
		maxPosture = 120,
		postureRegen = 20,
		walkSpeed = 0,
		aggroRange = 0,
		leashRange = 0,
		preferredRange = 0,
		attackCooldown = 99,
		attacks = {},
		emberReward = 0,
		xpReward = 0,
		modelId = 0,
		look = { skin = { 205, 180, 120 }, body = { 170, 140, 90 }, legs = { 120, 95, 60 }, headwear = "Sack", scale = 1 },
		training = true,
	},
	-- Hub training yard: practise deflects and every perilous answer. Barely hurts, no rewards.
	sparring_master = {
		name = "Sparring Master",
		chapter = 0,
		maxHealth = 600,
		maxPosture = 60,
		postureRegen = 10,
		walkSpeed = 8,
		aggroRange = 13,
		leashRange = 16,
		preferredRange = 7,
		attackCooldown = 1.8,
		attacks = {
			tap = { name = "Lesson: Deflect", style = "SlashRight", damage = 1, postureDamage = 12, windup = 0.6, active = 0.12, recovery = 0.5, range = 8, arcDegrees = 90, weight = 4, animationId = PLACEHOLDER_ANIM },
			thrust = { name = "Lesson: Pierce", style = "Thrust", damage = 2, postureDamage = 10, windup = 0.9, active = 0.2, recovery = 0.8, range = 11, arcDegrees = 30, weight = 1, lunge = 4, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
			sweep = { name = "Lesson: Sweep", damage = 2, postureDamage = 6, windup = 0.9, active = 0.2, recovery = 0.8, range = 10, arcDegrees = 220, weight = 1, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
			grab = { name = "Lesson: Grasp", damage = 2, postureDamage = 0, windup = 0.9, active = 0.2, recovery = 0.8, range = 7, arcDegrees = 60, weight = 1, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 0,
		xpReward = 0,
		combos = { { "tap", "tap", "tap" }, { "tap", "thrust" }, { "tap", "sweep" } },
		comboChance = 0.5,
		guardChance = 0.3,
		deflectChance = 0.5,
		modelId = 0,
		training = true,
		look = { skin = { 215, 185, 150 }, body = { 235, 225, 205 }, legs = { 60, 50, 45 }, headwear = "Hair", accent = { 140, 40, 35 }, weapon = "staff_pilgrim", scale = 1.05 },
	},
	rustbound_bandit = {
		name = "Rustbound Bandit",
		chapter = 0,
		maxHealth = 60,
		maxPosture = 40,
		postureRegen = 8,
		walkSpeed = 13,
		aggroRange = 40,
		leashRange = 90,
		preferredRange = 10,
		attackCooldown = 1.6,
		attacks = {
			slash = { name = "Rusted Slash", style = "SlashRight", damage = 8, postureDamage = 10, windup = 0.45, active = 0.15, recovery = 0.5, range = 7, arcDegrees = 90, weight = 3, animationId = PLACEHOLDER_ANIM },
			lunge = { name = "Desperate Lunge", style = "Thrust", damage = 12, postureDamage = 14, windup = 0.7, active = 0.2, recovery = 0.8, range = 12, arcDegrees = 40, weight = 1, lunge = 7, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 6,
		xpReward = 10,
		combos = { { "slash", "slash" }, { "slash", "lunge" } },
		comboChance = 0.4,
		flinch = true,
		guardChance = 0.25,
		deflectChance = 0.5,
		modelId = 0,
		look = { skin = { 200, 160, 130 }, body = { 120, 60, 40 }, legs = { 60, 50, 45 }, headwear = "Hood", accent = { 150, 80, 40 }, weapon = "dao_rustcutter", scale = 1 },
	},
	lantern_ghoul = {
		name = "Lantern Ghoul",
		chapter = 0,
		maxHealth = 90,
		maxPosture = 70,
		postureRegen = 5,
		walkSpeed = 9,
		aggroRange = 32,
		leashRange = 70,
		preferredRange = 6,
		attackCooldown = 2.2,
		attacks = {
			claw = { name = "Wick Claw", style = "SlashLeft", damage = 10, postureDamage = 8, windup = 0.55, active = 0.15, recovery = 0.6, range = 6, arcDegrees = 100, weight = 3, animationId = PLACEHOLDER_ANIM },
			grasp = { name = "Smothering Grasp", damage = 18, postureDamage = 0, windup = 0.9, active = 0.25, recovery = 1.0, range = 6, arcDegrees = 60, weight = 1, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 9,
		xpReward = 14,
		flinch = true,
		modelId = 0,
		look = { skin = { 120, 140, 120 }, body = { 50, 55, 50 }, legs = { 40, 40, 40 }, headwear = "Lantern", accent = { 255, 190, 90 }, glow = { 255, 170, 70 }, scale = 1.1 },
	},
	-- Chapter 1: Rustwood Pass
	rustwood_stalker = {
		name = "Rustwood Stalker",
		chapter = 1,
		maxHealth = 260,
		maxPosture = 90,
		postureRegen = 10,
		walkSpeed = 17,
		aggroRange = 45,
		leashRange = 100,
		preferredRange = 12,
		attackCooldown = 1.3,
		attacks = {
			hook = { name = "Bark-Hook Slash", style = "SlashLeft", damage = 22, postureDamage = 16, windup = 0.35, active = 0.12, recovery = 0.45, range = 8, arcDegrees = 100, weight = 3, animationId = PLACEHOLDER_ANIM },
			leap = { name = "Canopy Drop", style = "AirSlam", damage = 30, postureDamage = 22, windup = 0.6, active = 0.2, recovery = 0.7, range = 16, arcDegrees = 45, weight = 1, lunge = 10, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 30,
		xpReward = 45,
		combos = { { "hook", "hook", "leap" } },
		comboChance = 0.35,
		flinch = true,
		guardChance = 0.2,
		deflectChance = 0.6,
		modelId = 0,
		look = { skin = { 150, 120, 90 }, body = { 70, 85, 50 }, legs = { 60, 50, 35 }, headwear = "Hood", accent = { 90, 110, 60 }, weapon = "spear_reedline", scale = 1.05 },
	},
	rust_eaten_sentinel = {
		name = "Rust-Eaten Sentinel",
		chapter = 1,
		maxHealth = 520,
		maxPosture = 180,
		postureRegen = 4,
		walkSpeed = 8,
		aggroRange = 30,
		leashRange = 60,
		preferredRange = 7,
		attackCooldown = 2.4,
		attacks = {
			hammer = { name = "Seized Hammer", style = "Overhead", damage = 34, postureDamage = 30, windup = 0.8, active = 0.2, recovery = 0.9, range = 8, arcDegrees = 80, weight = 3, animationId = PLACEHOLDER_ANIM },
			quake = { name = "Groaning Quake", damage = 26, postureDamage = 10, windup = 1.1, active = 0.3, recovery = 1.1, range = 11, arcDegrees = 360, weight = 1, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 55,
		xpReward = 80,
		combos = { { "hammer", "hammer" } },
		comboChance = 0.3,
		guardChance = 0.4,
		deflectChance = 0.7,
		modelId = 0,
		look = { skin = { 120, 90, 70 }, body = { 110, 70, 45 }, legs = { 90, 60, 40 }, headwear = "Helm", accent = { 150, 85, 45 }, weapon = "staff_pilgrim", scale = 1.45 },
	},
	-- Duelists: few hit points, iron posture, deflect strings and punish with thrusts.
	ashen_duelist = {
		name = "Ashen Duelist",
		chapter = 0,
		maxHealth = 140,
		maxPosture = 85,
		postureRegen = 14,
		walkSpeed = 15,
		aggroRange = 38,
		leashRange = 80,
		preferredRange = 9,
		attackCooldown = 1.1,
		attacks = {
			cut = { name = "Cinder Cut", style = "SlashRight", damage = 12, postureDamage = 14, windup = 0.32, active = 0.12, recovery = 0.4, range = 7, arcDegrees = 90, weight = 3, animationId = PLACEHOLDER_ANIM },
			rising = { name = "Rising Ash", style = "SlashLeft", damage = 14, postureDamage = 18, windup = 0.45, active = 0.15, recovery = 0.5, range = 7, arcDegrees = 70, weight = 2, animationId = PLACEHOLDER_ANIM },
			needle = { name = "Ash Needle", style = "Thrust", damage = 22, postureDamage = 20, windup = 0.75, active = 0.2, recovery = 0.7, range = 13, arcDegrees = 30, weight = 1, lunge = 8, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 18,
		xpReward = 26,
		combos = { { "cut", "cut", "rising" }, { "cut", "rising", "needle" }, { "rising", "cut" } },
		comboChance = 0.55,
		guardChance = 0.55,
		deflectChance = 0.75,
		modelId = 0,
		look = { skin = { 210, 175, 150 }, body = { 60, 55, 60 }, legs = { 40, 38, 42 }, headwear = "Hair", accent = { 200, 70, 50 }, weapon = "jian_moonwater", scale = 1 },
	},
	-- Brutes: slow, huge posture, sweeping and grabbing. Jump the sweeps, dash from the grabs.
	mire_brute = {
		name = "Mire Brute",
		chapter = 0,
		maxHealth = 420,
		maxPosture = 160,
		postureRegen = 5,
		walkSpeed = 9,
		aggroRange = 30,
		leashRange = 60,
		preferredRange = 8,
		attackCooldown = 2.2,
		attacks = {
			smash = { name = "Mire Smash", style = "Overhead", damage = 28, postureDamage = 30, windup = 0.85, active = 0.2, recovery = 0.9, range = 9, arcDegrees = 80, weight = 3, animationId = PLACEHOLDER_ANIM },
			sweep = { name = "Root Sweep", damage = 24, postureDamage = 10, windup = 0.8, active = 0.25, recovery = 0.9, range = 11, arcDegrees = 200, weight = 2, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
			grab = { name = "Bog Grip", damage = 34, postureDamage = 0, windup = 0.9, active = 0.25, recovery = 1.1, range = 7, arcDegrees = 60, weight = 1, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 40,
		xpReward = 55,
		combos = { { "smash", "sweep" } },
		comboChance = 0.3,
		guardChance = 0.15,
		deflectChance = 0.3,
		modelId = 0,
		look = { skin = { 110, 120, 90 }, body = { 70, 80, 55 }, legs = { 55, 60, 40 }, headwear = "Horns", accent = { 120, 160, 90 }, glow = { 150, 255, 120 }, weapon = "gb_gatebreaker", scale = 1.55 },
	},
	-- Ashen Valley: more variety ------------------------------------------------------------
	-- Rust Hound: a lean rusted beast. Fast bites, a pounce you dash into.
	rust_hound = {
		name = "Rust Hound",
		chapter = 0,
		maxHealth = 120,
		maxPosture = 60,
		postureRegen = 10,
		walkSpeed = 22,
		aggroRange = 45,
		leashRange = 100,
		preferredRange = 9,
		attackCooldown = 1.0,
		attacks = {
			bite = { name = "Rust Bite", pose = "Swipe", damage = 12, postureDamage = 12, windup = 0.35, active = 0.12, recovery = 0.4, range = 7, arcDegrees = 90, weight = 3, animationId = PLACEHOLDER_ANIM },
			pounce = { name = "Lunging Pounce", pose = "Pounce", damage = 18, postureDamage = 18, windup = 0.6, active = 0.25, recovery = 0.6, range = 18, arcDegrees = 40, weight = 2, lunge = 12, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 14,
		xpReward = 20,
		combos = { { "bite", "bite" }, { "bite", "pounce" } },
		comboChance = 0.4,
		flinch = true,
		modelId = 0,
		creature = "Tiger",
		look = { skin = { 200, 170, 140 }, body = { 150, 80, 50 }, legs = { 60, 40, 30 }, accent = { 60, 35, 25 }, glow = { 255, 140, 60 }, scale = 0.6 },
	},
	-- Kite Archer: shoots from range; arrows can be deflected back.
	kite_archer = {
		name = "Kite Archer",
		chapter = 0,
		maxHealth = 90,
		maxPosture = 50,
		postureRegen = 8,
		walkSpeed = 14,
		aggroRange = 60,
		leashRange = 90,
		preferredRange = 26,
		attackCooldown = 1.4,
		attacks = {
			arrow = { name = "Rusted Arrow", style = "CastPush", kind = "Projectile", speed = 85, damage = 12, postureDamage = 10, windup = 0.6, active = 0.1, recovery = 0.4, range = 55, arcDegrees = 360, weight = 3, color = { 220, 190, 140 }, animationId = PLACEHOLDER_ANIM },
			spread = { name = "Arrow Spread", style = "CastPush", kind = "Volley", count = 3, spread = 24, speed = 80, damage = 9, postureDamage = 8, windup = 0.8, active = 0.1, recovery = 0.6, range = 50, arcDegrees = 360, weight = 1, color = { 220, 190, 140 }, animationId = PLACEHOLDER_ANIM },
			kick = { name = "Back Kick", style = "SlashRight", damage = 9, postureDamage = 12, windup = 0.4, active = 0.15, recovery = 0.5, range = 6, arcDegrees = 90, weight = 1, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 12,
		xpReward = 18,
		flinch = true,
		modelId = 0,
		look = { skin = { 205, 170, 140 }, body = { 90, 100, 70 }, legs = { 60, 55, 45 }, headwear = "Helm", accent = { 120, 110, 80 }, weapon = "fan_paper_crane", scale = 1 },
	},
	-- Ash Monk: staff and palms. Guards a lot; his palm strike sends a short shockwave.
	ash_monk = {
		name = "Ash Monk",
		chapter = 0,
		maxHealth = 240,
		maxPosture = 140,
		postureRegen = 12,
		walkSpeed = 13,
		aggroRange = 36,
		leashRange = 80,
		preferredRange = 8,
		attackCooldown = 1.3,
		attacks = {
			staff = { name = "Staff Sweep", style = "SlashRight", damage = 14, postureDamage = 18, windup = 0.45, active = 0.15, recovery = 0.5, range = 10, arcDegrees = 140, weight = 3, animationId = PLACEHOLDER_ANIM },
			jab = { name = "Staff Thrust", style = "Thrust", damage = 16, postureDamage = 20, windup = 0.4, active = 0.12, recovery = 0.45, range = 11, arcDegrees = 40, weight = 2, animationId = PLACEHOLDER_ANIM },
			palm = { name = "Ash Palm", style = "CastPush", kind = "Wave", speed = 30, damage = 16, postureDamage = 20, windup = 0.8, active = 0.2, recovery = 0.8, range = 20, arcDegrees = 360, weight = 1, color = { 220, 210, 200 }, animationId = PLACEHOLDER_ANIM },
			sweep = { name = "Low Staff", style = "Sweep", damage = 18, postureDamage = 12, windup = 0.6, active = 0.2, recovery = 0.7, range = 11, arcDegrees = 200, weight = 1, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 22,
		xpReward = 32,
		combos = { { "staff", "jab" }, { "jab", "jab", "staff" }, { "staff", "sweep" } },
		comboChance = 0.45,
		guardChance = 0.55,
		deflectChance = 0.55,
		modelId = 0,
		look = { skin = { 210, 180, 150 }, body = { 200, 110, 50 }, legs = { 150, 80, 40 }, headwear = "Sack", accent = { 120, 60, 30 }, weapon = "staff_pilgrim", scale = 1.05 },
	},
	-- Shadow Shinobi: fragile, very fast. Shuriken fans and a dashing cut.
	shadow_shinobi = {
		name = "Shadow Shinobi",
		chapter = 0,
		maxHealth = 100,
		maxPosture = 55,
		postureRegen = 10,
		walkSpeed = 23,
		aggroRange = 50,
		leashRange = 100,
		preferredRange = 14,
		attackCooldown = 0.9,
		attacks = {
			cut = { name = "Shadow Cut", style = "SlashRight", damage = 13, postureDamage = 12, windup = 0.28, active = 0.1, recovery = 0.35, range = 7, arcDegrees = 100, weight = 3, animationId = PLACEHOLDER_ANIM },
			shuriken = { name = "Shuriken Fan", style = "CastPush", kind = "Volley", count = 3, spread = 30, speed = 110, damage = 8, postureDamage = 8, windup = 0.45, active = 0.1, recovery = 0.4, range = 45, arcDegrees = 360, weight = 2, color = { 200, 200, 220 }, animationId = PLACEHOLDER_ANIM },
			dash = { name = "Flash Step Cut", style = "DashForward", damage = 20, postureDamage = 18, windup = 0.55, active = 0.2, recovery = 0.6, range = 18, arcDegrees = 40, weight = 1, lunge = 14, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 16,
		xpReward = 24,
		combos = { { "cut", "cut", "cut" }, { "shuriken", "dash" } },
		comboChance = 0.5,
		flinch = true,
		deflectChance = 0.3,
		modelId = 0,
		look = { skin = { 190, 160, 140 }, body = { 25, 25, 30 }, legs = { 20, 20, 25 }, headwear = "Hood", accent = { 30, 30, 36 }, weapon = "dao_rustcutter", scale = 0.95 },
	},
	-- Lantern Wisp: a floating paper lantern that spits fire.
	lantern_wisp = {
		name = "Lantern Wisp",
		chapter = 0,
		maxHealth = 70,
		maxPosture = 40,
		postureRegen = 8,
		walkSpeed = 12,
		aggroRange = 50,
		leashRange = 80,
		preferredRange = 22,
		attackCooldown = 1.6,
		attacks = {
			ember = { name = "Ember Spit", kind = "Projectile", speed = 55, damage = 10, postureDamage = 8, windup = 0.6, active = 0.1, recovery = 0.4, range = 45, arcDegrees = 360, weight = 3, color = { 255, 150, 60 }, animationId = PLACEHOLDER_ANIM },
			bloom = { name = "Fire Bloom", kind = "Rain", count = 3, radius = 6, delay = 1, damage = 14, postureDamage = 8, windup = 0.7, active = 0.1, recovery = 0.6, range = 45, arcDegrees = 360, weight = 1, color = { 255, 120, 40 }, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 10,
		xpReward = 15,
		flinch = true,
		modelId = 0,
		creature = "Drone",
		look = { skin = { 0, 0, 0 }, body = { 230, 210, 170 }, legs = { 0, 0, 0 }, accent = { 190, 50, 40 }, glow = { 255, 160, 60 }, scale = 0.85 },
	},
	-- Spear Ronin: long reach, thrust strings, a low sweep.
	spear_ronin = {
		name = "Spear Ronin",
		chapter = 0,
		maxHealth = 200,
		maxPosture = 100,
		postureRegen = 11,
		walkSpeed = 15,
		aggroRange = 40,
		leashRange = 90,
		preferredRange = 12,
		attackCooldown = 1.2,
		attacks = {
			thrust = { name = "Long Thrust", style = "Thrust", damage = 16, postureDamage = 16, windup = 0.4, active = 0.12, recovery = 0.45, range = 14, arcDegrees = 30, weight = 3, animationId = PLACEHOLDER_ANIM },
			sweep = { name = "Shaft Sweep", style = "Sweep", damage = 18, postureDamage = 12, windup = 0.6, active = 0.2, recovery = 0.6, range = 14, arcDegrees = 220, weight = 1, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
			spin = { name = "Whirling Spear", style = "Spin", damage = 14, postureDamage = 16, windup = 0.55, active = 0.25, recovery = 0.6, range = 12, arcDegrees = 360, weight = 1, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 20,
		xpReward = 30,
		combos = { { "thrust", "thrust", "thrust" }, { "thrust", "sweep" }, { "spin", "thrust" } },
		comboChance = 0.5,
		guardChance = 0.3,
		deflectChance = 0.4,
		modelId = 0,
		look = { skin = { 210, 180, 150 }, body = { 60, 60, 90 }, legs = { 40, 40, 60 }, headwear = "Helm", accent = { 140, 140, 160 }, weapon = "spear_reedline", scale = 1.05 },
	},
	-- ELITES: super enemies. Each guards a zone and hits like a mini boss.
	oni_captain = {
		name = "Crimson Oni Captain",
		chapter = 0,
		elite = true,
		maxHealth = 1600,
		maxPosture = 280,
		postureRegen = 8,
		walkSpeed = 14,
		aggroRange = 40,
		leashRange = 70,
		preferredRange = 9,
		attackCooldown = 1.4,
		attacks = {
			rampage = { name = "Crimson Rampage", style = "Spin", special = true, damage = 14, postureDamage = 14, windup = 0.7, active = 1.0, recovery = 0.9, range = 13, arcDegrees = 200, weight = 2, lingerHits = 4, animationId = PLACEHOLDER_ANIM },
			hellfire = { name = "Hellfire Eruption", style = "CastSky", special = true, kind = "Rain", count = 6, radius = 7, delay = 1, damage = 30, postureDamage = 14, windup = 0.9, active = 0.2, recovery = 0.9, range = 50, arcDegrees = 360, weight = 2, color = { 255, 70, 40 }, animationId = PLACEHOLDER_ANIM },
			cleave = { name = "Crimson Cleave", style = "Overhead", damage = 34, postureDamage = 36, windup = 0.7, active = 0.2, recovery = 0.8, range = 12, arcDegrees = 100, weight = 3, animationId = PLACEHOLDER_ANIM },
			sweep = { name = "Wide Cut", style = "SlashRight", damage = 26, postureDamage = 26, windup = 0.55, active = 0.2, recovery = 0.6, range = 12, arcDegrees = 160, weight = 3, animationId = PLACEHOLDER_ANIM },
			stomp = { name = "War Stomp", special = true, style = "CastSky", kind = "Wave", speed = 32, damage = 24, postureDamage = 16, windup = 0.9, active = 0.2, recovery = 0.9, range = 40, arcDegrees = 360, weight = 2, color = { 255, 80, 60 }, animationId = PLACEHOLDER_ANIM },
			charge = { name = "Bull Charge", special = true, style = "Thrust", damage = 38, postureDamage = 34, windup = 0.8, active = 0.3, recovery = 0.9, range = 24, arcDegrees = 30, weight = 1, lunge = 18, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
			grab = { name = "Captain's Grip", style = "Grasp", damage = 44, postureDamage = 0, windup = 0.85, active = 0.25, recovery = 1, range = 9, arcDegrees = 60, weight = 1, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 400,
		xpReward = 500,
		combos = { { "sweep", "sweep", "cleave" }, { "cleave", "stomp" }, { "sweep", "charge" } , { "rampage", "cleave" } },
		comboChance = 0.5,
		guardChance = 0.3,
		deflectChance = 0.45,
		modelId = 0,
		look = { skin = { 170, 50, 40 }, body = { 90, 30, 30 }, legs = { 50, 25, 25 }, headwear = "Horns", accent = { 235, 225, 205 }, glow = { 255, 80, 40 }, weapon = "gb_ashen_colossus", scale = 2 },
	},
	gravelord = {
		name = "Gravelord Ishiki",
		chapter = 0,
		elite = true,
		maxHealth = 1200,
		maxPosture = 200,
		postureRegen = 10,
		walkSpeed = 11,
		aggroRange = 50,
		leashRange = 70,
		preferredRange = 18,
		attackCooldown = 1.5,
		attacks = {
			procession = { name = "Spirit Procession", style = "CastPush", special = true, kind = "Volley", count = 8, spread = 90, speed = 55, damage = 12, postureDamage = 10, windup = 1.0, active = 0.1, recovery = 0.8, range = 55, arcDegrees = 360, weight = 2, color = { 140, 220, 255 }, animationId = PLACEHOLDER_ANIM },
			grave_tide = { name = "Grave Tide", style = "CastSky", special = true, kind = "Wave", speed = 30, damage = 24, postureDamage = 18, windup = 0.9, active = 0.2, recovery = 0.9, range = 45, arcDegrees = 360, weight = 2, color = { 120, 200, 255 }, animationId = PLACEHOLDER_ANIM },
			soul_orb = { name = "Soul Lantern", special = true, style = "CastPush", kind = "Projectile", deflectable = true, speed = 40, damage = 26, postureDamage = 26, windup = 0.8, active = 0.1, recovery = 0.6, range = 60, arcDegrees = 360, weight = 3, color = { 140, 220, 255 }, animationId = PLACEHOLDER_ANIM },
			wisps = { name = "Wisp Fan", style = "CastPush", kind = "Volley", count = 5, spread = 50, speed = 60, damage = 12, postureDamage = 10, windup = 0.8, active = 0.1, recovery = 0.7, range = 55, arcDegrees = 360, weight = 2, color = { 140, 220, 255 }, animationId = PLACEHOLDER_ANIM },
			graves = { name = "Graves Open", style = "CastSky", kind = "Rain", count = 5, radius = 7, delay = 1.1, damage = 28, postureDamage = 12, windup = 0.9, active = 0.2, recovery = 0.9, range = 60, arcDegrees = 360, weight = 2, color = { 120, 200, 255 }, animationId = PLACEHOLDER_ANIM },
			scythe = { name = "Grave Scythe", style = "Sweep", damage = 28, postureDamage = 18, windup = 0.65, active = 0.2, recovery = 0.7, range = 12, arcDegrees = 240, weight = 2, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 380,
		xpReward = 480,
		combos = { { "soul_orb", "wisps" }, { "scythe", "graves" } , { "procession", "scythe" } },
		comboChance = 0.35,
		guardChance = 0.2,
		deflectChance = 0.3,
		modelId = 0,
		look = { skin = { 140, 160, 150 }, body = { 30, 35, 40 }, legs = { 25, 28, 30 }, headwear = "Lantern", accent = { 140, 220, 255 }, glow = { 140, 220, 255 }, weapon = "staff_bellringer", scale = 1.6 },
	},
	gorge_matriarch = {
		name = "Gorge Matriarch",
		chapter = 0,
		elite = true,
		maxHealth = 1400,
		maxPosture = 220,
		postureRegen = 9,
		walkSpeed = 20,
		aggroRange = 45,
		leashRange = 80,
		preferredRange = 12,
		attackCooldown = 1.3,
		attacks = {
			frenzy = { name = "Frenzied Mauling", pose = "Swipe", special = true, damage = 14, postureDamage = 14, windup = 0.6, active = 1.0, recovery = 0.8, range = 13, arcDegrees = 140, weight = 2, lingerHits = 5, animationId = PLACEHOLDER_ANIM },
			geyser = { name = "Rust Geyser", pose = "Roar", special = true, kind = "Rain", count = 5, radius = 7, delay = 1, damage = 28, postureDamage = 12, windup = 0.8, active = 0.2, recovery = 0.9, range = 45, arcDegrees = 360, weight = 1, color = { 255, 120, 50 }, animationId = PLACEHOLDER_ANIM },
			maul = { name = "Maul", pose = "Swipe", damage = 30, postureDamage = 28, windup = 0.5, active = 0.15, recovery = 0.6, range = 13, arcDegrees = 120, weight = 3, animationId = PLACEHOLDER_ANIM },
			pounce = { name = "Matriarch's Pounce", special = true, pose = "Pounce", damage = 36, postureDamage = 32, windup = 0.7, active = 0.3, recovery = 0.8, range = 28, arcDegrees = 40, weight = 2, lunge = 20, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
			tail = { name = "Tail Lash", pose = "Spin", damage = 24, postureDamage = 16, windup = 0.6, active = 0.25, recovery = 0.6, range = 14, arcDegrees = 360, weight = 2, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
			howl = { name = "Rusting Howl", special = true, pose = "Roar", kind = "Wave", speed = 34, damage = 20, postureDamage = 18, windup = 0.9, active = 0.3, recovery = 0.9, range = 40, arcDegrees = 360, weight = 1, color = { 255, 140, 60 }, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 420,
		xpReward = 520,
		combos = { { "maul", "maul", "tail" }, { "pounce", "maul" } , { "frenzy", "tail" } },
		comboChance = 0.45,
		flinch = false,
		deflectChance = 0.2,
		modelId = 0,
		creature = "Tiger",
		look = { skin = { 230, 210, 180 }, body = { 190, 90, 40 }, legs = { 60, 40, 30 }, accent = { 40, 25, 20 }, glow = { 255, 90, 40 }, scale = 1.3 },
	},
	masked_retainer = {
		name = "Masked Retainer Kurogiri",
		chapter = 0,
		elite = true,
		maxHealth = 1100,
		maxPosture = 180,
		postureRegen = 14,
		walkSpeed = 19,
		aggroRange = 45,
		leashRange = 80,
		preferredRange = 9,
		attackCooldown = 0.9,
		attacks = {
			mist_crescent = { name = "Mist Crescent", style = "SlashRight", special = true, kind = "Projectile", deflectable = true, visual = "Crescent", speed = 75, damage = 24, postureDamage = 26, windup = 0.55, active = 0.1, recovery = 0.5, range = 55, arcDegrees = 360, weight = 2, color = { 200, 200, 255 }, animationId = PLACEHOLDER_ANIM },
			afterimage = { name = "Afterimage Flurry", style = "Spin", special = true, damage = 12, postureDamage = 14, windup = 0.55, active = 1.0, recovery = 0.7, range = 11, arcDegrees = 160, weight = 2, lingerHits = 5, animationId = PLACEHOLDER_ANIM },
			thousand_mist = { name = "Thousand Mist Cuts", style = "CastSky", special = true, kind = "Rain", count = 7, radius = 6, delay = 0.9, damage = 22, postureDamage = 12, windup = 0.7, active = 0.2, recovery = 0.8, range = 50, arcDegrees = 360, weight = 1, color = { 220, 220, 255 }, animationId = PLACEHOLDER_ANIM },
			cut = { name = "Mist Cut", style = "SlashRight", damage = 20, postureDamage = 20, windup = 0.3, active = 0.12, recovery = 0.35, range = 9, arcDegrees = 110, weight = 3, animationId = PLACEHOLDER_ANIM },
			reverse = { name = "Returning Cut", style = "SlashLeft", damage = 20, postureDamage = 22, windup = 0.32, active = 0.12, recovery = 0.4, range = 9, arcDegrees = 110, weight = 2, animationId = PLACEHOLDER_ANIM },
			thrust = { name = "Mist Needle", special = true, style = "Thrust", damage = 34, postureDamage = 30, windup = 0.65, active = 0.2, recovery = 0.7, range = 18, arcDegrees = 30, weight = 1, lunge = 12, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
			shuriken = { name = "Mist Shuriken", style = "CastPush", kind = "Volley", count = 5, spread = 40, speed = 110, damage = 10, postureDamage = 10, windup = 0.5, active = 0.1, recovery = 0.4, range = 45, arcDegrees = 360, weight = 1, color = { 190, 190, 210 }, animationId = PLACEHOLDER_ANIM },
			low = { name = "Ground Mist", style = "Sweep", damage = 24, postureDamage = 14, windup = 0.5, active = 0.2, recovery = 0.6, range = 11, arcDegrees = 220, weight = 1, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 450,
		xpReward = 550,
		combos = { { "cut", "reverse", "cut", "thrust" }, { "cut", "cut", "low" }, { "shuriken", "thrust" } , { "afterimage", "thrust" } },
		comboChance = 0.65,
		guardChance = 0.5,
		deflectChance = 0.75,
		modelId = 0,
		look = { skin = { 230, 225, 220 }, body = { 40, 30, 50 }, legs = { 30, 25, 35 }, headwear = "Visor", accent = { 200, 60, 60 }, glow = { 255, 60, 60 }, weapon = "jian_ninth_bell", scale = 1.2 },
	},
	-- Neon Verge ---------------------------------------------------------------------------
	-- Cyber-samurai: fast katana strings, deflects a lot, a plasma thrust you must dash into.
	chrome_ronin = {
		name = "Chrome Ronin",
		chapter = 0,
		maxHealth = 220,
		maxPosture = 110,
		postureRegen = 14,
		walkSpeed = 17,
		aggroRange = 42,
		leashRange = 90,
		preferredRange = 9,
		attackCooldown = 1.0,
		attacks = {
			cut = { name = "Mono-Edge Cut", style = "SlashRight", damage = 16, postureDamage = 16, windup = 0.3, active = 0.12, recovery = 0.4, range = 8, arcDegrees = 100, weight = 3, animationId = PLACEHOLDER_ANIM },
			reverse = { name = "Reverse Cut", style = "SlashLeft", damage = 16, postureDamage = 18, windup = 0.35, active = 0.12, recovery = 0.45, range = 8, arcDegrees = 100, weight = 2, animationId = PLACEHOLDER_ANIM },
			plasma = { name = "Plasma Thrust", style = "Thrust", damage = 30, postureDamage = 26, windup = 0.7, active = 0.2, recovery = 0.7, range = 16, arcDegrees = 30, weight = 1, lunge = 10, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 40,
		xpReward = 60,
		combos = { { "cut", "reverse", "cut" }, { "cut", "plasma" }, { "reverse", "cut", "reverse", "plasma" } },
		comboChance = 0.6,
		guardChance = 0.5,
		deflectChance = 0.7,
		modelId = 0,
		look = { skin = { 200, 200, 210 }, body = { 35, 35, 45 }, legs = { 25, 25, 32 }, headwear = "Visor", accent = { 170, 170, 185 }, glow = { 255, 60, 200 }, weapon = "jian_moonwater", scale = 1.05 },
	},
	-- Hovering drone: keeps its distance and fires bolts (guard them, or dash through).
	drone_sentry = {
		name = "Drone Sentry",
		chapter = 0,
		maxHealth = 110,
		maxPosture = 50,
		postureRegen = 8,
		walkSpeed = 14,
		aggroRange = 55,
		leashRange = 90,
		preferredRange = 26,
		attackCooldown = 1.6,
		attacks = {
			bolt = { name = "Arc Bolt", kind = "Projectile", speed = 70, damage = 12, postureDamage = 10, windup = 0.55, active = 0.1, recovery = 0.4, range = 45, arcDegrees = 360, weight = 3, color = { 60, 230, 255 }, animationId = PLACEHOLDER_ANIM },
			burst = { name = "Scatter Burst", kind = "Volley", count = 3, spread = 24, speed = 80, damage = 9, postureDamage = 8, windup = 0.8, active = 0.1, recovery = 0.6, range = 40, arcDegrees = 360, weight = 1, color = { 255, 60, 200 }, animationId = PLACEHOLDER_ANIM },
			ram = { name = "Ram", damage = 10, postureDamage = 12, windup = 0.5, active = 0.2, recovery = 0.6, range = 6, arcDegrees = 90, weight = 1, lunge = 6, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 30,
		xpReward = 45,
		flinch = true,
		modelId = 0,
		creature = "Drone",
		look = { skin = { 0, 0, 0 }, body = { 50, 52, 64 }, legs = { 0, 0, 0 }, accent = { 190, 195, 210 }, glow = { 60, 230, 255 }, scale = 1 },
	},
	-- Rail Brute: hydraulic giant. Jump the stomp-wave, dash out of the crushing grab.
	rail_brute = {
		name = "Rail Brute",
		chapter = 0,
		maxHealth = 560,
		maxPosture = 190,
		postureRegen = 6,
		walkSpeed = 10,
		aggroRange = 32,
		leashRange = 70,
		preferredRange = 8,
		attackCooldown = 2,
		attacks = {
			slam = { name = "Piston Slam", style = "Overhead", damage = 30, postureDamage = 32, windup = 0.8, active = 0.2, recovery = 0.9, range = 9, arcDegrees = 90, weight = 3, animationId = PLACEHOLDER_ANIM },
			stomp = { name = "Shock Stomp", style = "CastSky", kind = "Wave", speed = 30, damage = 22, postureDamage = 14, windup = 0.9, active = 0.2, recovery = 0.9, range = 32, arcDegrees = 360, weight = 2, color = { 255, 190, 60 }, animationId = PLACEHOLDER_ANIM },
			crush = { name = "Hydraulic Crush", style = "Grasp", damage = 38, postureDamage = 0, windup = 0.9, active = 0.25, recovery = 1.1, range = 7, arcDegrees = 60, weight = 1, perilous = true, perilousKind = "Grasp", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 70,
		xpReward = 90,
		combos = { { "slam", "slam" } },
		comboChance = 0.3,
		guardChance = 0.2,
		deflectChance = 0.25,
		modelId = 0,
		look = { skin = { 150, 150, 160 }, body = { 200, 150, 40 }, legs = { 60, 60, 70 }, headwear = "Visor", accent = { 90, 90, 100 }, glow = { 255, 190, 60 }, weapon = "gb_gatebreaker", scale = 1.6 },
	},
	-- Aeloria -------------------------------------------------------------------------------
	-- Bronze Hoplite: shield wall (guards a lot), spear thrusts, a perilous charge.
	bronze_hoplite = {
		name = "Bronze Hoplite",
		chapter = 0,
		maxHealth = 320,
		maxPosture = 150,
		postureRegen = 10,
		walkSpeed = 13,
		aggroRange = 40,
		leashRange = 85,
		preferredRange = 10,
		attackCooldown = 1.3,
		attacks = {
			jab = { name = "Spear Jab", style = "Thrust", damage = 18, postureDamage = 18, windup = 0.4, active = 0.12, recovery = 0.45, range = 11, arcDegrees = 40, weight = 3, animationId = PLACEHOLDER_ANIM },
			bash = { name = "Shield Bash", style = "SlashLeft", damage = 14, postureDamage = 26, windup = 0.45, active = 0.15, recovery = 0.5, range = 7, arcDegrees = 90, weight = 2, animationId = PLACEHOLDER_ANIM },
			charge = { name = "Phalanx Charge", style = "Thrust", damage = 34, postureDamage = 30, windup = 0.85, active = 0.3, recovery = 0.8, range = 20, arcDegrees = 30, weight = 1, lunge = 14, perilous = true, perilousKind = "Pierce", animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 60,
		xpReward = 80,
		combos = { { "jab", "jab", "bash" }, { "bash", "charge" } },
		comboChance = 0.45,
		guardChance = 0.7,
		deflectChance = 0.55,
		modelId = 0,
		look = { skin = { 215, 175, 140 }, body = { 170, 40, 35 }, legs = { 180, 120, 60 }, headwear = "Crest", accent = { 180, 30, 30 }, weapon = "spear_crimson_tassel", scale = 1.1 },
	},
	-- Siren Archer: shoots from range; her charged song-arrow can be deflected back.
	siren_archer = {
		name = "Siren Archer",
		chapter = 0,
		maxHealth = 180,
		maxPosture = 70,
		postureRegen = 10,
		walkSpeed = 15,
		aggroRange = 60,
		leashRange = 90,
		preferredRange = 28,
		attackCooldown = 1.5,
		attacks = {
			arrow = { name = "Bronze Arrow", style = "CastPush", kind = "Projectile", speed = 85, damage = 14, postureDamage = 10, windup = 0.6, active = 0.1, recovery = 0.4, range = 55, arcDegrees = 360, weight = 3, color = { 230, 200, 140 }, animationId = PLACEHOLDER_ANIM },
			song = { name = "Siren's Note", style = "CastSky", kind = "Projectile", speed = 40, deflectable = true, damage = 20, postureDamage = 22, windup = 0.9, active = 0.1, recovery = 0.6, range = 50, arcDegrees = 360, weight = 1, color = { 140, 220, 255 }, animationId = PLACEHOLDER_ANIM },
			fan = { name = "Arrow Fan", style = "CastPush", kind = "Volley", count = 4, spread = 36, speed = 80, damage = 10, postureDamage = 8, windup = 0.8, active = 0.1, recovery = 0.6, range = 45, arcDegrees = 360, weight = 1, color = { 230, 200, 140 }, animationId = PLACEHOLDER_ANIM },
			kick = { name = "Retreating Kick", style = "SlashRight", damage = 10, postureDamage = 14, windup = 0.4, active = 0.15, recovery = 0.5, range = 6, arcDegrees = 90, weight = 1, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 45,
		xpReward = 65,
		flinch = true,
		modelId = 0,
		look = { skin = { 225, 200, 175 }, body = { 240, 235, 220 }, legs = { 200, 190, 170 }, headwear = "Laurel", accent = { 100, 160, 200 }, glow = { 200, 230, 255 }, weapon = "fan_paper_crane", scale = 1 },
	},
	-- Marble Sentinel: a walking statue. Slow, huge posture, ground-shaking stomps.
	marble_sentinel = {
		name = "Marble Sentinel",
		chapter = 0,
		maxHealth = 800,
		maxPosture = 240,
		postureRegen = 5,
		walkSpeed = 8,
		aggroRange = 30,
		leashRange = 60,
		preferredRange = 9,
		attackCooldown = 2.4,
		attacks = {
			sweep = { name = "Marble Sweep", style = "Sweep", damage = 30, postureDamage = 16, windup = 0.9, active = 0.25, recovery = 1, range = 12, arcDegrees = 220, weight = 2, perilous = true, perilousKind = "Sweep", animationId = PLACEHOLDER_ANIM },
			smash = { name = "Pillar Smash", style = "Overhead", damage = 40, postureDamage = 36, windup = 1, active = 0.2, recovery = 1, range = 10, arcDegrees = 80, weight = 3, animationId = PLACEHOLDER_ANIM },
			quake = { name = "Temple Quake", style = "CastSky", kind = "Wave", speed = 28, damage = 26, postureDamage = 16, windup = 1.1, active = 0.2, recovery = 1.1, range = 36, arcDegrees = 360, weight = 2, color = { 240, 230, 210 }, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 110,
		xpReward = 140,
		guardChance = 0.2,
		deflectChance = 0.2,
		modelId = 0,
		look = { skin = { 236, 232, 222 }, body = { 225, 220, 210 }, legs = { 205, 198, 186 }, headwear = "Laurel", accent = { 205, 198, 186 }, glow = { 255, 215, 120 }, weapon = "staff_bellringer", scale = 1.8 },
	},
} :: { [string]: EnemyDef }

return EnemyConfig
