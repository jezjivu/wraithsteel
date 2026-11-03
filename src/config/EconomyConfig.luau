--!strict
-- EconomyConfig: every economy number (Ember, Jade, XP curve, Power, caps, multipliers).
-- Owner: Agent A (Architect). Tune here only; services must never hardcode these.

local EconomyConfig = {}

EconomyConfig.DataVersion = 10 -- bump together with a migration in Logic/Migrations

EconomyConfig.StartingEmber = 50
EconomyConfig.StartingJade = 0
EconomyConfig.StartingWeapon = "jian_wanderer"
EconomyConfig.StartingSpiritSlots = 3 -- equipped spirits
EconomyConfig.MaxSpiritSlots = 6
EconomyConfig.StartingSpiritStorage = 60
EconomyConfig.MaxEmber = 1e15 -- hard clamp to avoid float precision issues

-- Levels ------------------------------------------------------------------------------------
EconomyConfig.MaxLevel = 120
-- XP needed to go from `level` to `level + 1`.
function EconomyConfig.XpToNext(level: number): number
	return math.floor(100 * level ^ 1.6)
end

-- Power -------------------------------------------------------------------------------------
-- Power = (Base + Level * PerLevel + weapon power + sum(spirit power)) * powerMultiplier,
-- clamped to the cap of the player's current chapter so content stays challenging.
EconomyConfig.BasePower = 10
EconomyConfig.PowerPerLevel = 4
EconomyConfig.PowerCapByChapter = {
	[0] = 250, -- Prologue
	[1] = 1200,
	[2] = 4000,
	[3] = 12000,
	[4] = 32000,
	[5] = 90000,
}

-- Multipliers -------------------------------------------------------------------------------
-- Sources inside a category add; categories multiply. e.g. ember = (1 + pass + boost) * (1 + spirits)
EconomyConfig.Multipliers = {
	Ember = {
		DoubleEmberPass = 1.0, -- +100%
		EmberBoost = 1.0, -- +100% while boost active
		PartyBonusPerMember = 0.05, -- +5% per extra party member
		VIPPass = 0.25,
	},
	Xp = {
		DoubleXPPass = 1.0, -- +100%
		VIPPass = 0.25,
	},
	Luck = {
		LuckyCharmPass = 0.25, -- luck x1.25
		LuckBoost = 0.5, -- luck x1.5 while active
	},
}
EconomyConfig.MaxLuck = 3

-- Enemy & boss rewards (multiplied by Ember multiplier) --------------------------------------
EconomyConfig.EnemyEmberBase = 10
EconomyConfig.EnemyXpBase = 12
EconomyConfig.BossFirstClearJade = 25

-- Offline / expeditions ----------------------------------------------------------------------
EconomyConfig.OfflineMinSeconds = 300 -- below this no offline reward
EconomyConfig.OfflineCapSeconds = 8 * 3600
EconomyConfig.OfflineCapSecondsWithPass = 12 * 3600
EconomyConfig.OfflineEmberPerMinutePerPower = 0.02
EconomyConfig.OfflineEfficiency = 0.5 -- offline earns 50% of the idle rate

-- Release refunds (Ember per spirit released, by rarity)
EconomyConfig.ReleaseRefund = {
	Common = 2,
	Uncommon = 6,
	Rare = 20,
	Epic = 80,
	Legendary = 400,
	Mythic = 2000,
}

-- Death: you drop part of your carried Ember where you fell. Reach the spot to get it back;
-- die again first and it's gone. Nothing drops inside boss arenas or in the hub.
EconomyConfig.DeathDrop = {
	fraction = 0.25,
	minimum = 20, -- don't bother dropping less than this
	recoverRadius = 8,
	hubSafeRadius = 150,
}

return EconomyConfig
