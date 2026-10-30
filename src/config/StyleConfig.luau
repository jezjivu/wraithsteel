--!strict
-- StyleConfig: fighting styles (stances) that layer on top of any weapon. Chosen at the Dojo in
-- the training yard (or the Styles menu), unlocked by level. All effects are multipliers applied
-- server-side (CombatService/CombatRules) except dash distance, which the client applies to its
-- own dash (the server still only grants i-frames + cooldown).

export type StyleDef = {
	name: string,
	description: string,
	unlockLevel: number,
	color: { number },
	speed: number, -- attack speed: windup/recovery are divided by this
	damage: number,
	posture: number, -- posture damage dealt
	knockback: number,
	parryWindowBonus: number, -- seconds added to the perfect-parry window
	riposteBonus: number, -- extra multiplier on the riposte after a perfect parry
	dashDistance: number,
	dashCooldown: number,
	airDashes: number, -- dashes allowed per jump
}

local StyleConfig = {}

StyleConfig.Default = "river"
StyleConfig.Order = { "river", "mountain", "wind", "ember" }

StyleConfig.Styles = {
	river = {
		name = "Flowing River",
		description = "Fluid and patient. Faster swings and a wider parry window.",
		unlockLevel = 1,
		color = { 110, 180, 255 },
		speed = 1.1, damage = 0.95, posture = 1.0, knockback = 0.9,
		parryWindowBonus = 0.06, riposteBonus = 0.2, dashDistance = 1.0, dashCooldown = 1.0, airDashes = 1,
	},
	mountain = {
		name = "Iron Mountain",
		description = "Rooted and crushing. Heavier posture damage and huge knockback, slower swings.",
		unlockLevel = 3,
		color = { 200, 150, 90 },
		speed = 0.9, damage = 1.05, posture = 1.35, knockback = 1.5,
		parryWindowBonus = 0, riposteBonus = 0.1, dashDistance = 0.85, dashCooldown = 1.1, airDashes = 0,
	},
	wind = {
		name = "Wind Step",
		description = "Never where they strike. Long, fast dashes and two air dashes.",
		unlockLevel = 5,
		color = { 150, 240, 200 },
		speed = 1.0, damage = 1.0, posture = 0.95, knockback = 1.0,
		parryWindowBonus = 0.02, riposteBonus = 0.2, dashDistance = 1.5, dashCooldown = 0.7, airDashes = 2,
	},
	ember = {
		name = "Ember Fang",
		description = "Reckless fire. More damage and brutal ripostes, less posture.",
		unlockLevel = 8,
		color = { 255, 120, 60 },
		speed = 1.05, damage = 1.2, posture = 0.9, knockback = 1.1,
		parryWindowBonus = 0, riposteBonus = 0.6, dashDistance = 1.1, dashCooldown = 1.0, airDashes = 1,
	},
} :: { [string]: StyleDef }

function StyleConfig.Get(id: string?): StyleDef
	return StyleConfig.Styles[id or StyleConfig.Default] or StyleConfig.Styles[StyleConfig.Default]
end

return StyleConfig
