--!strict
-- WeaponConfig: weapon classes, their movesets, and every weapon (stats, price, look).
-- Frame data is in seconds. Owner: Agent B. All names are original to WRAITHSTEEL.
-- TODO(Studio/Agent B): every animationId is a placeholder ("rbxassetid://0"). Replace with
-- uploaded animations and add Animation Events "Hit" at the start of each move's active window.
-- Weapon looks are built from parts by Shared/WeaponModels using `visual` below (no uploads
-- needed); a Studio-made model can replace one later via modelId.

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

export type WeaponClass = "Jian" | "Dao" | "Spear" | "Fan" | "Staff" | "Greatblade"

-- Colors are {r, g, b} 0-255 so this file loads outside Roblox (unit tests).
export type WeaponVisual = {
	blade: { number }, -- main metal color
	accent: { number }, -- guard / caps / ribs
	grip: { number }, -- handle wrap
	tassel: { number }?, -- tassel / cloth color, nil = none
	length: number, -- blade (or shaft) length in studs
	width: number?, -- blade width multiplier (1 = class default)
	glow: { number }?, -- neon edge + light color, nil = none
}

export type WeaponDef = {
	name: string,
	class: WeaponClass,
	rarity: string, -- display tier (SpiritConfig rarity names/colors)
	description: string,
	power: number,
	price: number,
	currency: "Ember" | "Jade", -- fixed price, never random
	unlockChapter: number,
	lightCombo: { string }, -- ordered move ids
	heavy: string,
	skills: { [string]: string }, -- Skill1/Skill2/Ultimate -> move id
	visual: WeaponVisual,
	modelId: number, -- optional Studio model; 0 = use the built model
}

local WeaponConfig = {}

local PLACEHOLDER_ANIM = "rbxassetid://0"

type MoveExtra = { cooldown: number?, cancel: boolean?, perilous: boolean? }

local function move(
	name: string,
	damage: number,
	posture: number,
	windup: number,
	active: number,
	recovery: number,
	range: number,
	arc: number,
	extra: MoveExtra?
): MoveDef
	local e: MoveExtra = extra or {}
	return {
		name = name,
		damage = damage,
		postureDamage = posture,
		windup = windup,
		active = active,
		recovery = recovery,
		range = range,
		arcDegrees = arc,
		cooldown = e.cooldown,
		dodgeCancelable = e.cancel,
		perilous = e.perilous,
		animationId = PLACEHOLDER_ANIM,
	}
end

local C = { cancel = true }

WeaponConfig.Moves = {
	-- Jian: fast, precise, rewards parries.
	jian_light_1 = move("Reed Cut", 8, 6, 0.12, 0.1, 0.18, 7, 90, C),
	jian_light_2 = move("Returning Reed", 8, 6, 0.1, 0.1, 0.18, 7, 90, C),
	jian_light_3 = move("Rising Lantern", 10, 8, 0.14, 0.12, 0.22, 7.5, 70, C),
	jian_light_4 = move("Ninth Gate Finisher", 16, 14, 0.22, 0.14, 0.4, 8, 120),
	jian_heavy = move("Bell-Splitting Thrust", 22, 24, 0.45, 0.15, 0.5, 9, 40),
	jian_skill_petal = move("Falling Petal Step", 18, 20, 0.2, 0.25, 0.35, 12, 60, { cooldown = 8 }),
	jian_skill_mirror = move("Still-Water Mirror", 0, 0, 0.05, 0.6, 0.2, 0, 360, { cooldown = 12 }),
	jian_ultimate = move("Nine Bells Toll", 60, 80, 0.6, 0.9, 0.8, 14, 360, { cooldown = 45 }),

	-- Dao: heavier single-edged cuts, wide arcs.
	dao_light_1 = move("Tidecut", 11, 8, 0.16, 0.12, 0.24, 7.5, 120, C),
	dao_light_2 = move("Backhand Ember", 12, 9, 0.15, 0.12, 0.24, 7.5, 120, C),
	dao_light_3 = move("Falling Furnace", 18, 16, 0.26, 0.14, 0.45, 8, 140),
	dao_heavy = move("Hearth-Splitter", 30, 28, 0.55, 0.15, 0.55, 8.5, 70),
	dao_skill_roll = move("Rolling Ember Slash", 24, 22, 0.25, 0.3, 0.4, 12, 70, { cooldown = 8 }),
	dao_skill_wall = move("Iron Wall Guard", 0, 0, 0.05, 0.7, 0.25, 0, 360, { cooldown = 12 }),
	dao_ultimate = move("Thousand Sparks", 75, 70, 0.6, 1.0, 0.8, 12, 360, { cooldown = 45 }),

	-- Spear: longest reach, narrow thrusts and one sweep.
	spear_light_1 = move("Reed Thrust", 7, 5, 0.13, 0.1, 0.2, 11, 30, C),
	spear_light_2 = move("Twin Thrust", 7, 5, 0.12, 0.1, 0.2, 11, 30, C),
	spear_light_3 = move("Sweeping Shaft", 9, 10, 0.18, 0.14, 0.26, 10, 180, C),
	spear_light_4 = move("Dragon Rises", 14, 14, 0.24, 0.14, 0.42, 12, 40),
	spear_heavy = move("Piercing Gale", 24, 22, 0.5, 0.15, 0.5, 14, 25),
	spear_skill_vault = move("Sky Vault", 20, 24, 0.3, 0.25, 0.4, 15, 50, { cooldown = 9 }),
	spear_skill_whirl = move("Whirling Tassel", 16, 18, 0.2, 0.5, 0.35, 10, 360, { cooldown = 10 }),
	spear_ultimate = move("Fifth Gate Lance", 70, 60, 0.7, 0.6, 0.8, 20, 40, { cooldown = 45 }),

	-- Fan: very fast flurries, posture pressure, a ranged volley.
	fan_light_1 = move("Flick", 5, 6, 0.08, 0.08, 0.14, 6.5, 110, C),
	fan_light_2 = move("Fold", 5, 6, 0.08, 0.08, 0.14, 6.5, 110, C),
	fan_light_3 = move("Unfurl", 6, 7, 0.09, 0.08, 0.15, 6.5, 110, C),
	fan_light_4 = move("Snap Shut", 6, 7, 0.09, 0.08, 0.15, 6.5, 110, C),
	fan_light_5 = move("Crane Spreads Wings", 10, 12, 0.16, 0.12, 0.3, 7, 160),
	fan_heavy = move("Gust Palm", 14, 30, 0.4, 0.15, 0.45, 10, 90),
	fan_skill_volley = move("Crane Feather Volley", 22, 14, 0.25, 0.4, 0.35, 18, 30, { cooldown = 7 }),
	fan_skill_fold = move("Folding Wind", 0, 0, 0.05, 0.55, 0.2, 0, 360, { cooldown = 11 }),
	fan_ultimate = move("Hundred Cranes Storm", 55, 90, 0.5, 1.2, 0.8, 14, 360, { cooldown = 45 }),

	-- Staff: posture breaker with wide swings.
	staff_light_1 = move("Pole Tap", 7, 10, 0.14, 0.12, 0.22, 8.5, 140, C),
	staff_light_2 = move("Turning Pole", 7, 10, 0.14, 0.12, 0.22, 8.5, 140, C),
	staff_light_3 = move("Low Sweep", 8, 12, 0.16, 0.12, 0.24, 8.5, 160, C),
	staff_light_4 = move("Overhead Bell", 12, 18, 0.24, 0.14, 0.4, 9, 90),
	staff_heavy = move("Mountain Pole", 20, 40, 0.5, 0.15, 0.55, 9, 120),
	staff_skill_vault = move("Pilgrim's Vault", 18, 26, 0.3, 0.25, 0.4, 13, 60, { cooldown = 8 }),
	staff_skill_spin = move("Bell Spin", 14, 22, 0.2, 0.6, 0.35, 9, 360, { cooldown = 10 }),
	staff_ultimate = move("Temple Bell Quake", 60, 100, 0.7, 0.6, 0.9, 15, 360, { cooldown = 45 }),

	-- Greatblade: slow, enormous hits, cannot dodge-cancel the finisher.
	gb_light_1 = move("Iron Arc", 16, 14, 0.3, 0.16, 0.4, 9, 150, C),
	gb_light_2 = move("Returning Iron", 18, 16, 0.28, 0.16, 0.4, 9, 150, C),
	gb_light_3 = move("Gate Falls", 26, 26, 0.45, 0.16, 0.7, 9.5, 100),
	gb_heavy = move("Gate-Breaking Drop", 42, 45, 0.8, 0.18, 0.8, 10, 60),
	gb_skill_charge = move("Colossus Charge", 30, 34, 0.35, 0.4, 0.5, 14, 50, { cooldown = 9 }),
	gb_skill_bulwark = move("Ashen Bulwark", 0, 0, 0.05, 0.8, 0.3, 0, 360, { cooldown = 14 }),
	gb_ultimate = move("Ninth Gate Sundering", 95, 110, 0.9, 0.5, 1.0, 15, 200, { cooldown = 45 }),
} :: { [string]: MoveDef }

-- Movesets shared by every weapon of a class.
WeaponConfig.ClassMoves = {
	Jian = { lightCombo = { "jian_light_1", "jian_light_2", "jian_light_3", "jian_light_4" }, heavy = "jian_heavy", skills = { Skill1 = "jian_skill_petal", Skill2 = "jian_skill_mirror", Ultimate = "jian_ultimate" } },
	Dao = { lightCombo = { "dao_light_1", "dao_light_2", "dao_light_3" }, heavy = "dao_heavy", skills = { Skill1 = "dao_skill_roll", Skill2 = "dao_skill_wall", Ultimate = "dao_ultimate" } },
	Spear = { lightCombo = { "spear_light_1", "spear_light_2", "spear_light_3", "spear_light_4" }, heavy = "spear_heavy", skills = { Skill1 = "spear_skill_vault", Skill2 = "spear_skill_whirl", Ultimate = "spear_ultimate" } },
	Fan = { lightCombo = { "fan_light_1", "fan_light_2", "fan_light_3", "fan_light_4", "fan_light_5" }, heavy = "fan_heavy", skills = { Skill1 = "fan_skill_volley", Skill2 = "fan_skill_fold", Ultimate = "fan_ultimate" } },
	Staff = { lightCombo = { "staff_light_1", "staff_light_2", "staff_light_3", "staff_light_4" }, heavy = "staff_heavy", skills = { Skill1 = "staff_skill_vault", Skill2 = "staff_skill_spin", Ultimate = "staff_ultimate" } },
	Greatblade = { lightCombo = { "gb_light_1", "gb_light_2", "gb_light_3" }, heavy = "gb_heavy", skills = { Skill1 = "gb_skill_charge", Skill2 = "gb_skill_bulwark", Ultimate = "gb_ultimate" } },
}

WeaponConfig.ClassBlurb = {
	Jian = "Fast and precise. Rewards perfect parries.",
	Dao = "Heavy curved cuts with wide arcs.",
	Spear = "Longest reach. Keep enemies at the tip.",
	Fan = "Blinding flurries that crush posture.",
	Staff = "Wide swings built to break stances.",
	Greatblade = "Slow, enormous blows. Commit and conquer.",
}

type WeaponSpec = {
	name: string,
	class: WeaponClass,
	rarity: string,
	description: string,
	power: number,
	price: number,
	currency: "Ember" | "Jade",
	unlockChapter: number,
	visual: WeaponVisual,
}

local function weapon(spec: WeaponSpec): WeaponDef
	local moves = WeaponConfig.ClassMoves[spec.class]
	return {
		name = spec.name,
		class = spec.class,
		rarity = spec.rarity,
		description = spec.description,
		power = spec.power,
		price = spec.price,
		currency = spec.currency,
		unlockChapter = spec.unlockChapter,
		lightCombo = moves.lightCombo,
		heavy = moves.heavy,
		skills = moves.skills,
		visual = spec.visual,
		modelId = 0,
	}
end

local STEEL = { 200, 205, 210 }
local DARK_STEEL = { 90, 92, 100 }
local BRASS = { 200, 160, 70 }
local RUST = { 150, 80, 40 }
local JADE = { 80, 190, 140 }
local LACQUER = { 120, 25, 25 }
local WOOD = { 110, 75, 45 }
local CLOTH = { 40, 35, 50 }

WeaponConfig.Weapons = {
	-- Prologue -------------------------------------------------------------------------------
	jian_wanderer = weapon({
		name = "Wanderer's Jian", class = "Jian", rarity = "Common", power = 5, price = 0, currency = "Ember", unlockChapter = 0,
		description = "A plain blade carried by every road-worn swordsman.",
		visual = { blade = STEEL, accent = BRASS, grip = CLOTH, tassel = { 180, 40, 40 }, length = 3.2 },
	}),
	dao_rustcutter = weapon({
		name = "Rustcutter Dao", class = "Dao", rarity = "Common", power = 8, price = 600, currency = "Ember", unlockChapter = 0,
		description = "Forged from bandit scrap. Bites deeper than it looks.",
		visual = { blade = RUST, accent = DARK_STEEL, grip = WOOD, length = 3.0 },
	}),
	spear_reedline = weapon({
		name = "Reedline Spear", class = "Spear", rarity = "Common", power = 8, price = 750, currency = "Ember", unlockChapter = 0,
		description = "A marsh-guard's spear, light as a reed.",
		visual = { blade = STEEL, accent = DARK_STEEL, grip = WOOD, tassel = { 170, 40, 40 }, length = 6.5 },
	}),
	fan_paper_crane = weapon({
		name = "Paper Crane Fan", class = "Fan", rarity = "Uncommon", power = 7, price = 750, currency = "Ember", unlockChapter = 0,
		description = "Steel ribs under painted paper. Folds into a club.",
		visual = { blade = { 235, 225, 205 }, accent = DARK_STEEL, grip = LACQUER, tassel = { 220, 60, 60 }, length = 2.0 },
	}),
	staff_pilgrim = weapon({
		name = "Pilgrim's Staff", class = "Staff", rarity = "Common", power = 7, price = 600, currency = "Ember", unlockChapter = 0,
		description = "Walked a thousand miles. Cracked a thousand helmets.",
		visual = { blade = WOOD, accent = BRASS, grip = WOOD, length = 6.0 },
	}),
	jian_moonwater = weapon({
		name = "Moonwater Jian", class = "Jian", rarity = "Rare", power = 14, price = 2500, currency = "Ember", unlockChapter = 0,
		description = "Its edge ripples like moonlight on a still pond.",
		visual = { blade = { 190, 215, 245 }, accent = { 220, 225, 235 }, grip = { 30, 40, 80 }, tassel = { 120, 170, 240 }, length = 3.4, glow = { 140, 190, 255 } },
	}),
	jian_ninth_bell = weapon({
		name = "Ninth-Bell Jian", class = "Jian", rarity = "Epic", power = 16, price = 600, currency = "Jade", unlockChapter = 0,
		description = "Hums with the echo of a bell no one has rung in centuries.",
		visual = { blade = { 60, 55, 70 }, accent = BRASS, grip = { 20, 20, 25 }, tassel = { 240, 190, 70 }, length = 3.5, glow = { 255, 200, 90 } },
	}),

	-- Chapter 1 ------------------------------------------------------------------------------
	dao_ember_tide = weapon({
		name = "Ember Tide Dao", class = "Dao", rarity = "Rare", power = 30, price = 9000, currency = "Ember", unlockChapter = 1,
		description = "Quenched in a furnace that never cooled.",
		visual = { blade = { 70, 60, 60 }, accent = BRASS, grip = LACQUER, length = 3.3, width = 1.15, glow = { 255, 120, 40 } },
	}),
	spear_crimson_tassel = weapon({
		name = "Crimson Tassel Spear", class = "Spear", rarity = "Rare", power = 32, price = 11000, currency = "Ember", unlockChapter = 1,
		description = "Its tassel is said to drink the dawn.",
		visual = { blade = STEEL, accent = BRASS, grip = LACQUER, tassel = { 210, 20, 30 }, length = 7.0 },
	}),
	fan_iron_lotus = weapon({
		name = "Iron Lotus Fan", class = "Fan", rarity = "Rare", power = 30, price = 10000, currency = "Ember", unlockChapter = 1,
		description = "Every rib a petal, every petal a blade.",
		visual = { blade = DARK_STEEL, accent = { 230, 120, 170 }, grip = { 30, 30, 30 }, tassel = { 230, 120, 170 }, length = 2.2 },
	}),
	staff_bellringer = weapon({
		name = "Bellringer Staff", class = "Staff", rarity = "Rare", power = 30, price = 9500, currency = "Ember", unlockChapter = 1,
		description = "Capped with temple bronze. Every strike tolls.",
		visual = { blade = { 60, 40, 30 }, accent = { 190, 140, 60 }, grip = { 60, 40, 30 }, length = 6.4, glow = { 255, 210, 120 } },
	}),
	gb_gatebreaker = weapon({
		name = "Gatebreaker", class = "Greatblade", rarity = "Epic", power = 38, price = 14000, currency = "Ember", unlockChapter = 1,
		description = "Less a sword than a door that learned to swing.",
		visual = { blade = DARK_STEEL, accent = RUST, grip = CLOTH, length = 4.6 },
	}),
	spear_skypiercer = weapon({
		name = "Skypiercer of the Fifth Gate", class = "Spear", rarity = "Legendary", power = 40, price = 900, currency = "Jade", unlockChapter = 1,
		description = "Thrown once at the sky. It came back with lightning.",
		visual = { blade = { 230, 235, 255 }, accent = { 120, 160, 255 }, grip = { 20, 30, 70 }, tassel = { 120, 160, 255 }, length = 7.4, glow = { 150, 190, 255 } },
	}),

	-- Chapter 2 ------------------------------------------------------------------------------
	dao_thunderhowl = weapon({
		name = "Thunderhowl Dao", class = "Dao", rarity = "Epic", power = 110, price = 60000, currency = "Ember", unlockChapter = 2,
		description = "Draw it in the rain and the clouds answer.",
		visual = { blade = { 210, 220, 240 }, accent = { 90, 120, 220 }, grip = { 20, 20, 40 }, length = 3.5, width = 1.2, glow = { 170, 200, 255 } },
	}),
	gb_ashen_colossus = weapon({
		name = "Ashen Colossus Blade", class = "Greatblade", rarity = "Legendary", power = 130, price = 80000, currency = "Ember", unlockChapter = 2,
		description = "Carved from the sword of a statue that walked.",
		visual = { blade = { 120, 115, 110 }, accent = { 230, 120, 50 }, grip = { 50, 30, 20 }, length = 5.2, width = 1.2, glow = { 255, 130, 50 } },
	}),
	jade_qilin_jian = weapon({
		name = "Jade Qilin Jian", class = "Jian", rarity = "Legendary", power = 115, price = 75000, currency = "Ember", unlockChapter = 2,
		description = "Polished jade over a steel heart. Lucky, they say.",
		visual = { blade = JADE, accent = BRASS, grip = { 20, 60, 40 }, tassel = JADE, length = 3.5, glow = { 120, 255, 190 } },
	}),
} :: { [string]: WeaponDef }

-- Display order in the Weapon Smith.
WeaponConfig.ShopOrder = {
	"jian_wanderer", "dao_rustcutter", "staff_pilgrim", "spear_reedline", "fan_paper_crane", "jian_moonwater", "jian_ninth_bell",
	"dao_ember_tide", "staff_bellringer", "fan_iron_lotus", "spear_crimson_tassel", "gb_gatebreaker", "spear_skypiercer",
	"dao_thunderhowl", "jade_qilin_jian", "gb_ashen_colossus",
}

-- Counter stances: during active frames, incoming non-perilous hits count as perfect parries.
WeaponConfig.CounterStanceMoves = { jian_skill_mirror = true, dao_skill_wall = true, fan_skill_fold = true, gb_skill_bulwark = true }

-- Ultimate charge: gained on dealing posture damage and on parries.
WeaponConfig.UltimateChargeMax = 100
WeaponConfig.UltimateChargePerParry = 12
WeaponConfig.UltimateChargePerPostureDamage = 0.25

-- How a held weapon sits in the hand: rotation (degrees) relative to the hand part, and how far
-- down the hand the grip sits (fraction of the hand's height). {-90, 0, 0} points the blade
-- along the hand's forward axis. TODO(Studio/Agent B): tune by eye after the first look.
WeaponConfig.GripRotation = { -90, 0, 0 }
WeaponConfig.GripDepth = 0.5

return WeaponConfig
