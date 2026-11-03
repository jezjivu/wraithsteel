--!strict
-- RaidService: 8-player raids (rules in Logic/RaidLogic, numbers in RaidConfig).
--
-- Lobby server (any public server):
--   RaidRequest("create", raidId) / ("join", lobbyId) / ("leave") / ("launch") / ("state")
--   Launch: TeleportService:ReserveServer -> manifest {raidId, members} written to MemoryStore
--   under the reserved server's PrivateServerId -> TeleportAsync with the access code.
-- Raid server (reserved: PrivateServerId ~= "" and PrivateServerOwnerId == 0):
--   reads the manifest by its OWN PrivateServerId (trusted; client TeleportData is ignored),
--   turns away non-members, waits for the members, runs the boss encounter with raid health,
--   enforces the time limit, grants raid rewards, then teleports everyone back to a public
--   server.
-- Studio: teleports do not work, so "launch" runs the raid right here (minimum size ignored).
--
-- TODO(Studio/Agent C): Workspace.RaidArena (a Part; the boss spawns on it). Without it the
-- boss spawns ahead of the first member. A dedicated raid boss + role mechanics (RaidConfig).
--
-- API:
--   RaidService.IsRaidServer() -> boolean
--   RaidService.LobbyOf(player) -> RaidLogic.Lobby?
--   RaidService.Started() -> boolean                      raid server: the fight has begun

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local RaidConfig = require(Config:WaitForChild("RaidConfig"))

local RaidLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("RaidLogic"))
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local BossService = require(script.Parent.BossService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local RaidService = { Name = "RaidService", Priority = 54 }

local lobbies: { [string]: RaidLogic.Lobby } = {}
local lobbyOf: { [number]: string } = {} -- userId -> lobbyId
local raidManifest: RaidLogic.Manifest? = nil -- set on a raid server
local raidStarted = false

function RaidService.IsRaidServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

function RaidService.LobbyOf(player: Player): RaidLogic.Lobby?
	local id = lobbyOf[player.UserId]
	return if id then lobbies[id] else nil
end

local function eligibility(player: Player): RaidLogic.Eligibility?
	local data = DataService.GetData(player)
	if data == nil then
		return nil
	end
	return { chapter = data.chapter, level = data.level }
end

local function names(ids: { number }): { string }
	local out = {}
	for _, id in ids do
		local p = Players:GetPlayerByUserId(id)
		table.insert(out, if p then p.DisplayName else "?")
	end
	return out
end

local function stateFor(player: Player): { [string]: any }
	local open = {}
	for _, l in lobbies do
		local leader = Players:GetPlayerByUserId(l.leader)
		table.insert(open, {
			id = l.id,
			raidId = l.raidId,
			leaderName = if leader then leader.DisplayName else "?",
			count = #l.members,
			launching = l.launching,
		})
	end
	local mine = RaidService.LobbyOf(player)
	return {
		raidServer = RaidService.IsRaidServer(),
		lobbies = open,
		mine = if mine
			then {
				id = mine.id,
				raidId = mine.raidId,
				isLeader = mine.leader == player.UserId,
				members = names(mine.members),
				launching = mine.launching,
			}
			else nil,
	}
end

local function pushAll()
	for _, p in Players:GetPlayers() do
		Net.Server.Fire("RaidEvent", p, stateFor(p))
	end
end

local function closeLobby(lobby: RaidLogic.Lobby, message: string?)
	lobbies[lobby.id] = nil
	for _, id in lobby.members do
		if lobbyOf[id] == lobby.id then
			lobbyOf[id] = nil
		end
		local p = Players:GetPlayerByUserId(id)
		if p and message then
			Net.Server.Fire("Notify", p, "Raid", message)
		end
	end
	pushAll()
end

local function near(a: Player, b: Player, radius: number): boolean
	local ra = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
	local rb = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
	return ra ~= nil and rb ~= nil and ra:IsA("BasePart") and rb:IsA("BasePart") and (ra.Position - rb.Position).Magnitude <= radius
end

-- Raid encounter (raid server, or the Studio stand-in) ----------------------------------------

local function arenaCFrame(players: { Player }): CFrame
	local arena = workspace:FindFirstChild("RaidArena")
	if arena and arena:IsA("BasePart") then
		return arena.CFrame + Vector3.new(0, arena.Size.Y / 2, 0)
	end
	for _, p in players do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local ahead = root.Position + (if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis) * 40
			return CFrame.lookAt(ahead, root.Position * Vector3.new(1, 0, 1) + Vector3.new(0, ahead.Y, 0))
		end
	end
	return CFrame.new(0, 10, 0)
end

local function sendHome(players: { Player })
	if not RaidService.IsRaidServer() then
		return -- Studio stand-in: everyone is already home
	end
	for _ = 1, RaidConfig.TeleportRetries do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, players)
		end)
		if ok then
			return
		end
		warn("[RaidService] teleport home failed:", err)
		task.wait(2)
	end
	for _, p in players do
		p:Kick("The raid has ended. Please rejoin WRAITHSTEEL.")
	end
end

local function grantRaidRewards(raidId: string, players: { Player })
	for _, p in players do
		local data = DataService.GetData(p) :: any
		if data and p.Parent == Players then
			local clears = data.raidClears[raidId] or 0
			local r = RaidLogic.Reward(raidId, clears)
			data.raidClears[raidId] = clears + 1
			DataService.Changed(p, "raidClears")
			ProgressionService.AddEmber(p, r.ember, "Raid:" .. raidId)
			ProgressionService.AddXp(p, r.xp)
			ProgressionService.AddJade(p, r.jade, "Raid:" .. raidId)
			Net.Server.Fire("Notify", p, "Raid", string.format("Raid cleared! +%d Ember, +%d XP, +%d Jade", r.ember, r.xp, r.jade))
			AnalyticsService.Custom(p, "RaidCleared", clears + 1)
		end
	end
end

local function runRaid(raidId: string, players: { Player }, onDone: (() -> ())?)
	local def = RaidConfig.Raids[raidId]
	local live = {}
	for _, p in players do
		if p.Parent == Players then
			table.insert(live, p)
		end
	end
	if #live == 0 then
		return
	end
	Net.Server.FireList("StoryEvent", live, { kind = "RealmEntered", name = def.name, subtitle = def.description })
	local encounterId = BossService.StartEncounter(def.bossId, arenaCFrame(live), live, nil, nil, RaidLogic.HealthMultiplier(raidId))
	if encounterId == nil then
		warn("[RaidService] could not start raid boss", def.bossId)
		sendHome(live)
		return
	end
	task.delay(def.timeLimitSeconds, function()
		if BossService.IsActive(encounterId) then
			Net.Server.FireList("Notify", live, "Raid", "The bell tolls - time is up.")
			BossService.Fail(encounterId)
		end
	end)
	local conn
	conn = BossService.EncounterEnded:Connect(function(id: string, _bossId: string, victory: boolean, participants: { Player })
		if id ~= encounterId then
			return
		end
		conn:Disconnect()
		if victory then
			grantRaidRewards(raidId, participants)
		end
		task.delay(RaidConfig.ReturnDelaySeconds, function()
			sendHome(Players:GetPlayers())
			if onDone then
				onDone()
			end
		end)
	end)
end

-- Lobby launch ----------------------------------------------------------------------------------

local function launch(lobby: RaidLogic.Lobby)
	lobby.launching = true
	pushAll()
	local players = {}
	for _, id in lobby.members do
		local p = Players:GetPlayerByUserId(id)
		if p then
			table.insert(players, p)
		end
	end
	if RunService:IsStudio() then
		runRaid(lobby.raidId, players, function()
			closeLobby(lobby, nil)
		end)
		return
	end
	local okReserve, code, privateId = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not okReserve or type(code) ~= "string" or type(privateId) ~= "string" then
		warn("[RaidService] ReserveServer failed:", code)
		lobby.launching = false
		pushAll()
		Net.Server.FireList("Notify", players, "Raid", "Could not open the raid gate. Try again.")
		return
	end
	local manifest = RaidLogic.BuildManifest(lobby, os.time())
	local okWrite = pcall(function()
		MemoryStoreService:GetHashMap(RaidConfig.ManifestStore):SetAsync(privateId, manifest, RaidConfig.ManifestSeconds)
	end)
	if not okWrite then
		lobby.launching = false
		pushAll()
		Net.Server.FireList("Notify", players, "Raid", "Could not open the raid gate. Try again.")
		return
	end
	local opts = Instance.new("TeleportOptions")
	opts.ReservedServerAccessCode = code
	opts:SetTeleportData({ raidId = lobby.raidId }) -- display only; the manifest is the authority
	for _ = 1, RaidConfig.TeleportRetries do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, players, opts)
		end)
		if ok then
			AnalyticsService.Custom(players[1], "RaidLaunched", #players)
			closeLobby(lobby, nil)
			return
		end
		warn("[RaidService] raid teleport failed:", err)
		task.wait(2)
	end
	lobby.launching = false
	pushAll()
	Net.Server.FireList("Notify", players, "Raid", "The raid gate failed to open. Try again.")
end

local function request(player: Player, op: string, arg: string?): (boolean, string?)
	if RaidService.IsRaidServer() then
		return false, "You are already in a raid"
	end
	local who = eligibility(player)
	if who == nil then
		return false, "Loading..."
	end
	local mine = RaidService.LobbyOf(player)
	if op == "state" then
		Net.Server.Fire("RaidEvent", player, stateFor(player))
		return true, nil
	elseif op == "create" then
		if mine then
			return false, "Leave your current raid first"
		end
		local raidId = arg or ""
		local ok, err = RaidLogic.CheckEligible(raidId, who)
		if not ok then
			return false, err
		end
		local lobby = RaidLogic.New(HttpService:GenerateGUID(false), raidId, player.UserId, os.time())
		lobbies[lobby.id] = lobby
		lobbyOf[player.UserId] = lobby.id
		pushAll()
		return true, "Raid lobby opened - others can join from the Raid panel"
	elseif op == "join" then
		if mine then
			return false, "Leave your current raid first"
		end
		local lobby = lobbies[arg or ""]
		if lobby == nil then
			return false, "That raid is gone"
		end
		local ok, err = RaidLogic.CheckEligible(lobby.raidId, who)
		if not ok then
			return false, err
		end
		local leader = Players:GetPlayerByUserId(lobby.leader)
		if leader == nil or not near(player, leader, RaidConfig.JoinRadius) then
			return false, "Stand near the raid leader to join"
		end
		local joined, joinErr = RaidLogic.Join(lobby, player.UserId)
		if not joined then
			return false, joinErr
		end
		lobbyOf[player.UserId] = lobby.id
		pushAll()
		return true, "Joined the raid"
	elseif op == "leave" then
		if mine == nil then
			return false, "Not in a raid"
		end
		if mine.launching then
			return false, "The raid is already leaving"
		end
		lobbyOf[player.UserId] = nil
		if RaidLogic.Leave(mine, player.UserId) then
			closeLobby(mine, nil)
		else
			pushAll()
		end
		return true, "Left the raid"
	elseif op == "launch" then
		if mine == nil then
			return false, "Not in a raid"
		end
		local ok, err = RaidLogic.CanLaunch(mine, player.UserId, RunService:IsStudio())
		if not ok then
			return false, err
		end
		task.spawn(launch, mine)
		return true, "The raid gate opens..."
	end
	return false, "Unknown action"
end

-- Raid server boot ------------------------------------------------------------------------------

local function bootRaidServer()
	local map = MemoryStoreService:GetHashMap(RaidConfig.ManifestStore)
	for _ = 1, 5 do
		local ok, value = pcall(function()
			return map:GetAsync(game.PrivateServerId)
		end)
		if ok and RaidLogic.ValidManifest(value, os.time()) then
			raidManifest = value
			break
		end
		task.wait(2)
	end
	local manifest = raidManifest
	if manifest == nil then
		warn("[RaidService] reserved server without a valid raid manifest; sending players home")
		Players.PlayerAdded:Connect(function(p)
			task.wait(3)
			sendHome({ p })
		end)
		sendHome(Players:GetPlayers())
		return
	end
	local function admit(p: Player)
		if not RaidLogic.IsMember(manifest, p.UserId) then
			sendHome({ p })
		end
	end
	Players.PlayerAdded:Connect(admit)
	for _, p in Players:GetPlayers() do
		admit(p)
	end
	-- Wait for the members (and their data), then fight with whoever made it.
	local deadline = os.clock() + RaidConfig.WaitForMembersSeconds
	while os.clock() < deadline do
		local present = 0
		for _, id in manifest.members do
			local p = Players:GetPlayerByUserId(id)
			if p and DataService.GetData(p) and p.Character then
				present += 1
			end
		end
		if present >= #manifest.members then
			break
		end
		task.wait(1)
	end
	local fighters = {}
	for _, id in manifest.members do
		local p = Players:GetPlayerByUserId(id)
		if p and DataService.GetData(p) then
			table.insert(fighters, p)
		end
	end
	if #fighters == 0 then
		return
	end
	raidStarted = true
	runRaid(manifest.raidId, fighters, nil)
end

function RaidService.Init() end

function RaidService.Start()
	Net.Server.OnInvoke("RaidRequest", request)
	if RaidService.IsRaidServer() then
		task.spawn(bootRaidServer)
		return
	end
	Players.PlayerRemoving:Connect(function(player)
		local lobby = RaidService.LobbyOf(player)
		lobbyOf[player.UserId] = nil
		if lobby and not lobby.launching then
			if RaidLogic.Leave(lobby, player.UserId) then
				closeLobby(lobby, nil)
			else
				pushAll()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(10)
			local now = os.time()
			for _, lobby in lobbies do
				if RaidLogic.Expired(lobby, now) then
					closeLobby(lobby, "Your raid lobby closed (idle too long)")
				end
			end
		end
	end)
end

function RaidService.Started(): boolean
	return raidStarted
end

return RaidService
