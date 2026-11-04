--!strict
-- StyleConfig: fighting styles (stances) that layer on top of any weapon. Chosen at the Dojo in
-- the training yard (or the Styles menu), unlocked by level. Each style has base multipliers
-- AND a signature mechanic (Logic/StyleLogic, server-side), its own stance and its own way of
-- swinging (AnimationConfig.StyleStances / StyleFlavor), so switching style changes the fight:
--   River    - Flow: every perfect deflect adds a Flow stack (faster, heavier strikes)
--   Mountain - Unshaken: heavy attacks and finishers have super armor; heavies crush guards
--   Wind     - Gale: strikes right after a dash crit; a much longer dash-strike window
--   Ember    - Heat: every hit you land stacks Heat (+damage); getting hit puts it out

export type Mechanic = {
	kind: "Flow" | "Unshaken" | "Gale" | "Heat",
	name: string,
	text: string, -- one line for the Dojo panel / HUD tooltip
	maxStacks: number?, -- Flow / Heat
	stackSeconds: number?, -- stacks fade this long after the last gain
	speedPerStack: number?, -- Flow: attack speed per stack
	posturePerStack: number?, -- Flow: posture damage per stack
	damagePerStack: number?, -- Heat
	postureTaken: number?, -- Unshaken: posture you take while armored
	guardCrush: number?, -- Unshaken: posture multiplier on a blocked heavy
	critWindow: number?, -- Gale: seconds after a dash
	critMultiplier: number?, -- Gale
	dashWindowMultiplier: number?, -- Gale: dash-strike window
	dodgeRefund: boolean?, -- Gale: dodging a hit with i-frames refunds the dash cooldown
}

export type StyleDef = {
	name: string,
	description: string,
	unlockLevel: number,
	color: { number },
	speed: number, -- attack speed: windup/recovery are divided by this
	damage: number,
	posture: number, -- posture damage dealt
	knockback: number,
	parryWindowBonus: number, -- seconds added to (or taken from) the perfect-parry window
	riposteBonus: number, -- extra multiplier on the riposte after a perfect parry
	dashDistance: number,
	dashCooldown: number,
	airDashes: number, -- dashes allowed per jump
	mechanic: Mechanic,
}

local StyleConfig = {}

StyleConfig.Default = "river"
StyleConfig.Order = { "river", "mountain", "wind", "ember" }

StyleConfig.Styles = {
	river = {
		name = "Flowing River",
		description = "Patient and precise. Deflect to build Flow, then answer faster and heavier.",
		unlockLevel = 1,
		color = { 110, 180, 255 },
		speed = 1.05, damage = 0.95, posture = 1.0, knockback = 0.9,
		parryWindowBonus = 0.07, riposteBonus = 0.3, dashDistance = 1.0, dashCooldown = 1.0, airDashes = 1,
		mechanic = {
			kind = "Flow",
			name = "Flow",
			text = "Each perfect deflect adds Flow (max 3): +12% attack speed and +15% posture damage per stack.",
			maxStacks = 3, stackSeconds = 6, speedPerStack = 0.12, posturePerStack = 0.15,
		},
	},
	mountain = {
		name = "Iron Mountain",
		description = "Rooted and crushing. Your heavy blows cannot be interrupted and break through guards.",
		unlockLevel = 3,
		color = { 200, 150, 90 },
		speed = 0.88, damage = 1.08, posture = 1.3, knockback = 1.5,
		parryWindowBonus = 0, riposteBonus = 0.1, dashDistance = 0.85, dashCooldown = 1.15, airDashes = 0,
		mechanic = {
			kind = "Unshaken",
			name = "Unshaken",
			text = "Heavy attacks and finishers have super armor (no knockback, half posture taken). Blocked heavies deal 1.7x posture.",
			postureTaken = 0.5, guardCrush = 1.7,
		},
	},
	wind = {
		name = "Wind Step",
		description = "Never where they strike. Dash in, cut, dash out - strikes off a dash are critical.",
		unlockLevel = 5,
		color = { 150, 240, 200 },
		speed = 1.0, damage = 0.98, posture = 0.9, knockback = 1.0,
		parryWindowBonus = 0.02, riposteBonus = 0.15, dashDistance = 1.45, dashCooldown = 0.7, airDashes = 2,
		mechanic = {
			kind = "Gale",
			name = "Gale",
			text = "Strikes within 0.8s of a dash always crit (x1.4). Dash strikes come out of a 2x longer window. Dodging a hit refunds your dash.",
			critWindow = 0.8, critMultiplier = 1.4, dashWindowMultiplier = 2, dodgeRefund = true,
		},
	},
	ember = {
		name = "Ember Fang",
		description = "Reckless fire. Keep hitting to stoke Heat - but every hit you take puts it out.",
		unlockLevel = 8,
		color = { 255, 120, 60 },
		speed = 1.05, damage = 1.1, posture = 0.9, knockback = 1.1,
		parryWindowBonus = -0.03, riposteBonus = 0.5, dashDistance = 1.1, dashCooldown = 1.0, airDashes = 1,
		mechanic = {
			kind = "Heat",
			name = "Heat",
			text = "Every hit you land adds Heat (max 5): +8% damage per stack. Taking a hit resets it; it fades 3s after your last hit.",
			maxStacks = 5, stackSeconds = 3, damagePerStack = 0.08,
		},
	},
} :: { [string]: StyleDef }

function StyleConfig.Get(id: string?): StyleDef
	return StyleConfig.Styles[id or StyleConfig.Default] or StyleConfig.Styles[StyleConfig.Default]
end

return StyleConfig
