--!strict
-- ProfileTemplate: the default ProfileData for a brand-new player (guide §8.3 ProfileData).
-- ProfileStore deep-copies this and Reconcile() fills in any keys added later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local SpellConfig = require(Config:WaitForChild("SpellConfig"))
local Types = require(Shared:WaitForChild("Types"))

local ProfileTemplate = {}

function ProfileTemplate.New(): Types.ProfileData
	return {
		dataVersion = EconomyConfig.DataVersion,

		ember = EconomyConfig.StartingEmber,
		jade = EconomyConfig.StartingJade,
		xp = 0,
		level = 1,

		chapter = 0,
		stage = 1,
		bossesDefeated = {},
		raidClears = {},
		tutorialDone = false,

		weapons = { [EconomyConfig.StartingWeapon] = true },
		equippedWeapon = EconomyConfig.StartingWeapon,
		fightingStyle = "river",
		spellLoadout = table.clone(SpellConfig.DefaultLoadout),
		waystones = { hub = true },
		respawnWaystone = "hub",
		skills = {},
		shortcuts = {},
		relics = {},
		lostEmber = { amount = 0, x = 0, y = 0, z = 0 },
		saga = { quest = 1, step = 1, progress = 0, started = false },

		spirits = {},
		tradesApplied = {},
		tradeOrder = {},
		equippedSpirits = {},
		spiritSlots = EconomyConfig.StartingSpiritSlots,
		spiritStorage = EconomyConfig.StartingSpiritStorage,
		nextUid = 1,
		lanternPity = {},
		hatchedTotal = 0,
		freeLanterns = { paper_lantern = 1 }, -- new players get one free first lantern

		expeditions = {},
		lastSeenAt = 0,

		lastDailyDay = -1,
		dailyStreak = 0,
		playtimeDay = -1,
		playtimeSeconds = 0,
		playtimeClaimed = {},

		quests = {},
		questDay = -1,

		codesRedeemed = {},

		nightMarket = { window = -1, bought = {} },

		pvpWins = 0,
		pvpLosses = 0,
		pvpStreak = 0,

		chips = 0,
		chipsDay = -1,
		chipsExchangedDay = -1,
		chipsExchanged = 0,

		receipts = {},
		receiptOrder = {},
		giftedPasses = {},
		giftMessagesSeen = {},
		giftTokens = {},
		boosts = {},
		robuxSpent = 0,

		funnelSteps = {},

		settings = {},
	}
end

return ProfileTemplate
