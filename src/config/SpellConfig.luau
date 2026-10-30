--!strict
-- SpellConfig: Qi arts (spells). Three slots on Z / X / C (gamepad: D-pad left/right/down).
-- Spells cost Qi; Qi regenerates over time and fills faster from landing hits and parries.
-- Spells unlock by level (free; no purchase). SpellService applies every number here.
-- All names are original to WRAITHSTEEL. Owner: Agent B (Bladesmith).

export type SpellDef = {
	name: string,
	text: string,
	-- Projectile: flies forward, bursts on the first enemy   Blink: teleport forward, cut through
	-- Barrier: shield + heal on yourself                       Seal: lightning strikes the target area
	-- Storm: whirling petals around you (pulls enemies in)     Lance: piercing line in front of you
	-- Bell: a giant bell falls on the target area (ultimate art)
	kind: "Projectile" | "Blink" | "Barrier" | "Seal" | "Storm" | "Lance" | "Bell",
	unlockLevel: number,
	qi: number,
	cooldown: number,
	color: { number },
	damage: number?,
	posture: number?,
	range: number?, -- max distance from you (target point / projectile / blink)
	radius: number?,
	width: number?, -- Lance / Blink: half-width of the hit corridor
	speed: number?, -- Projectile studs/s
	delay: number?, -- seconds before the hit lands (telegraph)
	knockback: number?,
	launch: number?,
	ticks: number?, -- Storm
	interval: number?,
	stun: number?, -- Seal: stagger seconds
	shield: number?, -- Barrier: fraction of max health
	heal: number?,
	seconds: number?,
	iframes: number?, -- Blink: invulnerable seconds
}

local SpellConfig = {}

SpellConfig.Order = { "lantern_flare", "ghost_step", "jade_barrier", "thunder_seal", "petal_storm", "mist_lance", "nine_bells" }
SpellConfig.Slots = 3
SpellConfig.DefaultLoadout = { "lantern_flare", "ghost_step", "jade_barrier" }
SpellConfig.KeyLabels = { "Z", "X", "C" }

SpellConfig.Qi = {
	max = 100,
	regenPerSecond = 6,
	onHit = 3, -- per hit you land
	onParry = 15, -- per perfect parry
	start = 60, -- Qi on spawn
}

SpellConfig.Spells = {
	lantern_flare = {
		name = "Lantern Flare", text = "Hurl a burst of lantern fire that explodes on the first enemy.",
		kind = "Projectile", unlockLevel = 1, qi = 18, cooldown = 2.5, color = { 255, 150, 60 },
		damage = 26, posture = 8, range = 70, speed = 110, radius = 6,
	},
	ghost_step = {
		name = "Ghost Step", text = "Vanish and reappear ahead, cutting everything you pass through.",
		kind = "Blink", unlockLevel = 1, qi = 15, cooldown = 4, color = { 170, 200, 255 },
		damage = 14, posture = 12, range = 26, width = 5, iframes = 0.35,
	},
	jade_barrier = {
		name = "Jade Barrier", text = "A jade ward absorbs damage and mends your wounds.",
		kind = "Barrier", unlockLevel = 3, qi = 30, cooldown = 14, color = { 90, 220, 150 },
		shield = 0.3, heal = 0.12, seconds = 6,
	},
	thunder_seal = {
		name = "Thunder Seal", text = "Call lightning onto the target area. Stuns everything it strikes.",
		kind = "Seal", unlockLevel = 5, qi = 35, cooldown = 9, color = { 150, 200, 255 },
		damage = 40, posture = 30, range = 45, radius = 11, delay = 0.45, stun = 1.2,
	},
	petal_storm = {
		name = "Petal Storm", text = "Razor petals whirl around you and drag enemies in.",
		kind = "Storm", unlockLevel = 8, qi = 40, cooldown = 11, color = { 255, 160, 200 },
		damage = 12, posture = 6, radius = 13, ticks = 6, interval = 0.3, knockback = -14,
	},
	mist_lance = {
		name = "Mist Lance", text = "A spear of freezing mist pierces every enemy in a line.",
		kind = "Lance", unlockLevel = 12, qi = 25, cooldown = 6, color = { 170, 230, 255 },
		damage = 34, posture = 22, range = 42, width = 4.5, knockback = 30, delay = 0.15,
	},
	nine_bells = {
		name = "Nine Bells", text = "Ultimate art: a colossal bell falls from the sky. Nothing stays standing.",
		kind = "Bell", unlockLevel = 15, qi = 100, cooldown = 35, color = { 255, 215, 120 },
		damage = 120, posture = 120, range = 40, radius = 18, delay = 0.9, launch = 34, knockback = 30,
	},
} :: { [string]: SpellDef }

return SpellConfig
