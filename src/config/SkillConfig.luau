--!strict
-- SkillConfig: the skill tree. Three paths; one skill point per level (plus a bonus point
-- every 5 levels). A skill needs one of its `requires` skills learned first. Ranks stack.
-- `stats` are added per rank into the same stat totals spirits use (CombatService.PlayerStats),
-- so every bonus here is applied by the existing combat code:
--   Attack, Posture, Health, Guard, Lifesteal, CritChance, CritDamage, Haste, QiRegen
--   ParryWindow (s), Riposte (x), Flask (charges), FlaskHeal, ExecutionHeal (fraction of
--   max HP), SecondBreathHeal, ArtPower, Stealth (enemies notice you later), Execution (x),
--   BloodRush (damage after a Severing Blow), DodgeQi, RingingSteel (deflect shockwave posture)
-- `art` = a blade art (SpellConfig) this skill unlocks for your art slots.
-- All names are original to WRAITHSTEEL.

export type SkillDef = {
	name: string,
	text: string,
	path: string,
	tier: number, -- row 1..5 (top to bottom)
	col: number, -- -1 / 0 / 1 inside the path column
	maxRank: number,
	cost: number?, -- points per rank (default 1)
	requires: { string }?, -- any one of these, learned
	stats: { [string]: number }?,
	art: string?,
	minLevel: number?,
}

export type PathDef = { id: string, name: string, text: string, color: { number } }

local SkillConfig = {}

SkillConfig.Paths = {
	{ id = "steel", name = "Way of Steel", text = "Cut harder, break guards, finish them.", color = { 225, 70, 55 } },
	{ id = "shadow", name = "Way of Shadow", text = "Move unseen, strike first, never stand still.", color = { 130, 120, 235 } },
	{ id = "resolve", name = "Way of Resolve", text = "Deflect everything, outlast anything.", color = { 240, 195, 90 } },
} :: { PathDef }

SkillConfig.PointsPerLevel = 1
SkillConfig.BonusEvery = 5 -- one extra point at every 5th level

SkillConfig.Skills = {
	-- Way of Steel ------------------------------------------------------------------------
	keen_edge = {
		name = "Keen Edge", text = "+5% damage per rank.",
		path = "steel", tier = 1, col = 0, maxRank = 3, stats = { Attack = 0.05 },
	},
	heavy_hand = {
		name = "Heavy Hand", text = "+8% posture damage per rank. Guards crumble faster.",
		path = "steel", tier = 2, col = -1, maxRank = 3, requires = { "keen_edge" }, stats = { Posture = 0.08 },
	},
	killing_rhythm = {
		name = "Killing Rhythm", text = "+4% critical chance per rank.",
		path = "steel", tier = 2, col = 1, maxRank = 2, requires = { "keen_edge" }, stats = { CritChance = 0.04 },
	},
	executioner = {
		name = "Executioner", text = "Severing Blows heal you for 15% of your max health.",
		path = "steel", tier = 3, col = -1, maxRank = 1, cost = 2, requires = { "heavy_hand" }, stats = { ExecutionHeal = 0.15 },
	},
	answering_steel = {
		name = "Answering Steel", text = "Ripostes after a perfect deflect hit +25% harder per rank.",
		path = "steel", tier = 3, col = 1, maxRank = 2, requires = { "killing_rhythm" }, stats = { Riposte = 0.25 },
	},
	moon_severance = {
		name = "Moon Severance", text = "New art: a giant, slow crescent that splits everything in a wide line.",
		path = "steel", tier = 4, col = 0, maxRank = 1, cost = 2, requires = { "executioner", "answering_steel" }, art = "moon_severance", minLevel = 6,
	},
	blood_rush = {
		name = "Blood Rush", text = "After a Severing Blow, deal +30% damage for 8 seconds.",
		path = "steel", tier = 4, col = 1, maxRank = 1, cost = 2, requires = { "answering_steel" }, stats = { BloodRush = 0.3 },
	},
	red_harvest = {
		name = "Red Harvest", text = "+25% critical damage per rank.",
		path = "steel", tier = 5, col = 0, maxRank = 2, requires = { "moon_severance" }, stats = { CritDamage = 0.25 },
	},

	-- Way of Shadow -----------------------------------------------------------------------
	light_feet = {
		name = "Light Feet", text = "Dash and art cooldowns -4% per rank.",
		path = "shadow", tier = 1, col = 0, maxRank = 3, stats = { Haste = 0.04 },
	},
	silent_step = {
		name = "Silent Step", text = "Unaware enemies notice you 20% later per rank.",
		path = "shadow", tier = 2, col = -1, maxRank = 2, requires = { "light_feet" }, stats = { Stealth = 0.2 },
	},
	flowing_breath = {
		name = "Flowing Breath", text = "+15% Qi regeneration per rank.",
		path = "shadow", tier = 2, col = 1, maxRank = 3, requires = { "light_feet" }, stats = { QiRegen = 0.15 },
	},
	shadow_harvest = {
		name = "Shadow Harvest", text = "Severing Blows deal 25% more to bosses per rank.",
		path = "shadow", tier = 3, col = -1, maxRank = 2, requires = { "silent_step" }, stats = { Execution = 0.25 },
	},
	drinking_blade = {
		name = "Drinking Blade", text = "Heal 2% of the damage you deal per rank.",
		path = "shadow", tier = 3, col = 1, maxRank = 2, requires = { "flowing_breath" }, stats = { Lifesteal = 0.02 },
	},
	phantom_rush = {
		name = "Phantom Rush", text = "New art: blink between up to five enemies, cutting each one.",
		path = "shadow", tier = 4, col = 0, maxRank = 1, cost = 2, requires = { "shadow_harvest", "drinking_blade" }, art = "phantom_rush", minLevel = 6,
	},
	vanishing_step = {
		name = "Vanishing Step", text = "Dodging through an attack restores 8 Qi per rank.",
		path = "shadow", tier = 4, col = 1, maxRank = 2, requires = { "drinking_blade" }, stats = { DodgeQi = 8 },
	},
	honed_arts = {
		name = "Honed Arts", text = "Blade arts deal +15% damage per rank.",
		path = "shadow", tier = 5, col = 0, maxRank = 2, requires = { "phantom_rush" }, stats = { ArtPower = 0.15 },
	},

	-- Way of Resolve ----------------------------------------------------------------------
	iron_body = {
		name = "Iron Body", text = "+6% max health per rank.",
		path = "resolve", tier = 1, col = 0, maxRank = 3, stats = { Health = 0.06 },
	},
	steady_guard = {
		name = "Steady Guard", text = "Perfect deflect window +0.02s per rank.",
		path = "resolve", tier = 2, col = -1, maxRank = 3, requires = { "iron_body" }, stats = { ParryWindow = 0.02 },
	},
	stone_stance = {
		name = "Stone Stance", text = "Take 8% less posture damage per rank.",
		path = "resolve", tier = 2, col = 1, maxRank = 3, requires = { "iron_body" }, stats = { Guard = 0.08 },
	},
	deep_gourd = {
		name = "Deep Gourd", text = "+1 Spring Flask charge.",
		path = "resolve", tier = 3, col = -1, maxRank = 1, cost = 2, requires = { "steady_guard" }, stats = { Flask = 1 },
	},
	healing_draught = {
		name = "Healing Draught", text = "Spring Flask heals +20% more per rank.",
		path = "resolve", tier = 3, col = 1, maxRank = 2, requires = { "stone_stance" }, stats = { FlaskHeal = 0.2 },
	},
	crimson_lotus = {
		name = "Crimson Lotus", text = "New art: a whirling bloom of blades that pulls enemies in and shreds their guard.",
		path = "resolve", tier = 4, col = 0, maxRank = 1, cost = 2, requires = { "deep_gourd", "healing_draught" }, art = "crimson_lotus", minLevel = 6,
	},
	ringing_steel = {
		name = "Ringing Steel", text = "Perfect deflects ring out: every enemy within 10 studs takes 18 posture damage per rank.",
		path = "resolve", tier = 4, col = -1, maxRank = 2, requires = { "deep_gourd" }, stats = { RingingSteel = 18 },
	},
	unbroken = {
		name = "Unbroken", text = "Second Breath brings you back with +25% more health per rank.",
		path = "resolve", tier = 5, col = 0, maxRank = 2, requires = { "crimson_lotus" }, stats = { SecondBreathHeal = 0.25 },
	},
} :: { [string]: SkillDef }

-- Stable display order per path (tier, then column).
function SkillConfig.ForPath(pathId: string): { string }
	local out = {}
	for id, s in SkillConfig.Skills do
		if s.path == pathId then
			table.insert(out, id)
		end
	end
	table.sort(out, function(a, b)
		local sa, sb = SkillConfig.Skills[a], SkillConfig.Skills[b]
		if sa.tier ~= sb.tier then
			return sa.tier < sb.tier
		end
		return sa.col < sb.col
	end)
	return out
end

-- The skill that unlocks an art (nil if the art needs no skill).
function SkillConfig.ArtSkill(spellId: string): string?
	for id, s in SkillConfig.Skills do
		if s.art == spellId then
			return id
		end
	end
	return nil
end

return SkillConfig
