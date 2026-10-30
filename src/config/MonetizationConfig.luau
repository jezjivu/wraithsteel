--!strict
-- MonetizationConfig: game passes and developer products.
-- TODO(Studio/Agent A): create the passes/products on the Creator Dashboard and replace every
-- id = 0 below. MarketService refuses to prompt an item whose id is 0, so nothing breaks before that.
-- Prices shown in UI come from MarketplaceService:GetProductInfo, never from this file.
-- Compliance: no paid item here grants a random reward directly. Jade (premium currency) can be
-- spent on Jade Lanterns, which are paid random items -> odds shown first + PolicyService gating.

export type PassDef = {
	id: number,
	name: string,
	description: string,
	giftProduct: string?, -- product key used to gift this pass to another player
}

export type ProductDef = {
	id: number,
	name: string,
	kind: "Jade" | "Boost" | "GiftPass",
	amount: number?, -- Jade granted
	boostId: string?, -- EconomyConfig boost key
	durationSeconds: number?,
	passKey: string?, -- for GiftPass products
}

local MonetizationConfig = {}

MonetizationConfig.Passes = {
	DoubleEmber = {
		id = 0,
		name = "Ember Furnace",
		description = "Earn 2x Ember forever.",
		giftProduct = "GiftDoubleEmber",
	},
	LuckyCharm = {
		id = 0,
		name = "Ninefold Charm",
		description = "x1.25 Luck on every Spirit Lantern (odds shown already include it).",
		giftProduct = "GiftLuckyCharm",
	},
	ExtraSpiritSlots = {
		id = 0,
		name = "Spirit Shrine",
		description = "+2 equipped Spirit slots.",
		giftProduct = "GiftExtraSpiritSlots",
	},
	TripleOpen = {
		id = 0,
		name = "Lantern Festival",
		description = "Open 3 Spirit Lanterns at once.",
		giftProduct = nil,
	},
	LongExpeditions = {
		id = 0,
		name = "Long Road",
		description = "Offline earnings cap raised from 8h to 12h.",
		giftProduct = nil,
	},
} :: { [string]: PassDef }

MonetizationConfig.Products = {
	JadeSmall = { id = 0, name = "Pouch of Jade", kind = "Jade", amount = 80 },
	JadeMedium = { id = 0, name = "Chest of Jade", kind = "Jade", amount = 450 },
	JadeLarge = { id = 0, name = "Vault of Jade", kind = "Jade", amount = 1000 },
	EmberBoost30 = { id = 0, name = "Ember Incense (30 min)", kind = "Boost", boostId = "EmberBoost", durationSeconds = 1800 },
	LuckBoost15 = { id = 0, name = "Fortune Incense (15 min)", kind = "Boost", boostId = "LuckBoost", durationSeconds = 900 },
	GiftDoubleEmber = { id = 0, name = "Gift: Ember Furnace", kind = "GiftPass", passKey = "DoubleEmber" },
	GiftLuckyCharm = { id = 0, name = "Gift: Ninefold Charm", kind = "GiftPass", passKey = "LuckyCharm" },
	GiftExtraSpiritSlots = { id = 0, name = "Gift: Spirit Shrine", kind = "GiftPass", passKey = "ExtraSpiritSlots" },
} :: { [string]: ProductDef }

MonetizationConfig.ReceiptHistoryLimit = 200 -- purchaseIds kept per profile for idempotency
MonetizationConfig.GiftTargetTimeoutSeconds = 120 -- PrepareGift selection expires after this

return MonetizationConfig
