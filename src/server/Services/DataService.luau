--!strict
-- DataService: player profiles via ProfileStore (vendored, Apache-2.0, src/server/Packages).
-- ProfileStore provides session locking (one server owns a profile at a time), periodic autosave
-- and BindToClose flushing. This service adds: template + Reconcile, dataVersion migrations,
-- client replication of public keys, a profile message router (used for offline gifting) and
-- SaveAndWait for idempotent receipt handling.
--
-- API (guide §8.3):
--   DataService.GetData(player) -> ProfileData?          (nil until loaded)
--   DataService.WaitForData(player, timeout?) -> ProfileData?
--   DataService.Changed(player, ...keys)                 replicate top-level keys after mutating
--   DataService.SaveAndWait(player, predicate, timeout) -> boolean
--   DataService.AddLoadHook(fn(player, data))            runs (may yield) before the snapshot
--   DataService.SetMessageHandler(kind, fn(player, data, message) -> boolean)
--   DataService.MessageAsync(userId, message) -> boolean
--   DataService.ProfileLoaded: Signal(player, data)
--   DataService.ProfileReleasing: Signal(player, data)   fired before the session ends

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))

local ServerRoot = script.Parent.Parent
local ProfileStore = require(ServerRoot:WaitForChild("Packages"):WaitForChild("ProfileStore"))
local ProfileTemplate = require(ServerRoot:WaitForChild("Logic"):WaitForChild("ProfileTemplate"))
local Migrations = require(ServerRoot:WaitForChild("Logic"):WaitForChild("Migrations"))

type ProfileData = Types.ProfileData

local STORE_NAME = "WraithsteelProfiles_v1"
local KEY_PREFIX = "Player_"

-- Keys never sent to the client (internal bookkeeping).
local PRIVATE_KEYS = {
	receipts = true,
	receiptOrder = true,
	giftMessagesSeen = true,
	funnelSteps = true,
	codesRedeemed = true,
	tradesApplied = true,
	tradeOrder = true,
	robuxSpent = true,
}

local DataService = {
	Name = "DataService",
	Priority = 0,
	ProfileLoaded = Signal.new(),
	ProfileReleasing = Signal.new(),
}

local store: any
local profiles: { [Player]: any } = {}
local messageHandlers: { [string]: (Player, ProfileData, { [string]: any }) -> boolean } = {}
local loadHooks: { (Player, ProfileData) -> () } = {}

local function publicSnapshot(data: ProfileData): { [string]: any }
	local out = {}
	for k, v in data :: any do
		if not PRIVATE_KEYS[k] then
			out[k] = v
		end
	end
	return out
end

function DataService.GetProfile(player: Player): any
	local p = profiles[player]
	if p and p:IsActive() then
		return p
	end
	return nil
end

function DataService.GetData(player: Player): ProfileData?
	local p = DataService.GetProfile(player)
	return if p then p.Data else nil
end

function DataService.WaitForData(player: Player, timeout: number?): ProfileData?
	local deadline = os.clock() + (timeout or 15)
	while os.clock() < deadline do
		local data = DataService.GetData(player)
		if data then
			return data
		end
		if player.Parent ~= Players then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

-- Sends the current values of the given top-level keys to the owning client.
function DataService.Changed(player: Player, ...: string)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	for _, key in { ... } do
		if not PRIVATE_KEYS[key] then
			Net.Server.Fire("ProfileChanged", player, key, (data :: any)[key])
		end
	end
end

-- Forces a save and waits until a save completes whose LastSavedData satisfies `predicate`.
-- Used by MarketService so PurchaseGranted is only returned once the receipt is persisted.
function DataService.SaveAndWait(player: Player, predicate: (any) -> boolean, timeout: number): boolean
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	if profile.LastSavedData and predicate(profile.LastSavedData) then
		return true
	end
	local done = false
	local conn = profile.OnAfterSave:Connect(function(last)
		if predicate(last) then
			done = true
		end
	end)
	profile:Save()
	local deadline = os.clock() + timeout
	while not done and os.clock() < deadline and profile:IsActive() do
		task.wait(0.1)
	end
	conn:Disconnect()
	-- In Studio mock mode saves still fire OnAfterSave; if the session ended mid-wait we must
	-- report failure so Roblox retries the receipt.
	return done
end

-- Registers fn(player, data) to run after a profile loads and migrates, before the snapshot is
-- sent and before ProfileLoaded fires. May yield. Register in Init().
function DataService.AddLoadHook(fn: (Player, ProfileData) -> ())
	table.insert(loadHooks, fn)
end

function DataService.SetMessageHandler(kind: string, fn: (Player, ProfileData, { [string]: any }) -> boolean)
	messageHandlers[kind] = fn
end

-- Sends a message to any player's profile (online or offline). Delivered on their next load.
function DataService.MessageAsync(userId: number, message: { [string]: any }): boolean
	local ok, result = pcall(function()
		return store:MessageAsync(KEY_PREFIX .. userId, message)
	end)
	return ok and result == true
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(KEY_PREFIX .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Your save could not be loaded. Please rejoin in a moment.")
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR
	local okMigrate, err = pcall(Migrations.Run, profile.Data)
	if not okMigrate then
		warn("[DataService] migration failed for", player.UserId, err)
		profile:EndSession()
		player:Kick("This server is out of date. Please rejoin to get the latest version.")
		return
	end
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your save was opened on another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile

	profile:MessageHandler(function(message, processed)
		local msg: any = message
		local kind = if type(msg) == "table" and type(msg.kind) == "string" then msg.kind else nil
		local handler = if kind then messageHandlers[kind] else nil
		if handler and handler(player, profile.Data, msg) then
			processed()
		end
	end)

	-- Load hooks run (and may yield) before anyone sees the data, e.g. trade recovery.
	for _, hook in loadHooks do
		local okHook: boolean, hookErr: any = pcall(hook, player, profile.Data)
		if not okHook then
			warn("[DataService] load hook failed for", player.UserId, hookErr)
		end
	end
	if player.Parent ~= Players or profiles[player] ~= profile then
		return
	end

	Net.Server.Fire("ProfileSnapshot", player, publicSnapshot(profile.Data))
	DataService.ProfileLoaded:Fire(player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		-- Listeners run synchronously-ish via task.spawn; give them the data before ending.
		DataService.ProfileReleasing:Fire(player, profile.Data)
		profile:EndSession()
		profiles[player] = nil
	end
end

function DataService.Init()
	store = ProfileStore.New(STORE_NAME, ProfileTemplate.New())
	if RunService:IsStudio() then
		-- In Studio without "Enable Studio Access to API Services", ProfileStore falls back to a
		-- mock store automatically. Nothing persists between Studio sessions in that case.
		ProfileStore.OnError:Connect(function(message, storeName, key)
			warn("[DataService] ProfileStore error", storeName, key, message)
		end)
	end
end

function DataService.Start()
	Net.Server.On("RequestSnapshot", function(player)
		local data = DataService.GetData(player)
		if data then
			Net.Server.Fire("ProfileSnapshot", player, publicSnapshot(data))
		end
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
