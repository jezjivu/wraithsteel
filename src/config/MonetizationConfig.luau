--!strict
-- MonetizationConfig: game passes and developer products.
-- TODO(Studio/Agent A): create the passes/products on the Creator Dashboard and replace every
-- id = 0 below. MarketService refuses to prompt an item whose id is 0, so nothing breaks before that.
-- Prices shown in UI come from MarketplaceService:GetProductInfo. `price` here is only the
-- intended Robux price, shown until the real item exists (and in Studio test purchases).
-- STUDIO TEST PURCHASES: in Roblox Studio, buying an item whose id is still 0 is simulated for
-- free (same grant code as a real receipt) so everything can be playtested. Never in live games.
-- Compliance: no paid item here grants a random reward directly. Jade (premium currency) can be
-- spent on Jade Lanterns, which are paid random items -> odds shown first + PolicyService gating.

export type PassDef = {
	id: number,
	price: number?,
	name: string,
	description: string,
	giftProduct: string?, -- product key used to gift this pass to another player
}

export type ProductDef = {
	id: number,
	price: number?,
	name: string,
	kind: "Jade" | "Boost" | "GiftPass" | "Levels" | "Ember" | "Bundle",
	amount: number?, -- Jade / Ember / levels granted
	bundle: { jade: number?, ember: number?, levels: number? }?,
	boostId: string?, -- EconomyConfig boost key
	durationSeconds: number?,
	passKey: string?, -- for GiftPass products
}

local MonetizationConfig = {}

MonetizationConfig.Passes = {
	DoubleEmber = {
		id = 0,
		price = 299,
		name = "Ember Furnace",
		description = "Earn 2x Ember forever.",
		giftProduct = "GiftDoubleEmber",
	},
	LuckyCharm = {
		id = 0,
		price = 249,
		name = "Ninefold Charm",
		description = "x1.25 Luck on every Spirit Lantern (odds shown already include it).",
		giftProduct = "GiftLuckyCharm",
	},
	ExtraSpiritSlots = {
		id = 0,
		price = 199,
		name = "Spirit Shrine",
		description = "+2 equipped Spirit slots.",
		giftProduct = "GiftExtraSpiritSlots",
	},
	DoubleXP = {
		id = 0,
		price = 249,
		name = "Scroll of Swift Learning",
		description = "Earn 2x XP from everything, forever.",
		giftProduct = nil,
	},
	ExtraFlask = {
		id = 0,
		price = 149,
		name = "Bottomless Gourd",
		description = "+1 Spring Flask charge (4 heals instead of 3).",
		giftProduct = nil,
	},
	VIP = {
		id = 0,
		price = 399,
		name = "Bell-Bearer's Seal (VIP)",
		description = "+25% Ember and XP, a golden name, and a VIP aura.",
		giftProduct = nil,
	},
	TripleOpen = {
		id = 0,
		price = 149,
		name = "Lantern Festival",
		description = "Open 3 Spirit Lanterns at once.",
		giftProduct = nil,
	},
	LongExpeditions = {
		id = 0,
		price = 99,
		name = "Long Road",
		description = "Offline earnings cap raised from 8h to 12h, plus a 3rd expedition slot.",
		giftProduct = nil,
	},
} :: { [string]: PassDef }

MonetizationConfig.Products = {
	JadeSmall = { id = 0, price = 49, name = "Pouch of Jade", kind = "Jade", amount = 80 },
	JadeMedium = { id = 0, price = 249, name = "Chest of Jade", kind = "Jade", amount = 450 },
	JadeLarge = { id = 0, price = 499, name = "Vault of Jade", kind = "Jade", amount = 1000 },
	EmberSmall = { id = 0, price = 39, name = "Sack of Ember", kind = "Ember", amount = 2500 },
	EmberLarge = { id = 0, price = 199, name = "Furnace of Ember", kind = "Ember", amount = 15000 },
	LevelUp1 = { id = 0, price = 29, name = "Level Up", kind = "Levels", amount = 1 },
	LevelUp5 = { id = 0, price = 119, name = "Five Levels", kind = "Levels", amount = 5 },
	LevelUp10 = { id = 0, price = 199, name = "Ten Levels", kind = "Levels", amount = 10 },
	StarterBundle = { id = 0, price = 99, name = "Wanderer's Bundle", kind = "Bundle", bundle = { jade = 200, ember = 5000, levels = 3 } },
	EmberBoost30 = { id = 0, price = 39, name = "Ember Incense (30 min)", kind = "Boost", boostId = "EmberBoost", durationSeconds = 1800 },
	LuckBoost15 = { id = 0, price = 49, name = "Fortune Incense (15 min)", kind = "Boost", boostId = "LuckBoost", durationSeconds = 900 },
	GiftDoubleEmber = { id = 0, price = 299, name = "Gift: Ember Furnace", kind = "GiftPass", passKey = "DoubleEmber" },
	GiftLuckyCharm = { id = 0, price = 299, name = "Gift: Ninefold Charm", kind = "GiftPass", passKey = "LuckyCharm" },
	GiftExtraSpiritSlots = { id = 0, price = 299, name = "Gift: Spirit Shrine", kind = "GiftPass", passKey = "ExtraSpiritSlots" },
} :: { [string]: ProductDef }

MonetizationConfig.ReceiptHistoryLimit = 200 -- purchaseIds kept per profile for idempotency
MonetizationConfig.GiftTargetTimeoutSeconds = 120 -- PrepareGift selection expires after this

return MonetizationConfig
