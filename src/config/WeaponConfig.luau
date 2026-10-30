--!strict
-- WeaponConfig: weapons and their movesets. Frame data is in seconds. Owner: Agent B.
-- TODO(Studio/Agent B): every animationId is a placeholder ("rbxassetid://0"). Replace with
-- uploaded animations and add Animation Events "Hit" at the start of each move's active window.

export type MoveDef = {
	name: string,
	damage: number,
	postureDamage: number,
	windup: number, -- before active frames
	active: number, -- hitbox live
	recovery: number, -- after active, cannot act (except dodge if cancelable)
	range: number, -- studs
	arcDegrees: number, -- horizontal hit arc
	cooldown: number?, -- for skills
	dodgeCancelable: boolean?,
	perilous: boolean?,
	animationId: string,
}

export type WeaponDef = {
	name: string,
	class: "Jian" | "Dao" | "Spear" | "Fan",
	power: number,
	lightCombo: { string }, -- ordered move ids
	heavy: string,
	skills: { [string]: string }, -- Skill1/Skill2/Ultimate -> move id
	modelId: number,
	unlockChapter: number,
}

local WeaponConfig = {}

local PLACEHOLDER_ANIM = "rbxassetid://0"

-- Jian moveset: fast, precise, rewards parries. Original move names.
WeaponConfig.Moves = {
	jian_light_1 = { name = "Reed Cut", damage = 8, postureDamage = 6, windup = 0.12, active = 0.1, recovery = 0.18, range = 7, arcDegrees = 90, dodgeCancelable = true, animationId = PLACEHOLDER_ANIM },
	jian_light_2 = { name = "Returning Reed", damage = 8, postureDamage = 6, windup = 0.1, active = 0.1, recovery = 0.18, range = 7, arcDegrees = 90, dodgeCancelable = true, animationId = PLACEHOLDER_ANIM },
	jian_light_3 = { name = "Rising Lantern", damage = 10, postureDamage = 8, windup = 0.14, active = 0.12, recovery = 0.22, range = 7.5, arcDegrees = 70, dodgeCancelable = true, animationId = PLACEHOLDER_ANIM },
	jian_light_4 = { name = "Ninth Gate Finisher", damage = 16, postureDamage = 14, windup = 0.22, active = 0.14, recovery = 0.4, range = 8, arcDegrees = 120, dodgeCancelable = false, animationId = PLACEHOLDER_ANIM },
	jian_heavy = { name = "Bell-Splitting Thrust", damage = 22, postureDamage = 24, windup = 0.45, active = 0.15, recovery = 0.5, range = 9, arcDegrees = 40, dodgeCancelable = false, animationId = PLACEHOLDER_ANIM },
	jian_skill_petal = { name = "Falling Petal Step", damage = 18, postureDamage = 20, windup = 0.2, active = 0.25, recovery = 0.35, range = 12, arcDegrees = 60, cooldown = 8, dodgeCancelable = false, animationId = PLACEHOLDER_ANIM },
	jian_skill_mirror = { name = "Still-Water Mirror", damage = 0, postureDamage = 0, windup = 0.05, active = 0.6, recovery = 0.2, range = 0, arcDegrees = 360, cooldown = 12, dodgeCancelable = false, animationId = PLACEHOLDER_ANIM },
	jian_ultimate = { name = "Nine Bells Toll", damage = 60, postureDamage = 80, windup = 0.6, active = 0.9, recovery = 0.8, range = 14, arcDegrees = 360, cooldown = 45, dodgeCancelable = false, animationId = PLACEHOLDER_ANIM },
} :: { [string]: MoveDef }

WeaponConfig.Weapons = {
	jian_wanderer = {
		name = "Wanderer's Jian",
		class = "Jian",
		power = 5,
		lightCombo = { "jian_light_1", "jian_light_2", "jian_light_3", "jian_light_4" },
		heavy = "jian_heavy",
		skills = { Skill1 = "jian_skill_petal", Skill2 = "jian_skill_mirror", Ultimate = "jian_ultimate" },
		modelId = 0, -- TODO(Studio)
		unlockChapter = 0,
	},
} :: { [string]: WeaponDef }

-- Still-Water Mirror is a counter stance: during its active frames, incoming non-perilous hits
-- are treated as perfect parries. Value lives here so CombatService stays data-driven.
WeaponConfig.CounterStanceMoves = { jian_skill_mirror = true }

-- Ultimate charge: gained on dealing posture damage and on parries.
WeaponConfig.UltimateChargeMax = 100
WeaponConfig.UltimateChargePerParry = 12
WeaponConfig.UltimateChargePerPostureDamage = 0.25

return WeaponConfig
