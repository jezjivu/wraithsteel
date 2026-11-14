--!strict
-- RewardLogic: pure rules for daily login, playtime gifts, offline earnings and daily quest picks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local RewardConfig = require(Config:WaitForChild("RewardConfig"))
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local Time = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Time"))

local RewardLogic = {}

-- Daily login ---------------------------------------------------------------------------------
-- Returns (canClaim, newStreak, rewardIndex).
function RewardLogic.Daily(lastDailyDay: number, streak: number, now: number): (boolean, number, number)
	local today = Time.DayKey(now)
	if lastDailyDay == today then
		return false, streak, ((streak - 1) % #RewardConfig.Daily) + 1
	end
	local newStreak = if lastDailyDay == today - 1 then streak + 1 else 1
	return true, newStreak, ((newStreak - 1) % #RewardConfig.Daily) + 1
end

-- Playtime gifts ------------------------------------------------------------------------------
export type PlaytimeData = { playtimeDay: number, playtimeSeconds: number, playtimeClaimed: { [string]: boolean } }

function RewardLogic.PlaytimeRollover(data: PlaytimeData, now: number)
	local today = Time.DayKey(now)
	if data.playtimeDay ~= today then
		data.playtimeDay = today
		data.playtimeSeconds = 0
		data.playtimeClaimed = {}
	end
end

function RewardLogic.CanClaimPlaytime(data: PlaytimeData, tierId: string): (boolean, string?)
	local tier = RewardConfig.Playtime[tierId]
	if tier == nil then
		return false, "Unknown gift"
	end
	if data.playtimeClaimed[tierId] then
		return false, "Already claimed"
	end
	if data.playtimeSeconds < tier.seconds then
		return false, "Not ready yet"
	end
	return true, nil
end

-- Offline earnings ----------------------------------------------------------------------------
-- Returns (creditedSeconds, ember). Clock skew (now < lastSeen) yields 0.
function RewardLogic.Offline(lastSeenAt: number, now: number, power: number, hasLongPass: boolean): (number, number)
	if lastSeenAt <= 0 then
		return 0, 0
	end
	local away = now - lastSeenAt
	if away < EconomyConfig.OfflineMinSeconds then
		return 0, 0
	end
	local cap = if hasLongPass then EconomyConfig.OfflineCapSecondsWithPass else EconomyConfig.OfflineCapSeconds
	local credited = math.min(away, cap)
	local perMinute = power * EconomyConfig.OfflineEmberPerMinutePerPower * EconomyConfig.OfflineEfficiency
	return credited, math.floor(credited / 60 * perMinute)
end

-- Daily quests --------------------------------------------------------------------------------
-- Deterministic pick so a rejoin on the same day shows the same quests.
function RewardLogic.PickDailyQuests(userId: number, dayKey: number): { string }
	local pool = {}
	for id, q in RewardConfig.Quests do
		if q.daily then
			table.insert(pool, id)
		end
	end
	table.sort(pool)
	local seed = (userId * 2654435761 + dayKey * 40503) % 4294967296
	local picked = {}
	local count = math.min(RewardConfig.DailyQuestCount, #pool)
	for _ = 1, count do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local i = (seed % #pool) + 1
		table.insert(picked, table.remove(pool, i) :: string)
	end
	table.sort(picked)
	return picked
end

return RewardLogic
