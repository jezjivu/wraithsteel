--!strict
-- QuestService: daily + story quests driven by stat increments from other services.
--
-- API:
--   QuestService.Increment(player, stat, amount?)   e.g. "EnemiesDefeated", "Boss:kagura_9"
--   QuestService.Claim(player, questId) -> (ok, message)
--   QuestService.StatIncremented: Signal(player, stat, amount)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local Time = require(Shared:WaitForChild("Time"))
local RewardConfig = require(Config:WaitForChild("RewardConfig"))

local RewardLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("RewardLogic"))
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local QuestService = {
	Name = "QuestService",
	Priority = 10,
	StatIncremented = Signal.new(),
}

-- Ensures today's daily quests exist and story quests for the player's chapter are active.
local function refresh(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local now = os.time()
	local today = Time.DayKey(now)
	if data.questDay ~= today then
		for id in table.clone(data.quests) do
			local def = RewardConfig.Quests[id]
			if def == nil or def.daily then
				data.quests[id] = nil
			end
		end
		for _, id in RewardLogic.PickDailyQuests(player.UserId, today) do
			data.quests[id] = { id = id, progress = 0, claimed = false, startedAt = now }
		end
		data.questDay = today
	end
	for id, def in RewardConfig.Quests do
		if not def.daily and data.quests[id] == nil and (def.chapter or 0) <= data.chapter then
			data.quests[id] = { id = id, progress = 0, claimed = false, startedAt = now }
		end
	end
	DataService.Changed(player, "quests")
end

function QuestService.Increment(player: Player, stat: string, amount: number?)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local n = amount or 1
	local changed = false
	for id, q in data.quests do
		local def = RewardConfig.Quests[id]
		if def and def.stat == stat and not q.claimed and q.progress < def.goal then
			q.progress = math.min(def.goal, q.progress + n)
			changed = true
		end
	end
	if changed then
		DataService.Changed(player, "quests")
	end
	QuestService.StatIncremented:Fire(player, stat, n)
end

function QuestService.Claim(player: Player, questId: string): (boolean, string)
	local data = DataService.GetData(player)
	local def = RewardConfig.Quests[questId]
	if data == nil or def == nil then
		return false, "Unknown quest"
	end
	local q = data.quests[questId]
	if q == nil or q.claimed then
		return false, "Nothing to claim"
	end
	if q.progress < def.goal then
		return false, "Not finished yet"
	end
	q.claimed = true
	ProgressionService.GrantReward(player, def.reward, "Quest:" .. questId)
	DataService.Changed(player, "quests")
	return true, "Quest complete: " .. def.name
end

function QuestService.Init() end

function QuestService.Start()
	DataService.ProfileLoaded:Connect(refresh)
	Net.Server.OnInvoke("ClaimQuest", QuestService.Claim)
	-- Roll daily quests over at UTC midnight for players who stay online.
	task.spawn(function()
		while true do
			task.wait(math.min(60, Time.SecondsUntilNextDay(os.time()) + 1))
			for _, player in Players:GetPlayers() do
				refresh(player)
			end
		end
	end)
end

QuestService.Refresh = refresh

return QuestService
