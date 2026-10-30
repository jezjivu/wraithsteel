--!strict
-- BossConfig: story/world/raid bosses. Owner: Agent C (Warden).
-- Bosses run the shared BossStateMachine (ServerScriptService.Logic.BossStateMachine).
-- Only the Prologue boss (Rust Tiger) is fully specified; the other 20 are listed in
-- ChapterConfig and get entries here in Phase 2/3.

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
	},
} :: { [string]: BossDef }

return BossConfig
