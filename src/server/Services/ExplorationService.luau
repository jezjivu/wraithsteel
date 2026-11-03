--!strict
-- ExplorationService: Souls-style world secrets in the Ashen Valley.
--   * Shortcut gates (MapConfig.Shortcuts): barred doors across a road that only open from one
--     side. Once you open one it stays open for you (profile.shortcuts); your client swings it
--     open and stops colliding with it, everyone else still sees it barred until they open it.
--   * Ashen Relics (MapConfig.Relics): glowing pickups hidden around the zones; each one is an
--     extra skill point (profile.relics, counted by SkillLogic).
-- Models live in Workspace.Exploration; clients read the profile to hide what they've done.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local MapConfig = require(Config:WaitForChild("MapConfig"))

local DataService = require(script.Parent.DataService)

local ExplorationService = { Name = "ExplorationService", Priority = 28 } -- after MapService (terrain)

local PROMPT_RANGE = 10

local function ground(x: number, z: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true
	local y0 = MapConfig.RoadY(x, z)
	local hit = workspace:Raycast(Vector3.new(x, y0 + 120, z), Vector3.new(0, -300, 0), params)
	return if hit then hit.Position else Vector3.new(x, y0, z)
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function prompt(parent: BasePart, action: string, object: string): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.MaxActivationDistance = PROMPT_RANGE
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Parent = parent
	return pp
end

local function notify(player: Player, kind: string, text: string)
	Net.Server.Fire("Notify", player, kind, text)
end

-- A tall barred double door between stone walls, spanning the road.
local function buildGate(folder: Instance, def: any)
	local model = Instance.new("Model")
	model.Name = def.id
	model:SetAttribute("Shortcut", def.id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- arrives whole on clients
	model.Parent = folder
	local base = ground(def.at[1], def.at[2])
	local dir = Vector3.new(def.dir[1], 0, def.dir[2]).Unit
	local cf = CFrame.lookAt(base, base + dir) -- -Z along the road, X across it
	local span = def.half * 2 + 6
	local wood = Color3.fromRGB(70, 45, 32)
	local iron = Color3.fromRGB(40, 40, 44)
	local stone = Color3.fromRGB(110, 106, 100)
	-- Walls on both sides, far past the road edge (they sink into the ridges).
	for _, side in { -1, 1 } do
		block(model, "Wall", Vector3.new(40, 30, 6), cf * CFrame.new(side * (span / 2 + 20), 15, 0), stone, Enum.Material.Slate)
		block(model, "Tower", Vector3.new(9, 36, 9), cf * CFrame.new(side * (span / 2 + 3), 18, 0), stone, Enum.Material.Slate)
		block(model, "TowerRoof", Vector3.new(12, 2, 12), cf * CFrame.new(side * (span / 2 + 3), 37, 0), Color3.fromRGB(50, 52, 60), Enum.Material.Slate)
		-- Hook point above each tower (GrappleController): climb up and look over the wall.
		local hook = block(model, "GrapplePoint", Vector3.new(0.3, 2.2, 2.2), cf * CFrame.new(side * (span / 2 + 3), 41, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 205, 110), Enum.Material.Neon)
		hook.Shape = Enum.PartType.Cylinder
		hook.CanCollide = false
		hook:SetAttribute("LandAt", (cf * CFrame.new(side * (span / 2 + 3), 41, 0)).Position)
		game:GetService("CollectionService"):AddTag(hook, "GrapplePoint")
	end
	block(model, "Lintel", Vector3.new(span + 18, 4, 7), cf * CFrame.new(0, 30, 0), stone, Enum.Material.Slate)
	-- Two door leaves, hinged at the towers.
	for _, side in { -1, 1 } do
		local leafW = span / 2
		local hinge = cf * CFrame.new(side * span / 2, 0, 0)
		local leaf = block(model, "Door", Vector3.new(leafW, 26, 2), hinge * CFrame.new(-side * leafW / 2, 13, 0), wood, Enum.Material.WoodPlanks)
		leaf:SetAttribute("Side", side)
		leaf:SetAttribute("Hinge", hinge)
		for k = 0, 2 do
			local band = block(model, "DoorBand", Vector3.new(leafW, 1.2, 2.3), hinge * CFrame.new(-side * leafW / 2, 4 + k * 9, 0), iron, Enum.Material.Metal)
			band.CanCollide = false
			band:SetAttribute("Side", side)
			band:SetAttribute("Hinge", hinge)
		end
	end
	-- The bar (visible on the side that can open it).
	local bar = block(model, "Bar", Vector3.new(span * 0.7, 1.6, 1.6), cf * CFrame.new(0, 12, if def.openSign > 0 then 1.9 else -1.9), iron, Enum.Material.Metal)
	bar.CanCollide = false
	-- Prompt on the bar.
	local pp = prompt(bar, "Lift the bar", def.name)
	pp.Triggered:Connect(function(player)
		local data = DataService.GetData(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if data == nil or root == nil or not root:IsA("BasePart") then
			return
		end
		if data.shortcuts[def.id] then
			return
		end
		local toPlayer = root.Position - base
		local toOpen = Vector3.new(def.openFrom[1], 0, def.openFrom[2]) - Vector3.new(base.X, 0, base.Z)
		if toPlayer.Magnitude > PROMPT_RANGE + 6 then
			return
		end
		if Vector3.new(toPlayer.X, 0, toPlayer.Z):Dot(toOpen) <= 0 then
			notify(player, "Error", "It's barred from the other side.")
			return
		end
		data.shortcuts[def.id] = true
		DataService.Changed(player, "shortcuts")
		notify(player, "Info", "Shortcut opened: " .. def.name)
	end)
end

local function buildRelic(folder: Instance, def: any)
	local pos = ground(def.at[1], def.at[2]) + Vector3.new(0, def.y or 3.2, 0)
	local model = Instance.new("Model")
	model.Name = def.id
	model:SetAttribute("Relic", def.id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = folder
	local plinth = block(model, "Plinth", Vector3.new(3, 1.2, 3), CFrame.new(pos - Vector3.new(0, 2.6, 0)), Color3.fromRGB(70, 66, 64), Enum.Material.Slate)
	plinth.CanCollide = false
	local gem = block(model, "Relic", Vector3.new(1.4, 2.2, 1.4), CFrame.new(pos) * CFrame.Angles(0, math.rad(45), math.rad(12)), Color3.fromRGB(255, 120, 70), Enum.Material.Neon)
	gem.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 130, 80)
	light.Range = 16
	light.Brightness = 2
	light.Parent = gem
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 160, 90))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Lifetime = NumberRange.new(1, 1.8)
	sparks.Rate = 8
	sparks.Speed = NumberRange.new(0.5, 1.5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = gem
	local pp = prompt(gem, "Take", "Ashen Relic")
	pp.Triggered:Connect(function(player)
		local data = DataService.GetData(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if data == nil or root == nil or not root:IsA("BasePart") or data.relics[def.id] then
			return
		end
		if (root.Position - pos).Magnitude > PROMPT_RANGE + 6 then
			return
		end
		data.relics[def.id] = true
		DataService.Changed(player, "relics")
		local found = 0
		for _ in data.relics do
			found += 1
		end
		notify(player, "Info", string.format("Ashen Relic %d/%d: +1 skill point", found, #MapConfig.Relics))
	end)
end

function ExplorationService.Init() end

function ExplorationService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Exploration"
	folder.Parent = workspace
	for _, g in MapConfig.Shortcuts do
		-- Which side of the door the bar is on (toward openFrom).
		local base = Vector3.new(g.at[1], 0, g.at[2])
		local dir = Vector3.new(g.dir[1], 0, g.dir[2]).Unit
		local toOpen = Vector3.new(g.openFrom[1], 0, g.openFrom[2]) - base
		local def = table.clone(g) :: any
		-- In the gate frame +Z points back along -dir; openSign > 0 means the open side is +Z.
		def.openSign = if toOpen:Dot(-dir) > 0 then 1 else -1
		local ok, err = pcall(function()
			buildGate(folder, def)
		end)
		if not ok then
			warn("[ExplorationService] gate", g.id, err)
		end
	end
	for _, r in MapConfig.Relics do
		local ok, err = pcall(function()
			buildRelic(folder, r)
		end)
		if not ok then
			warn("[ExplorationService] relic", r.id, err)
		end
	end
	local function clean(player: Player)
		local data = DataService.GetData(player)
		if data then
			data.shortcuts = if type(data.shortcuts) == "table" then data.shortcuts else {}
			data.relics = if type(data.relics) == "table" then data.relics else {}
		end
	end
	DataService.ProfileLoaded:Connect(clean)
	for _, p in Players:GetPlayers() do
		clean(p)
	end
end

return ExplorationService
