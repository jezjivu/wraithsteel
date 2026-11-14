--!strict
-- Net: creates every remote from NetSchema (server) and exposes typed helpers.
-- Server handlers only ever see arguments that passed NetValidate and the per-player rate limit.
-- Rejected calls are dropped silently (no error back to a possibly malicious client) and counted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NetSchema = require(script.Parent.NetSchema)
local NetValidate = require(script.Parent.NetValidate)
local RateLimiter = require(script.Parent.RateLimiter)
local Signal = require(script.Parent.Signal)

local FOLDER_NAME = "Remotes"

local Net = {}

-- Fired on the server whenever a client call is rejected: (player, remoteName, reason)
Net.Rejected = Signal.new()

local remotes: { [string]: Instance } = {}
local limiters: { [string]: any } = {}

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if folder == nil then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Instance
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function getRemote(name: string): Instance
	local cached = remotes[name]
	if cached then
		return cached
	end
	local def = NetSchema[name]
	assert(def, "Net: unknown remote " .. name)
	local folder = getFolder()
	local remote: Instance
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			remote = existing
		else
			remote = Instance.new(if def.kind == "Event" then "RemoteEvent" else "RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	else
		remote = folder:WaitForChild(name)
	end
	remotes[name] = remote
	return remote
end

-- Server ---------------------------------------------------------------------------------------

Net.Server = {}

-- Creates every remote up front so clients can WaitForChild them. Call once from Bootstrap.
function Net.Server.Init()
	assert(RunService:IsServer(), "Net.Server.Init on client")
	for name in NetSchema do
		getRemote(name)
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:Remove(player)
		end
	end)
end

local function guard(name: string, player: Player, ...: any): boolean
	local def = NetSchema[name]
	local limiter = limiters[name]
	if limiter and not limiter:Allow(player) then
		Net.Rejected:Fire(player, name, "rate")
		return false
	end
	local ok, reason = NetValidate.Check(def.args or {}, table.pack(...))
	if not ok then
		Net.Rejected:Fire(player, name, reason)
		return false
	end
	return true
end

local function setupLimiter(name: string)
	local def = NetSchema[name]
	assert(def.direction == "ToServer", "Net: " .. name .. " is not a ToServer remote")
	if def.rate and limiters[name] == nil then
		limiters[name] = RateLimiter.new(def.rate.burst, def.rate.perSecond)
	end
end

-- Connect a handler for a ToServer RemoteEvent. handler(player, ...validated args)
function Net.Server.On(name: string, handler: (Player, ...any) -> ())
	setupLimiter(name)
	local remote = getRemote(name) :: RemoteEvent
	remote.OnServerEvent:Connect(function(player, ...)
		if guard(name, player, ...) then
			handler(player, ...)
		end
	end)
end

-- Bind a handler for a ToServer RemoteFunction. Rejected calls return nil.
-- Handler errors are caught so a client can never make the server error-spam.
function Net.Server.OnInvoke(name: string, handler: (Player, ...any) -> ...any)
	setupLimiter(name)
	local remote = getRemote(name) :: RemoteFunction
	remote.OnServerInvoke = function(player, ...)
		if not guard(name, player, ...) then
			return nil
		end
		local result = table.pack(pcall(handler, player, ...))
		if not result[1] then
			warn("[Net] handler error", name, result[2])
			return nil
		end
		return table.unpack(result, 2, result.n)
	end
end

function Net.Server.Fire(name: string, player: Player, ...: any)
	(getRemote(name) :: RemoteEvent):FireClient(player, ...)
end

function Net.Server.FireAll(name: string, ...: any)
	(getRemote(name) :: RemoteEvent):FireAllClients(...)
end

function Net.Server.FireList(name: string, players: { Player }, ...: any)
	local remote = getRemote(name) :: RemoteEvent
	for _, p in players do
		remote:FireClient(p, ...)
	end
end

-- Client ---------------------------------------------------------------------------------------

Net.Client = {}

function Net.Client.Fire(name: string, ...: any)
	(getRemote(name) :: RemoteEvent):FireServer(...)
end

function Net.Client.Invoke(name: string, ...: any): ...any
	return (getRemote(name) :: RemoteFunction):InvokeServer(...)
end

function Net.Client.On(name: string, handler: (...any) -> ()): RBXScriptConnection
	return (getRemote(name) :: RemoteEvent).OnClientEvent:Connect(handler)
end

return Net
