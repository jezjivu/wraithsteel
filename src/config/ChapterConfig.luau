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
	-- The chapter follows the story (SagaConfig quests with `unlocksChapter`, or a chapter finale
	-- boss below). It gates lanterns, weapons, expeditions, Night Market items and the Power cap.
	[0] = { name = "Prologue: The Cracked Bell", zone = "Realm_Japan", recommendedPower = 20, stages = 3, bosses = {}, unlockLantern = "paper_lantern" },
	[1] = { name = "Chapter 1: The City That Never Stopped Ringing", zone = "Realm_Neon", recommendedPower = 200, stages = 5, bosses = { "kagura_9" }, unlockLantern = "rustwood_lantern" },
	[2] = { name = "Chapter 2: The Island of the Sun", zone = "Realm_Greek", recommendedPower = 900, stages = 5, bosses = { "archon_helion" }, unlockLantern = "tidewater_lantern" },
	[3] = { name = "Chapter 3: Ironcrow Keep", zone = "Realm_Keep", recommendedPower = 3000, stages = 5, bosses = { "tessai", "ashrei" } },
	[4] = { name = "Chapter 4: The Bell Remembers", zone = "Realm_Next", recommendedPower = 9000, stages = 5, bosses = {} }, -- (to be continued)
	[5] = { name = "Chapter 5: The Ninth Gate", zone = "Realm_NinthGate", recommendedPower = 25000, stages = 6, bosses = {} },
} :: { [number]: ChapterDef }

ChapterConfig.FinalChapter = 5

-- Party / co-op
ChapterConfig.MaxPartySize = 4
ChapterConfig.RaidSize = 8

return ChapterConfig
