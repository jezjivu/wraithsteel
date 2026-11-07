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

-- task: cooperative scheduler driven by __tick(); waits and delays honor real time (os.clock),
-- Heartbeat fires at most every HEARTBEAT_EVERY seconds.
local waiting = {} -- { { co, due } }
local delayed = {} -- { { f, args, due } }
local HEARTBEAT_EVERY = 1 / 30
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
task.wait = function(t)
	if coroutine.isyieldable() then
		table.insert(waiting, { co = coroutine.running(), due = os.clock() + (t or 1 / 30) })
		coroutine.yield()
	end
	return t or 1 / 30
end
task.delay = function(t, f, ...)
	table.insert(delayed, { f = f, args = table.pack(...), due = os.clock() + (t or 0) })
	return nil
end
task.cancel = function() end
local lastBeat = os.clock()
function __tick()
	local nowT = os.clock()
	if nowT - lastBeat >= HEARTBEAT_EVERY then
		local rs = rawget(game, "__children").RunService
		if rs and rs.Heartbeat and rs.Heartbeat.Fire then
			rs.Heartbeat:Fire(math.min(nowT - lastBeat, 0.1))
		end
		lastBeat = nowT
	end
	local keepW = {}
	local dueW = {}
	for _, w in waiting do
		if w.due <= nowT then
			table.insert(dueW, w)
		else
			table.insert(keepW, w)
		end
	end
	waiting = keepW
	for _, w in dueW do
		resume(w.co)
	end
	local keepD = {}
	local dueD = {}
	for _, d in delayed do
		if d.due <= nowT then
			table.insert(dueD, d)
		else
			table.insert(keepD, d)
		end
	end
	delayed = keepD
	for _, d in dueD do
		task.spawn(d.f, table.unpack(d.args, 1, d.args.n))
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

-- A simple character (Humanoid + HumanoidRootPart) at `pos`; fires CharacterAdded.
function __giveCharacter(p, pos)
	local ch = Instance.new("Model")
	ch.Name = p.Name
	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	hum.MaxHealth = 100
	hum.Health = 100
	hum.WalkSpeed = 16
	hum.JumpPower = 50
	hum.FloorMaterial = "Material.Plastic"
	hum.GetState = function()
		return "HumanoidStateType.Running"
	end
	hum.MoveTo = function() end
	hum.ChangeState = function() end
	hum.Parent = ch
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(pos.X, pos.Y, pos.Z)
	root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	root.Parent = ch
	ch.PrimaryPart = root
	ch.Parent = workspace
	p.Character = ch
	p.CharacterAdded:Fire(ch)
	return ch
end

-- Runs the scheduler for `seconds` of real time (timers in the game use os.clock).
function __advance(seconds)
	local stop = os.clock() + seconds
	while os.clock() < stop do
		__tick()
	end
end
