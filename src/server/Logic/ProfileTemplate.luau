--!strict
-- ProfileTemplate: the default ProfileData for a brand-new player (guide §8.3 ProfileData).
-- ProfileStore deep-copies this and Reconcile() fills in any keys added later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
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
		tutorialDone = false,

		weapons = { [EconomyConfig.StartingWeapon] = true },
		equippedWeapon = EconomyConfig.StartingWeapon,

		spirits = {},
		equippedSpirits = {},
		spiritSlots = EconomyConfig.StartingSpiritSlots,
		spiritStorage = EconomyConfig.StartingSpiritStorage,
		nextUid = 1,
		lanternPity = {},
		hatchedTotal = 0,

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

		receipts = {},
		receiptOrder = {},
		giftedPasses = {},
		giftMessagesSeen = {},
		boosts = {},
		robuxSpent = 0,

		funnelSteps = {},

		settings = {},
	}
end

return ProfileTemplate
