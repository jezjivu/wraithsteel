--!strict
-- RewardService: daily login streak, playtime gifts and offline earnings.
--
-- API:
--   RewardService.ClaimDaily(player) -> (ok, message, reward?)
--   RewardService.ClaimPlaytime(player, tierId) -> (ok, message)
--   RewardService.ClaimOffline(player) -> (ok, message, ember?)
--   RewardService.PendingOffline(player) -> (seconds, ember)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Time = require(Shared:WaitForChild("Time"))
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local RewardConfig = require(Config:WaitForChild("RewardConfig"))

local RewardLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("RewardLogic"))
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local MarketService = require(script.Parent.MarketService)

local PLAYTIME_TICK = 5
local LAST_SEEN_INTERVAL = 60

local RewardService = { Name = "RewardService", Priority = 11 }

local pendingOffline: { [Player]: { seconds: number, ember: number } } = {}

function RewardService.PendingOffline(player: Player): (number, number)
	local p = pendingOffline[player]
	if p then
		return p.seconds, p.ember
	end
	return 0, 0
end

function RewardService.ClaimDaily(player: Player): (boolean, string, any)
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading...", nil
	end
	local now = os.time()
	local ok, streak, index = RewardLogic.Daily(data.lastDailyDay, data.dailyStreak, now)
	if not ok then
		return false, "Come back in " .. Time.FormatDuration(Time.SecondsUntilNextDay(now)), nil
	end
	data.lastDailyDay = Time.DayKey(now)
	data.dailyStreak = streak
	local reward = RewardConfig.Daily[index]
	ProgressionService.GrantReward(player, reward, "Daily")
	DataService.Changed(player, "lastDailyDay", "dailyStreak")
	return true, "Day " .. streak .. " reward claimed!", reward
end

function RewardService.ClaimPlaytime(player: Player, tierId: string): (boolean, string)
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	RewardLogic.PlaytimeRollover(data, os.time())
	local ok, reason = RewardLogic.CanClaimPlaytime(data, tierId)
	if not ok then
		return false, reason or "Not ready"
	end
	data.playtimeClaimed[tierId] = true
	ProgressionService.GrantReward(player, RewardConfig.Playtime[tierId].reward, "Playtime:" .. tierId)
	DataService.Changed(player, "playtimeClaimed")
	return true, "Gift claimed!"
end

function RewardService.ClaimOffline(player: Player): (boolean, string, number?)
	local p = pendingOffline[player]
	if p == nil or p.ember <= 0 then
		return false, "No offline earnings", nil
	end
	pendingOffline[player] = nil
	local granted = ProgressionService.AddEmber(player, p.ember, "Offline", false)
	return true, "Welcome back! +" .. FormatNumber.Short(granted) .. " Ember", granted
end

local function onLoaded(player: Player, data: any)
	local now = os.time()
	local seconds, ember = RewardLogic.Offline(
		data.lastSeenAt,
		now,
		ProgressionService.GetPower(player),
		MarketService.HasPass(player, "LongExpeditions")
	)
	if ember > 0 then
		pendingOffline[player] = { seconds = seconds, ember = ember }
		Net.Server.Fire("Notify", player, "Offline", string.format("You were away %s: %s Ember waiting", Time.FormatDuration(seconds), FormatNumber.Short(ember)))
	end
	data.lastSeenAt = now
	RewardLogic.PlaytimeRollover(data, now)
end

function RewardService.Init() end

function RewardService.Start()
	DataService.ProfileLoaded:Connect(onLoaded)
	DataService.ProfileReleasing:Connect(function(player: Player, data: any)
		data.lastSeenAt = os.time()
		-- Unclaimed offline earnings are kept: lastSeenAt was already advanced on load, so grant now.
		local p = pendingOffline[player]
		if p and p.ember > 0 then
			data.ember += p.ember
		end
		pendingOffline[player] = nil
	end)

	Net.Server.OnInvoke("ClaimDaily", RewardService.ClaimDaily)
	Net.Server.OnInvoke("ClaimPlaytime", RewardService.ClaimPlaytime)
	Net.Server.OnInvoke("ClaimOffline", RewardService.ClaimOffline)

	task.spawn(function()
		local sinceLastSeen = 0
		while true do
			task.wait(PLAYTIME_TICK)
			sinceLastSeen += PLAYTIME_TICK
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataService.GetData(player)
				if data then
					RewardLogic.PlaytimeRollover(data, now)
					data.playtimeSeconds += PLAYTIME_TICK
					if sinceLastSeen >= LAST_SEEN_INTERVAL then
						data.lastSeenAt = now -- crash safety: offline time never double-counts
					end
				end
			end
			if sinceLastSeen >= LAST_SEEN_INTERVAL then
				sinceLastSeen = 0
			end
		end
	end)
end

return RewardService
