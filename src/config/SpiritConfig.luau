--!strict
-- SpiritConfig: rarities, mutations and the Spirit roster (Prologue + Chapter 1 for now).
-- All names are original to WRAITHSTEEL. Owner: Agent B (Bladesmith).
-- TODO(Studio/Agent D): model + icon asset ids are placeholders (0) until models are built.

export type RarityDef = {
	order: number,
	color: Color3?,
	powerMultiplier: number,
	luckAffinity: number, -- how strongly Luck boosts this rarity in Odds
	fuseCount: number?, -- spirits of this rarity needed to fuse up; nil = cannot fuse
	fuseCostEmber: number?,
}

export type MutationDef = {
	order: number,
	powerMultiplier: number,
	weight: number, -- rolled independently on every hatch
	luckAffinity: number,
}

export type SpiritDef = {
	name: string,
	rarity: string, -- base rarity it hatches at
	basePower: number,
	chapter: number,
	element: string,
	stats: { [string]: number }, -- stat bonuses at base rarity, level 1 (Shared/SpiritStats scales them)
	ability: string, -- SpiritConfig.Abilities id: auto-cast in combat, all at once on Spirit Burst
	flavor: string,
	modelId: number,
	iconId: number,
	visual: SpiritVisual, -- part-built companion model (Shared/SpiritModels)
}

-- Companion combat ability (SpiritAbilityService casts it; SpiritFollowerController shows it).
--   Bolt   - fires at the nearest enemy           Dive  - swoops onto the target, small blast
--   Pounce - leaps at the target (knockback)      Heal  - heals the owner below `threshold`
--   Shield - absorb shield on the owner           Nova  - blast around the owner
--   Chain  - lightning jumping between enemies    Bloom - blast around the owner + heal
--   Toll   - huge bell blast on the target
export type AbilityDef = {
	name: string,
	text: string,
	kind: "Bolt" | "Dive" | "Pounce" | "Heal" | "Shield" | "Nova" | "Chain" | "Bloom" | "Toll",
	cooldown: number,
	damage: number?, -- base damage before player power / spirit strength scaling
	posture: number?,
	range: number?, -- studs from the owner to the target
	radius: number?, -- blast radius
	knockback: number?,
	chains: number?,
	heal: number?, -- fraction of the owner's max health
	shield: number?, -- fraction of the owner's max health
	seconds: number?, -- shield duration
	threshold: number?, -- Heal/Shield: owner health fraction at or below which it auto-casts
}

export type SpiritVisual = {
	shape: "Winged" | "Beast" | "Fish" | "Wraith",
	color: { number }, -- body RGB
	accent: { number }, -- glow/detail RGB
	size: number,
	features: { string }?, -- Beast details: Ears, BushyTail, Toad, Tusks, Scales, Horns, Mane
	aura: ("Embers" | "Sparks" | "Mist" | "Leaves" | "Bubbles" | "Void" | "Glimmer")?, -- particle aura
	crest: ("Flame" | "Halo" | "Crown" | "Orbit")?, -- floating detail above the companion
}

local SpiritConfig = {}

local function rgb(r: number, g: number, b: number): Color3?
	-- Color3 does not exist in plain-Luau tests; keep config loadable there.
	if Color3 ~= nil then
		return Color3.fromRGB(r, g, b)
	end
	return nil
end

SpiritConfig.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

SpiritConfig.Rarities = {
	Common = { order = 1, color = rgb(190, 190, 190), powerMultiplier = 1, luckAffinity = 0, fuseCount = 3, fuseCostEmber = 25 },
	Uncommon = { order = 2, color = rgb(110, 200, 120), powerMultiplier = 1.6, luckAffinity = 0.25, fuseCount = 3, fuseCostEmber = 120 },
	Rare = { order = 3, color = rgb(80, 150, 240), powerMultiplier = 2.6, luckAffinity = 0.6, fuseCount = 3, fuseCostEmber = 600 },
	Epic = { order = 4, color = rgb(170, 90, 230), powerMultiplier = 4.5, luckAffinity = 1, fuseCount = 4, fuseCostEmber = 3000 },
	Legendary = { order = 5, color = rgb(245, 180, 60), powerMultiplier = 8, luckAffinity = 1, fuseCount = 5, fuseCostEmber = 20000 },
	Mythic = { order = 6, color = rgb(235, 70, 90), powerMultiplier = 15, luckAffinity = 1, fuseCount = nil, fuseCostEmber = nil },
} :: { [string]: RarityDef }

-- Mutation odds are shown in the odds UI alongside spirit odds (they are part of the roll).
SpiritConfig.MutationOrder = { "None", "Ashen", "Gilded", "Moonlit", "Stormforged", "Hollow" }
SpiritConfig.Mutations = {
	None = { order = 1, powerMultiplier = 1, weight = 9000, luckAffinity = 0 },
	Ashen = { order = 2, powerMultiplier = 1.25, weight = 500, luckAffinity = 0.5 },
	Gilded = { order = 3, powerMultiplier = 1.5, weight = 300, luckAffinity = 0.75 },
	Moonlit = { order = 4, powerMultiplier = 1.75, weight = 150, luckAffinity = 1 },
	Stormforged = { order = 5, powerMultiplier = 2.25, weight = 45, luckAffinity = 1 },
	Hollow = { order = 6, powerMultiplier = 3, weight = 5, luckAffinity = 1 },
} :: { [string]: MutationDef }

SpiritConfig.Spirits = {
	-- Prologue: The Cracked Bell
	lantern_moth = {
		name = "Lantern Moth", rarity = "Common", basePower = 3, chapter = 0, element = "Flame",
		stats = { Attack = 0.04, QiRegen = 0.08 }, ability = "wickfire_dart",
		flavor = "Drawn to every flame, it carries a spark home in its wings.",
		modelId = 0, iconId = 0,
		visual = { shape = "Winged", color = { 230, 200, 140 }, accent = { 255, 170, 60 }, size = 1, aura = "Embers" },
	},
	ember_sparrow = {
		name = "Ember Sparrow", rarity = "Common", basePower = 4, chapter = 0, element = "Flame",
		stats = { CritChance = 0.03, Attack = 0.03 }, ability = "cinder_dive",
		flavor = "Nests in chimney ash and dives like a falling coal.",
		modelId = 0, iconId = 0,
		visual = { shape = "Winged", color = { 200, 90, 50 }, accent = { 255, 140, 60 }, size = 0.9, aura = "Embers", crest = "Flame" },
	},
	reed_fox = {
		name = "Reed Fox", rarity = "Uncommon", basePower = 6, chapter = 0, element = "Wind",
		stats = { EmberFind = 0.08, Haste = 0.04 }, ability = "reed_pounce",
		flavor = "Sniffs out dropped Ember and bites the ankles of anyone who argues.",
		modelId = 0, iconId = 0,
		visual = { shape = "Beast", color = { 210, 140, 70 }, accent = { 250, 240, 220 }, features = { "Ears", "BushyTail" }, size = 1, aura = "Leaves" },
	},
	inkcap_toad = {
		name = "Inkcap Toad", rarity = "Uncommon", basePower = 7, chapter = 0, element = "Water",
		stats = { Health = 0.08, Lifesteal = 0.01 }, ability = "dew_croak",
		flavor = "Its croak shakes healing dew from the air.",
		modelId = 0, iconId = 0,
		visual = { shape = "Beast", color = { 60, 70, 90 }, accent = { 120, 200, 220 }, features = { "Toad" }, size = 0.9, aura = "Bubbles" },
	},
	brass_carp = {
		name = "Brass Carp", rarity = "Rare", basePower = 12, chapter = 0, element = "Metal",
		stats = { Guard = 0.08, Health = 0.06 }, ability = "brass_scale_ward",
		flavor = "Swims through the air in a slow circle, scales ringing like coins.",
		modelId = 0, iconId = 0,
		visual = { shape = "Fish", color = { 210, 160, 70 }, accent = { 250, 220, 140 }, size = 1, aura = "Glimmer", crest = "Orbit" },
	},
	-- Chapter 1: Rustwood Pass
	mist_heron = {
		name = "Mist Heron", rarity = "Rare", basePower = 16, chapter = 1, element = "Water",
		stats = { Haste = 0.08, QiRegen = 0.12 }, ability = "mist_veil",
		flavor = "Where it lands, the fog thickens and blades go astray.",
		modelId = 0, iconId = 0,
		visual = { shape = "Winged", color = { 220, 230, 240 }, accent = { 140, 190, 230 }, size = 1.2, aura = "Mist" },
	},
	rustwood_boar = {
		name = "Rustwood Boar", rarity = "Uncommon", basePower = 9, chapter = 1, element = "Wood",
		stats = { Posture = 0.1, Health = 0.05 }, ability = "tusk_charge",
		flavor = "Has never once walked around a tree.",
		modelId = 0, iconId = 0,
		visual = { shape = "Beast", color = { 120, 70, 45 }, accent = { 230, 220, 200 }, features = { "Tusks", "Ears" }, size = 1.15, aura = "Leaves" },
	},
	thunder_pangolin = {
		name = "Thunder Pangolin", rarity = "Epic", basePower = 30, chapter = 1, element = "Thunder",
		stats = { CritChance = 0.06, CritDamage = 0.25 }, ability = "rolling_thunder",
		flavor = "Curls into a ball, rolls downhill, and arrives as a storm.",
		modelId = 0, iconId = 0,
		visual = { shape = "Beast", color = { 80, 90, 120 }, accent = { 140, 200, 255 }, features = { "Scales" }, size = 1.1, aura = "Sparks", crest = "Orbit" },
	},
	jade_qilin_cub = {
		name = "Jade Qilin Cub", rarity = "Legendary", basePower = 60, chapter = 1, element = "Wood",
		stats = { Luck = 0.08, Health = 0.12, Attack = 0.06 }, ability = "jade_bloom",
		flavor = "Flowers open in its hoofprints. Fortune follows close behind.",
		modelId = 0, iconId = 0,
		visual = { shape = "Beast", color = { 80, 190, 140 }, accent = { 240, 200, 90 }, features = { "Horns", "Mane", "BushyTail" }, size = 1.2, aura = "Glimmer", crest = "Crown" },
	},
	ninth_bell_wraith = {
		name = "Ninth-Bell Wraith", rarity = "Mythic", basePower = 120, chapter = 1, element = "Void",
		stats = { Attack = 0.15, Posture = 0.2, Lifesteal = 0.03 }, ability = "ninth_toll",
		flavor = "The echo of a bell that was never rung. It rings for you now.",
		modelId = 0, iconId = 0,
		visual = { shape = "Wraith", color = { 40, 30, 60 }, accent = { 200, 120, 255 }, size = 1.3, aura = "Void", crest = "Halo" },
	},
} :: { [string]: SpiritDef }

-- Companion abilities (numbers only; SpiritAbilityService applies them).
SpiritConfig.Abilities = {
	wickfire_dart = { name = "Wickfire Dart", text = "Flicks a dart of flame at your target.", kind = "Bolt", cooldown = 4, damage = 14, posture = 4, range = 40 },
	cinder_dive = { name = "Cinder Dive", text = "Dives onto your target and bursts into cinders.", kind = "Dive", cooldown = 6, damage = 20, posture = 8, range = 35, radius = 7 },
	reed_pounce = { name = "Reed Pounce", text = "Leaps at your target and knocks it off balance.", kind = "Pounce", cooldown = 7, damage = 16, posture = 14, range = 30, knockback = 18 },
	dew_croak = { name = "Dew Croak", text = "Heals you when you are hurt.", kind = "Heal", cooldown = 12, heal = 0.14, threshold = 0.7 },
	brass_scale_ward = { name = "Brass Scale Ward", text = "Wraps you in a ringing brass shield during fights.", kind = "Shield", cooldown = 15, shield = 0.2, seconds = 6, threshold = 0.95 },
	mist_veil = { name = "Mist Veil", text = "Bursts into blinding mist around you, battering posture.", kind = "Nova", cooldown = 10, damage = 14, posture = 18, radius = 12 },
	tusk_charge = { name = "Tusk Charge", text = "Charges through your target, hurling it away.", kind = "Pounce", cooldown = 8, damage = 24, posture = 24, range = 30, knockback = 42 },
	rolling_thunder = { name = "Rolling Thunder", text = "Lightning that leaps between up to 4 enemies.", kind = "Chain", cooldown = 8, damage = 28, posture = 12, range = 40, chains = 4 },
	jade_bloom = { name = "Jade Bloom", text = "A blooming blast that hurts enemies and heals you.", kind = "Bloom", cooldown = 12, damage = 32, posture = 14, radius = 14, heal = 0.12 },
	ninth_toll = { name = "Ninth Toll", text = "Drops a phantom bell on your target. Shatters posture.", kind = "Toll", cooldown = 14, damage = 60, posture = 70, range = 40, radius = 14 },
} :: { [string]: AbilityDef }

-- Stats: order shown in the UI, labels, and hard caps for the equipped total.
-- All values are fractions (0.05 = +5%).
SpiritConfig.StatOrder = { "Attack", "CritChance", "CritDamage", "Health", "Lifesteal", "Posture", "Guard", "Haste", "QiRegen", "EmberFind", "Luck" }
SpiritConfig.StatInfo = {
	Attack = { label = "Attack", cap = 1.0 },
	CritChance = { label = "Crit Chance", cap = 0.6 },
	CritDamage = { label = "Crit Damage", cap = 2.5 },
	Health = { label = "Health", cap = 1.0 },
	Lifesteal = { label = "Lifesteal", cap = 0.15 },
	Posture = { label = "Posture Damage", cap = 0.8 },
	Guard = { label = "Guard", cap = 0.5 }, -- less posture damage taken
	Haste = { label = "Cooldown Speed", cap = 0.4 }, -- dash, spell and spirit cooldowns
	QiRegen = { label = "Qi Regen", cap = 1.0 },
	EmberFind = { label = "Ember Find", cap = 1.5 },
	Luck = { label = "Luck", cap = 0.5 },
} :: { [string]: { label: string, cap: number } }

-- Stat strength: rarity above the base adds sqrt(power ratio); levels add a little each.
SpiritConfig.StatPerLevel = 0.02
SpiritConfig.MutationStatMultiplier = { None = 1, Ashen = 1.1, Gilded = 1.15, Moonlit = 1.2, Stormforged = 1.3, Hollow = 1.5 } :: { [string]: number }
-- Every mutation also adds its own flat bonus stat.
SpiritConfig.MutationBonus = {
	Ashen = { stat = "Guard", value = 0.04 },
	Gilded = { stat = "EmberFind", value = 0.1 },
	Moonlit = { stat = "QiRegen", value = 0.15 },
	Stormforged = { stat = "CritChance", value = 0.04 },
	Hollow = { stat = "Lifesteal", value = 0.03 },
} :: { [string]: { stat: string, value: number } }

-- Auto-casting in combat and the Spirit Burst (T): every companion casts at once, stronger.
SpiritConfig.AutoCast = { tick = 0.25, engageRange = 32, combatWindow = 6, gap = 0.5 }
SpiritConfig.Burst = { cooldown = 25, multiplier = 1.6 }
SpiritConfig.CombatXpShare = 0.5 -- equipped spirits earn this share of an enemy's XP reward

-- Mutation looks for companion models: tint over the body color + glow color.
SpiritConfig.MutationLooks = {
	Ashen = { tint = { 150, 150, 150 }, tintAmount = 0.6, glow = { 200, 200, 200 } },
	Gilded = { tint = { 255, 205, 80 }, tintAmount = 0.55, glow = { 255, 215, 100 } },
	Moonlit = { tint = { 200, 220, 255 }, tintAmount = 0.5, glow = { 170, 200, 255 } },
	Stormforged = { tint = { 90, 140, 255 }, tintAmount = 0.45, glow = { 120, 190, 255 } },
	Hollow = { tint = { 30, 20, 40 }, tintAmount = 0.7, glow = { 190, 90, 255 } },
} :: { [string]: { tint: { number }, tintAmount: number, glow: { number } } }

-- Companion followers (SpiritFollowerController).
SpiritConfig.Follow = {
	distance = 4.5, -- studs behind the player
	spacing = 2.6, -- between companions
	height = 3, -- above the ground-ish (relative to the root)
	bob = 0.35,
	smoothing = 8, -- higher = snappier follow
	cullDistance = 180, -- companions of players farther than this from the camera are hidden
}

SpiritConfig.LevelCap = 50
SpiritConfig.PowerPerLevel = 0.04 -- +4% of base per level

-- Spirit XP needed to go from `level` to `level + 1` (XP comes from expeditions).
function SpiritConfig.XpToNext(level: number): number
	return math.floor(50 * level ^ 1.4)
end

-- Power of one spirit instance.
function SpiritConfig.PowerOf(id: string, rarity: string, mutation: string, level: number): number
	local def = SpiritConfig.Spirits[id]
	local r = SpiritConfig.Rarities[rarity]
	local m = SpiritConfig.Mutations[mutation]
	if def == nil or r == nil or m == nil then
		return 0
	end
	local rarityScale = r.powerMultiplier / SpiritConfig.Rarities[def.rarity].powerMultiplier
	return def.basePower * rarityScale * m.powerMultiplier * (1 + (level - 1) * SpiritConfig.PowerPerLevel)
end

return SpiritConfig
