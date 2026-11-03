--!strict
-- Types: the frozen data contracts shared by server, client and config.
-- NOTE: WRAITHSTEEL_AGENT_GUIDE.md was not present in the repo during cloud/night-1, so these
-- types are a reconstruction of §8.3 from the task brief. Reconcile against the guide before
-- changing any field; once reconciled, treat this file as FROZEN (add fields, never rename).

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

-- Spirit mutations are rolled on hatch, independent of rarity.
export type Mutation = "None" | "Gilded" | "Ashen" | "Moonlit" | "Stormforged" | "Hollow"

export type OddsEntry = {
	id: string,
	weight: number,
	-- 0 = luck does not affect this entry, 1 = luck fully multiplies it. Defaults to 0.
	luckAffinity: number?,
}

export type OddsResult = {
	id: string,
	chance: number, -- exact probability 0..1 (used by server rolls)
	percent: number, -- display percent rounded to 2dp; all percents sum to exactly 100
}

export type SpiritInstance = {
	uid: string,
	id: string, -- key in SpiritConfig.Spirits
	rarity: Rarity,
	mutation: Mutation,
	level: number,
	xp: number,
	fusedCount: number, -- how many fusions produced this spirit lineage (cosmetic star)
	locked: boolean, -- locked spirits cannot be fused/traded/released
	obtainedAt: number,
}

export type QuestState = {
	id: string,
	progress: number,
	claimed: boolean,
	startedAt: number,
}

export type ExpeditionState = {
	id: string,
	spiritUids: { string },
	startedAt: number,
	endsAt: number,
}

export type ProfileData = {
	dataVersion: number,

	-- Currencies / progression
	ember: number, -- soft currency
	jade: number, -- premium currency (earnable in-game and purchasable)
	xp: number,
	level: number,

	-- Story
	chapter: number, -- 0 = Prologue, 1..5
	stage: number,
	bossesDefeated: { [string]: number }, -- bossId -> clear count
	tutorialDone: boolean,

	-- Combat loadout
	weapons: { [string]: boolean }, -- weaponId -> owned
	equippedWeapon: string,
	fightingStyle: string, -- StyleConfig id
	spellLoadout: { string }, -- SpellConfig ids per art slot ("" = empty); added in dataVersion 3
	waystones: { [string]: boolean }, -- attuned waystones (fast travel); added in dataVersion 4
	respawnWaystone: string, -- where you respawn (last waystone you rested at)
	saga: { quest: number, step: number, progress: number, started: boolean }, -- main questline (SagaLogic)
	skills: { [string]: number }, -- skill tree: skillId -> rank (SkillConfig); added in dataVersion 8
	shortcuts: { [string]: boolean }, -- opened shortcut gates (MapConfig.Shortcuts); dataVersion 9
	relics: { [string]: boolean }, -- Ashen Relics found (MapConfig.Relics); dataVersion 9

	-- Spirits
	spirits: { [string]: SpiritInstance }, -- uid -> instance
	equippedSpirits: { string }, -- uids
	spiritSlots: number,
	spiritStorage: number,
	nextUid: number,
	lanternPity: { [string]: number }, -- lanternId -> rolls since last pity-qualifying rarity
	hatchedTotal: number,
	freeLanterns: { [string]: number }, -- lanternId -> free opens (from rewards/codes; Ember lanterns only)

	-- Expeditions / offline
	expeditions: { [string]: ExpeditionState }, -- slotId -> state
	lastSeenAt: number,

	-- Rewards
	lastDailyDay: number,
	dailyStreak: number,
	playtimeDay: number,
	playtimeSeconds: number,
	playtimeClaimed: { [string]: boolean },

	-- Quests
	quests: { [string]: QuestState },
	questDay: number,

	-- Codes
	codesRedeemed: { [string]: boolean },

	-- Monetization
	receipts: { [string]: boolean }, -- purchaseId -> granted
	receiptOrder: { string }, -- FIFO used to cap `receipts`
	giftedPasses: { [string]: boolean }, -- passKey -> true
	giftMessagesSeen: { [string]: boolean },
	giftTokens: { [string]: number }, -- passKey -> undelivered gifts the buyer can still send
	boosts: { [string]: number }, -- boostId -> expiresAt (os.time)
	robuxSpent: number,

	-- Analytics
	funnelSteps: { [string]: boolean },

	-- Settings
	settings: { [string]: any },
}

export type CombatAction =
	"LightAttack"
	| "HeavyAttack"
	| "Parry"
	| "Dodge"
	| "Skill1"
	| "Skill2"
	| "Ultimate"
	| "SpiritCall"

export type CombatRequest = {
	action: CombatAction,
	seq: number, -- client sequence number, strictly increasing per player
	aim: Vector3?, -- unit look direction; server re-validates
	comboIndex: number?,
}

export type CombatOutcome = "Hit" | "Blocked" | "Parried" | "Dodged" | "PostureBroken" | "Rejected"

export type DamageEvent = {
	sourceId: string,
	targetId: string,
	damage: number,
	postureDamage: number,
	outcome: CombatOutcome,
	moveId: string,
}

export type Team = "Players" | "Enemies"

export type AttackToken = {
	combatantId: string,
	targetId: string,
	grantedAt: number,
	expiresAt: number,
}

export type BossPhase = {
	hpThreshold: number, -- phase starts when hp fraction <= this
	moves: { string },
	enrage: boolean?,
}

return {}
