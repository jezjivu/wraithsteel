--!strict
-- ProgressionService: Ember, Jade, XP/levels, Power and multipliers.
-- All numbers come from EconomyConfig; formulas from Shared/ProgressionMath.
--
-- API:
--   AddEmber(player, amount, source, applyMultiplier?) -> number granted
--   SpendEmber(player, amount, sink) -> boolean
--   AddJade(player, amount, source) / SpendJade(player, amount, sink) -> boolean
--   AddXp(player, amount) -> levelsGained
--   GrantReward(player, reward: RewardConfig.Reward, source) -> applies ember/jade/xp/lantern
--   GetMultiplier(player, category: "Ember"|"Luck") -> number
--   GetLuck(player) -> number (capped at EconomyConfig.MaxLuck)
--   GetPower(player) -> number (chapter-capped); RefreshPower(player)
--   LevelUp: Signal(player, newLevel)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Signal = require(Shared:WaitForChild("Signal"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionMath = require(Shared:WaitForChild("ProgressionMath"))
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))

local SpiritLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("SpiritLogic"))
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ProgressionService = {
	Name = "ProgressionService",
	Priority = 4,
	LevelUp = Signal.new(),
}

-- Session-only extra multipliers (e.g. party bonus) set by other services.
local sessionBonus: { [Player]: { [string]: number } } = {}

function ProgressionService.SetSessionBonus(player: Player, category: string, value: number)
	sessionBonus[player] = sessionBonus[player] or {}
	sessionBonus[player][category] = value
end

function ProgressionService.GetMultiplier(player: Player, category: string): number
	local active = {}
	if category == "Ember" then
		active.DoubleEmberPass = MarketService.HasPass(player, "DoubleEmber")
		active.EmberBoost = MarketService.BoostActive(player, "EmberBoost")
	elseif category == "Luck" then
		active.LuckyCharmPass = MarketService.HasPass(player, "LuckyCharm")
		active.LuckBoost = MarketService.BoostActive(player, "LuckBoost")
	end
	local extra = (sessionBonus[player] and sessionBonus[player][category]) or 0
	local data = DataService.GetData(player)
	if data then
		if category == "Ember" then
			extra += SpiritLogic.PassiveTotal(data :: any, "EmberMultiplier")
		elseif category == "Luck" then
			extra += SpiritLogic.PassiveTotal(data :: any, "Luck")
		end
	end
	return ProgressionMath.CategoryMultiplier(category, active, extra)
end

function ProgressionService.GetLuck(player: Player): number
	return math.min(ProgressionService.GetMultiplier(player, "Luck"), EconomyConfig.MaxLuck)
end

function ProgressionService.AddEmber(player: Player, amount: number, source: string, applyMultiplier: boolean?): number
	local data = DataService.GetData(player)
	if data == nil or amount <= 0 then
		return 0
	end
	local granted = amount
	if applyMultiplier ~= false then
		granted = math.floor(amount * ProgressionService.GetMultiplier(player, "Ember"))
	end
	data.ember = math.min(EconomyConfig.MaxEmber, data.ember + granted)
	DataService.Changed(player, "ember")
	AnalyticsService.Economy(player, "Source", "Ember", granted, data.ember, "Gameplay", source)
	return granted
end

function ProgressionService.SpendEmber(player: Player, amount: number, sink: string): boolean
	local data = DataService.GetData(player)
	if data == nil or amount < 0 or data.ember < amount then
		return false
	end
	data.ember -= amount
	DataService.Changed(player, "ember")
	AnalyticsService.Economy(player, "Sink", "Ember", amount, data.ember, "Shop", sink)
	return true
end

function ProgressionService.AddJade(player: Player, amount: number, source: string)
	local data = DataService.GetData(player)
	if data == nil or amount <= 0 then
		return
	end
	data.jade += amount
	DataService.Changed(player, "jade")
	AnalyticsService.Economy(player, "Source", "Jade", amount, data.jade, "Gameplay", source)
end

function ProgressionService.SpendJade(player: Player, amount: number, sink: string): boolean
	local data = DataService.GetData(player)
	if data == nil or amount < 0 or data.jade < amount then
		return false
	end
	data.jade -= amount
	DataService.Changed(player, "jade")
	AnalyticsService.Economy(player, "Sink", "Jade", amount, data.jade, "Shop", sink)
	return true
end

function ProgressionService.GetPower(player: Player): number
	local data = DataService.GetData(player)
	if data == nil then
		return 0
	end
	local weapon = WeaponConfig.Weapons[data.equippedWeapon]
	local _, capped = ProgressionMath.Power(
		data.level,
		if weapon then weapon.power else 0,
		SpiritLogic.EquippedPower(data :: any),
		data.chapter
	)
	return capped
end

-- Publishes Power/Level as attributes (cheap for HUD + other services to read).
function ProgressionService.RefreshPower(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	player:SetAttribute("Power", ProgressionService.GetPower(player))
	player:SetAttribute("Level", data.level)
end

function ProgressionService.AddXp(player: Player, amount: number): number
	local data = DataService.GetData(player)
	if data == nil or amount <= 0 then
		return 0
	end
	local level, xp, gained = ProgressionMath.ApplyXp(data.level, data.xp, amount)
	data.level, data.xp = level, xp
	DataService.Changed(player, "xp", "level")
	if gained > 0 then
		ProgressionService.RefreshPower(player)
		ProgressionService.LevelUp:Fire(player, level)
		Net.Server.Fire("Notify", player, "LevelUp", "Level " .. level .. "!")
	end
	return gained
end

export type Reward = { ember: number?, jade: number?, xp: number?, lantern: string? }

-- Fixed rewards (daily, quests, codes) are NOT multiplied by Ember boosts.
function ProgressionService.GrantReward(player: Player, reward: Reward, source: string)
	if reward.ember then
		ProgressionService.AddEmber(player, reward.ember, source, false)
	end
	if reward.jade then
		ProgressionService.AddJade(player, reward.jade, source)
	end
	if reward.xp then
		ProgressionService.AddXp(player, reward.xp)
	end
	if reward.lantern then
		local data = DataService.GetData(player)
		if data then
			data.freeLanterns[reward.lantern] = (data.freeLanterns[reward.lantern] or 0) + 1
			DataService.Changed(player, "freeLanterns")
		end
	end
end

function ProgressionService.Init() end

function ProgressionService.Start()
	DataService.ProfileLoaded:Connect(function(player)
		ProgressionService.RefreshPower(player)
	end)
	MarketService.PassGranted:Connect(function(player)
		ProgressionService.RefreshPower(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessionBonus[player] = nil
	end)
end

return ProgressionService
