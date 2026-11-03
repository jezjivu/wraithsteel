--!strict
-- SpellConfig: Qi arts (spells). Three slots on Z / X / C (gamepad: D-pad left/right/down).
-- Spells cost Qi; Qi regenerates over time and fills faster from landing hits and parries.
-- Spells unlock by level (free; no purchase). SpellService applies every number here.
-- All names are original to WRAITHSTEEL. Owner: Agent B (Bladesmith).

export type SpellDef = {
	name: string,
	text: string,
	-- Blade arts (all melee/movement):
	--   Flurry    - flash to the target and cut it a dozen times in a second (Thousand Cuts)
	--   Blink     - vanish forward, cutting everything you pass through (Ghost Step)
	--   SlashWave - a flying crescent of steel that pierces the whole line (Crescent Wave)
	--   Fissure   - a slash into the ground: the earth splits forward in a line (Earthsplitter)
	--   Rising    - a rising cut that launches everyone around you, and you with it (Rising Dragon)
	--   Storm     - spin into a blade cyclone that drags enemies in (Tempest Spin)
	--   SkyFall   - leap high and fall on the target like a meteor (Heaven's Fall)
	--   Chain     - blink from enemy to enemy, cutting each (Phantom Rush)
	-- Arts unlocked by a skill (SkillConfig `art`) also need that skill learned.
	kind: "Flurry" | "Blink" | "SlashWave" | "Fissure" | "Rising" | "Storm" | "SkyFall" | "Chain",
	unlockLevel: number,
	qi: number,
	cooldown: number,
	color: { number },
	damage: number?, -- per hit
	posture: number?,
	range: number?, -- max distance from you (target point / dash / wave)
	radius: number?,
	width: number?, -- corridor half-width (Blink / SlashWave / Fissure)
	speed: number?, -- SlashWave studs/s
	delay: number?, -- seconds before the hit lands
	knockback: number?,
	launch: number?,
	ticks: number?, -- Flurry / Storm hits
	interval: number?,
	iframes: number?, -- invulnerable seconds while it runs
	count: number?, -- Chain: max targets
}

local SpellConfig = {}

SpellConfig.Order = { "thousand_cuts", "ghost_step", "crescent_wave", "earthsplitter", "rising_dragon", "tempest_spin", "heavens_fall", "moon_severance", "phantom_rush", "crimson_lotus" }
SpellConfig.Slots = 3
SpellConfig.DefaultLoadout = { "thousand_cuts", "ghost_step", "crescent_wave" }
SpellConfig.KeyLabels = { "Z", "X", "C" }

SpellConfig.Qi = {
	max = 100,
	regenPerSecond = 6,
	onHit = 3, -- per hit you land
	onParry = 15, -- per perfect parry
	onKill = 10, -- per enemy you helped defeat
	start = 60, -- Qi on spawn
}

SpellConfig.Spells = {
	thousand_cuts = {
		name = "Thousand Cuts", text = "Flash to your target and carve it a dozen times in a single second.",
		kind = "Flurry", unlockLevel = 1, qi = 25, cooldown = 6, color = { 230, 230, 255 },
		damage = 8, posture = 6, range = 30, radius = 9, ticks = 12, interval = 0.07, iframes = 1,
	},
	ghost_step = {
		name = "Ghost Step", text = "Vanish and reappear ahead, cutting everything you pass through.",
		kind = "Blink", unlockLevel = 1, qi = 15, cooldown = 4, color = { 170, 200, 255 },
		damage = 16, posture = 14, range = 26, width = 5, iframes = 0.35,
	},
	crescent_wave = {
		name = "Crescent Wave", text = "Swing so fast the air itself cuts: a crescent of steel pierces the whole line.",
		kind = "SlashWave", unlockLevel = 1, qi = 18, cooldown = 2.5, color = { 120, 220, 255 },
		damage = 26, posture = 16, range = 60, width = 5, speed = 130,
	},
	earthsplitter = {
		name = "Earthsplitter", text = "Drive your blade into the ground: the earth splits open in a line ahead.",
		kind = "Fissure", unlockLevel = 3, qi = 28, cooldown = 7, color = { 255, 160, 70 },
		damage = 34, posture = 30, range = 45, width = 5, delay = 0.25, launch = 28,
	},
	rising_dragon = {
		name = "Rising Dragon", text = "A rising cut that launches everyone around you into the air - and you after them.",
		kind = "Rising", unlockLevel = 5, qi = 30, cooldown = 8, color = { 255, 210, 90 },
		damage = 30, posture = 26, radius = 11, launch = 46, iframes = 0.4,
	},
	tempest_spin = {
		name = "Tempest Spin", text = "Spin into a cyclone of blades that drags enemies in.",
		kind = "Storm", unlockLevel = 8, qi = 35, cooldown = 10, color = { 200, 240, 255 },
		damage = 11, posture = 8, radius = 13, ticks = 7, interval = 0.18, knockback = -14,
	},
	heavens_fall = {
		name = "Heaven's Fall", text = "Ultimate art: leap high into the sky and fall on your target like a meteor.",
		kind = "SkyFall", unlockLevel = 12, qi = 70, cooldown = 25, color = { 255, 120, 60 },
		damage = 90, posture = 90, range = 40, radius = 16, delay = 0.85, launch = 34, iframes = 1.1,
	},
	-- Skill-tree arts (SkillConfig): learned in the Skills panel.
	moon_severance = {
		name = "Moon Severance", text = "A giant pale crescent rolls forward slowly, splitting everything in a wide line.",
		kind = "SlashWave", unlockLevel = 1, qi = 40, cooldown = 12, color = { 235, 235, 255 },
		damage = 70, posture = 55, range = 80, width = 11, speed = 70,
	},
	phantom_rush = {
		name = "Phantom Rush", text = "Blink from enemy to enemy - up to five - cutting each as you pass.",
		kind = "Chain", unlockLevel = 1, qi = 35, cooldown = 10, color = { 150, 130, 255 },
		damage = 34, posture = 26, range = 40, count = 5, interval = 0.16, iframes = 1.1,
	},
	crimson_lotus = {
		name = "Crimson Lotus", text = "A whirling bloom of blades: pulls enemies in and shreds their posture.",
		kind = "Storm", unlockLevel = 1, qi = 40, cooldown = 12, color = { 255, 70, 90 },
		damage = 9, posture = 16, radius = 16, ticks = 10, interval = 0.14, knockback = -18,
	},
} :: { [string]: SpellDef }

return SpellConfig
