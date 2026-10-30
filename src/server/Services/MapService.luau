--!strict
-- MapService: generates the Japanese-inspired world from MapConfig when the place has no
-- hand-built map: sculpted terrain (grass valley, stone paths, raked sand, koi pond, snowy
-- mountains) plus part-built props (torii gates and a torii tunnel, stone lanterns, sakura and
-- maple trees with drifting leaves, bamboo groves, graveyard, zen garden, boss shrines, a temple
-- with a bell tower, a five-roof pagoda, an arched bridge, Carillon Hollow) and the
-- EnemySpawns / BossArenas folders the combat services use.
-- Skipped entirely if Workspace.World exists or Workspace has attribute UseStudioMap = true.
-- Terrain is only sculpted if the place has no terrain near the origin already.
-- TODO(Studio/Agent D): replace with a hand-built map; keep folder names + attributes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local MapConfig = require(Config:WaitForChild("MapConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))

local MapService = { Name = "MapService", Priority = 27 }

local C = MapConfig.Colors
local rng = Random.new(MapConfig.Seed)
local world: Model

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: { number } | Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = if typeof(color) == "Color3" then color else rgb(color :: { number })
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	-- Performance: static decor never needs touch events, and small pieces cast no shadows.
	p.CanTouch = false
	if math.max(size.X, size.Y, size.Z) < MapConfig.Perf.ShadowMinSize then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: { number }, material: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = rgb(color)
	w.Material = material or Enum.Material.SmoothPlastic
	w.CanTouch = false
	w.CastShadow = math.max(size.X, size.Y, size.Z) >= MapConfig.Perf.ShadowMinSize
	w.Parent = parent
	return w
end

-- Vertical cylinder (Roblox cylinders run along X).
local function column(parent: Instance, name: string, height: number, diameter: number, base: Vector3, color: { number } | Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

local function light(p: BasePart, color: { number }, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = rgb(color)
	l.Range = range
	l.Brightness = brightness or 1.5
	l.Parent = p
end

local function model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or world
	return m
end

local function xz(v: { number }, y: number?): Vector3
	return Vector3.new(v[1], y or 0, v[2])
end

-- Distance from point to a path segment (keeps props off the walkways).
local function segDist(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local len2 = ab:Dot(ab)
	local t = if len2 > 0 then math.clamp(ap:Dot(ab) / len2, 0, 1) else 0
	local closest = Vector3.new(a.X, 0, a.Z) + ab * t
	return (Vector3.new(p.X, 0, p.Z) - closest).Magnitude
end

local function nearPath(p: Vector3, margin: number): boolean
	local main = MapConfig.Path
	if segDist(p, xz(main.from), xz(main.to)) < main.width / 2 + margin then
		return true
	end
	for _, sp in MapConfig.SidePaths do
		if segDist(p, xz(sp[1]), xz(sp[2])) < MapConfig.SidePathWidth / 2 + margin then
			return true
		end
	end
	return false
end

local function inArea(p: Vector3, margin: number): boolean
	for _, a in MapConfig.Areas do
		if (Vector3.new(p.X, 0, p.Z) - xz(a.center)).Magnitude < a.radius + margin then
			return true
		end
	end
	local hub = ZoneConfig.Zones[1]
	return hub ~= nil and (Vector3.new(p.X, 0, p.Z) - xz(hub.center)).Magnitude < hub.radius + margin
end

-- Terrain ---------------------------------------------------------------------------------------
local function hasTerrain(): boolean
	local ok, result = pcall(function()
		local region = Region3.new(Vector3.new(-8, -8, -8), Vector3.new(8, 0, 8)):ExpandToGrid(4)
		local _, occ = workspace.Terrain:ReadVoxels(region, 4)
		for _, plane in occ do
			for _, row in plane do
				for _, v in row do
					if v > 0 then
						return true
					end
				end
			end
		end
		return false
	end)
	return ok and result == true
end

local function pathTerrain(a: Vector3, b: Vector3, width: number, material: Enum.Material)
	local mid = (a + b) / 2
	local len = (Vector3.new(b.X - a.X, 0, b.Z - a.Z)).Magnitude
	local cf = CFrame.lookAt(Vector3.new(mid.X, -1, mid.Z), Vector3.new(b.X, -1, b.Z))
	workspace.Terrain:FillBlock(cf, Vector3.new(width, 2, len + width), material)
end

local function sculpt()
	local T = workspace.Terrain
	local g = MapConfig.GroundSize
	local gc = MapConfig.GroundCenter
	-- Grass valley floor (top at y = 0), in four tiles.
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			T:FillBlock(CFrame.new(gc[1] + dx * g[1] / 4, -6, gc[2] + dz * g[2] / 4), Vector3.new(g[1] / 2, 12, g[2] / 2), Enum.Material.Grass)
		end
	end
	-- Paths.
	pathTerrain(xz(MapConfig.Path.from), xz(MapConfig.Path.to), MapConfig.Path.width, Enum.Material.Cobblestone)
	for _, sp in MapConfig.SidePaths do
		pathTerrain(xz(sp[1]), xz(sp[2]), MapConfig.SidePathWidth, Enum.Material.Ground)
	end
	-- Mountains with snow caps.
	for _, m in MapConfig.Mountains do
		T:FillBall(Vector3.new(m[1], -m[3] * 0.45, m[2]), m[3], Enum.Material.Rock)
		if m[3] > MapConfig.SnowAbove then
			T:FillBall(Vector3.new(m[1], m[3] * 0.38, m[2]), m[3] * 0.22, Enum.Material.Snow)
		end
	end
	-- Rolling grassy hills between the areas.
	local b = MapConfig.ScatterBounds
	local hills, tries = 0, 0
	while hills < MapConfig.HillCount and tries < 200 do
		tries += 1
		local r = rng:NextNumber(18, 34)
		local p = Vector3.new(rng:NextNumber(b[1], b[2]), 0, rng:NextNumber(b[3], b[4]))
		if not nearPath(p, r) and not inArea(p, r) then
			hills += 1
			T:FillBall(Vector3.new(p.X, -r * 0.72, p.Z), r, Enum.Material.Grass)
		end
	end
	-- Swaying grass blades + clear teal water.
	pcall(function()
		T.Decoration = true
		T.WaterColor = Color3.fromRGB(40, 110, 120)
		T.WaterTransparency = 0.6
		T.WaterReflectance = 0.6
		T.WaterWaveSize = 0.05
	end)
	-- Area grounds.
	for _, a in MapConfig.Areas do
		local c = xz(a.center)
		if a.theme == "Garden" then
			T:FillCylinder(CFrame.new(c + Vector3.new(0, -1, 0)), 2, a.radius * 0.8, Enum.Material.Sand)
		elseif a.theme == "Pond" then
			T:FillCylinder(CFrame.new(c + Vector3.new(0, -4, 0)), 8, a.radius * 0.75, Enum.Material.Air)
			T:FillCylinder(CFrame.new(c + Vector3.new(0, -6.5, 0)), 3, a.radius * 0.75, Enum.Material.Mud)
			T:FillCylinder(CFrame.new(c + Vector3.new(0, -3, 0)), 4, a.radius * 0.75, Enum.Material.Water)
		elseif a.theme == "Shrine" or a.theme == "Temple" or a.theme == "Hollow" then
			T:FillCylinder(CFrame.new(c + Vector3.new(0, -1, 0)), 2, a.radius * 0.85, Enum.Material.Pavement)
		elseif a.theme == "Graves" then
			T:FillCylinder(CFrame.new(c + Vector3.new(0, -1, 0)), 2, a.radius * 0.9, Enum.Material.Ground)
		elseif a.theme == "Maples" then
			T:FillCylinder(CFrame.new(c + Vector3.new(0, -1, 0)), 2, a.radius, Enum.Material.LeafyGrass)
		end
	end
end

-- Props -----------------------------------------------------------------------------------------
local function torii(parent: Instance, base: Vector3, facing: number, width: number, height: number)
	local m = model("Torii", parent)
	local cf = CFrame.new(base) * CFrame.Angles(0, facing, 0)
	for _, x in { -width / 2, width / 2 } do
		local p = (cf * CFrame.new(x, 0, 0)).Position
		column(m, "Pillar", height, 1.6, p, C.ToriiRed, Enum.Material.Wood)
		column(m, "Foot", 1.2, 2.1, p, C.ToriiBlack, Enum.Material.Wood)
	end
	part(m, "Nuki", Vector3.new(width + 2, 1, 1), cf * CFrame.new(0, height * 0.75, 0), C.ToriiRed, Enum.Material.Wood)
	part(m, "Kasagi", Vector3.new(width + 6, 1.2, 1.8), cf * CFrame.new(0, height + 0.6, 0), C.ToriiBlack, Enum.Material.Wood)
	part(m, "Shimaki", Vector3.new(width + 5, 0.8, 1.4), cf * CFrame.new(0, height - 0.3, 0), C.ToriiRed, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		wedge(m, "KasagiTip", Vector3.new(1.8, 1.2, 1.6), cf * CFrame.new(side * (width / 2 + 3.6), height + 0.9, 0) * CFrame.Angles(0, math.rad(90 * side), 0), C.ToriiBlack, Enum.Material.Wood)
	end
	part(m, "Gakuzuka", Vector3.new(0.8, height * 0.22, 0.8), cf * CFrame.new(0, height * 0.87, 0), C.ToriiBlack, Enum.Material.Wood)
end

-- Only every Nth lantern carries a real light (lights are the most expensive decor).
local lanternCount = 0
local function stoneLantern(parent: Instance, base: Vector3, scale: number?)
	local s = scale or 1
	local m = model("StoneLantern", parent)
	part(m, "Base", Vector3.new(2, 0.6, 2) * s, CFrame.new(base + Vector3.new(0, 0.3 * s, 0)), C.Stone, Enum.Material.Slate)
	column(m, "Post", 2.6 * s, 0.9 * s, base + Vector3.new(0, 0.6 * s, 0), C.Stone, Enum.Material.Slate)
	part(m, "Platform", Vector3.new(1.8, 0.4, 1.8) * s, CFrame.new(base + Vector3.new(0, 3.4 * s, 0)), C.Stone, Enum.Material.Slate)
	local box = part(m, "LightBox", Vector3.new(1.2, 1.2, 1.2) * s, CFrame.new(base + Vector3.new(0, 4.2 * s, 0)), C.LanternGlow, Enum.Material.Neon)
	lanternCount += 1
	if lanternCount % MapConfig.Perf.LanternLightEvery == 0 then
		light(box, C.LanternGlow, 16 * s, 1.3)
	end
	part(m, "Roof", Vector3.new(2.6, 0.5, 2.6) * s, CFrame.new(base + Vector3.new(0, 5.05 * s, 0)), C.Stone, Enum.Material.Slate)
	part(m, "Cap", Vector3.new(1.2, 0.5, 1.2) * s, CFrame.new(base + Vector3.new(0, 5.5 * s, 0)), C.Stone, Enum.Material.Slate)
	part(m, "Jewel", Vector3.new(0.5, 0.5, 0.5) * s, CFrame.new(base + Vector3.new(0, 6, 0) * s), C.Stone, Enum.Material.Slate, Enum.PartType.Ball)
end

local function drifting(p: BasePart, color: { number }, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(color))
	e.LightEmission = 0.2
	e.Size = NumberSequence.new(0.35, 0.2)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = rate
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(1.2, -1.6, 0.6)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = p
end

-- Sakura / maple: a leaning trunk, a branch and a cluster of round canopies dropping leaves.
local function tree(parent: Instance, base: Vector3, canopy: { number }, canopy2: { number }, scale: number)
	local m = model("Tree", parent)
	local lean = rng:NextNumber(-12, 12)
	local yaw = rng:NextNumber(0, 360)
	local trunkH = 9 * scale
	local trunk = part(m, "Trunk", Vector3.new(trunkH, 1.3 * scale, 1.3 * scale), CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), math.rad(lean)) * CFrame.new(0, trunkH / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), C.DarkWood, Enum.Material.Wood, Enum.PartType.Cylinder)
	local top = (trunk.CFrame * CFrame.new(trunkH / 2, 0, 0)).Position
	part(m, "Branch", Vector3.new(5 * scale, 0.7 * scale, 0.7 * scale), CFrame.lookAt(top, top + Vector3.new(rng:NextNumber(-1, 1), 0.8, rng:NextNumber(-1, 1))) * CFrame.new(0, 0, -2 * scale) * CFrame.Angles(0, math.rad(90), 0), C.DarkWood, Enum.Material.Wood)
	local main: Part? = nil
	for i = 1, 5 do
		local off = Vector3.new(rng:NextNumber(-3.5, 3.5), rng:NextNumber(0, 3), rng:NextNumber(-3.5, 3.5)) * scale
		local size = rng:NextNumber(5, 7.5) * scale
		local c = part(m, "Canopy", Vector3.new(size, size * 0.8, size), CFrame.new(top + off + Vector3.new(0, 1.5 * scale, 0)), if i % 2 == 0 then canopy2 else canopy, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		c.CanCollide = false
		main = main or c
	end
	if main then
		drifting(main, canopy, 1.5)
	end
end

local function bambooGrove(parent: Instance, center: Vector3, radius: number, count: number)
	local m = model("Bamboo", parent)
	local placed = 0
	local tries = 0
	while placed < count and tries < count * 6 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * radius
		local p = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if not nearPath(p, 3) then
			placed += 1
			local h = rng:NextNumber(14, 24)
			local color = if rng:NextNumber() < 0.5 then C.Bamboo else C.BambooDark
			column(m, "Stalk", h, 0.55, p, color, Enum.Material.SmoothPlastic)
			for y = 3, h - 2, MapConfig.Perf.BambooNodeSpacing do
				column(m, "Node", 0.25, 0.68, p + Vector3.new(0, y, 0), C.BambooDark, Enum.Material.SmoothPlastic)
			end
			local leaf = wedge(m, "Leaves", Vector3.new(0.2, 2.2, 3), CFrame.new(p + Vector3.new(0, h - 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(70)), C.Bamboo)
			leaf.CanCollide = false
		end
	end
end

local function graveyard(parent: Instance, center: Vector3, radius: number)
	local m = model("Graveyard", parent)
	for _ = 1, 18 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(6, radius)
		local p = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if not nearPath(p, 2) then
			local h = rng:NextNumber(2.5, 4.5)
			part(m, "Gravestone", Vector3.new(1.2, h, 0.6), CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), rng:NextNumber(0, 6.28), 0), { 120, 120, 125 }, Enum.Material.Slate)
			part(m, "Base", Vector3.new(1.8, 0.4, 1.2), CFrame.new(p + Vector3.new(0, 0.2, 0)), { 100, 100, 105 }, Enum.Material.Slate)
		end
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		stoneLantern(m, center + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius * 0.7), 0.8)
	end
	-- Pale spirit lights hovering over the graves.
	local hover = part(m, "SpiritLights", Vector3.new(radius * 1.6, 4, radius * 1.6), CFrame.new(center + Vector3.new(0, 4, 0)), C.SpiritGlow)
	hover.Transparency = 1
	hover.CanCollide = false
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(C.SpiritGlow))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.5, 0)
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = 6
	e.Speed = NumberRange.new(0.2, 0.6)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = hover
end

local function zenGarden(parent: Instance, center: Vector3, radius: number)
	local m = model("ZenGarden", parent)
	for i = -4, 4 do
		local line = part(m, "Rake", Vector3.new(radius * 1.4, 0.06, 0.18), CFrame.new(center + Vector3.new(0, 0.04, i * 2.2)), { 215, 200, 170 }, Enum.Material.Sand)
		line.CanCollide = false
	end
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + 0.4
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius * 0.5)
		local s = rng:NextNumber(2.5, 5)
		part(m, "Rock", Vector3.new(s, s * 0.7, s * 1.1), CFrame.new(p + Vector3.new(0, s * 0.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { 95, 95, 100 }, Enum.Material.Rock, Enum.PartType.Ball)
		part(m, "Moss", Vector3.new(s * 1.3, 0.1, s * 1.3), CFrame.new(p + Vector3.new(0, 0.05, 0)), { 90, 120, 60 }, Enum.Material.Grass, Enum.PartType.Ball)
	end
	-- Low wooden fence around the garden.
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		if math.abs(math.sin(a)) > 0.25 or math.cos(a) > 0 then -- leave the west side open
			local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius * 0.95)
			column(m, "FencePost", 2.4, 0.4, p, C.Wood, Enum.Material.Wood)
		end
	end
end

local function shrineDeck(parent: Instance, center: Vector3, radius: number, facing: number)
	local m = model("ShrineDeck", parent)
	local cf = CFrame.new(center) * CFrame.Angles(0, facing, 0)
	-- Small hall at the back.
	local hall = cf * CFrame.new(0, 0, radius * 0.75)
	for _, x in { -6, 6 } do
		for _, z in { -3, 3 } do
			column(m, "HallPillar", 9, 1, (hall * CFrame.new(x, 0, z)).Position, C.ToriiRed, Enum.Material.Wood)
		end
	end
	part(m, "HallBack", Vector3.new(12, 8, 0.6), hall * CFrame.new(0, 4, 3), C.Plaster, Enum.Material.SmoothPlastic)
	part(m, "HallRoofL", Vector3.new(17, 0.8, 6), hall * CFrame.new(0, 10, -1.8) * CFrame.Angles(math.rad(-22), 0, 0), C.Roof, Enum.Material.Slate)
	part(m, "HallRoofR", Vector3.new(17, 0.8, 6), hall * CFrame.new(0, 10, 1.8) * CFrame.Angles(math.rad(22), 0, 0), C.Roof, Enum.Material.Slate)
	-- Entrance torii and guardian lanterns.
	torii(m, (cf * CFrame.new(0, 0, -radius * 0.85)).Position, facing, 10, 13)
	for _, x in { -8, 8 } do
		stoneLantern(m, (cf * CFrame.new(x, 0, -radius * 0.55)).Position, 1.1)
	end
	-- Guardian statues (stylised lion-dogs) flanking the hall.
	for _, x in { -9, 9 } do
		local p = (cf * CFrame.new(x, 0, radius * 0.5)).Position
		part(m, "StatueBase", Vector3.new(3, 2, 3), CFrame.new(p + Vector3.new(0, 1, 0)), C.Stone, Enum.Material.Slate)
		part(m, "StatueBody", Vector3.new(2, 2.4, 2.6), CFrame.new(p + Vector3.new(0, 3.2, 0)), C.Stone, Enum.Material.Slate)
		part(m, "StatueHead", Vector3.new(2, 1.8, 1.8), CFrame.new(p + Vector3.new(0, 5, 0)) * CFrame.Angles(0, facing, 0) * CFrame.new(0, 0, -0.8), C.Stone, Enum.Material.Slate)
	end
end

local function temple(parent: Instance, center: Vector3, radius: number)
	shrineDeck(parent, center, radius, 0)
	local m = model("BellTower", parent)
	local p = center + Vector3.new(radius * 0.7, 0, -radius * 0.2)
	for _, x in { -3, 3 } do
		for _, z in { -3, 3 } do
			column(m, "Pillar", 12, 0.9, p + Vector3.new(x, 0, z), C.DarkWood, Enum.Material.Wood)
		end
	end
	part(m, "Roof", Vector3.new(10, 1, 10), CFrame.new(p + Vector3.new(0, 12.5, 0)), C.Roof, Enum.Material.Slate)
	part(m, "RoofTop", Vector3.new(6, 1, 6), CFrame.new(p + Vector3.new(0, 13.5, 0)), C.Roof, Enum.Material.Slate)
	local bell = column(m, "Bell", 4.5, 3.6, p + Vector3.new(0, 6.5, 0), { 140, 110, 60 }, Enum.Material.Metal)
	light(bell, C.LanternGlow, 10, 0.6)
end

local function pagoda(parent: Instance, center: Vector3)
	local m = model("Pagoda", parent)
	local y = 0
	for tier = 1, 5 do
		local w = 16 - tier * 2
		local h = 6 - tier * 0.4
		part(m, "Story", Vector3.new(w, h, w), CFrame.new(center + Vector3.new(0, y + h / 2, 0)), if tier % 2 == 0 then C.Plaster else C.ToriiRed, Enum.Material.Wood)
		y += h
		part(m, "Roof", Vector3.new(w + 6, 0.8, w + 6), CFrame.new(center + Vector3.new(0, y + 0.4, 0)), C.Roof, Enum.Material.Slate)
		for _, cx in { -1, 1 } do
			for _, cz in { -1, 1 } do
				wedge(m, "Eave", Vector3.new(1.4, 1.2, 2.4), CFrame.new(center + Vector3.new(cx * (w / 2 + 3), y + 0.9, cz * (w / 2 + 3))) * CFrame.Angles(0, math.atan2(cx, cz), 0), C.Roof, Enum.Material.Slate)
			end
		end
		y += 1
	end
	column(m, "Spire", 9, 0.6, center + Vector3.new(0, y, 0), { 170, 140, 70 }, Enum.Material.Metal)
	for i = 1, 5 do
		column(m, "SpireRing", 0.3, 1.6, center + Vector3.new(0, y + i * 1.4, 0), { 170, 140, 70 }, Enum.Material.Metal)
	end
end

local function pond(parent: Instance, center: Vector3, radius: number)
	local m = model("PondDecor", parent)
	-- Arched red bridge across the pond (west-east).
	local span = radius * 1.8
	local segs = 7
	for i = 0, segs - 1 do
		local t0, t1 = i / segs, (i + 1) / segs
		local x0, x1 = -span / 2 + span * t0, -span / 2 + span * t1
		local y0, y1 = math.sin(t0 * math.pi) * 3.5, math.sin(t1 * math.pi) * 3.5
		local a, b = center + Vector3.new(x0, y0 + 0.3, 0), center + Vector3.new(x1, y1 + 0.3, 0)
		local mid = (a + b) / 2
		part(m, "Deck", Vector3.new(6, 0.5, (b - a).Magnitude + 0.2), CFrame.lookAt(mid, b), C.ToriiRed, Enum.Material.Wood)
		for _, z in { -3, 3 } do
			part(m, "Rail", Vector3.new(0.3, 0.3, (b - a).Magnitude + 0.2), CFrame.lookAt(mid + Vector3.new(0, 2.2, z), b + Vector3.new(0, 2.2, z)), C.ToriiRed, Enum.Material.Wood)
			column(m, "Post", 2.2, 0.35, a + Vector3.new(0, 0, z), C.ToriiRed, Enum.Material.Wood)
		end
	end
	-- Lily pads, rocks, a lantern on the shore, fireflies.
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(4, radius * 0.65)
		local pad = part(m, "LilyPad", Vector3.new(0.1, 2.2, 2.2), CFrame.new(center + Vector3.new(math.cos(a) * r, -0.9, math.sin(a) * r)) * CFrame.Angles(0, 0, math.rad(90)), { 70, 130, 60 }, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		pad.CanCollide = false
	end
	stoneLantern(m, center + Vector3.new(0, 0, radius * 0.9), 1)
	local flies = part(m, "Fireflies", Vector3.new(radius * 1.6, 5, radius * 1.6), CFrame.new(center + Vector3.new(0, 3, 0)), { 255, 240, 140 })
	flies.Transparency = 1
	flies.CanCollide = false
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 140))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.25, 0)
	e.Lifetime = NumberRange.new(2, 4)
	e.Rate = 10
	e.Speed = NumberRange.new(0.3, 1)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = flies
end

local function hollow(parent: Instance, center: Vector3, radius: number)
	local m = model("CarillonHollow", parent)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		tree(m, center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius, C.Sakura, C.SakuraDeep, 1.2)
	end
	-- A huge cracked bell half-sunk at the north edge.
	local bellPos = center + Vector3.new(0, 0, -radius * 0.7)
	local bell = part(m, "SunkenBell", Vector3.new(10, 14, 14), CFrame.new(bellPos + Vector3.new(0, 3, 0)) * CFrame.Angles(math.rad(12), 0, math.rad(90)), { 120, 95, 55 }, Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	local crack = part(m, "BellCrack", Vector3.new(0.4, 8, 0.6), CFrame.new(bellPos + Vector3.new(0, 4, 6.6)) * CFrame.Angles(0, 0, math.rad(10)), C.LanternGlow, Enum.Material.Neon)
	light(crack, C.LanternGlow, 20, 2)
	local _ = bell
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		stoneLantern(m, center + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius * 0.55), 0.9)
	end
end

-- Spawns + arenas -------------------------------------------------------------------------------
local function spawnFolders()
	if workspace:FindFirstChild("EnemySpawns") == nil then
		local folder = Instance.new("Folder")
		folder.Name = "EnemySpawns"
		for _, s in MapConfig.EnemySpawns do
			local p = part(folder, s.name, Vector3.new(4, 0.2, 4), CFrame.new(xz(s.at, 0.2)), { 255, 255, 255 })
			p.Transparency = 1
			p.CanCollide = false
			p:SetAttribute("EnemyId", s.enemyId)
			p:SetAttribute("Count", s.count)
			p:SetAttribute("RespawnSeconds", s.respawn)
		end
		folder.Parent = workspace
	end
	if workspace:FindFirstChild("BossArenas") == nil then
		local folder = Instance.new("Folder")
		folder.Name = "BossArenas"
		for _, a in MapConfig.BossArenas do
			local pad = part(folder, a.name, Vector3.new(10, 0.4, 10), CFrame.new(xz(a.at, 0.1)), { 60, 50, 50 }, Enum.Material.Slate)
			pad:SetAttribute("BossId", a.bossId)
			-- Glowing rune border so the challenge pad reads from afar.
			for i = 0, 3 do
				local rune = part(pad, "Rune", Vector3.new(10.4, 0.1, 0.4), CFrame.new(xz(a.at, 0.32)) * CFrame.Angles(0, math.rad(90 * i), 0) * CFrame.new(0, 0, 5), { 255, 120, 60 }, Enum.Material.Neon)
				rune.CanCollide = false
			end
			light(pad, { 255, 120, 60 }, 16, 1)
		end
		folder.Parent = workspace
	end
end

local function build()
	world = Instance.new("Model")
	world.Name = "World"
	world.Parent = workspace

	if not hasTerrain() then
		sculpt()
	end

	-- Main path: lanterns on both sides, torii gates, and the torii tunnel.
	local path = MapConfig.Path
	local from, to = xz(path.from), xz(path.to)
	local dir = (to - from).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local facing = math.atan2(-dir.X, -dir.Z)
	local lanterns = model("PathLanterns")
	local length = (to - from).Magnitude
	for d = 8, length, MapConfig.LanternSpacing do
		for _, s in { -1, 1 } do
			local p = from + dir * d + side * s * (path.width / 2 + 2.5)
			if not inArea(p, -4) then
				stoneLantern(lanterns, p, 0.9)
			end
		end
	end
	local gates = model("ToriiGates")
	for _, z in MapConfig.Torii do
		torii(gates, Vector3.new(from.X, 0, z), facing, path.width + 2, 15)
	end
	local tunnel = MapConfig.ToriiTunnel
	for z = tunnel.from, tunnel.to, -tunnel.spacing do
		torii(gates, Vector3.new(from.X, 0, z), facing, path.width + 1, 12)
	end

	-- Areas.
	for _, a in MapConfig.Areas do
		local c = xz(a.center)
		local m = model(a.name)
		if a.theme == "Bamboo" then
			bambooGrove(m, c + Vector3.new(-26, 0, 0), 18, 45)
			bambooGrove(m, c + Vector3.new(26, 0, -6), 18, 45)
		elseif a.theme == "Graves" then
			graveyard(m, c, a.radius)
		elseif a.theme == "Maples" then
			for i = 1, 9 do
				local ang = i / 9 * math.pi * 2
				local p = c + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(a.radius * 0.45, a.radius)
				if not nearPath(p, 4) then
					tree(m, p, C.Maple, C.MapleGold, rng:NextNumber(0.9, 1.3))
				end
			end
		elseif a.theme == "Garden" then
			zenGarden(m, c, a.radius)
		elseif a.theme == "Shrine" then
			shrineDeck(m, c, a.radius, 0)
		elseif a.theme == "Temple" then
			temple(m, c, a.radius)
		elseif a.theme == "Pond" then
			pond(m, c, a.radius)
		elseif a.theme == "Pagoda" then
			pagoda(m, c)
		elseif a.theme == "Hollow" then
			hollow(m, c, a.radius)
		end
	end

	-- Scattered sakura across the valley, off paths and outside areas.
	local sakura = model("Sakura")
	local placed, tries = 0, 0
	local b = MapConfig.ScatterBounds
	local total = MapConfig.SakuraCount + MapConfig.MapleCount
	while placed < total and tries < 1200 do
		tries += 1
		local p = Vector3.new(rng:NextNumber(b[1], b[2]), 0, rng:NextNumber(b[3], b[4]))
		if not nearPath(p, 6) and not inArea(p, 6) then
			placed += 1
			if placed <= MapConfig.SakuraCount then
				tree(sakura, p, C.Sakura, C.SakuraDeep, rng:NextNumber(0.9, 1.4))
			else
				tree(sakura, p, C.Maple, C.MapleGold, rng:NextNumber(0.9, 1.3))
			end
		end
	end

	-- Ambient petals drifting over the whole valley.
	local sky = part(world, "PetalSky", Vector3.new(300, 2, 360), CFrame.new(0, 45, -40), C.Sakura)
	sky.Transparency = 1
	sky.CanCollide = false
	sky.CanQuery = false
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(C.Sakura))
	e.LightEmission = 0.15
	e.Size = NumberSequence.new(0.45, 0.3)
	e.Lifetime = NumberRange.new(14, 20)
	e.Rate = MapConfig.PetalRate
	e.Speed = NumberRange.new(1, 2)
	e.Acceleration = Vector3.new(1.5, -2.2, 0.8)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Parent = sky
end

function MapService.Init() end

function MapService.Start()
	if workspace:GetAttribute("UseStudioMap") == true or workspace:FindFirstChild("World") then
		return
	end
	local ok, err = pcall(build :: any)
	if not ok then
		warn("[MapService] map generation failed:", err)
	end
	spawnFolders()
end

return MapService
