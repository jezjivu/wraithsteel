--!strict
-- Quests panel (Quest Board / menu): daily login, playtime gifts, offline earnings, quests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Time = require(Shared:WaitForChild("Time"))
local RewardConfig = require(Config:WaitForChild("RewardConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local DataController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("DataController"))

local C = Kit.Colors

local function rewardText(r: { [string]: any }): string
	local parts = {}
	if r.ember then
		table.insert(parts, r.ember .. " Ember")
	end
	if r.jade then
		table.insert(parts, r.jade .. " Jade")
	end
	if r.xp then
		table.insert(parts, r.xp .. " XP")
	end
	if r.lantern then
		table.insert(parts, "free lantern")
	end
	return table.concat(parts, " + ")
end

local Panel: PanelTypes.Panel = {
	Title = "Quest Board",
	WatchKeys = { "quests", "dailyStreak", "lastDailyDay", "playtimeClaimed" },
	Render = function(body, ctx)
		-- Daily login
		local streak = DataController.Get("dailyStreak") or 0
		local claimedToday = DataController.Get("lastDailyDay") == Time.DayKey(os.time())
		local row = Kit.Row(body, 56)
		local info = Kit.Stack(row)
		Kit.Label(info, "Daily Gift", { bold = true, color = C.Gold })
		Kit.Label(info, if claimedToday then "Come back tomorrow · streak " .. streak else "Streak " .. streak .. " - claim today's gift", { size = 13, color = C.Muted })
		Kit.Button(row, if claimedToday then "Claimed" else "Claim", if claimedToday then C.Row else C.Good, function()
			local _, msg = Net.Client.Invoke("ClaimDaily")
			ctx.notify(msg or "Try again")
		end, 110)
		Kit.Button(row, "Offline Ember", C.Blue, function()
			local _, msg = Net.Client.Invoke("ClaimOffline")
			ctx.notify(msg or "Nothing waiting")
		end, 130)

		-- Playtime gifts
		Kit.Section(body, "Playtime gifts (today)")
		local claimed = DataController.Get("playtimeClaimed") or {}
		local gifts = Kit.Row(body, 48)
		for _, tierId in RewardConfig.PlaytimeOrder do
			local tier = RewardConfig.Playtime[tierId]
			local done = claimed[tierId] == true
			Kit.Button(gifts, (if done then "Claimed " else "") .. math.floor(tier.seconds / 60) .. " min", if done then C.Row else C.Gold, function()
				local _, msg = Net.Client.Invoke("ClaimPlaytime", tierId)
				ctx.notify(msg or "Not ready yet")
			end, 110)
		end

		-- Quests
		Kit.Section(body, "Quests")
		local quests = DataController.Get("quests") or {}
		local ids = {}
		for id in quests do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			local da, db = RewardConfig.Quests[a], RewardConfig.Quests[b]
			if da and db and da.daily ~= db.daily then
				return not da.daily
			end
			return a < b
		end)
		for i, id in ids do
			local q = quests[id]
			local def = RewardConfig.Quests[id]
			if def then
				local r = Kit.Row(body, 58, i % 2 == 0)
				local st = Kit.Stack(r)
				Kit.Label(st, (if def.daily then "Daily: " else "Story: ") .. def.name, { bold = true })
				Kit.Label(st, string.format("%d / %d  ·  %s", q.progress, def.goal, rewardText(def.reward)), { size = 13, color = C.Muted })
				local ready = q.progress >= def.goal and not q.claimed
				Kit.Button(r, if q.claimed then "Done" elseif ready then "Claim" else "In progress", if ready then C.Good else C.Row, function()
					if ready then
						local _, msg = Net.Client.Invoke("ClaimQuest", id)
						ctx.notify(msg or "Try again")
					end
				end, 120)
			end
		end
	end,
}

return Panel
