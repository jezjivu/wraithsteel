--!strict
-- TradeService: player-to-player Spirit trading (rules in Logic/TradeLogic).
-- Flow: A requests B -> B requests A back (or accepts from the Trade panel) -> session opens ->
-- both pick Spirits (any change clears confirmations) -> both confirm -> countdown -> server
-- re-validates -> escrow record committed to the trade ledger (Logic/TradeLedger) -> each
-- profile applies its side in one synchronous step -> both profiles are saved right away.
-- Crash safety: a profile that missed its side (server died before it saved) gets it on its
-- next load via a DataService load hook (TradeLedger.Recover). Spirits of both players are
-- frozen (Logic/TradeLock) while the ledger is written.
-- Compliance (paid-flag rule): Spirits with `paid = true` can only be offered when BOTH players'
-- policy allows paid item trading. Free Spirits trade for everyone.
--
-- API:
--   TradeService.CanTrade(player) -> boolean            any trading at all (always true now)
--   TradeService.CanTradePaid(a, b) -> boolean          paid Spirits allowed between a and b

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local NetValidate = require(Shared:WaitForChild("NetValidate"))
local TradeConfig = require(Config:WaitForChild("TradeConfig"))

local Logic = script.Parent.Parent:WaitForChild("Logic")
local TradeLogic = require(Logic:WaitForChild("TradeLogic"))
local TradeLedger = require(Logic:WaitForChild("TradeLedger"))
local TradeLock = require(Logic:WaitForChild("TradeLock"))
local DataService = require(script.Parent.DataService)
local PolicyService = require(script.Parent.PolicyService)
local ProgressionService = require(script.Parent.ProgressionService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local TradeService = { Name = "TradeService", Priority = 51 }

local requests: { [number]: { [number]: number } } = {} -- target -> { from -> expiresAt }
local sessions: { [number]: TradeLogic.Session } = {} -- userId -> session (both sides point to it)

local ledger: TradeLedger.Store

function TradeService.CanTrade(_player: Player): boolean
	return true
end

function TradeService.CanTradePaid(a: Player, b: Player): boolean
	return PolicyService.CanTradePaidItems(a) and PolicyService.CanTradePaidItems(b)
end

-- In-memory store: Studio without API access only (nothing persists, warns once).
local function memoryStore(): TradeLedger.Store
	local mem: { [string]: any } = {}
	return {
		update = function(key, fn)
			local new = fn(mem[key])
			if new ~= nil then
				mem[key] = new
			end
			return true, mem[key]
		end,
		get = function(key)
			return true, mem[key]
		end,
	}
end

local function dataStore(ds: DataStore): TradeLedger.Store
	return {
		update = function(key, fn)
			local ok, value = pcall(function()
				return ds:UpdateAsync(key, function(old)
					return fn(old)
				end)
			end)
			if not ok then
				warn("[TradeService] ledger update failed", key, value)
			end
			return ok, value
		end,
		get = function(key)
			local ok, value = pcall(function()
				return ds:GetAsync(key)
			end)
			if not ok then
				warn("[TradeService] ledger read failed", key, value)
			end
			return ok, value
		end,
	}
end

local function makeLedger(): TradeLedger.Store
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(TradeConfig.LedgerStoreName)
	end)
	if ok and ds and RunService:IsStudio() then
		local probeOk = pcall(function()
			return ds:GetAsync("probe")
		end)
		if not probeOk then
			warn("[TradeService] Studio without DataStore access: trade ledger is in memory only")
			return memoryStore()
		end
	end
	if not ok or ds == nil then
		if RunService:IsStudio() then
			return memoryStore()
		end
		error("[TradeService] trade ledger DataStore unavailable: " .. tostring(ds))
	end
	return dataStore(ds)
end

local function summary(data: any, uids: { string }): { any }
	local out = {}
	for _, uid in uids do
		local s = data and data.spirits[uid]
		if s then
			table.insert(out, { uid = uid, id = s.id, rarity = s.rarity, mutation = s.mutation, level = s.level })
		end
	end
	return out
end

local function push(player: Player)
	local me = player.UserId
	local s = sessions[me]
	local incoming = {}
	local now = os.time()
	local pending = requests[me]
	if pending then
		for from, expires in pending do
			local p = Players:GetPlayerByUserId(from)
			if p and expires > now then
				table.insert(incoming, { userId = from, name = p.DisplayName })
			end
		end
	end
	if s == nil then
		Net.Server.Fire("TradeEvent", player, {
			active = false,
			incoming = incoming,
			allowed = TradeService.CanTrade(player),
			paidAllowed = PolicyService.CanTradePaidItems(player),
		})
		return
	end
	local mine, theirs = TradeLogic.SideOf(s, me)
	if mine == nil or theirs == nil then
		return
	end
	local partner = Players:GetPlayerByUserId(theirs.userId)
	Net.Server.Fire("TradeEvent", player, {
		active = true,
		allowed = true,
		paidAllowed = s.allowPaid,
		executing = s.executing,
		partnerName = if partner then partner.DisplayName else "?",
		myOffer = summary(DataService.GetData(player), mine.offer),
		theirOffer = summary(partner and DataService.GetData(partner), theirs.offer),
		myConfirmed = mine.confirmed,
		theirConfirmed = theirs.confirmed,
		countdown = if s.countdownEndsAt then math.max(0, s.countdownEndsAt - os.clock()) else nil,
		incoming = incoming,
	})
end

local function pushBoth(s: TradeLogic.Session)
	for _, id in { s.a.userId, s.b.userId } do
		local p = Players:GetPlayerByUserId(id)
		if p then
			push(p)
		end
	end
end

local function close(s: TradeLogic.Session, message: string?)
	sessions[s.a.userId] = nil
	sessions[s.b.userId] = nil
	for _, id in { s.a.userId, s.b.userId } do
		local p = Players:GetPlayerByUserId(id)
		if p then
			if message then
				Net.Server.Fire("Notify", p, "Trade", message)
			end
			push(p)
		end
	end
end

local function near(a: Player, b: Player): boolean
	local ra = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
	local rb = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
	if ra and rb and ra:IsA("BasePart") and rb:IsA("BasePart") then
		return (ra.Position - rb.Position).Magnitude <= TradeConfig.MaxDistance
	end
	return false
end

local function requestTrade(player: Player, targetUserId: number): (boolean, string?)
	local target = Players:GetPlayerByUserId(targetUserId)
	if target == nil or target == player then
		return false, "That player is not here"
	end
	if not TradeService.CanTrade(player) or not TradeService.CanTrade(target) then
		return false, "Trading is not available for one of these accounts."
	end
	if sessions[player.UserId] or sessions[targetUserId] then
		return false, "Someone is already trading"
	end
	if not near(player, target) then
		return false, "Stand closer to trade"
	end
	local now = os.time()
	local theirRequest = requests[player.UserId] and requests[player.UserId][targetUserId]
	if theirRequest and theirRequest > now then
		requests[player.UserId][targetUserId] = nil
		local s = TradeLogic.New(targetUserId, player.UserId, TradeService.CanTradePaid(player, target))
		sessions[player.UserId] = s
		sessions[targetUserId] = s
		pushBoth(s)
		return true, "Trade opened with " .. target.DisplayName
	end
	requests[targetUserId] = requests[targetUserId] or {}
	requests[targetUserId][player.UserId] = now + TradeConfig.RequestSeconds
	Net.Server.Fire("Notify", target, "Trade", player.DisplayName .. " wants to trade. Open Trade to accept.")
	push(target)
	return true, "Trade request sent"
end

local function update(player: Player, msg: { [string]: any }): (boolean, string?)
	local s = sessions[player.UserId]
	local op = msg.op
	if s == nil then
		return false, "No active trade"
	end
	if op == "offer" then
		local uids = msg.uids
		if not NetValidate.Check({ "uidList" }, table.pack(uids)) then
			return false, "Invalid selection"
		end
		local data = DataService.GetData(player)
		if data == nil then
			return false, "Loading..."
		end
		local ok, err = TradeLogic.SetOffer(s, player.UserId, data :: any, uids)
		pushBoth(s)
		return ok, err
	elseif op == "confirm" then
		TradeLogic.Confirm(s, player.UserId, os.clock())
		pushBoth(s)
		return true, nil
	elseif op == "unconfirm" then
		TradeLogic.Unconfirm(s, player.UserId)
		pushBoth(s)
		return true, nil
	elseif op == "cancel" then
		if s.executing then
			return false, "Trade is being completed"
		end
		close(s, player.DisplayName .. " cancelled the trade")
		return true, nil
	end
	return false, "Unknown action"
end

-- Saves the profile, then drops settled ids from the user's ledger index.
local function saveAndPrune(player: Player, applied: { string }, settled: { string })
	task.spawn(function()
		local saved = DataService.SaveAndWait(player, function(last)
			for _, id in applied do
				if not (last.tradesApplied and last.tradesApplied[id]) then
					return false
				end
			end
			return true
		end, 30)
		if saved then
			TradeLedger.Prune(ledger, player.UserId, settled)
		end
	end)
end

local function applyLive(p: Player?, userId: number, record: TradeLedger.Record)
	local data = p and DataService.GetData(p)
	if p == nil or data == nil then
		return -- left mid-commit: their next load applies it (TradeLedger.Recover)
	end
	if TradeLedger.Apply(data :: any, record, userId, os.time()) then
		DataService.Changed(p, "spirits", "equippedSpirits")
		ProgressionService.RefreshPower(p)
	end
	saveAndPrune(p, { record.id }, { record.id })
end

local function execute(s: TradeLogic.Session)
	local pa = Players:GetPlayerByUserId(s.a.userId)
	local pb = Players:GetPlayerByUserId(s.b.userId)
	local da = pa and DataService.GetData(pa)
	local db = pb and DataService.GetData(pb)
	if pa == nil or pb == nil or da == nil or db == nil then
		close(s, "Trade cancelled")
		return
	end
	-- Policy can only get stricter mid-session (PolicyService refreshes); re-check paid items.
	s.allowPaid = s.allowPaid and TradeService.CanTradePaid(pa, pb)
	local ok, err = TradeLogic.Validate(s, da :: any, db :: any)
	if not ok then
		close(s, "Trade failed: " .. (err or "?"))
		return
	end
	s.executing = true
	TradeLock.Set(s.a.userId, true)
	TradeLock.Set(s.b.userId, true)
	pushBoth(s)
	local record = TradeLedger.BuildRecord(HttpService:GenerateGUID(false), s.a.userId, da :: any, s.a.offer, s.b.userId, db :: any, s.b.offer, os.time())
	local result = TradeLedger.Commit(ledger, record) -- yields (DataStore)
	if result == "committed" then
		applyLive(Players:GetPlayerByUserId(s.a.userId), s.a.userId, record)
		applyLive(Players:GetPlayerByUserId(s.b.userId), s.b.userId, record)
	end
	TradeLock.Set(s.a.userId, false)
	TradeLock.Set(s.b.userId, false)
	if result == "committed" then
		AnalyticsService.Custom(pa, "TradeCompleted", #s.a.offer + #s.b.offer)
		close(s, "Trade complete!")
	elseif result == "aborted" then
		close(s, "Trade could not be saved. Nothing changed - please try again.")
	else
		-- Outcome unknown: leave profiles untouched and let the ledger settle it on rejoin.
		close(s, nil)
		for _, p in { pa, pb } do
			if p.Parent == Players then
				p:Kick("Your trade could not be confirmed. Please rejoin - your Spirits are safe.")
			end
		end
	end
end

local function recover(player: Player, data: any)
	TradeLock.Set(player.UserId, true)
	local okRecover, applied, settled = pcall(TradeLedger.Recover, ledger, data, player.UserId, os.time())
	TradeLock.Set(player.UserId, false)
	if not okRecover then
		warn("[TradeService] trade recovery failed for", player.UserId, applied)
		return
	end
	if #applied > 0 then
		AnalyticsService.Custom(player, "TradeRecovered", #applied)
		task.delay(3, function()
			if player.Parent == Players then
				Net.Server.Fire("Notify", player, "Trade", "A trade from your last session was completed.")
			end
		end)
	end
	if #settled > 0 then
		saveAndPrune(player, applied, settled)
	end
end

function TradeService.Init()
	ledger = makeLedger()
	DataService.AddLoadHook(recover)
end

function TradeService.Start()
	Net.Server.OnInvoke("TradeRequest", requestTrade)
	Net.Server.OnInvoke("TradeUpdate", update)
	Players.PlayerAdded:Connect(function(p)
		task.wait(2)
		push(p)
	end)
	Players.PlayerRemoving:Connect(function(player)
		requests[player.UserId] = nil
		local s = sessions[player.UserId]
		if s and not s.executing then
			close(s, "Trade cancelled: player left")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local seen: { [TradeLogic.Session]: boolean } = {}
			for _, s in sessions do
				if not seen[s] then
					seen[s] = true
					if not s.executing and TradeLogic.Ready(s, os.clock()) then
						task.spawn(execute, s) -- sets s.executing before its first yield
					end
				end
			end
		end
	end)
end

return TradeService
