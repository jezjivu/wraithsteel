--!strict
-- ChapterService: story progression (Prologue + 5 chapters, ChapterConfig).
-- Advances the player's chapter when they defeat the chapter's final boss. Zone gating,
-- teleports and cutscenes are Studio work for Agent D.
-- TODO(Studio/Agent D): zone gates (Workspace.<zone>/Gate parts) that check
--   ChapterService.HasUnlocked(player, chapter); cutscene/dialogue ids in StoryEvent payloads.
--
-- API:
--   ChapterService.HasUnlocked(player, chapter) -> boolean
--   ChapterService.Advance(player) -- called when the chapter finale is cleared
--   ChapterService.ChapterAdvanced: Signal(player, newChapter)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local ChapterConfig = require(Config:WaitForChild("ChapterConfig"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local QuestService = require(script.Parent.QuestService)
local BossService = require(script.Parent.BossService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ChapterService = {
	Name = "ChapterService",
	Priority = 40,
	ChapterAdvanced = Signal.new(),
}

function ChapterService.HasUnlocked(player: Player, chapter: number): boolean
	local data = DataService.GetData(player)
	return data ~= nil and data.chapter >= chapter
end

function ChapterService.Advance(player: Player)
	local data = DataService.GetData(player)
	if data == nil or data.chapter >= ChapterConfig.FinalChapter then
		return
	end
	data.chapter += 1
	data.stage = 1
	DataService.Changed(player, "chapter", "stage")
	ProgressionService.RefreshPower(player) -- new chapter raises the Power cap
	QuestService.Refresh(player) -- unlock story quests for the new chapter
	local def = ChapterConfig.Chapters[data.chapter]
	Net.Server.Fire("StoryEvent", player, { kind = "ChapterUnlocked", chapter = data.chapter, name = def.name })
	if data.chapter == 1 then
		AnalyticsService.Onboarding(player, "Chapter1Entered")
	end
	ChapterService.ChapterAdvanced:Fire(player, data.chapter)
end

function ChapterService.Init() end

function ChapterService.Start()
	BossService.BossDefeated:Connect(function(bossId, participants)
		for _, player in participants do
			local data = DataService.GetData(player)
			if data then
				local chapter = ChapterConfig.Chapters[data.chapter]
				if chapter and chapter.bosses[#chapter.bosses] == bossId then
					ChapterService.Advance(player)
				end
			end
		end
	end)
	Net.Server.On("StoryAdvance", function(player, beatId)
		-- TODO(Agent D): validate story beats (dialogue finished, area reached) and advance `stage`.
		local _ = player and beatId
	end)
end

return ChapterService
