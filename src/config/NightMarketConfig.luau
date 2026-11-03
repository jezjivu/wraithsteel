--!strict
-- NightMarketConfig: the rotating Night Market stall. Owner: Agent A.
-- Stock rotates every WindowSeconds. The window number is `os.time() // WindowSeconds`, and the
-- stock for a window is picked by Shared/NightMarketLogic from a seed derived ONLY from that
-- number, so every server (and every client) shows the same stock at the same time.
-- Compliance: every item is a FIXED, fully described reward at a fixed price - the stock
-- rotation is not a purchase, so nothing bought here is random (no odds needed). Items never
-- include lanterns or anything that rolls. Spirits bought with Ember/Jade carry `paid = true`.

export type ItemDef = {
	name: string,
	description: string,
	kind: "Spirit" | "Boost" | "Ember",
	currency: "Ember" | "Jade",
	price: number,
	limit: number, -- purchases per player per window
	weight: number, -- how often the item shows up in the rotation (stock pick only)
	chapter: number, -- shown to everyone, buyable from this chapter
	spirit: { id: string, rarity: string, mutation: string }?,
	boostId: string?, -- EconomyConfig boost key
	seconds: number?,
	amount: number?, -- Ember for Jade swaps
}

local NightMarketConfig = {}

NightMarketConfig.WindowSeconds = 600 -- a new stock every 10 minutes (global seed os.time() // 600)
NightMarketConfig.SlotCount = 4
NightMarketConfig.SeedSalt = 0x5EED -- change to reshuffle every future window
-- TODO(Studio/Agent D): build a lantern-lit stall with attribute Station = "NightMarket"
-- (HubService wires the prompt). Until then the market opens from the menu bar.

NightMarketConfig.Items = {
	moth_gilded = {
		name = "Gilded Lantern Moth",
		description = "A Common Lantern Moth with the Gilded mutation.",
		kind = "Spirit",
		currency = "Ember",
		price = 900,
		limit = 1,
		weight = 30,
		chapter = 0,
		spirit = { id = "lantern_moth", rarity = "Common", mutation = "Gilded" },
	},
	fox_moonlit = {
		name = "Moonlit Reed Fox",
		description = "An Uncommon Reed Fox with the Moonlit mutation.",
		kind = "Spirit",
		currency = "Ember",
		price = 2400,
		limit = 1,
		weight = 20,
		chapter = 0,
		spirit = { id = "reed_fox", rarity = "Uncommon", mutation = "Moonlit" },
	},
	carp_rare = {
		name = "Brass Carp",
		description = "A Rare Brass Carp, no mutation.",
		kind = "Spirit",
		currency = "Ember",
		price = 6000,
		limit = 1,
		weight = 10,
		chapter = 1,
		spirit = { id = "brass_carp", rarity = "Rare", mutation = "None" },
	},
	heron_jade = {
		name = "Stormforged Mist Heron",
		description = "A Mist Heron with the Stormforged mutation.",
		kind = "Spirit",
		currency = "Jade",
		price = 120,
		limit = 1,
		weight = 6,
		chapter = 1,
		spirit = { id = "mist_heron", rarity = "Rare", mutation = "Stormforged" },
	},
	ember_incense = {
		name = "Ember Incense (10 min)",
		description = "+100% Ember for 10 minutes.",
		kind = "Boost",
		currency = "Ember",
		price = 1500,
		limit = 2,
		weight = 25,
		chapter = 0,
		boostId = "EmberBoost",
		seconds = 600,
	},
	fortune_incense = {
		name = "Fortune Incense (5 min)",
		description = "x1.5 Luck for 5 minutes (shown in lantern odds).",
		kind = "Boost",
		currency = "Jade",
		price = 25,
		limit = 2,
		weight = 15,
		chapter = 0,
		boostId = "LuckBoost",
		seconds = 300,
	},
	ember_crate = {
		name = "Crate of Ember",
		description = "Swap 30 Jade for 3,500 Ember.",
		kind = "Ember",
		currency = "Jade",
		price = 30,
		limit = 3,
		weight = 15,
		chapter = 0,
		amount = 3500,
	},
} :: { [string]: ItemDef }

-- Stable iteration order for the stock pick (never rely on table order).
NightMarketConfig.ItemOrder = {
	"moth_gilded",
	"fox_moonlit",
	"carp_rare",
	"heron_jade",
	"ember_incense",
	"fortune_incense",
	"ember_crate",
}

return NightMarketConfig
