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
			slash = { name = "Rusted Slash", damage = 8, postureDamage = 10, windup = 0.45, active = 0.15, recovery = 0.5, range = 7, arcDegrees = 90, weight = 3, animationId = PLACEHOLDER_ANIM },
			lunge = { name = "Desperate Lunge", damage = 12, postureDamage = 14, windup = 0.7, active = 0.2, recovery = 0.8, range = 12, arcDegrees = 40, weight = 1, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 6,
		xpReward = 10,
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
			claw = { name = "Wick Claw", damage = 10, postureDamage = 8, windup = 0.55, active = 0.15, recovery = 0.6, range = 6, arcDegrees = 100, weight = 3, animationId = PLACEHOLDER_ANIM },
			grasp = { name = "Smothering Grasp", damage = 18, postureDamage = 0, windup = 0.9, active = 0.25, recovery = 1.0, range = 6, arcDegrees = 60, weight = 1, perilous = true, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 9,
		xpReward = 14,
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
			hook = { name = "Bark-Hook Slash", damage = 22, postureDamage = 16, windup = 0.35, active = 0.12, recovery = 0.45, range = 8, arcDegrees = 100, weight = 3, animationId = PLACEHOLDER_ANIM },
			leap = { name = "Canopy Drop", damage = 30, postureDamage = 22, windup = 0.6, active = 0.2, recovery = 0.7, range = 16, arcDegrees = 45, weight = 1, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 30,
		xpReward = 45,
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
			hammer = { name = "Seized Hammer", damage = 34, postureDamage = 30, windup = 0.8, active = 0.2, recovery = 0.9, range = 8, arcDegrees = 80, weight = 3, animationId = PLACEHOLDER_ANIM },
			quake = { name = "Groaning Quake", damage = 26, postureDamage = 10, windup = 1.1, active = 0.3, recovery = 1.1, range = 11, arcDegrees = 360, weight = 1, perilous = true, animationId = PLACEHOLDER_ANIM },
		},
		emberReward = 55,
		xpReward = 80,
		modelId = 0,
		look = { skin = { 120, 90, 70 }, body = { 110, 70, 45 }, legs = { 90, 60, 40 }, headwear = "Helm", accent = { 150, 85, 45 }, weapon = "staff_pilgrim", scale = 1.45 },
	},
} :: { [string]: EnemyDef }

return EnemyConfig
