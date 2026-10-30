--!strict
-- MarketService: game passes (cached), gifted passes, developer products with idempotent
-- ProcessReceipt (guide §8.2 rule 6; core rule documented in Logic/ReceiptLedger).
--
-- API:
--   MarketService.HasPass(player, passKey) -> boolean     owned OR gifted
--   MarketService.PassGranted: Signal(player, passKey)
--   MarketService.BoostActive(player, boostId) -> boolean
--   MarketService.PromptProduct(player, productKey) / PromptPass(player, passKey)
--   MarketService.ProcessReceipt(receiptInfo) -> Enum.ProductPurchaseDecision

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))

local ReceiptLedger = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("ReceiptLedger"))
local DataService = require(script.Parent.DataService)
local AnalyticsService = require(script.Parent.AnalyticsService)

type ProfileData = Types.ProfileData

local SAVE_WAIT_SECONDS = 20

local MarketService = {
	Name = "MarketService",
	Priority = 3,
	PassGranted = Signal.new(),
}

local passCache: { [Player]: { [string]: boolean } } = {}
local passKeyById: { [number]: string } = {}
local productKeyById: { [number]: string } = {}
local pendingGift: { [Player]: { targetUserId: number, passKey: string, expiresAt: number } } = {}

for key, def in MonetizationConfig.Passes do
	if def.id ~= 0 then
		passKeyById[def.id] = key
	end
end
for key, def in MonetizationConfig.Products do
	if def.id ~= 0 then
		productKeyById[def.id] = key
	end
end

local function notify(player: Player, kind: string, text: string)
	Net.Server.Fire("Notify", player, kind, text)
end

function MarketService.HasPass(player: Player, passKey: string): boolean
	local cached = passCache[player]
	if cached and cached[passKey] then
		return true
	end
	local data = DataService.GetData(player)
	return data ~= nil and data.giftedPasses[passKey] == true
end

function MarketService.BoostActive(player: Player, boostId: string): boolean
	local data = DataService.GetData(player)
	return data ~= nil and (data.boosts[boostId] or 0) > os.time()
end

local function grantPassLocally(player: Player, passKey: string)
	local cached = passCache[player]
	if cached and not cached[passKey] then
		cached[passKey] = true
	end
	MarketService.PassGranted:Fire(player, passKey)
	Net.Server.Fire("Notify", player, "Pass", MonetizationConfig.Passes[passKey].name .. " unlocked!")
end

local function loadPasses(player: Player)
	local owned = {}
	passCache[player] = owned
	for key, def in MonetizationConfig.Passes do
		if def.id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, def.id)
			if ok and has then
				owned[key] = true
				MarketService.PassGranted:Fire(player, key)
			end
		end
	end
end

-- Grants -----------------------------------------------------------------------------------

-- Delivers a gifted pass to `targetUserId` (online in this server: direct; otherwise a profile
-- message). Idempotent on the recipient side via giftMessagesSeen[purchaseId].
local function deliverGift(buyer: Player, targetUserId: number, passKey: string, purchaseId: string): boolean
	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		local tdata = DataService.GetData(target)
		if tdata then
			if not tdata.giftMessagesSeen[purchaseId] then
				tdata.giftMessagesSeen[purchaseId] = true
				tdata.giftedPasses[passKey] = true
				DataService.Changed(target, "giftedPasses")
				grantPassLocally(target, passKey)
				notify(target, "Gift", buyer.DisplayName .. " gifted you " .. MonetizationConfig.Passes[passKey].name .. "!")
			end
			return true
		end
	end
	return DataService.MessageAsync(targetUserId, {
		kind = "GiftPass",
		passKey = passKey,
		fromUserId = buyer.UserId,
		fromName = buyer.DisplayName,
		purchaseId = purchaseId,
	})
end

local function grantProduct(player: Player, data: ProfileData, productKey: string, purchaseId: string): boolean
	local def = MonetizationConfig.Products[productKey]
	if def.kind == "Jade" then
		local amount = def.amount or 0
		data.jade += amount
		DataService.Changed(player, "jade")
		AnalyticsService.Economy(player, "Source", "Jade", amount, data.jade, "IAP", productKey)
		return true
	elseif def.kind == "Boost" then
		local boostId = def.boostId :: string
		local now = os.time()
		data.boosts[boostId] = math.max(now, data.boosts[boostId] or 0) + (def.durationSeconds or 0)
		DataService.Changed(player, "boosts")
		return true
	elseif def.kind == "GiftPass" then
		local passKey = def.passKey :: string
		local pending = pendingGift[player]
		if pending and pending.passKey == passKey and pending.expiresAt > os.time() then
			if deliverGift(player, pending.targetUserId, passKey, purchaseId) then
				pendingGift[player] = nil
				notify(player, "Gift", "Gift sent!")
				return true
			end
		end
		-- No valid recipient (expired selection, recipient unreachable): keep it as a token the
		-- buyer can send later so the purchase is never lost.
		data.giftTokens[passKey] = (data.giftTokens[passKey] or 0) + 1
		DataService.Changed(player, "giftTokens")
		notify(player, "Gift", "Gift saved - you can send it from the Store later.")
		return true
	end
	return false
end

-- ProcessReceipt -----------------------------------------------------------------------------

function MarketService.ProcessReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local productKey = productKeyById[info.ProductId]
	if productKey == nil then
		warn("[MarketService] receipt for unknown product", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.WaitForData(player, 15)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	local decision = ReceiptLedger.Apply(
		data :: any,
		purchaseId,
		tonumber(info.CurrencySpent) or 0,
		MonetizationConfig.ReceiptHistoryLimit,
		function()
			return grantProduct(player, data, productKey, purchaseId)
		end
	)
	if decision == "GrantFailed" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Granted or AlreadyGranted: only confirm once the purchaseId is persisted.
	local saved = DataService.SaveAndWait(player, function(last)
		return type(last) == "table" and type(last.receipts) == "table" and last.receipts[purchaseId] == true
	end, SAVE_WAIT_SECONDS)
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Prompts ----------------------------------------------------------------------------------

function MarketService.PromptProduct(player: Player, productKey: string)
	local def = MonetizationConfig.Products[productKey]
	if def == nil or def.id == 0 then
		notify(player, "Error", "That item is not available yet.")
		return
	end
	MarketplaceService:PromptProductPurchase(player, def.id)
end

function MarketService.PromptPass(player: Player, passKey: string)
	local def = MonetizationConfig.Passes[passKey]
	if def == nil or def.id == 0 then
		notify(player, "Error", "That pass is not available yet.")
		return
	end
	if MarketService.HasPass(player, passKey) then
		notify(player, "Info", "You already own " .. def.name .. ".")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, def.id)
end

-- Records who the buyer wants to gift to, then prompts the gift product.
local function prepareGift(player: Player, targetUserId: number, passKey: string): (boolean, string?)
	local pass = MonetizationConfig.Passes[passKey]
	if pass == nil or pass.giftProduct == nil then
		return false, "This pass cannot be gifted."
	end
	if targetUserId == player.UserId then
		return false, "You cannot gift yourself."
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if target and MarketService.HasPass(target, passKey) then
		return false, "They already own this pass."
	end
	local data = DataService.GetData(player)
	if data and (data.giftTokens[passKey] or 0) > 0 then
		-- Send a saved gift token instead of charging again.
		if deliverGift(player, targetUserId, passKey, "token:" .. player.UserId .. ":" .. os.time()) then
			data.giftTokens[passKey] -= 1
			DataService.Changed(player, "giftTokens")
			return true, "Saved gift sent!"
		end
		return false, "Could not reach that player. Try again later."
	end
	pendingGift[player] = {
		targetUserId = targetUserId,
		passKey = passKey,
		expiresAt = os.time() + MonetizationConfig.GiftTargetTimeoutSeconds,
	}
	MarketService.PromptProduct(player, pass.giftProduct :: string)
	return true, nil
end

local priceCache: { [string]: number } = {}
local function storeInfo(player: Player)
	local passes = {}
	for key, def in MonetizationConfig.Passes do
		local price = priceCache["pass:" .. key]
		if price == nil and def.id ~= 0 then
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, def.id, Enum.InfoType.GamePass)
			if ok and info then
				price = info.PriceInRobux
				priceCache["pass:" .. key] = price
			end
		end
		passes[key] = { name = def.name, description = def.description, available = def.id ~= 0, owned = MarketService.HasPass(player, key), price = price, giftable = def.giftProduct ~= nil }
	end
	local products = {}
	for key, def in MonetizationConfig.Products do
		local price = priceCache["product:" .. key]
		if price == nil and def.id ~= 0 then
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, def.id, Enum.InfoType.Product)
			if ok and info then
				price = info.PriceInRobux
				priceCache["product:" .. key] = price
			end
		end
		products[key] = { name = def.name, kind = def.kind, amount = def.amount, available = def.id ~= 0, price = price }
	end
	return { passes = passes, products = products }
end

function MarketService.Init()
	DataService.SetMessageHandler("GiftPass", function(player, data, message)
		local purchaseId = tostring(message.purchaseId)
		local passKey = message.passKey
		if MonetizationConfig.Passes[passKey] == nil then
			return true -- drop malformed
		end
		if not data.giftMessagesSeen[purchaseId] then
			data.giftMessagesSeen[purchaseId] = true
			data.giftedPasses[passKey] = true
			DataService.Changed(player, "giftedPasses")
			grantPassLocally(player, passKey)
			notify(player, "Gift", tostring(message.fromName) .. " gifted you " .. MonetizationConfig.Passes[passKey].name .. "!")
		end
		return true
	end)
end

function MarketService.Start()
	MarketplaceService.ProcessReceipt = MarketService.ProcessReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById[passId]
		if purchased and key then
			grantPassLocally(player, key)
			AnalyticsService.Custom(player, "PassPurchased:" .. key)
		end
	end)

	Players.PlayerAdded:Connect(loadPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		passCache[player] = nil
		pendingGift[player] = nil
	end)

	Net.Server.On("PromptProduct", MarketService.PromptProduct)
	Net.Server.On("PromptPass", MarketService.PromptPass)
	Net.Server.OnInvoke("PrepareGift", prepareGift)
	Net.Server.OnInvoke("GetStoreInfo", storeInfo)
end

return MarketService
