-- server_mock: server-side engine shims on top of engine_mock + ui_mock, so tools/smoke_server.py
-- can boot every service (Init + Start), let a fake player join, and run a number of "ticks".
-- Threads that call task.wait park until the next tick; errors in any thread are reported.
-- Only for smoke tests - this is NOT Roblox, so a clean run means "no obvious boot errors".

__asyncSignals = true
local errors = {}
function __onThreadError(co, err)
	table.insert(errors, tostring(err) .. "\n" .. debug.traceback(co))
end
function __smokeErrors()
	return errors
end

-- task: cooperative scheduler driven by __tick()
local waiting = {}
local delayed = {}
local function resume(co, ...)
	if coroutine.status(co) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		__onThreadError(co, err)
	end
end
task.spawn = function(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	resume(co, ...)
	return co
end
task.defer = task.spawn
task.wait = function()
	if coroutine.isyieldable() then
		table.insert(waiting, coroutine.running())
		coroutine.yield()
	end
	return 0.1
end
task.delay = function(_, f, ...)
	table.insert(delayed, { f = f, args = table.pack(...) })
end
function __tick()
	local w, d = waiting, delayed
	waiting, delayed = {}, {}
	for _, co in w do
		resume(co)
	end
	for _, x in d do
		task.spawn(x.f, table.unpack(x.args, 1, x.args.n))
	end
end

-- game properties ProfileStore / RaidService read
rawset(game, "PlaceId", 0)
rawset(game, "JobId", "smoke")
rawset(game, "GameId", 0)
rawset(game, "PrivateServerId", "")
rawset(game, "PrivateServerOwnerId", 0)
rawset(game, "BindToClose", function() end)

function __serverSetup()
	local function addService(name, svc)
		rawget(game, "__children")[name] = svc
	end

	local RunService = game:GetService("RunService")
	RunService.IsServer = function()
		return true
	end
	RunService.IsClient = function()
		return false
	end

	-- Remotes folder must be an engine instance under the (harness) ReplicatedStorage.
	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	rawget(game:GetService("ReplicatedStorage"), "__children").Remotes = remotes
	local REMOTE_MT = getmetatable(remotes)
	local oldIndex = REMOTE_MT.__index
	REMOTE_MT.__index = function(self, k)
		if k == "FireClient" or k == "FireAllClients" or k == "FireServer" then
			return function() end
		end
		if k == "OnServerEvent" or k == "OnClientEvent" then
			local props = rawget(self, "__props")
			props[k] = props[k] or __newSignal()
			return props[k]
		end
		return oldIndex(self, k)
	end

	-- Data stores: always fail like Studio without API access -> ProfileStore uses its mock.
	local function failingStore()
		local st = {}
		for _, m in { "GetAsync", "SetAsync", "UpdateAsync", "RemoveAsync", "IncrementAsync", "GetVersionAsync", "ListVersionsAsync" } do
			st[m] = function()
				error("403: Studio access to API services is not enabled")
			end
		end
		return st
	end
	addService("DataStoreService", {
		GetDataStore = function()
			return failingStore()
		end,
		GetOrderedDataStore = function()
			return failingStore()
		end,
	})
	addService("MessagingService", { SubscribeAsync = function() return { Disconnect = function() end } end, PublishAsync = function() end })
	addService("MemoryStoreService", { GetHashMap = function()
		return { GetAsync = function() return nil end, SetAsync = function() return true end, UpdateAsync = function() return nil end }
	end, GetSortedMap = function() return {} end })
	addService("MarketplaceService", {
		PromptProductPurchase = function() end,
		PromptGamePassPurchase = function() end,
		UserOwnsGamePassAsync = function() return false end,
		GetProductInfo = function() return { PriceInRobux = 0 } end,
		PromptGamePassPurchaseFinished = __newSignal(),
		PromptProductPurchaseFinished = __newSignal(),
	})
	addService("PolicyService", { GetPolicyInfoForPlayerAsync = function()
		return { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true, AllowedExternalLinkReferences = {} }
	end })
	addService("TeleportService", { ReserveServer = function() return "code", "psid" end, TeleportAsync = function() end })
	addService("AnalyticsService", setmetatable({}, { __index = function()
		return function() end
	end }))
	addService("PhysicsService", { RegisterCollisionGroup = function() end, CollisionGroupSetCollidable = function() end })
	addService("ChangeHistoryService", { SetWaypoint = function() end })
	addService("ServerStorage", Instance.new("Folder"))
	local tagged = {}
	addService("CollectionService", {
		AddTag = function(_, inst, tag)
			tagged[tag] = tagged[tag] or {}
			if not table.find(tagged[tag], inst) then
				table.insert(tagged[tag], inst)
			end
		end,
		RemoveTag = function(_, inst, tag)
			local t = tagged[tag]
			local i = t and table.find(t, inst)
			if i then
				table.remove(t, i)
			end
		end,
		HasTag = function(_, inst, tag)
			return tagged[tag] ~= nil and table.find(tagged[tag], inst) ~= nil
		end,
		GetTagged = function(_, tag)
			return table.clone(tagged[tag] or {})
		end,
		GetInstanceAddedSignal = function()
			return __newSignal()
		end,
		GetInstanceRemovedSignal = function()
			return __newSignal()
		end,
	})
	__players = game:GetService("Players")
	local Players = __players
	local all = __allPlayers
	Players.GetPlayers = function()
		return all
	end
	Players.GetPlayerByUserId = function(_, id)
		for _, p in all do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end

end

__allPlayers = {}

-- A fake joining player (no character yet; then a simple character).
function __joinPlayer(userId, name)
	local p = Instance.new("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = userId
	p.AccountAge = 100
	p.MembershipType = "MembershipType.None"
	p.Kick = function(_, msg)
		table.insert(errors, "kicked " .. name .. ": " .. tostring(msg))
	end
	p.LoadCharacter = function() end
	p.CharacterAdded = __newSignal()
	p.CharacterRemoving = __newSignal()
	local gui = Instance.new("PlayerGui")
	gui.Name = "PlayerGui"
	gui.Parent = p
	table.insert(__allPlayers, p)
	local Players = __players
	rawget(p, "__props").Parent = Players -- Players is a plain table here: set without reparenting
	rawset(p, "__isPlayer", true)
	Players.PlayerAdded:Fire(p)
	return p
end
