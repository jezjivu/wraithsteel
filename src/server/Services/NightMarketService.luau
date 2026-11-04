--!strict
-- NightMarketService: the rotating Night Market (rules in Shared/NightMarketLogic).
-- Stock is global and deterministic: window = os.time() // NightMarketConfig.WindowSeconds,
-- seed = hash(window, salt). Every server sells the same items at the same time and the client
-- can show the stock and countdown itself. Prices and items are fixed (nothing random is sold).
--
-- API:
--   NightMarketService.Info(player) -> { window, endsAt, stock = { {slot,itemId,bought} } }
--   NightMarketService.Buy(player, slot, clientWindow) -> (ok, message)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local NightMarketLogic = require(Shared:WaitForChild("NightMarketLogic"))
local NightMarketConfig = require(Config:WaitForChild("NightMarketConfig"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local SpiritService = require(script.Parent.SpiritService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local NightMarketService = { Name = "NightMarketService", Priority = 24 }

local busy: { [Player]: boolean } = {}

local function state(data: any, window: number): NightMarketLogic.PlayerState
	local st = NightMarketLogic.Fresh(data.nightMarket, window)
	data.nightMarket = st
	return st
end

function NightMarketService.Info(player: Player): any
	local data = DataService.GetData(player)
	if data == nil then
		return nil
	end
	local window = NightMarketLogic.Window(os.time())
	local st = state(data, window)
	local stock = {}
	for _, e in NightMarketLogic.Stock(window) do
		table.insert(stock, { slot = e.slot, itemId = e.itemId, bought = st.bought[e.itemId] or 0 })
	end
	return { window = window, endsAt = NightMarketLogic.WindowEndsAt(window), stock = stock }
end

local function grant(player: Player, def: NightMarketConfig.ItemDef): boolean
	local data = DataService.GetData(player)
	if data == nil then
		return false
	end
	if def.kind == "Spirit" and def.spirit then
		-- Bought with Robux-purchasable currency -> paid flag (trade rule).
		return SpiritService.Grant(player, def.spirit.id, def.spirit.rarity, def.spirit.mutation, true) ~= nil
	elseif def.kind == "Boost" and def.boostId and def.seconds then
		local now = os.time()
		data.boosts[def.boostId] = math.max(now, data.boosts[def.boostId] or 0) + def.seconds
		DataService.Changed(player, "boosts")
		return true
	elseif def.kind == "Ember" and def.amount then
		ProgressionService.AddEmber(player, def.amount, "NightMarket", false)
		return true
	end
	return false
end

function NightMarketService.Buy(player: Player, slot: number, clientWindow: number): (boolean, string?)
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	if busy[player] then
		return false, "One moment"
	end
	local window = NightMarketLogic.Window(os.time())
	local st = state(data, window)
	local itemId, err = NightMarketLogic.CanBuy(st, window, clientWindow, slot, data.chapter)
	if itemId == nil then
		return false, err
	end
	local def = NightMarketConfig.Items[itemId]
	if def.kind == "Spirit" and SpiritService.FreeStorage(player) < 1 then
		return false, "Your Spirit storage is full"
	end
	busy[player] = true
	local paid = if def.currency == "Jade"
		then ProgressionService.SpendJade(player, def.price, "NightMarket:" .. itemId)
		else ProgressionService.SpendEmber(player, def.price, "NightMarket:" .. itemId)
	if not paid then
		busy[player] = nil
		return false, "Not enough " .. def.currency
	end
	if not grant(player, def) then
		-- Refund: nothing was given (should not happen; config is validated by tests).
		if def.currency == "Jade" then
			ProgressionService.AddJade(player, def.price, "NightMarketRefund")
		else
			ProgressionService.AddEmber(player, def.price, "NightMarketRefund", false)
		end
		busy[player] = nil
		return false, "Could not deliver that item"
	end
	st.bought[itemId] = (st.bought[itemId] or 0) + 1
	DataService.Changed(player, "nightMarket")
	AnalyticsService.Custom(player, "NightMarketBuy", def.price)
	busy[player] = nil
	return true, def.name .. " is yours!"
end

function NightMarketService.Init() end

function NightMarketService.Start()
	Net.Server.OnInvoke("GetNightMarket", NightMarketService.Info)
	Net.Server.OnInvoke("BuyNightMarket", NightMarketService.Buy)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)
end

return NightMarketService
