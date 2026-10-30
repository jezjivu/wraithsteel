--!strict
-- BossConfig: story/world/raid bosses. Owner: Agent C (Warden).
-- Bosses run the shared BossStateMachine (ServerScriptService.Logic.BossStateMachine).
-- Prologue + Chapter 1 bosses are specified (5 of 21); the rest are listed in ChapterConfig
-- and get entries here as their chapters are built.

local EnemyConfig = require(script.Parent.EnemyConfig)

export type BossMove = {
	name: string,
	damage: number,
	postureDamage: number,
	windup: number,
	active: number,
	recovery: number,
	range: number,
	arcDegrees: number,
	weight: number,
	cooldown: number,
	perilous: boolean?,
	minRange: number?, -- only chosen when target is at least this far (gap closers)
	hits: number?, -- multi-hit flurries
	animationId: string,
}

export type BossPhaseDef = {
	hpThreshold: number, -- phase becomes active when hp fraction <= threshold
	moves: { string },
	speedMultiplier: number,
	enrage: boolean?,
	transitionSeconds: number, -- invulnerable roar/cutscene between phases
}

export type BossDef = {
	name: string,
	title: string,
	chapter: number,
	kind: "Story" | "World" | "Raid",
	maxHealth: number,
	healthPerExtraPlayer: number, -- fraction added per additional player (co-op scaling)
	maxPosture: number,
	postureRegen: number,
	postureBrokenSeconds: number,
	walkSpeed: number,
	moves: { [string]: BossMove },
	phases: { BossPhaseDef },
	idleBetweenMoves: number,
	rewards: { ember: number, xp: number, jadeFirstClear: number },
	modelId: number,
	look: EnemyConfig.RigLook?,
}

local BossConfig = {}

local PLACEHOLDER_ANIM = "rbxassetid://0"

BossConfig.Bosses = {
	rust_tiger = {
		name = "Rust Tiger",
		title = "Warden of the Cracked Bell",
		chapter = 0,
		kind = "Story",
		maxHealth = 1400,
		healthPerExtraPlayer = 0.6,
		maxPosture = 220,
		postureRegen = 6,
		postureBrokenSeconds = 3.5,
		walkSpeed = 18,
		moves = {
			claw_swipe = { name = "Corroded Swipe", damage = 14, postureDamage = 16, windup = 0.5, active = 0.15, recovery = 0.55, range = 10, arcDegrees = 110, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			pounce = { name = "Iron Pounce", damage = 22, postureDamage = 26, windup = 0.75, active = 0.25, recovery = 0.9, range = 28, minRange = 12, arcDegrees = 50, weight = 2, cooldown = 6, animationId = PLACEHOLDER_ANIM },
			flurry = { name = "Rattling Flurry", damage = 9, postureDamage = 12, windup = 0.4, active = 0.9, recovery = 0.7, range = 10, arcDegrees = 100, weight = 2, cooldown = 7, hits = 4, animationId = PLACEHOLDER_ANIM },
			tail_sweep = { name = "Chain-Tail Sweep", damage = 16, postureDamage = 10, windup = 0.65, active = 0.2, recovery = 0.6, range = 12, arcDegrees = 360, weight = 1, cooldown = 9, perilous = true, animationId = PLACEHOLDER_ANIM },
			rust_roar = { name = "Rust Roar", damage = 10, postureDamage = 30, windup = 1.0, active = 0.4, recovery = 1.0, range = 18, arcDegrees = 360, weight = 1, cooldown = 14, animationId = PLACEHOLDER_ANIM },
			corroded_charge = { name = "Corroded Charge", damage = 28, postureDamage = 20, windup = 0.9, active = 0.6, recovery = 1.2, range = 40, minRange = 15, arcDegrees = 30, weight = 2, cooldown = 10, perilous = true, animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "claw_swipe", "pounce", "flurry", "tail_sweep" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.5, moves = { "claw_swipe", "pounce", "flurry", "tail_sweep", "rust_roar", "corroded_charge" }, speedMultiplier = 1.2, enrage = true, transitionSeconds = 2.5 },
		},
		idleBetweenMoves = 0.8,
		rewards = { ember = 300, xp = 400, jadeFirstClear = 25 },
		modelId = 0, -- TODO(Studio/Agent C): Rust Tiger rig
		look = { skin = { 220, 130, 50 }, body = { 200, 110, 40 }, legs = { 60, 40, 30 }, headwear = "Horns", accent = { 40, 30, 25 }, weapon = "dao_rustcutter", scale = 2.2 },
	},
	-- Chapter 1: Rustwood Pass
	hollow_abbot = {
		name = "Hollow Abbot",
		title = "Keeper of the Silent Bell",
		chapter = 1,
		kind = "Story",
		maxHealth = 5200,
		healthPerExtraPlayer = 0.6,
		maxPosture = 420,
		postureRegen = 8,
		postureBrokenSeconds = 4,
		walkSpeed = 16,
		moves = {
			staff_sweep = { name = "Rattan Sweep", damage = 40, postureDamage = 30, windup = 0.45, active = 0.15, recovery = 0.5, range = 11, arcDegrees = 140, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			bell_palm = { name = "Silent Bell Palm", damage = 55, postureDamage = 60, windup = 0.7, active = 0.15, recovery = 0.7, range = 8, arcDegrees = 50, weight = 2, cooldown = 6, animationId = PLACEHOLDER_ANIM },
			pilgrim_dash = { name = "Pilgrim's Dash", damage = 50, postureDamage = 35, windup = 0.6, active = 0.3, recovery = 0.8, range = 26, arcDegrees = 40, weight = 2, cooldown = 8, minRange = 12, animationId = PLACEHOLDER_ANIM },
			hollow_chant = { name = "Hollow Chant", damage = 45, postureDamage = 20, windup = 1.2, active = 0.5, recovery = 1.0, range = 16, arcDegrees = 360, weight = 1, cooldown = 14, perilous = true, animationId = PLACEHOLDER_ANIM },
			prayer_beads = { name = "Hundred Prayer Beads", damage = 14, postureDamage = 10, windup = 0.5, active = 1.0, recovery = 0.6, range = 12, arcDegrees = 90, weight = 2, cooldown = 10, hits = 5, animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "staff_sweep", "bell_palm", "pilgrim_dash", "prayer_beads" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.45, moves = { "staff_sweep", "bell_palm", "pilgrim_dash", "prayer_beads", "hollow_chant" }, speedMultiplier = 1.15, enrage = true, transitionSeconds = 2.5 },
		},
		idleBetweenMoves = 0.7,
		rewards = { ember = 1200, xp = 1500, jadeFirstClear = 30 },
		modelId = 0, -- TODO(Studio/Agent C)
		look = { skin = { 170, 165, 160 }, body = { 90, 90, 100 }, legs = { 70, 70, 80 }, headwear = "Hood", accent = { 200, 190, 170 }, weapon = "staff_bellringer", scale = 1.9 },
	},
	twin_cinder_sisters = {
		name = "Twin Cinder Sisters",
		title = "Embers That Never Part",
		chapter = 1,
		kind = "Story",
		maxHealth = 6000,
		healthPerExtraPlayer = 0.6,
		maxPosture = 460,
		postureRegen = 7,
		postureBrokenSeconds = 3.5,
		walkSpeed = 20,
		moves = {
			cinder_fan = { name = "Cinder Fan", damage = 38, postureDamage = 26, windup = 0.4, active = 0.15, recovery = 0.45, range = 10, arcDegrees = 120, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			ember_crossing = { name = "Ember Crossing", damage = 16, postureDamage = 12, windup = 0.45, active = 0.9, recovery = 0.6, range = 10, arcDegrees = 100, weight = 2, cooldown = 7, hits = 4, animationId = PLACEHOLDER_ANIM },
			sister_swap = { name = "Sister Swap", damage = 48, postureDamage = 30, windup = 0.55, active = 0.25, recovery = 0.7, range = 24, arcDegrees = 40, weight = 2, cooldown = 8, minRange = 10, animationId = PLACEHOLDER_ANIM },
			ash_veil = { name = "Ash Veil", damage = 52, postureDamage = 15, windup = 1.0, active = 0.4, recovery = 1.0, range = 14, arcDegrees = 360, weight = 1, cooldown = 13, perilous = true, animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "cinder_fan", "ember_crossing", "sister_swap" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.5, moves = { "cinder_fan", "ember_crossing", "sister_swap", "ash_veil" }, speedMultiplier = 1.2, enrage = true, transitionSeconds = 3 },
		},
		idleBetweenMoves = 0.7,
		rewards = { ember = 1400, xp = 1700, jadeFirstClear = 30 },
		modelId = 0, -- TODO(Studio/Agent C)
		look = { skin = { 230, 190, 160 }, body = { 170, 40, 35 }, legs = { 90, 25, 25 }, headwear = "Hair", accent = { 255, 140, 60 }, weapon = "fan_iron_lotus", glow = { 255, 120, 50 }, scale = 1.7 },
	},
	rustwood_matriarch = {
		name = "Rustwood Matriarch",
		title = "Mother of the Corroded Grove",
		chapter = 1,
		kind = "Story",
		maxHealth = 7400,
		healthPerExtraPlayer = 0.6,
		maxPosture = 560,
		postureRegen = 6,
		postureBrokenSeconds = 4,
		walkSpeed = 14,
		moves = {
			root_lash = { name = "Root Lash", damage = 44, postureDamage = 28, windup = 0.5, active = 0.2, recovery = 0.6, range = 14, arcDegrees = 120, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			thorn_volley = { name = "Thorn Volley", damage = 12, postureDamage = 8, windup = 0.6, active = 1.0, recovery = 0.6, range = 30, arcDegrees = 40, weight = 2, cooldown = 9, hits = 6, minRange = 10, animationId = PLACEHOLDER_ANIM },
			trampling_charge = { name = "Trampling Charge", damage = 70, postureDamage = 40, windup = 0.9, active = 0.6, recovery = 1.2, range = 40, arcDegrees = 30, weight = 2, cooldown = 11, minRange = 15, perilous = true, animationId = PLACEHOLDER_ANIM },
			sap_burst = { name = "Sap Burst", damage = 40, postureDamage = 45, windup = 1.0, active = 0.3, recovery = 0.9, range = 13, arcDegrees = 360, weight = 1, cooldown = 12, animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "root_lash", "thorn_volley", "trampling_charge" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.5, moves = { "root_lash", "thorn_volley", "trampling_charge", "sap_burst" }, speedMultiplier = 1.15, enrage = true, transitionSeconds = 3 },
		},
		idleBetweenMoves = 0.7,
		rewards = { ember = 1700, xp = 2000, jadeFirstClear = 35 },
		modelId = 0, -- TODO(Studio/Agent C)
		look = { skin = { 110, 130, 80 }, body = { 80, 70, 45 }, legs = { 60, 50, 35 }, headwear = "Horns", accent = { 140, 160, 90 }, weapon = "spear_crimson_tassel", scale = 2.5 },
	},
	gatekeeper_of_rust = {
		name = "Gatekeeper of Rust",
		title = "First of the Nine Gates",
		chapter = 1,
		kind = "Story",
		maxHealth = 11000,
		healthPerExtraPlayer = 0.6,
		maxPosture = 700,
		postureRegen = 6,
		postureBrokenSeconds = 4.5,
		walkSpeed = 16,
		moves = {
			gate_cleave = { name = "Gate Cleave", damage = 55, postureDamage = 38, windup = 0.55, active = 0.2, recovery = 0.6, range = 12, arcDegrees = 130, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			chain_whip = { name = "Chain Whip", damage = 40, postureDamage = 26, windup = 0.5, active = 0.2, recovery = 0.6, range = 20, arcDegrees = 60, weight = 2, cooldown = 6, minRange = 8, animationId = PLACEHOLDER_ANIM },
			rust_rush = { name = "Rust Rush", damage = 65, postureDamage = 40, windup = 0.75, active = 0.5, recovery = 1.0, range = 36, arcDegrees = 30, weight = 2, cooldown = 9, minRange = 14, animationId = PLACEHOLDER_ANIM },
			gate_slam = { name = "Gate Slam", damage = 80, postureDamage = 80, windup = 1.1, active = 0.2, recovery = 1.1, range = 10, arcDegrees = 70, weight = 1, cooldown = 10, animationId = PLACEHOLDER_ANIM },
			iron_toll = { name = "Iron Toll", damage = 60, postureDamage = 25, windup = 1.3, active = 0.5, recovery = 1.2, range = 20, arcDegrees = 360, weight = 1, cooldown = 15, perilous = true, animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "gate_cleave", "chain_whip", "gate_slam" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.66, moves = { "gate_cleave", "chain_whip", "gate_slam", "rust_rush" }, speedMultiplier = 1.1, transitionSeconds = 2.5 },
			{ hpThreshold = 0.33, moves = { "gate_cleave", "chain_whip", "gate_slam", "rust_rush", "iron_toll" }, speedMultiplier = 1.25, enrage = true, transitionSeconds = 3 },
		},
		idleBetweenMoves = 0.7,
		rewards = { ember = 2600, xp = 3000, jadeFirstClear = 50 },
		modelId = 0, -- TODO(Studio/Agent C)
		look = { skin = { 90, 90, 100 }, body = { 60, 60, 70 }, legs = { 45, 45, 55 }, headwear = "Helm", accent = { 160, 80, 40 }, weapon = "gb_gatebreaker", scale = 2.7 },
	},
	-- World bosses (WorldBossService) ---------------------------------------------------------
	hollow_carillon = {
		name = "The Hollow Carillon",
		title = "A Bell That Rings Itself",
		chapter = 0,
		kind = "World",
		maxHealth = 9000,
		healthPerExtraPlayer = 0.5,
		maxPosture = 900,
		postureRegen = 10,
		postureBrokenSeconds = 5,
		walkSpeed = 10,
		moves = {
			clapper_sweep = { name = "Clapper Sweep", damage = 26, postureDamage = 24, windup = 0.6, active = 0.25, recovery = 0.6, range = 14, arcDegrees = 150, weight = 4, cooldown = 0, animationId = PLACEHOLDER_ANIM },
			chain_lash = { name = "Rusted Chain Lash", damage = 22, postureDamage = 18, windup = 0.5, active = 0.3, recovery = 0.6, range = 26, minRange = 8, arcDegrees = 50, weight = 2, cooldown = 6, animationId = PLACEHOLDER_ANIM },
			resonance = { name = "Resonance", damage = 9, postureDamage = 14, windup = 0.6, active = 1.2, recovery = 0.8, range = 16, arcDegrees = 360, weight = 2, cooldown = 10, hits = 6, animationId = PLACEHOLDER_ANIM },
			toll_wave = { name = "Toll Wave", damage = 18, postureDamage = 45, windup = 1.0, active = 0.4, recovery = 1.0, range = 32, arcDegrees = 360, weight = 1, cooldown = 14, animationId = PLACEHOLDER_ANIM },
			bell_slam = { name = "Falling Bell", damage = 48, postureDamage = 20, windup = 1.4, active = 0.3, recovery = 1.4, range = 18, arcDegrees = 360, weight = 1, cooldown = 16, perilous = true, animationId = PLACEHOLDER_ANIM },
		},
		phases = {
			{ hpThreshold = 1.0, moves = { "clapper_sweep", "chain_lash", "resonance" }, speedMultiplier = 1, transitionSeconds = 0 },
			{ hpThreshold = 0.6, moves = { "clapper_sweep", "chain_lash", "resonance", "toll_wave" }, speedMultiplier = 1.1, transitionSeconds = 3 },
			{ hpThreshold = 0.3, moves = { "clapper_sweep", "chain_lash", "resonance", "toll_wave", "bell_slam" }, speedMultiplier = 1.25, enrage = true, transitionSeconds = 3 },
		},
		idleBetweenMoves = 0.9,
		rewards = { ember = 1500, xp = 1200, jadeFirstClear = 40 },
		modelId = 0, -- TODO(Studio/Agent C): giant bell construct rig
		look = { skin = { 150, 115, 60 }, body = { 130, 95, 45 }, legs = { 90, 65, 35 }, headwear = "Bell", accent = { 255, 200, 120 }, weapon = "staff_bellringer", glow = { 255, 190, 110 }, scale = 3.4 },
	},
} :: { [string]: BossDef }

return BossConfig
