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
	animationId: string,
}

-- Procedural rig look (RigBuilder) used until a Studio rig exists in ServerStorage.
-- Colors are {r, g, b}; weapon is a WeaponConfig id held in the right hand.
export type RigLook = {
	skin: { number },
	body: { number },
	legs: { number },
	headwear: ("Hood" | "Helm" | "Horns" | "Lantern" | "Sack" | "Hair" | "Bell")?,
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
}

local EnemyConfig = {}

-- AI scheduler / director ------------------------------------------------------------------
EnemyConfig.AITickRate = 10 -- Hz, batched across all enemies
EnemyConfig.MaxEnemiesPerTickSlice = 40 -- spread work over frames if more are alive
EnemyConfig.AttackTokensPerPlayer = 2 -- at most N enemies attack the same player at once
EnemyConfig.AttackTokenDuration = 2.5 -- seconds a token is held before it must be returned
EnemyConfig.AttackTokenCooldown = 0.6 -- seconds before a returned token can be re-granted
EnemyConfig.StateReplicationRate = 10 -- Hz, batched EnemyState remote
EnemyConfig.DespawnAfterDeath = 4
EnemyConfig.DefaultRespawnSeconds = 20
EnemyConfig.DefaultSpawnScatter = 6 -- studs; spawn Parts can override with attribute Scatter
EnemyConfig.PostureBrokenSeconds = 2.5
EnemyConfig.DefaultStep = 2.5 -- studs every enemy strike steps forward
EnemyConfig.HitKnockback = 10 -- studs/s pushback when an enemy hit lands
EnemyConfig.PerilousKnockback = 38
EnemyConfig.ComboGap = 0.12 -- seconds between strikes in a combo (instead of full recovery)
EnemyConfig.FlinchSeconds = 0.35
EnemyConfig.FlinchCooldown = 1.4 -- an enemy cannot be flinch-locked
EnemyConfig.GuardSeconds = 1.4
EnemyConfig.GuardDamageMultiplier = 0.2 -- health damage taken through guard
EnemyConfig.GuardPostureMultiplier = 1.4 -- guard soaks more posture (break it!)
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
} :: { [string]: EnemyDef }

return EnemyConfig
