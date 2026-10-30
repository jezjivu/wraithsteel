--!strict
-- DebugService: STUDIO-ONLY chat commands for playtesting before the real UI exists.
-- Does nothing in live servers (RunService:IsStudio() is false there).
--   /ember 1000          add Ember
--   /odds paper_lantern  show lantern odds as toasts
--   /open paper_lantern  open a lantern (Studio only - real UI must show odds first)
--   /spirits             list your Spirits
--   /equipall            equip as many Spirits as slots allow
--   /daily               claim daily reward
--   /stats               show level/power

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local SpiritConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SpiritConfig"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local SpiritService = require(script.Parent.SpiritService)
local LanternService = require(script.Parent.LanternService)
local RewardService = require(script.Parent.RewardService)

local DebugService = { Name = "DebugService", Priority = 90 }

local function say(player: Player, text: string)
	Net.Server.Fire("Notify", player, "Info", text)
	print("[Debug]", player.Name, text)
end

local commands: { [string]: (Player, string?) -> () } = {
	["/ember"] = function(player, arg)
		local n = tonumber(arg) or 1000
		ProgressionService.AddEmber(player, n, "Debug", false)
		say(player, "+" .. FormatNumber.Short(n) .. " Ember")
	end,
	["/odds"] = function(player, arg)
		local sheet = LanternService.OddsSheet(player, arg or "paper_lantern")
		if sheet == nil then
			say(player, "Unknown lantern")
			return
		end
		for _, r in sheet.spirits do
			say(player, SpiritConfig.Spirits[r.id].name .. ": " .. FormatNumber.Percent(r.percent))
		end
	end,
	["/open"] = function(player, arg)
		local results, err = LanternService.Open(player, arg or "paper_lantern", 1)
		if results == nil then
			say(player, err or "Failed")
			return
		end
		for _, r in results do
			local mut = if r.mutation ~= "None" then r.mutation .. " " else ""
			say(player, "Hatched " .. mut .. SpiritConfig.Spirits[r.spirit].name .. " (" .. r.rarity .. ")")
		end
	end,
	["/spirits"] = function(player)
		local data = DataService.GetData(player)
		if data == nil then
			return
		end
		local n = 0
		for uid, s in data.spirits do
			n += 1
			if n <= 6 then
				say(player, uid .. ": " .. SpiritConfig.Spirits[s.id].name .. " " .. s.rarity .. " " .. s.mutation)
			end
		end
		say(player, n .. " Spirits total")
	end,
	["/equipall"] = function(player)
		local data = DataService.GetData(player)
		if data == nil then
			return
		end
		for uid in data.spirits do
			SpiritService.Equip(player, uid)
		end
		say(player, "Equipped " .. #data.equippedSpirits .. " Spirits. Power " .. ProgressionService.GetPower(player))
	end,
	["/daily"] = function(player)
		local _, msg = RewardService.ClaimDaily(player)
		say(player, msg)
	end,
	["/stats"] = function(player)
		local data = DataService.GetData(player)
		if data then
			say(player, string.format("Lv %d  XP %d  Power %d  Chapter %d", data.level, data.xp, ProgressionService.GetPower(player), data.chapter))
		end
	end,
}

local function hook(player: Player)
	player.Chatted:Connect(function(message)
		local cmd, arg = string.match(message, "^(/%a+)%s*(%S*)")
		local fn = cmd and commands[string.lower(cmd)]
		if fn then
			fn(player, if arg ~= "" then arg else nil)
		end
	end)
end

function DebugService.Init() end

function DebugService.Start()
	if not RunService:IsStudio() then
		return
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	print("[DebugService] Studio chat commands: /ember /odds /open /spirits /equipall /daily /stats")
end

return DebugService
