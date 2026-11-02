--!strict
-- RewardConfig: daily login, playtime gifts, offline earnings, daily quests. Owner: Agent A.

export type Reward = {
	ember: number?,
	jade: number?,
	xp: number?,
	lantern: string?, -- grants one free open of this lantern (Ember lanterns only)
}

local RewardConfig = {}

-- Daily login: 7-day cycle; missing a day resets the streak to day 1.
RewardConfig.Daily = {
	{ ember = 100 },
	{ ember = 200 },
	{ ember = 300, jade = 5 },
	{ ember = 400 },
	{ ember = 600, jade = 10 },
	{ ember = 800 },
	{ ember = 1200, jade = 25, lantern = "paper_lantern" },
} :: { Reward }

-- Playtime gifts, reset daily. Keys are stable ids (saved in profile).
RewardConfig.PlaytimeOrder = { "pt5", "pt15", "pt30", "pt60" }
RewardConfig.Playtime = {
	pt5 = { seconds = 5 * 60, reward = { ember = 50 } :: Reward },
	pt15 = { seconds = 15 * 60, reward = { ember = 150 } :: Reward },
	pt30 = { seconds = 30 * 60, reward = { ember = 300, jade = 3 } :: Reward },
	pt60 = { seconds = 60 * 60, reward = { ember = 700, jade = 5 } :: Reward },
}

-- Quests ------------------------------------------------------------------------------------
export type QuestDef = {
	name: string,
	stat: string, -- QuestService.Increment(player, stat, n) drives progress
	goal: number,
	reward: Reward,
	daily: boolean,
	chapter: number?, -- story quests: available from this chapter
}

RewardConfig.DailyQuestCount = 3
RewardConfig.Quests = {
	d_defeat_enemies = { name = "Clear the Road", stat = "EnemiesDefeated", goal = 25, reward = { ember = 250 }, daily = true },
	d_parries = { name = "Steel Meets Steel", stat = "PerfectParries", goal = 15, reward = { ember = 200, xp = 100 }, daily = true },
	d_lanterns = { name = "Light the Way", stat = "LanternsOpened", goal = 5, reward = { ember = 150 }, daily = true },
	d_posture_breaks = { name = "Break Their Stance", stat = "PostureBreaks", goal = 8, reward = { ember = 220 }, daily = true },
	d_fusions = { name = "Twin Flames", stat = "Fusions", goal = 1, reward = { ember = 180, jade = 2 }, daily = true },
	s_prologue_kagehisa = { name = "Silence Kagehisa", stat = "Boss:kagehisa", goal = 1, reward = { ember = 500, xp = 300 }, daily = false, chapter = 0 },
	s_first_lantern = { name = "A Spirit Answers", stat = "LanternsOpened", goal = 1, reward = { ember = 60 }, daily = false, chapter = 0 },
} :: { [string]: QuestDef }

return RewardConfig
