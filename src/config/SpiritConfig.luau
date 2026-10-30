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
	passive: string?, -- passive id handled by SpiritService
	modelId: number,
	iconId: number,
	visual: SpiritVisual, -- part-built companion model (Shared/SpiritModels)
}

export type SpiritVisual = {
	shape: "Winged" | "Beast" | "Fish" | "Wraith",
	color: { number }, -- body RGB
	accent: { number }, -- glow/detail RGB
	size: number,
	features: { string }?, -- Beast details: Ears, BushyTail, Toad, Tusks, Scales, Horns, Mane
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
	lantern_moth = { name = "Lantern Moth", rarity = "Common", basePower = 3, chapter = 0, element = "Flame", passive = nil, modelId = 0, iconId = 0, visual = { shape = "Winged", color = { 230, 200, 140 }, accent = { 255, 170, 60 }, size = 1 } },
	ember_sparrow = { name = "Ember Sparrow", rarity = "Common", basePower = 4, chapter = 0, element = "Flame", passive = nil, modelId = 0, iconId = 0, visual = { shape = "Winged", color = { 200, 90, 50 }, accent = { 255, 140, 60 }, size = 0.9 } },
	reed_fox = { name = "Reed Fox", rarity = "Uncommon", basePower = 6, chapter = 0, element = "Wind", passive = "ember_find_small", modelId = 0, iconId = 0, visual = { shape = "Beast", color = { 210, 140, 70 }, accent = { 250, 240, 220 }, features = { "Ears", "BushyTail" }, size = 1 } },
	inkcap_toad = { name = "Inkcap Toad", rarity = "Uncommon", basePower = 7, chapter = 0, element = "Water", passive = nil, modelId = 0, iconId = 0, visual = { shape = "Beast", color = { 60, 70, 90 }, accent = { 120, 200, 220 }, features = { "Toad" }, size = 0.9 } },
	brass_carp = { name = "Brass Carp", rarity = "Rare", basePower = 12, chapter = 0, element = "Metal", passive = "posture_guard_small", modelId = 0, iconId = 0, visual = { shape = "Fish", color = { 210, 160, 70 }, accent = { 250, 220, 140 }, size = 1 } },
	-- Chapter 1: Rustwood Pass
	mist_heron = { name = "Mist Heron", rarity = "Rare", basePower = 16, chapter = 1, element = "Water", passive = "dodge_cooldown_small", modelId = 0, iconId = 0, visual = { shape = "Winged", color = { 220, 230, 240 }, accent = { 140, 190, 230 }, size = 1.2 } },
	rustwood_boar = { name = "Rustwood Boar", rarity = "Uncommon", basePower = 9, chapter = 1, element = "Wood", passive = nil, modelId = 0, iconId = 0, visual = { shape = "Beast", color = { 120, 70, 45 }, accent = { 230, 220, 200 }, features = { "Tusks", "Ears" }, size = 1.15 } },
	thunder_pangolin = { name = "Thunder Pangolin", rarity = "Epic", basePower = 30, chapter = 1, element = "Thunder", passive = "parry_ember", modelId = 0, iconId = 0, visual = { shape = "Beast", color = { 80, 90, 120 }, accent = { 140, 200, 255 }, features = { "Scales" }, size = 1.1 } },
	jade_qilin_cub = { name = "Jade Qilin Cub", rarity = "Legendary", basePower = 60, chapter = 1, element = "Wood", passive = "luck_small", modelId = 0, iconId = 0, visual = { shape = "Beast", color = { 80, 190, 140 }, accent = { 240, 200, 90 }, features = { "Horns", "Mane", "BushyTail" }, size = 1.2 } },
	ninth_bell_wraith = { name = "Ninth-Bell Wraith", rarity = "Mythic", basePower = 120, chapter = 1, element = "Void", passive = "posture_break_bonus", modelId = 0, iconId = 0, visual = { shape = "Wraith", color = { 40, 30, 60 }, accent = { 200, 120, 255 }, size = 1.3 } },
} :: { [string]: SpiritDef }

-- Passive effects (numbers only; SpiritService applies them).
SpiritConfig.Passives = {
	ember_find_small = { stat = "EmberMultiplier", value = 0.03 },
	posture_guard_small = { stat = "PostureDamageTaken", value = -0.05 },
	dodge_cooldown_small = { stat = "DodgeCooldown", value = -0.05 },
	parry_ember = { stat = "EmberOnParry", value = 2 },
	luck_small = { stat = "Luck", value = 0.05 },
	posture_break_bonus = { stat = "PostureDamageDealt", value = 0.1 },
}

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
