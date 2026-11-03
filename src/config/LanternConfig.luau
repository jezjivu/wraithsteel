--!strict
-- LanternConfig: Spirit Lanterns (the game's eggs). Owner: Agent B.
-- Compliance: odds for every lantern are computed by Shared/Odds from exactly these weights,
-- shown in the UI before purchase, and used by the server roll. Pity rules are shown too.
-- `paid = true` forces a lantern to count as a paid random item. Lanterns priced in a currency
-- that is sold for Robux (MonetizationConfig) count as paid automatically - see
-- Shared/LanternOdds.IsPaid. Paid lanterns are blocked (except free opens) where PolicyService
-- restricts paid random items.

export type LanternEntry = { spirit: string, weight: number }

export type LanternDef = {
	name: string,
	chapter: number, -- unlocked at this chapter
	currency: "Ember" | "Jade",
	price: number,
	paid: boolean,
	entries: { LanternEntry },
	pity: { rolls: number, minRarity: string }?, -- guarantee minRarity+ within `rolls` opens
	modelId: number, -- TODO(Studio): lantern model asset
}

local LanternConfig = {}

LanternConfig.MaxOpenPerRequest = 3 -- requires TripleOpen pass for 3, otherwise 1
LanternConfig.OpenCooldownSeconds = 0.75

LanternConfig.Lanterns = {
	paper_lantern = {
		name = "Paper Lantern",
		chapter = 0,
		currency = "Ember",
		price = 60,
		paid = false,
		entries = {
			{ spirit = "lantern_moth", weight = 4500 },
			{ spirit = "ember_sparrow", weight = 3500 },
			{ spirit = "reed_fox", weight = 1200 },
			{ spirit = "inkcap_toad", weight = 700 },
			{ spirit = "brass_carp", weight = 100 },
		},
		pity = nil,
		modelId = 0,
	},
	rustwood_lantern = {
		name = "Rustwood Lantern",
		chapter = 1,
		currency = "Ember",
		price = 400,
		paid = false,
		entries = {
			{ spirit = "rustwood_boar", weight = 4800 },
			{ spirit = "inkcap_toad", weight = 2700 },
			{ spirit = "mist_heron", weight = 1800 },
			{ spirit = "brass_carp", weight = 600 },
			{ spirit = "thunder_pangolin", weight = 95 },
			{ spirit = "jade_qilin_cub", weight = 5 },
		},
		pity = nil,
		modelId = 0,
	},
	jade_lantern = {
		name = "Jade Lantern",
		chapter = 0,
		currency = "Jade",
		price = 50,
		paid = true,
		entries = {
			{ spirit = "mist_heron", weight = 5000 },
			{ spirit = "brass_carp", weight = 3500 },
			{ spirit = "thunder_pangolin", weight = 1300 },
			{ spirit = "jade_qilin_cub", weight = 190 },
			{ spirit = "ninth_bell_wraith", weight = 10 },
		},
		pity = { rolls = 40, minRarity = "Epic" },
		modelId = 0,
	},
} :: { [string]: LanternDef }

return LanternConfig
