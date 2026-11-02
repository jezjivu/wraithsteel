--!strict
-- ChapterConfig: story structure (Prologue + 5 chapters, 21 bosses). Owner: Agent D (Artisan).
-- Boss ids listed here must exist in BossConfig before their chapter ships; ChapterService
-- tolerates missing ones so later phases can fill them in.

export type ChapterDef = {
	name: string,
	zone: string, -- TODO(Studio/Agent D): Workspace zone folder name built in Studio
	recommendedPower: number,
	stages: number,
	bosses: { string }, -- in story order; last one is the chapter finale
	unlockLantern: string?,
}

local ChapterConfig = {}

ChapterConfig.Chapters = {
	[0] = { name = "Prologue: The Cracked Bell", zone = "Zone_Prologue", recommendedPower = 20, stages = 3, bosses = { "bell_engine" }, unlockLantern = "paper_lantern" },
	[1] = { name = "Chapter 1: Rustwood Pass", zone = "Zone_Rustwood", recommendedPower = 200, stages = 5, bosses = { "hollow_abbot", "twin_cinder_sisters", "rustwood_matriarch", "gatekeeper_of_rust" }, unlockLantern = "rustwood_lantern" },
	[2] = { name = "Chapter 2: The Drowned Market", zone = "Zone_DrownedMarket", recommendedPower = 900, stages = 5, bosses = { "tidewidow", "lantern_magistrate", "eel_of_debts", "gatekeeper_of_tides" } },
	[3] = { name = "Chapter 3: Ashfall Monastery", zone = "Zone_Ashfall", recommendedPower = 3000, stages = 5, bosses = { "ash_monk_duo", "bellless_novice", "cinder_ox", "gatekeeper_of_ash" } },
	[4] = { name = "Chapter 4: The Hanging Gardens of Thunder", zone = "Zone_Thunder", recommendedPower = 9000, stages = 5, bosses = { "storm_crane", "copper_general", "silk_tempest", "gatekeeper_of_thunder" } },
	[5] = { name = "Chapter 5: The Ninth Gate", zone = "Zone_NinthGate", recommendedPower = 25000, stages = 6, bosses = { "wraith_regent", "the_unrung", "steel_that_remembers", "bell_of_nine_gates" } },
} :: { [number]: ChapterDef }

ChapterConfig.FinalChapter = 5

-- Party / co-op
ChapterConfig.MaxPartySize = 4
ChapterConfig.RaidSize = 8

return ChapterConfig
