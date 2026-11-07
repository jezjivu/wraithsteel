--!strict
-- LanternService: opens Spirit Lanterns (the game's eggs) with server RNG.
-- Compliance (guide §0):
--   * odds come from Shared/LanternOdds (same function the UI shows via GetLanternOdds)
--   * paid lanterns (LanternOdds.IsPaid: priced in a Robux-purchasable currency, i.e. Jade AND
--     Ember, since both are sold in the store) are refused when PolicyService says paid random
--     items are restricted for this player; free opens (rewards/codes) still work there
--   * Spirits bought with currency from a paid lantern get `paid = true` (trade rule)
--   * pity rules are part of the displayed odds sheet
--
-- API:
--   LanternService.Open(player, lanternId, count) -> { results } | (nil, reason)
--   LanternService.OddsSheet(player, lanternId) -> LanternOdds.OddsSheet
--   LanternService.Opened: Signal(player, lanternId, results)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local LanternOdds = require(Shared:WaitForChild("LanternOdds"))
local LanternConfig = require(Config:WaitForChild("LanternConfig"))

local LanternRoll = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("LanternRoll"))
local DataService = require(script.Parent.DataService)
local PolicyService = require(script.Parent.PolicyService)
local MarketService = require(script.Parent.MarketService)
local ProgressionService = require(script.Parent.ProgressionService)
local SpiritService = require(script.Parent.SpiritService)
local QuestService = require(script.Parent.QuestService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local LanternService = {
	Name = "LanternService",
	Priority = 21,
	Opened = Signal.new(),
}

local rng = Random.new()
local lastOpenAt: { [Player]: number } = {}

local function roll01(): number
	return rng:NextNumber()
end

function LanternService.OddsSheet(player: Player, lanternId: string): LanternOdds.OddsSheet?
	if LanternConfig.Lanterns[lanternId] == nil then
		return nil
	end
	local data = DataService.GetData(player)
	local pity = if data then data.lanternPity[lanternId] or 0 else 0
	return LanternOdds.Sheet(lanternId, ProgressionService.GetLuck(player), pity)
end

local function maxCount(player: Player): number
	return if MarketService.HasPass(player, "TripleOpen") then LanternConfig.MaxOpenPerRequest else 1
end

function LanternService.Open(player: Player, lanternId: string, count: number): (any, string?)
	local lantern = LanternConfig.Lanterns[lanternId]
	local data = DataService.GetData(player)
	if lantern == nil or data == nil then
		return nil, "Unavailable"
	end
	local isPaid = LanternOdds.IsPaid(lanternId)
	local restricted = isPaid and not PolicyService.CanBuyPaidRandomItems(player)
	if data.chapter < lantern.chapter then
		return nil, "Reach the chapter where this lantern is found first."
	end
	count = math.clamp(math.floor(count), 1, maxCount(player))
	local now = os.clock()
	if now - (lastOpenAt[player] or 0) < LanternConfig.OpenCooldownSeconds then
		return nil, "Slow down"
	end
	if SpiritService.FreeStorage(player) < count then
		return nil, "Your Spirit storage is full. Release or fuse Spirits first."
	end

	-- Pay: free opens first (Ember lanterns only), then currency.
	-- Free opens (rewards/codes, never Robux) are not paid randomness, so they work everywhere.
	local free = math.min(count, data.freeLanterns[lanternId] or 0)
	if restricted and free < count then
		return nil, "This lantern is not available in your region."
	end
	local cost = lantern.price * (count - free)
	local paid = if cost == 0
		then true
		elseif lantern.currency == "Jade" then ProgressionService.SpendJade(player, cost, "Lantern:" .. lanternId)
		else ProgressionService.SpendEmber(player, cost, "Lantern:" .. lanternId)
	if not paid then
		return nil, "Not enough " .. lantern.currency
	end
	if free > 0 then
		data.freeLanterns[lanternId] -= free
		DataService.Changed(player, "freeLanterns")
	end
	lastOpenAt[player] = now

	local luck = ProgressionService.GetLuck(player)
	local results = {}
	for i = 1, count do
		local r = LanternRoll.Roll(lanternId, luck, data.lanternPity, roll01)
		-- Opens beyond the free ones were bought with currency; flag them if that currency is paid.
		local inst = SpiritService.Grant(player, r.spirit, r.rarity, r.mutation, isPaid and i > free)
		table.insert(results, { uid = inst and inst.uid, spirit = r.spirit, rarity = r.rarity, mutation = r.mutation, pity = r.pityTriggered })
	end
	data.hatchedTotal += count
	DataService.Changed(player, "lanternPity", "hatchedTotal")

	QuestService.Increment(player, "LanternsOpened", count)
	AnalyticsService.Onboarding(player, "FirstLanternOpened")
	LanternService.Opened:Fire(player, lanternId, results)
	return results, nil
end

function LanternService.Init() end

function LanternService.Start()
	Net.Server.OnInvoke("GetLanternOdds", LanternService.OddsSheet)
	Net.Server.OnInvoke("OpenLantern", LanternService.Open)
	Players.PlayerRemoving:Connect(function(player)
		lastOpenAt[player] = nil
	end)
end

return LanternService
