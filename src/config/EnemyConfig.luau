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
EnemyConfig.PostureBrokenSeconds = 2.5
EnemyConfig.SpawnFolderName = "EnemySpawns" -- TODO(Studio/Agent D): Workspace folder of spawn Parts
EnemyConfig.TemplateFolderName = "Enemies" -- TODO(Studio/Agent C): ServerStorage folder of rigs

local PLACEHOLDER_ANIM = "rbxassetid://0"

EnemyConfig.Enemies = {
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
	},
} :: { [string]: EnemyDef }

return EnemyConfig
