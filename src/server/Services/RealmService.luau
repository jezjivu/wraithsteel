--!strict
-- RealmService: the three realms (RealmConfig) and the portals between them.
--   * Builds Neon Verge (World/NeonBuilder), Aeloria (World/AeloriaBuilder) and Ironcrow Keep
--     (World/KeepBuilder) into
--     Workspace.Realms unless that already exists (EditTools can build it in edit mode).
--   * Adds each realm's enemy spawns (Workspace.EnemySpawns), boss shrines
--     (Workspace.BossArenas) and waystones (WaystoneService).
--   * Portals: a gate into a realm stays sealed until that realm's unlockBoss is defeated.
--   * Publishes the player attribute "Realm" (client lighting/weather follow it).
--
-- API:
--   RealmService.Build()             -- build the realm geometry (edit mode safe)
--   RealmService.CanEnter(player, realmId) -> (boolean, string?)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local RealmConfig = require(Config:WaitForChild("RealmConfig"))
local BossConfig = require(Config:WaitForChild("BossConfig"))

local World = script.Parent.Parent:WaitForChild("World")
local NeonBuilder = require(World:WaitForChild("NeonBuilder"))
local AeloriaBuilder = require(World:WaitForChild("AeloriaBuilder"))
local KeepBuilder = require(World:WaitForChild("KeepBuilder"))
local K = require(World:WaitForChild("BuildKit"))

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local HubService = require(script.Parent.HubService)
local WaystoneService = require(script.Parent.WaystoneService)

local RealmService = { Name = "RealmService", Priority = 29.5 } -- after HubService (portal in the hub), before EnemyService (spawns)

local lastPortal: { [Player]: number } = {}

local function origin(realmId: string): Vector3
	local o = RealmConfig.Realms[realmId].origin
	return Vector3.new(o[1], o[2], o[3])
end

local function groundAt(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, name in { "EnemySpawns", "BossArenas", "Waystones", "Portals", "SpiritFollowers" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false
	local hit = workspace:Raycast(pos + Vector3.new(0, 300, 0), Vector3.new(0, -700, 0), params)
	return if hit then hit.Position else pos
end

-- Local realm point -> grounded world position. Japan portal points are relative to the hub.
local function worldPoint(realmId: string, at: { number }, relativeToHub: boolean?): Vector3
	local p: Vector3
	if relativeToHub then
		local c = HubService.Center()
		p = Vector3.new(c.X + at[1], c.Y, c.Z + at[2])
	else
		p = RealmConfig.World(realmId, at)
	end
	return groundAt(p)
end

function RealmService.Build()
	if workspace:FindFirstChild("Realms") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Realms"
	folder:SetAttribute("Generated", true)
	folder.Parent = workspace
	local ok, err = pcall(function()
		NeonBuilder.Build(origin("neon"), folder)
	end)
	if not ok then
		warn("[RealmService] Neon Verge build failed:", err)
	end
	local ok2, err2 = pcall(function()
		AeloriaBuilder.Build(origin("greek"), folder)
	end)
	if not ok2 then
		warn("[RealmService] Aeloria build failed:", err2)
	end
	local ok3, err3 = pcall(function()
		KeepBuilder.Build(origin("keep"), folder)
	end)
	if not ok3 then
		warn("[RealmService] Ironcrow Keep build failed:", err3)
	end
end

local function ensureFolder(name: string): Folder
	local f = workspace:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	local new = Instance.new("Folder")
	new.Name = name
	new.Parent = workspace
	return new
end

local function addSpawnsAndArenas()
	local spawns = ensureFolder("EnemySpawns")
	local arenas = ensureFolder("BossArenas")
	for _, id in RealmConfig.Order do
		local r = RealmConfig.Realms[id]
		for _, s in r.spawns do
			if spawns:FindFirstChild(s.name) == nil then
				local p = K.part(spawns, s.name, Vector3.new(4, 0.2, 4), CFrame.new(worldPoint(id, s.at) + Vector3.new(0, 0.3, 0)), Color3.new(1, 1, 1))
				p.Transparency = 1
				p.CanCollide = false
				p.CanQuery = false
				p:SetAttribute("EnemyId", s.enemyId)
				p:SetAttribute("Count", s.count)
				p:SetAttribute("RespawnSeconds", s.respawn)
			end
		end
		for _, a in r.arenas do
			if arenas:FindFirstChild(a.name) == nil then
				local base = worldPoint(id, a.at)
				local accent = K.rgb(r.color)
				local pad = K.part(arenas, a.name, Vector3.new(12, 0.6, 12), CFrame.new(base + Vector3.new(0, 0.3, 0)), Color3.fromRGB(50, 46, 52), Enum.Material.Slate)
				pad:SetAttribute("BossId", a.bossId)
				for i = 0, 3 do
					local rune = K.decor(pad, "Rune", Vector3.new(12.4, 0.1, 0.5), CFrame.new(base + Vector3.new(0, 0.62, 0)) * CFrame.Angles(0, math.rad(90 * i), 0) * CFrame.new(0, 0, 6), accent, Enum.Material.Neon)
					rune.Transparency = 0.1
				end
				K.light(pad, accent, 18, 1.2)
				local def = BossConfig.Bosses[a.bossId]
				if def then
					local plate = K.decor(pad, "BossName", Vector3.new(10, 2, 0.3), CFrame.new(base + Vector3.new(0, 5, -6.5)), Color3.fromRGB(15, 15, 20))
					K.sign(plate, def.name, accent, Enum.Font.Antique)
				end
			end
		end
		for _, w in r.waystones do
			if WaystoneService.Position(w.id) == nil then
				WaystoneService.Register(w.id, w.name, worldPoint(id, w.at), id)
			end
		end
	end
end

function RealmService.CanEnter(player: Player, realmId: string): (boolean, string?)
	local r = RealmConfig.Realms[realmId]
	if r == nil then
		return false, "Unknown realm"
	end
	local data = DataService.GetData(player)
	if r.unlockLevel and (data == nil or data.level < r.unlockLevel) then
		return false, "Sealed. Reach level " .. r.unlockLevel .. " to open this gate."
	end
	local need = r.unlockBoss
	if need == nil then
		return true, nil
	end
	if data and (data.bossesDefeated[need] or 0) > 0 then
		return true, nil
	end
	local boss = BossConfig.Bosses[need]
	return false, "Sealed. Defeat " .. (if boss then boss.name else need) .. " to open this gate."
end

-- A standing ring gate with a swirling core (color of the destination realm).
local function buildPortal(def: RealmConfig.PortalDef)
	local folder = ensureFolder("Portals")
	local dest = RealmConfig.Realms[def.to]
	local color = K.rgb(dest.color)
	local base = worldPoint(def.from, def.at, def.from == "japan")
	local m = K.model("Portal_" .. def.from .. "_" .. def.to, folder)
	local cf = CFrame.new(base) * CFrame.Angles(0, math.rad(def.facing), 0)
	local R = 9
	local segments = 20
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local p = cf * CFrame.new(math.cos(a) * R, R + 1 + math.sin(a) * R, 0)
		K.part(m, "Ring", Vector3.new(2.2, 3.4, 2.2), p * CFrame.Angles(0, 0, a), Color3.fromRGB(60, 58, 64), Enum.Material.Basalt)
		if i % 2 == 0 then
			K.decor(m, "RingGlow", Vector3.new(0.6, 2, 2.4), p * CFrame.Angles(0, 0, a) * CFrame.new(0, 0, 0), color, Enum.Material.Neon)
		end
	end
	local core = K.decor(m, "Core", Vector3.new(0.4, R * 1.9, R * 1.9), cf * CFrame.new(0, R + 1, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, 0), color, Enum.Material.ForceField, Enum.PartType.Cylinder)
	core.CFrame = cf * CFrame.new(0, R + 1, 0) * CFrame.Angles(0, math.rad(90), 0)
	core.Transparency = 0.15
	K.light(core, color, 40, 2.5)
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(color)
	swirl.LightEmission = 1
	swirl.Size = NumberSequence.new(0.6, 0)
	swirl.Lifetime = NumberRange.new(1, 2)
	swirl.Rate = 40
	swirl.Speed = NumberRange.new(2, 5)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Parent = core
	K.part(m, "Step", Vector3.new(24, 1, 8), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(80, 76, 72), Enum.Material.Slate)
	local plate = K.decor(m, "Name", Vector3.new(14, 2.4, 0.4), cf * CFrame.new(0, R * 2 + 4, 0), Color3.fromRGB(15, 15, 20))
	K.sign(plate, dest.name, color, Enum.Font.Antique)
	local point = K.decor(m, "PortalPoint", Vector3.new(10, 10, 6), cf * CFrame.new(0, 5, 0), color)
	point.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter"
	prompt.ObjectText = dest.name
	prompt.HoldDuration = 0.6
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 14
	prompt.Parent = point
	prompt.Triggered:Connect(function(player)
		RealmService.Travel(player, def.to)
	end)
end

-- Where you arrive in a realm (in front of its return portal / arrival point).
local function arrivalPoint(realmId: string): Vector3
	local r = RealmConfig.Realms[realmId]
	if realmId == "japan" then
		return worldPoint("japan", r.arrival, true)
	end
	return worldPoint(realmId, r.arrival)
end

function RealmService.Travel(player: Player, realmId: string)
	local ok, reason = RealmService.CanEnter(player, realmId)
	if not ok then
		Net.Server.Fire("Notify", player, "Info", reason or "Sealed")
		return
	end
	local c = CombatService.GetByPlayer(player)
	if c == nil or c.dead then
		return
	end
	local now = os.clock()
	if now - (lastPortal[player] or 0) < RealmConfig.PortalCooldown then
		return
	end
	lastPortal[player] = now
	local target = arrivalPoint(realmId) + Vector3.new(0, 4, 0)
	pcall(function()
		player:RequestStreamAroundAsync(target, 8)
	end)
	c.model:PivotTo(CFrame.new(target))
	player:SetAttribute("Realm", realmId)
	Net.Server.FireAll("CombatEvent", { kind = "Rest", targetId = c.id })
	Net.Server.Fire("StoryEvent", player, { kind = "RealmEntered", realm = realmId, name = RealmConfig.Realms[realmId].name, subtitle = RealmConfig.Realms[realmId].subtitle })
end

function RealmService.Init() end

function RealmService.Start()
	RealmService.Build()
	addSpawnsAndArenas()
	for _, p in RealmConfig.Portals do
		local ok, err = pcall(buildPortal :: any, p)
		if not ok then
			warn("[RealmService] portal failed:", err)
		end
	end
	-- Which realm is each player in? (client lighting/weather + quests)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local ch = player.Character
				local root = ch and ch:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local realm = if player:GetAttribute("InArena") == true then player:GetAttribute("Realm") else RealmConfig.At(root.Position)
					if player:GetAttribute("Realm") ~= realm then
						player:SetAttribute("Realm", realm)
					end
					-- Fell off a realm (Ironcrow Keep's chasm): back to the nearest waystone there.
					local r = RealmConfig.Realms[realm]
					if r and realm ~= "japan" and root.Position.Y < r.origin[2] - RealmConfig.FallRespawnDepth then
						local best, bestD = nil, math.huge
						for _, w in r.waystones do
							local wp = WaystoneService.Position(w.id)
							if wp and (wp - root.Position).Magnitude < bestD then
								best, bestD = wp, (wp - root.Position).Magnitude
							end
						end
						if best then
							root.AssemblyLinearVelocity = Vector3.zero
							ch:PivotTo(CFrame.new(best + Vector3.new(0, 4, 4)))
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastPortal[p] = nil
	end)
end

return RealmService
