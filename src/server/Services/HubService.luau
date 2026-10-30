--!strict
-- HubService: the hub town. If Workspace.Hub is missing, builds a placeholder blockout from
-- HubConfig (plaza, bell tower, lanterns, one stall per station, weapon racks showing every
-- weapon model, lantern pedestals, training yard, gate to the Wilds, spawn point).
-- Every part with attribute Station gets a ProximityPrompt; the CLIENT opens the matching
-- panel (UIController). All purchases still go through server-validated remotes.
-- TODO(Studio/Agent D): build the real hub; keep the Station/LanternId attributes.
--
-- API:
--   HubService.StationPosition(kind) -> Vector3?
--   HubService.Center() -> Vector3

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local HubConfig = require(Config:WaitForChild("HubConfig"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local LanternConfig = require(Config:WaitForChild("LanternConfig"))
local EnemyConfig = require(Config:WaitForChild("EnemyConfig"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))

local HubService = { Name = "HubService", Priority = 29 }

local stationPositions: { [string]: Vector3 } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Ground height the hub is built on. Found by raycasting down (so the hub sits on whatever
-- ground the place has: baseplate, generated terrain or a Studio-built map) instead of a
-- hard-coded Y that can leave stalls buried.
local groundY: number? = nil

local function findGround(): number
	local o = HubConfig.Origin
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, name in { "Hub", "SpiritFollowers" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	params.FilterDescendantsInstances = ignore
	-- Sample the center and a ring; use the highest hit so nothing ends up below the surface.
	local best: number? = nil
	for i = 0, 6 do
		local offset = if i == 0 then Vector3.zero else Vector3.new(math.cos(i), 0, math.sin(i)) * (HubConfig.PlazaRadius * 0.6)
		local from = Vector3.new(o[1], o[2] + 400, o[3]) + offset
		local hit = workspace:Raycast(from, Vector3.new(0, -800, 0), params)
		if hit and hit.Instance and not (hit.Instance:IsA("BasePart") and not hit.Instance.CanCollide) then
			best = math.max(best or -math.huge, hit.Position.Y)
		end
	end
	return best or o[2]
end

local function center(): Vector3
	local o = HubConfig.Origin
	return Vector3.new(o[1], groundY or o[2], o[3])
end
HubService.Center = center

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false -- static decor: no touch events
	p.CastShadow = math.max(size.X, size.Y, size.Z) >= 3
	p.Parent = parent
	return p
end

local function cylinderY(parent: Instance, name: string, height: number, diameter: number, pos: Vector3, color: Color3, material: Enum.Material?): Part
	local p = block(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function sign(parent: BasePart, title: string, subtitle: string?, color: Color3, offsetY: number, width: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width or 220, if subtitle then 64 else 36)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 120
	gui.AlwaysOnTop = false
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 36)
	t.BackgroundColor3 = Color3.fromRGB(20, 18, 24)
	t.BackgroundTransparency = 0.2
	t.TextColor3 = color
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.Text = title
	t.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = t
	if subtitle then
		local s = Instance.new("TextLabel")
		s.Position = UDim2.fromOffset(0, 38)
		s.Size = UDim2.new(1, 0, 0, 24)
		s.BackgroundTransparency = 1
		s.TextColor3 = Color3.fromRGB(235, 230, 220)
		s.TextStrokeTransparency = 0.4
		s.Font = Enum.Font.Gotham
		s.TextScaled = true
		s.Text = subtitle
		s.Parent = gui
	end
end

local function lanternPost(parent: Instance, pos: Vector3, color: Color3)
	cylinderY(parent, "LanternPost", 7, 0.5, pos + Vector3.new(0, 3.5, 0), Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
	local lamp = block(parent, "Lantern", Vector3.new(1.4, 1.8, 1.4), CFrame.new(pos + Vector3.new(0, 7.6, 0)), color, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = lamp
end

local function addPrompt(part: BasePart, actionText: string, objectText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = HubConfig.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.Parent = part
end

-- A pitched-roof market stall facing the plaza center. Returns its station point part.
local function stall(parent: Instance, def: HubConfig.StationDef): BasePart
	local c = center()
	local a = math.rad(def.angle)
	local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
	local pos = c + dir * HubConfig.StallRing
	local face = CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z)) -- front faces the plaza
	local model = Instance.new("Model")
	model.Name = def.name
	model.Parent = parent
	local roofColor = rgb(def.color)
	local wood = Color3.fromRGB(95, 65, 40)

	block(model, "Floor", Vector3.new(16, 0.4, 12), face * CFrame.new(0, -0.05, 0), Color3.fromRGB(120, 100, 80), Enum.Material.WoodPlanks)
	block(model, "BackWall", Vector3.new(16, 9, 0.8), face * CFrame.new(0, 5, 5.6), wood, Enum.Material.WoodPlanks)
	for _, x in { -7.5, 7.5 } do
		for _, z in { -5.5, 5.5 } do
			block(model, "Pillar", Vector3.new(0.8, 10, 0.8), face * CFrame.new(x, 5, z), Color3.fromRGB(140, 40, 35), Enum.Material.Wood)
		end
	end
	-- Pitched roof from two wedges + a ridge beam.
	block(model, "RoofL", Vector3.new(18, 0.6, 7.6), face * CFrame.new(0, 11.4, -3.1) * CFrame.Angles(math.rad(-25), 0, 0), roofColor, Enum.Material.Slate)
	block(model, "RoofR", Vector3.new(18, 0.6, 7.6), face * CFrame.new(0, 11.4, 3.1) * CFrame.Angles(math.rad(25), 0, 0), roofColor, Enum.Material.Slate)
	block(model, "Ridge", Vector3.new(18.6, 0.8, 0.8), face * CFrame.new(0, 13.1, 0), Color3.fromRGB(40, 30, 25), Enum.Material.Wood)

	local counter = block(model, "Counter", Vector3.new(10, 2.6, 2.2), face * CFrame.new(0, 1.3, -3.5), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	sign(counter, def.name, def.subtitle, roofColor:Lerp(Color3.new(1, 1, 1), 0.45), 9)
	-- The prompt lives on an invisible, non-colliding point in front of the counter, at chest
	-- height on the plaza side, so it is always reachable without climbing anything.
	local point = block(model, "StationPoint", Vector3.new(4, 4, 1), face * CFrame.new(0, 3, -6.5), roofColor)
	point.Transparency = 1
	point.CanCollide = false
	point.CanQuery = false
	point:SetAttribute("Station", def.kind)
	addPrompt(point, "Open", def.name)
	stationPositions[def.kind] = point.Position

	lanternPost(model, (face * CFrame.new(-9.5, 0, -6)).Position, Color3.fromRGB(255, 170, 80))
	lanternPost(model, (face * CFrame.new(9.5, 0, -6)).Position, Color3.fromRGB(255, 170, 80))
	return point
end

-- Level frame facing the plaza, at ground height, origin at the stall center (the station
-- point sits 6.5 studs in front of it).
local function flatFrame(point: BasePart): CFrame
	local p = point.Position
	local ground = Vector3.new(p.X, center().Y, p.Z)
	local c = center()
	return CFrame.lookAt(ground, Vector3.new(c.X, ground.Y, c.Z)) * CFrame.new(0, 0, 6.5)
end

-- Racks along both sides of the Weapon Smith showing every weapon model with name + price.
local function weaponRacks(parent: Instance, counter: BasePart)
	local face = flatFrame(counter)
	local rack = Instance.new("Model")
	rack.Name = "WeaponRacks"
	rack.Parent = parent
	local ids = WeaponConfig.ShopOrder
	local perSide = math.ceil(#ids / 2)
	for i, id in ids do
		local side = if i <= perSide then -1 else 1
		local slot = if i <= perSide then i - 1 else i - perSide - 1
		-- Racks run outward from each side of the stall, toward the plaza.
		local base = face * CFrame.new(side * 11.5, 0, -2 - slot * 2.6)
		local stand = block(rack, "Stand", Vector3.new(2, 0.8, 2), base * CFrame.new(0, 0.4, 0), Color3.fromRGB(60, 45, 35), Enum.Material.Wood)
		local model = WeaponModels.Build(id, true)
		if model then
			local def = WeaponConfig.Weapons[id]
			-- Stand the weapon upright, blade up, edge turned toward the walkway.
			model:PivotTo(base * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.rad(90 * side), 0))
			model.Parent = rack
			local priceText = if def.price == 0 then "Free" else FormatNumber.Short(def.price) .. " " .. def.currency
			local rarity = SpiritConfig.Rarities[def.rarity]
			local tagColor = (rarity and rarity.color) or Color3.new(1, 1, 1)
			sign(stand, def.name, priceText, tagColor, WeaponModels.Length(id) + 2.5, 170)
		end
	end
end

local function lanternShrine(parent: Instance, counter: BasePart)
	local face = flatFrame(counter)
	for i, lanternId in HubConfig.ShrineLanterns do
		local def = LanternConfig.Lanterns[lanternId]
		if def then
			local x = (i - (#HubConfig.ShrineLanterns + 1) / 2) * 7
			local pedestalCf = face * CFrame.new(x, 0, -11)
			cylinderY(parent, "Pedestal", 0.8, 4, (pedestalCf * CFrame.new(0, 0.4, 0)).Position, Color3.fromRGB(90, 85, 80), Enum.Material.Slate)
			local color = if def.paid then Color3.fromRGB(90, 230, 160) elseif def.chapter > 0 then Color3.fromRGB(230, 120, 60) else Color3.fromRGB(255, 210, 120)
			local lamp = block(parent, def.name, Vector3.new(2.2, 3, 2.2), pedestalCf * CFrame.new(0, 3.2, 0), color, Enum.Material.Neon)
			lamp.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 14
			light.Parent = lamp
			lamp:SetAttribute("Station", "LanternShrine")
			lamp:SetAttribute("LanternId", lanternId)
			local price = FormatNumber.Short(def.price) .. " " .. def.currency
			sign(lamp, def.name, price, color, 3.5, 180)
			addPrompt(lamp, "View odds", def.name)
		end
	end
end

local function bellTower(parent: Instance)
	local c = center()
	local stone = Color3.fromRGB(110, 105, 100)
	for _, x in { -5, 5 } do
		for _, z in { -5, 5 } do
			block(parent, "TowerPillar", Vector3.new(1.6, 22, 1.6), CFrame.new(c + Vector3.new(x, 11, z)), Color3.fromRGB(140, 40, 35), Enum.Material.Wood)
		end
	end
	block(parent, "TowerBase", Vector3.new(14, 0.4, 14), CFrame.new(c + Vector3.new(0, 0.2, 0)), stone, Enum.Material.Cobblestone)
	block(parent, "TowerRoof", Vector3.new(16, 1.4, 16), CFrame.new(c + Vector3.new(0, 22.7, 0)), Color3.fromRGB(50, 45, 50), Enum.Material.Slate)
	block(parent, "TowerRoofTop", Vector3.new(9, 1.4, 9), CFrame.new(c + Vector3.new(0, 24.1, 0)), Color3.fromRGB(50, 45, 50), Enum.Material.Slate)
	cylinderY(parent, "BellBody", 6, 6, c + Vector3.new(0, 17, 0), Color3.fromRGB(150, 110, 55), Enum.Material.Metal)
	local lip = cylinderY(parent, "BellLip", 0.8, 7, c + Vector3.new(0, 13.8, 0), Color3.fromRGB(130, 95, 45), Enum.Material.Metal)
	local crack = block(parent, "BellCrack", Vector3.new(0.3, 4, 6.2), CFrame.new(c + Vector3.new(0, 16, 0)) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 190, 110)
	glow.Range = 24
	glow.Parent = crack
	sign(lip, HubConfig.Name, "The Cracked Bell still hums", Color3.fromRGB(255, 215, 150), 14, 300)
end

local function wildsGate(parent: Instance)
	local c = center()
	local gatePos = c + Vector3.new(0, 0, -HubConfig.PlazaRadius + 2)
	local red = Color3.fromRGB(165, 35, 30)
	for _, x in { -9, 9 } do
		block(parent, "GatePillar", Vector3.new(2, 18, 2), CFrame.new(gatePos + Vector3.new(x, 9, 0)), red, Enum.Material.Wood)
	end
	block(parent, "GateBeamTop", Vector3.new(26, 1.6, 2.4), CFrame.new(gatePos + Vector3.new(0, 18.4, 0)), Color3.fromRGB(40, 30, 30), Enum.Material.Wood)
	local beam = block(parent, "GateBeam", Vector3.new(21, 1.2, 1.6), CFrame.new(gatePos + Vector3.new(0, 15, 0)), red, Enum.Material.Wood)
	sign(beam, "To the Wilds", "Enemies & boss arenas ahead", Color3.fromRGB(255, 120, 100), 6, 260)
end

local function trainingYard(parent: Instance)
	local o = HubConfig.TrainingYardOffset
	local yard = center() + Vector3.new(o[1], o[2], o[3])
	local fence = Color3.fromRGB(100, 75, 50)
	block(parent, "YardFloor", Vector3.new(30, 0.4, 16), CFrame.new(yard + Vector3.new(0, 0.2, 0)), Color3.fromRGB(150, 130, 95), Enum.Material.Sand)
	for _, x in { -15, 15 } do
		block(parent, "YardFence", Vector3.new(0.6, 2.4, 16), CFrame.new(yard + Vector3.new(x, 1.2, 0)), fence, Enum.Material.Wood)
	end
	local signPost = block(parent, "YardSign", Vector3.new(4, 0.4, 0.4), CFrame.new(yard + Vector3.new(0, 6, -8)), fence, Enum.Material.Wood)
	sign(signPost, "Training Yard", "Try your weapons on the dummies", Color3.fromRGB(240, 220, 170), 2, 260)

	-- Dojo pavilion at the back of the yard: pick a fighting style.
	local dojo = Instance.new("Model")
	dojo.Name = "Dojo"
	dojo.Parent = parent
	local back = yard + Vector3.new(0, 0, 13)
	block(dojo, "DojoFloor", Vector3.new(18, 0.4, 8), CFrame.new(back + Vector3.new(0, -0.05, 0)), Color3.fromRGB(140, 105, 70), Enum.Material.WoodPlanks)
	for _, x in { -8.5, 8.5 } do
		for _, z in { -3.5, 3.5 } do
			block(dojo, "DojoPillar", Vector3.new(0.8, 9, 0.8), CFrame.new(back + Vector3.new(x, 4.5, z)), Color3.fromRGB(140, 40, 35), Enum.Material.Wood)
		end
	end
	block(dojo, "DojoRoof", Vector3.new(21, 0.8, 11), CFrame.new(back + Vector3.new(0, 9.4, 0)), Color3.fromRGB(45, 45, 55), Enum.Material.Slate)
	block(dojo, "DojoBack", Vector3.new(17, 8, 0.4), CFrame.new(back + Vector3.new(0, 4.2, 3.8)), Color3.fromRGB(235, 228, 210), Enum.Material.SmoothPlastic)
	local scroll = block(dojo, "StyleScroll", Vector3.new(3, 5, 0.2), CFrame.new(back + Vector3.new(0, 4.5, 3.5)), Color3.fromRGB(245, 240, 225), Enum.Material.Fabric)
	local point = block(dojo, "StationPoint", Vector3.new(4, 4, 1), CFrame.new(back + Vector3.new(0, 3, -5)), Color3.new(1, 1, 1))
	point.Transparency = 1
	point.CanCollide = false
	point.CanQuery = false
	point:SetAttribute("Station", "Dojo")
	addPrompt(point, "Learn styles", "Dojo of Nine Forms")
	stationPositions.Dojo = point.Position
	sign(scroll, "Dojo of Nine Forms", "Fighting styles", Color3.fromRGB(255, 200, 150), 5, 240)

	local spawns = workspace:FindFirstChild(EnemyConfig.SpawnFolderName)
	if spawns == nil then
		spawns = Instance.new("Folder")
		spawns.Name = EnemyConfig.SpawnFolderName
		spawns.Parent = workspace
	end
	for i = 1, HubConfig.TrainingDummies do
		local x = (i - (HubConfig.TrainingDummies + 1) / 2) * 8
		local spot = block(spawns :: Instance, "TrainingDummySpawn" .. i, Vector3.new(2, 0.2, 2), CFrame.new(yard + Vector3.new(x, 0.5, 2)), fence)
		spot.Transparency = 1
		spot.CanCollide = false
		spot:SetAttribute("EnemyId", "training_dummy")
		spot:SetAttribute("Count", 1)
		spot:SetAttribute("RespawnSeconds", 3)
		spot:SetAttribute("Scatter", 0)
	end
end

local function build()
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	local c = center()

	local plaza = block(hub, "Plaza", Vector3.new(0.4, HubConfig.PlazaRadius * 2, HubConfig.PlazaRadius * 2), CFrame.new(c + Vector3.new(0, -0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(125, 120, 112), Enum.Material.Cobblestone)
	plaza.Shape = Enum.PartType.Cylinder
	local inner = block(hub, "PlazaInner", Vector3.new(0.42, 30, 30), CFrame.new(c + Vector3.new(0, -0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 140, 125), Enum.Material.Slate)
	inner.Shape = Enum.PartType.Cylinder

	bellTower(hub)
	wildsGate(hub)
	trainingYard(hub)

	-- Lantern ring around the plaza.
	for i = 0, 11 do
		local a = math.rad(i * 30 + 15)
		lanternPost(hub, c + Vector3.new(math.sin(a), 0, -math.cos(a)) * 24, Color3.fromRGB(255, 180, 90))
	end

	for _, def in HubConfig.Stations do
		local counter = stall(hub, def)
		if def.kind == "WeaponSmith" then
			weaponRacks(hub, counter)
		elseif def.kind == "LanternShrine" then
			lanternShrine(hub, counter)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(c + Vector3.new(0, 0.05, -14))
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(150, 140, 125)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	hub:SetAttribute("Generated", true)
	hub:SetAttribute("GroundY", c.Y)
	hub.Parent = workspace
end

-- Wires prompts for a Studio-built hub (parts tagged with the Station attribute).
local function wireExisting(hub: Instance)
	local g = hub:GetAttribute("GroundY")
	if type(g) == "number" then
		groundY = g
	end
	for _, d in hub:GetDescendants() do
		if d:IsA("BasePart") then
			local kind = d:GetAttribute("Station")
			if type(kind) == "string" then
				stationPositions[kind] = stationPositions[kind] or d.Position
				if d:FindFirstChildOfClass("ProximityPrompt") == nil then
					addPrompt(d, "Open", kind)
				end
			end
		end
	end
end

function HubService.StationPosition(kind: string): Vector3?
	return stationPositions[kind]
end

-- Builds the hub town (also callable in edit mode through ServerScriptService.EditTools).
function HubService.Build()
	if workspace:FindFirstChild("Hub") then
		return
	end
	groundY = findGround()
	build()
end

function HubService.Init() end

function HubService.Start()
	local existing = workspace:FindFirstChild("Hub")
	if existing then
		wireExisting(existing)
	else
		groundY = findGround()
		build()
	end
end

return HubService
