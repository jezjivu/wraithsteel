--!strict
-- ValleyBuilder: builds Ashen Valley (MapConfig) - a long, linear feudal-Japan journey.
--   1. Terrain: a ground ribbon along the road (rising up the stair to the plateau), clearings
--      for every zone, rock ridges walling the road on both sides, a river through the gorge,
--      a hot spring.
--   2. Props, ALL placed by raycasting the finished terrain (nothing sinks into the ground):
--      flagstone road, stone lanterns, sakura/maple rows, a torii tunnel, zone gates with name
--      plaques, and a themed set piece per zone (bamboo forest, graveyard, river + bridge,
--      burned village, stone stair, temple complex, the fallen bell at the boss gate).
--   3. EnemySpawns / BossArenas / WorldBossSpawns folders for the combat services.
--
-- API:
--   ValleyBuilder.Build(parent: Instance) -> Model     -- the World model
--   ValleyBuilder.Ground(x, z) -> Vector3               -- terrain surface point

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local MapConfig = require(Config:WaitForChild("MapConfig"))
local HubConfig = require(Config:WaitForChild("HubConfig"))
local K = require(script.Parent:WaitForChild("BuildKit"))

local ValleyBuilder = {}

local C = MapConfig.Colors
local function col(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local rng = Random.new(MapConfig.Seed)
local T = workspace.Terrain
local HUB = { HubConfig.Origin[1], HubConfig.Origin[3] }
local HUB_RADIUS = 145

-- Geometry helpers ----------------------------------------------------------------------------
local function segDist(x: number, z: number, ax: number, az: number, bx: number, bz: number): (number, number)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / len2, 0, 1) else 0
	local px, pz = ax + dx * t, az + dz * t
	return math.sqrt((x - px) ^ 2 + (z - pz) ^ 2), t
end

-- Is a disc (x, z, radius) clear of the road corridor, every zone and the hub?
local function clearOfPlay(x: number, z: number, radius: number): boolean
	for _, R in MapConfig.Roads do
		for i = 1, #R - 1 do
			local a, b = R[i], R[i + 1]
			local d = segDist(x, z, a.at[1], a.at[2], b.at[1], b.at[2])
			if d < math.max(a.half, b.half) + radius then
				return false
			end
		end
	end
	for _, area in MapConfig.Areas do
		if K.dist(x, z, area.center[1], area.center[2]) < area.radius + radius then
			return false
		end
	end
	return K.dist(x, z, HUB[1], HUB[2]) >= HUB_RADIUS + radius
end

function ValleyBuilder.Ground(x: number, z: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true
	local y0 = MapConfig.RoadY(x, z)
	local hit = workspace:Raycast(Vector3.new(x, y0 + 120, z), Vector3.new(0, -300, 0), params)
	return if hit then hit.Position else Vector3.new(x, y0, z)
end
local ground = ValleyBuilder.Ground

type RP = MapConfig.RoutePoint
local function isStair(a: RP, b: RP): boolean
	return math.abs(a.y - b.y) > 0.5
end

-- Walks every road: calls fn(x, z, y, dirX, dirZ, segStart, segEnd, roadIndex) every `step`.
local function walkRoute(step: number, fn: (number, number, number, number, number, RP, RP, number) -> ())
	for r, R in MapConfig.Roads do
		for i = 1, #R - 1 do
			local a, b = R[i], R[i + 1]
			local dx, dz = b.at[1] - a.at[1], b.at[2] - a.at[2]
			local len = math.sqrt(dx * dx + dz * dz)
			if len > 0 then
				local ux, uz = dx / len, dz / len
				local d = 0
				while d < len do
					local t = d / len
					fn(a.at[1] + dx * t, a.at[2] + dz * t, a.y + (b.y - a.y) * t, ux, uz, a, b, r)
					d += step
				end
			end
		end
	end
end

local function areaOf(theme: string): MapConfig.AreaDef?
	for _, a in MapConfig.Areas do
		if a.theme == theme then
			return a
		end
	end
	return nil
end

-- Terrain ---------------------------------------------------------------------------------------
local function sculpt()
	for name, c in MapConfig.MaterialColors do
		pcall(function()
			T:SetMaterialColor((Enum.Material :: any)[name], col(c))
		end)
	end
	pcall(function()
		T.Decoration = false -- grass blades hid flagstones and small props
		T.WaterColor = Color3.fromRGB(40, 110, 120)
		T.WaterTransparency = 0.6
		T.WaterReflectance = 0.6
		T.WaterWaveSize = 0.05
	end)
	-- Hub ground.
	T:FillCylinder(CFrame.new(HUB[1], -6, HUB[2]), 12, HUB_RADIUS + 40, Enum.Material.Grass)
	-- Road ribbon: wide grass + an earth strip, following the road height.
	walkRoute(8, function(x, z, y, _ux, _uz, a, b)
		local half = a.half
		local stair = isStair(a, b)
		local top = if stair then y - 2 else y
		-- Solid all the way down, so raised roads are cliffs, not floating slabs.
		local h = math.max(16, top + 24)
		T:FillCylinder(CFrame.new(x, top - h / 2, z), h, half + 40, Enum.Material.Grass)
		if not stair then
			T:FillCylinder(CFrame.new(x, top - 1, z), 2, half * 0.42, Enum.Material.Ground)
		end
	end)
	-- Zone clearings.
	for _, a in MapConfig.Areas do
		local c = Vector3.new(a.center[1], a.y, a.center[2])
		local h = math.max(16, a.y + 24)
		T:FillCylinder(CFrame.new(c - Vector3.new(0, h / 2, 0)), h, a.radius + 25, Enum.Material.Grass)
		local mat = if a.theme == "Temple" or a.theme == "BellGate" then Enum.Material.Pavement
			elseif a.theme == "Graves" or a.theme == "Village" then Enum.Material.Ground
			elseif a.theme == "Gorge" then Enum.Material.LeafyGrass
			elseif a.theme == "Springs" then Enum.Material.Limestone
			else nil
		if mat then
			T:FillCylinder(CFrame.new(c - Vector3.new(0, 1, 0)), 2, a.radius * 0.75, mat)
		end
	end
	-- Ridges: two rows of rock mountains walling the road.
	local cfg = MapConfig.Ridge
	local function ridgeBall(x: number, z: number, r: number)
		for _ = 1, 3 do
			if clearOfPlay(x, z, r * 0.78) then
				local baseY = MapConfig.RoadY(x, z)
				T:FillBall(Vector3.new(x, baseY - r * 0.2, z), r, Enum.Material.Rock)
				if r > cfg.snowAbove then
					T:FillBall(Vector3.new(x, baseY + r * 0.62, z), r * 0.25, Enum.Material.Snow)
				end
				return
			end
			r *= 0.8
		end
	end
	walkRoute(cfg.spacing, function(x, z, _y, ux, uz, a)
		local half = a.half
		for _, side in { -1, 1 } do
			local r = rng:NextNumber(cfg.minRadius, cfg.maxRadius)
			local off = half + r * 0.8 + 6
			ridgeBall(x - uz * side * off, z + ux * side * off, r)
			local r2 = rng:NextNumber(cfg.maxRadius, cfg.maxRadius * 1.4)
			local off2 = off + r * 0.6 + r2 * 0.5
			ridgeBall(x - uz * side * off2, z + ux * side * off2, r2)
		end
	end)
	-- Ring the zones and the hub too.
	for _, a in MapConfig.Areas do
		for i = 0, 11 do
			local ang = i / 12 * math.pi * 2
			local r = rng:NextNumber(cfg.minRadius, cfg.maxRadius)
			local off = a.radius + r * 0.8 + 8
			ridgeBall(a.center[1] + math.cos(ang) * off, a.center[2] + math.sin(ang) * off, r)
		end
	end
	for i = 0, 13 do
		local ang = i / 14 * math.pi * 2
		local r = rng:NextNumber(cfg.minRadius, cfg.maxRadius)
		local off = HUB_RADIUS + r * 0.8 + 10
		ridgeBall(HUB[1] + math.cos(ang) * off, HUB[2] + math.sin(ang) * off, r)
	end
	-- Gorge river: a channel straight across the clearing.
	local g = areaOf("Gorge")
	if g then
		local c = Vector3.new(g.center[1], 0, g.center[2])
		local cf = CFrame.new(c) * CFrame.Angles(0, math.rad(80), 0)
		T:FillBlock(cf * CFrame.new(0, -3, 0), Vector3.new(16, 8, g.radius * 2.6), Enum.Material.Air)
		T:FillBlock(cf * CFrame.new(0, -6.5, 0), Vector3.new(16, 3, g.radius * 2.6), Enum.Material.Mud)
		T:FillBlock(cf * CFrame.new(0, -2.6, 0), Vector3.new(16, 3.2, g.radius * 2.6), Enum.Material.Water)
	end
	-- Hot spring pools.
	local sp = areaOf("Springs")
	if sp then
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			local p = Vector3.new(sp.center[1] + math.cos(a) * 11, 0, sp.center[2] + math.sin(a) * 11)
			T:FillCylinder(CFrame.new(p - Vector3.new(0, 1.5, 0)), 4, 7, Enum.Material.Air)
			T:FillCylinder(CFrame.new(p - Vector3.new(0, 2.5, 0)), 2.4, 7, Enum.Material.Water)
		end
	end
end

-- Props ----------------------------------------------------------------------------------------
local function torii(parent: Instance, base: Vector3, yaw: number, width: number, height: number, plaque: string?)
	local m = K.model("Torii", parent)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	for _, x in { -width / 2, width / 2 } do
		local p = (cf * CFrame.new(x, 0, 0)).Position
		K.column(m, "Pillar", height, 1.7, p - Vector3.new(0, 1, 0), col(C.ToriiRed), Enum.Material.Wood)
		K.column(m, "Foot", 1.4, 2.3, p - Vector3.new(0, 0.4, 0), col(C.ToriiBlack), Enum.Material.Wood)
	end
	K.part(m, "Nuki", Vector3.new(width + 2, 1, 1), cf * CFrame.new(0, height * 0.72, 0), col(C.ToriiRed), Enum.Material.Wood)
	K.part(m, "Kasagi", Vector3.new(width + 6, 1.3, 2), cf * CFrame.new(0, height + 0.4, 0), col(C.ToriiBlack), Enum.Material.Wood)
	K.part(m, "Shimaki", Vector3.new(width + 5, 0.9, 1.5), cf * CFrame.new(0, height - 0.6, 0), col(C.ToriiRed), Enum.Material.Wood)
	for _, side in { -1, 1 } do
		K.wedge(m, "KasagiTip", Vector3.new(2, 1.3, 1.8), cf * CFrame.new(side * (width / 2 + 3.9), height + 0.75, 0) * CFrame.Angles(0, math.rad(90 * side), 0), col(C.ToriiBlack), Enum.Material.Wood)
	end
	if plaque then
		local board = K.part(m, "Plaque", Vector3.new(math.min(width * 0.55, 14), 2.6, 0.4), cf * CFrame.new(0, height * 0.86, 0), col(C.ToriiBlack), Enum.Material.Wood)
		K.sign(board, plaque, Color3.fromRGB(245, 215, 150), Enum.Font.Antique)
	end
end

local lanterns = 0
local function stoneLantern(parent: Instance, base: Vector3, s: number?)
	local k = s or 1
	local m = K.model("StoneLantern", parent)
	local stone = col(C.Stone)
	K.part(m, "Base", Vector3.new(2, 0.6, 2) * k, CFrame.new(base + Vector3.new(0, 0.3 * k, 0)), stone, Enum.Material.Slate)
	K.column(m, "Post", 2.6 * k, 0.9 * k, base + Vector3.new(0, 0.6 * k, 0), stone, Enum.Material.Slate)
	K.part(m, "Platform", Vector3.new(1.8, 0.4, 1.8) * k, CFrame.new(base + Vector3.new(0, 3.4 * k, 0)), stone, Enum.Material.Slate)
	local box = K.decor(m, "LightBox", Vector3.new(1.2, 1.2, 1.2) * k, CFrame.new(base + Vector3.new(0, 4.2 * k, 0)), col(C.LanternGlow), Enum.Material.Neon)
	lanterns += 1
	if lanterns % MapConfig.Perf.LanternLightEvery == 0 then
		K.light(box, col(C.LanternGlow), 18 * k, 1.3)
	end
	K.part(m, "Roof", Vector3.new(2.6, 0.5, 2.6) * k, CFrame.new(base + Vector3.new(0, 5.05 * k, 0)), stone, Enum.Material.Slate)
	K.part(m, "Cap", Vector3.new(1, 0.6, 1) * k, CFrame.new(base + Vector3.new(0, 5.6 * k, 0)), stone, Enum.Material.Slate)
end

local function drifting(p: BasePart, color: { number }, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(col(color))
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

local function tree(parent: Instance, base: Vector3, canopy: { number }, canopy2: { number }, scale: number, leaves: boolean?)
	local m = K.model("Tree", parent)
	local lean = rng:NextNumber(-10, 10)
	local yaw = rng:NextNumber(0, 360)
	local trunkH = 10 * scale
	local trunk = K.part(m, "Trunk", Vector3.new(trunkH, 1.4 * scale, 1.4 * scale), CFrame.new(base - Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.rad(yaw), math.rad(lean)) * CFrame.new(0, trunkH / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), col(C.DarkWood), Enum.Material.Wood, Enum.PartType.Cylinder)
	local top = (trunk.CFrame * CFrame.new(trunkH / 2, 0, 0)).Position
	local first: Part? = nil
	for i = 1, 5 do
		local off = Vector3.new(rng:NextNumber(-3.5, 3.5), rng:NextNumber(0, 3), rng:NextNumber(-3.5, 3.5)) * scale
		local size = rng:NextNumber(5.5, 8) * scale
		local c = K.decor(m, "Canopy", Vector3.new(size, size * 0.8, size), CFrame.new(top + off + Vector3.new(0, 1.5 * scale, 0)), col(if i % 2 == 0 then canopy2 else canopy), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		first = first or c
	end
	if first and leaves ~= false then
		drifting(first, canopy, 1.2)
	end
end

local function bamboo(parent: Instance, base: Vector3)
	local h = rng:NextNumber(18, 30)
	local d = rng:NextNumber(0.7, 1.1)
	local stalk = K.column(parent, "Bamboo", h, d, base - Vector3.new(0, 0.5, 0), col(if rng:NextNumber() < 0.5 then C.Bamboo else C.BambooDark), Enum.Material.SmoothPlastic)
	stalk.CastShadow = false
	for y = 4, h - 2, 4.5 do
		K.decor(parent, "Node", Vector3.new(0.25, d + 0.15, d + 0.15), CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), col(C.BambooDark), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	local tuft = K.decor(parent, "Leaves", Vector3.new(4, 2.5, 4), CFrame.new(base + Vector3.new(0, h, 0)), col(C.BambooDark), Enum.Material.Grass, Enum.PartType.Ball)
	tuft.CastShadow = false
end

-- House: raised floor, wooden walls, a tiled hip roof. burned = charred and broken.
local function house(parent: Instance, base: Vector3, yaw: number, burned: boolean)
	local m = K.model("House", parent)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	local wood = if burned then col(C.Charred) else col(C.Wood)
	K.part(m, "Floor", Vector3.new(16, 1.2, 12), cf * CFrame.new(0, 0.3, 0), col(C.DarkWood), Enum.Material.WoodPlanks)
	for _, x in { -7.5, 7.5 } do
		for _, z in { -5.5, 5.5 } do
			K.part(m, "Post", Vector3.new(0.9, 9, 0.9), cf * CFrame.new(x, 5, z), col(C.DarkWood), Enum.Material.Wood)
		end
	end
	K.part(m, "BackWall", Vector3.new(15, if burned then 5 else 8, 0.6), cf * CFrame.new(0, if burned then 3.5 else 5, 5.4), if burned then wood else col(C.Plaster), Enum.Material.Plaster)
	K.part(m, "SideWall", Vector3.new(0.6, 8, 10.6), cf * CFrame.new(-7.4, 5, 0), wood, Enum.Material.WoodPlanks)
	if not burned then
		K.part(m, "SideWall2", Vector3.new(0.6, 8, 10.6), cf * CFrame.new(7.4, 5, 0), wood, Enum.Material.WoodPlanks)
		K.part(m, "Roof", Vector3.new(19, 1, 15), cf * CFrame.new(0, 9.8, 0), col(C.Roof), Enum.Material.Slate)
		K.part(m, "RoofTop", Vector3.new(12, 1.4, 8), cf * CFrame.new(0, 11, 0), col(C.Roof), Enum.Material.Slate)
		local lamp = K.decor(m, "DoorLamp", Vector3.new(1.2, 1.6, 1.2), cf * CFrame.new(5, 6, -6.4), Color3.fromRGB(255, 120, 80), Enum.Material.Neon, Enum.PartType.Ball)
		K.light(lamp, Color3.fromRGB(255, 150, 90), 14, 1)
	else
		-- Half the roof collapsed.
		K.part(m, "BrokenRoof", Vector3.new(11, 1, 15), cf * CFrame.new(-4, 7.5, 0) * CFrame.Angles(0, 0, math.rad(-20)), col(C.Charred), Enum.Material.Slate)
		local ember = K.decor(m, "Embers", Vector3.new(6, 0.5, 6), cf * CFrame.new(2, 1.2, 0), Color3.fromRGB(255, 90, 30), Enum.Material.Neon)
		ember.Transparency = 0.4
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 6
		fire.Color = Color3.fromRGB(255, 120, 40)
		fire.Parent = ember
	end
end

local function pagoda(parent: Instance, base: Vector3, tiers: number)
	local m = K.model("Pagoda", parent)
	local y = 0
	for i = 0, tiers - 1 do
		local w = 18 - i * 2.4
		K.part(m, "Body", Vector3.new(w * 0.7, 6, w * 0.7), CFrame.new(base + Vector3.new(0, y + 3, 0)), col(C.ToriiRed), Enum.Material.Wood)
		K.part(m, "Eave", Vector3.new(w, 0.8, w), CFrame.new(base + Vector3.new(0, y + 6.4, 0)), col(C.Roof), Enum.Material.Slate)
		y += 6.8
	end
	K.column(m, "Spire", 9, 0.6, base + Vector3.new(0, y, 0), Color3.fromRGB(200, 170, 80), Enum.Material.Metal)
end

-- Temple hall: stone base with steps, red pillars, plaster walls, double hip roof.
local function templeHall(parent: Instance, base: Vector3, yaw: number)
	local m = K.model("TempleHall", parent)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	K.part(m, "Base", Vector3.new(44, 3, 32), cf * CFrame.new(0, 1.5, 0), col(C.Stone), Enum.Material.Slate)
	for i = 0, 3 do
		K.part(m, "Step", Vector3.new(16, 0.75, 2), cf * CFrame.new(0, 0.375 + i * 0.75, -16 - (3 - i) * 2), col(C.Stone), Enum.Material.Slate)
	end
	for x = -18, 18, 6 do
		for _, z in { -12, 12 } do
			K.column(m, "Pillar", 14, 1.4, (cf * CFrame.new(x, 3, z)).Position, col(C.ToriiRed), Enum.Material.Wood)
		end
	end
	K.part(m, "BackWall", Vector3.new(38, 13, 1), cf * CFrame.new(0, 9.5, 11), col(C.Plaster), Enum.Material.Plaster)
	K.part(m, "Roof1", Vector3.new(52, 1.5, 40), cf * CFrame.new(0, 17.8, 0), col(C.Roof), Enum.Material.Slate)
	K.part(m, "Roof1b", Vector3.new(40, 2.5, 28), cf * CFrame.new(0, 19.5, 0), col(C.Roof), Enum.Material.Slate)
	K.part(m, "Roof2", Vector3.new(30, 1.4, 20), cf * CFrame.new(0, 22, 0), col(C.Roof), Enum.Material.Slate)
	K.part(m, "Ridge", Vector3.new(30, 1.6, 2), cf * CFrame.new(0, 23.5, 0), Color3.fromRGB(200, 170, 80), Enum.Material.Metal)
	local altar = K.decor(m, "AltarGlow", Vector3.new(3, 3, 3), cf * CFrame.new(0, 6, 6), col(C.LanternGlow), Enum.Material.Neon, Enum.PartType.Ball)
	K.light(altar, col(C.LanternGlow), 30, 1.6)
end

local function bellTower(parent: Instance, base: Vector3)
	local m = K.model("BellTower", parent)
	for _, x in { -4, 4 } do
		for _, z in { -4, 4 } do
			K.part(m, "Leg", Vector3.new(1.2, 16, 1.2), CFrame.new(base + Vector3.new(x, 8, z)), col(C.DarkWood), Enum.Material.Wood)
		end
	end
	K.part(m, "Roof", Vector3.new(13, 1.2, 13), CFrame.new(base + Vector3.new(0, 16.6, 0)), col(C.Roof), Enum.Material.Slate)
	local bell = K.part(m, "Bell", Vector3.new(5.5, 4.6, 4.6), CFrame.new(base + Vector3.new(0, 11.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 115, 55), Enum.Material.Metal, Enum.PartType.Cylinder)
	K.light(bell, col(C.LanternGlow), 16, 1)
end

local function grave(parent: Instance, base: Vector3)
	local h = rng:NextNumber(2.5, 4.5)
	local stone = Color3.fromRGB(120 + rng:NextInteger(-10, 10), 118, 112)
	K.part(parent, "GraveBase", Vector3.new(2.6, 0.8, 2.2), CFrame.new(base + Vector3.new(0, 0.2, 0)), stone, Enum.Material.Slate)
	K.part(parent, "Grave", Vector3.new(1.4, h, 1), CFrame.new(base + Vector3.new(0, h / 2 + 0.6, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), stone, Enum.Material.Slate)
	if rng:NextNumber() < 0.3 then
		local candle = K.decor(parent, "Candle", Vector3.new(0.4, 0.8, 0.4), CFrame.new(base + Vector3.new(0.9, 1, -0.8)), col(C.LanternGlow), Enum.Material.Neon)
		K.light(candle, col(C.LanternGlow), 8, 0.8)
	end
end

local function steam(parent: Instance, pos: Vector3)
	local p = K.decor(parent, "Steam", Vector3.new(6, 0.5, 6), CFrame.new(pos), col(C.Steam))
	p.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(col(C.Steam))
	e.Transparency = NumberSequence.new(0.6, 1)
	e.Size = NumberSequence.new(2, 6)
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = 6
	e.Speed = NumberRange.new(1, 2)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = p
end

-- Zone set pieces ------------------------------------------------------------------------------
local function onRoad(x: number, z: number, margin: number): boolean
	for _, R in MapConfig.Roads do
		for i = 1, #R - 1 do
			local a, b = R[i], R[i + 1]
			if segDist(x, z, a.at[1], a.at[2], b.at[1], b.at[2]) < a.half * 0.5 + margin then
				return true
			end
		end
	end
	return false
end

local function scatterIn(a: MapConfig.AreaDef, minR: number, maxR: number, count: number, avoidRoad: number, fn: (Vector3) -> ())
	local placed, tries = 0, 0
	while placed < count and tries < count * 8 do
		tries += 1
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber(minR * minR / (maxR * maxR), 1)) * maxR
		local x, z = a.center[1] + math.cos(ang) * r, a.center[2] + math.sin(ang) * r
		if not onRoad(x, z, avoidRoad) then
			placed += 1
			fn(ground(x, z))
		end
	end
end

local function buildZones(world: Model)
	for _, a in MapConfig.Areas do
		local m = K.model(a.name, world)
		local c = ground(a.center[1], a.center[2])
		if a.theme == "ToriiRoad" then
			-- Senbon torii tunnel along the road.
			for z = 40, -150, -9 do
				local p = ground(0, z)
				torii(m, p, 0, 13, 13, if z == 40 then "TORII ROAD" else nil)
			end
		elseif a.theme == "Bamboo" then
			scatterIn(a, 10, a.radius, 260, 9, function(p)
				bamboo(m, p)
			end)
			scatterIn(a, 20, a.radius, 14, 10, function(p)
				local s = rng:NextNumber(3, 6)
				K.part(m, "Boulder", Vector3.new(s, s * 0.75, s), CFrame.new(p + Vector3.new(0, s * 0.2, 0)), Color3.fromRGB(100, 98, 95), Enum.Material.Rock, Enum.PartType.Ball)
			end)
			local shrine = ground(a.center[1] + 34, a.center[2] + 6)
			torii(m, shrine, math.rad(90), 8, 9)
			stoneLantern(m, shrine + Vector3.new(0, 0, 6), 1)
			stoneLantern(m, shrine + Vector3.new(0, 0, -6), 1)
		elseif a.theme == "Graves" then
			for row = -4, 4 do
				for i = -5, 5 do
					local x, z = a.center[1] + i * 7 + rng:NextNumber(-1, 1), a.center[2] + row * 9 + rng:NextNumber(-1, 1)
					if K.dist(x, z, a.center[1], a.center[2]) < a.radius * 0.85 and not onRoad(x, z, 4) then
						grave(m, ground(x, z))
					end
				end
			end
			for i = 1, 6 do
				local ang = i / 6 * math.pi * 2
				stoneLantern(m, ground(a.center[1] + math.cos(ang) * a.radius * 0.7, a.center[2] + math.sin(ang) * a.radius * 0.7), 1.3)
			end
			-- Dead, bare trees and a low mist.
			scatterIn(a, a.radius * 0.6, a.radius, 10, 6, function(p)
				tree(m, p, { 70, 60, 60 }, { 55, 50, 50 }, rng:NextNumber(0.8, 1.1), false)
			end)
			local mist = K.decor(m, "Mist", Vector3.new(a.radius * 1.6, 1, a.radius * 1.6), CFrame.new(c + Vector3.new(0, 1, 0)), Color3.new(1, 1, 1))
			mist.Transparency = 1
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(200, 205, 215))
			e.Transparency = NumberSequence.new(0.75, 1)
			e.Size = NumberSequence.new(8, 14)
			e.Lifetime = NumberRange.new(6, 9)
			e.Rate = 10
			e.Speed = NumberRange.new(0.5, 1)
			e.Shape = Enum.ParticleEmitterShape.Box
			e.Parent = mist
		elseif a.theme == "Springs" then
			for i = 0, 2 do
				local ang = i / 3 * math.pi * 2
				local p = ground(a.center[1] + math.cos(ang) * 11, a.center[2] + math.sin(ang) * 11)
				steam(m, p + Vector3.new(0, 0.5, 0))
				for k = 0, 5 do
					local ra = k / 6 * math.pi * 2
					local rp = ground(p.X + math.cos(ra) * 8, p.Z + math.sin(ra) * 8)
					K.part(m, "PoolRock", Vector3.new(2.6, 1.6, 2.6), CFrame.new(rp + Vector3.new(0, 0.3, 0)), Color3.fromRGB(110, 105, 100), Enum.Material.Rock, Enum.PartType.Ball)
				end
			end
		elseif a.theme == "Gorge" then
			-- Arched red bridge over the river, waterfall cliff upstream, maples everywhere.
			local cf = CFrame.new(Vector3.new(a.center[1], 0, a.center[2])) * CFrame.Angles(0, math.rad(80), 0)
			local road = CFrame.lookAt(c, c + (cf.RightVector))
			for i = -5, 5 do
				local y = 2.5 - (i / 5) ^ 2 * 2.2
				K.part(m, "BridgeDeck", Vector3.new(14, 0.8, 3.2), road * CFrame.new(0, y, i * 3), col(C.Wood), Enum.Material.WoodPlanks)
			end
			for _, s in { -1, 1 } do
				for i = -5, 5, 2 do
					local y = 2.5 - (i / 5) ^ 2 * 2.2
					K.part(m, "Rail", Vector3.new(0.6, 3, 0.6), road * CFrame.new(s * 6.8, y + 1.8, i * 3), col(C.ToriiRed), Enum.Material.Wood)
				end
				K.part(m, "Handrail", Vector3.new(0.5, 0.5, 32), road * CFrame.new(s * 6.8, 3.6, 0), col(C.ToriiRed), Enum.Material.Wood)
			end
			local up = cf * CFrame.new(0, 0, -a.radius * 1.05)
			T:FillBlock(up * CFrame.new(0, 22, -10), Vector3.new(80, 50, 24), Enum.Material.Rock)
			local fall = K.decor(m, "Waterfall", Vector3.new(14, 46, 0.8), up * CFrame.new(0, 21, 2.2), col(C.WaterFall), Enum.Material.Glass)
			fall.Transparency = 0.25
			local foam = K.decor(m, "Foam", Vector3.new(18, 1, 6), up * CFrame.new(0, 0.5, 5), Color3.new(1, 1, 1))
			foam.Transparency = 1
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(Color3.new(1, 1, 1))
			e.Transparency = NumberSequence.new(0.5, 1)
			e.Size = NumberSequence.new(3, 7)
			e.Lifetime = NumberRange.new(1.5, 2.5)
			e.Rate = 25
			e.Speed = NumberRange.new(3, 6)
			e.Shape = Enum.ParticleEmitterShape.Box
			e.Parent = foam
			scatterIn(a, 25, a.radius, 26, 10, function(p)
				tree(m, p, C.Maple, C.MapleGold, rng:NextNumber(1, 1.5))
			end)
		elseif a.theme == "Village" then
			for i = 0, 9 do
				local ang = i / 10 * math.pi * 2 + 0.2
				local r = a.radius * rng:NextNumber(0.5, 0.78)
				local x, z = a.center[1] + math.cos(ang) * r, a.center[2] + math.sin(ang) * r
				if not onRoad(x, z, 10) then
					local p = ground(x, z)
					house(m, p, math.atan2(a.center[1] - x, a.center[2] - z) + math.pi, i % 3 ~= 0)
				end
			end
			local well = c + Vector3.new(14, 0, 10)
			K.column(m, "Well", 2.4, 6, ground(well.X, well.Z), col(C.Stone), Enum.Material.Cobblestone)
			scatterIn(a, a.radius * 0.8, a.radius, 8, 6, function(p)
				tree(m, p, { 60, 50, 45 }, { 45, 40, 38 }, rng:NextNumber(0.9, 1.2), false)
			end)
			torii(m, ground(a.center[1] + 30, a.center[2] - 60), math.rad(30), 10, 11, "ASHEN VILLAGE")
		elseif a.theme == "Stairs" then
			-- The stair itself is built along the stair segment (below); lanterns line the top.
			stoneLantern(m, ground(a.center[1] - 14, a.center[2] - 130), 1.4)
			stoneLantern(m, ground(a.center[1] + 14, a.center[2] - 130), 1.4)
		elseif a.theme == "Temple" then
			templeHall(m, ground(a.center[1], a.center[2] - 60), 0)
			bellTower(m, ground(a.center[1] + 55, a.center[2] - 10))
			pagoda(m, ground(a.center[1] - 60, a.center[2] - 30), 5)
			-- Zen garden: raked sand rectangle with rocks.
			local zg = ground(a.center[1] + 40, a.center[2] + 40)
			K.part(m, "ZenSand", Vector3.new(30, 0.3, 22), CFrame.new(zg + Vector3.new(0, 0.1, 0)), Color3.fromRGB(226, 218, 196), Enum.Material.Sand)
			for i = 1, 3 do
				K.part(m, "ZenRock", Vector3.new(3, 2, 3) * i * 0.7, CFrame.new(zg + Vector3.new(-9 + i * 6, 0.6, rng:NextNumber(-5, 5))), Color3.fromRGB(95, 92, 90), Enum.Material.Rock, Enum.PartType.Ball)
			end
			for i = 1, 10 do
				local ang = i / 10 * math.pi * 2
				stoneLantern(m, ground(a.center[1] + math.cos(ang) * a.radius * 0.75, a.center[2] + math.sin(ang) * a.radius * 0.75), 1.2)
			end
			scatterIn(a, a.radius * 0.8, a.radius, 12, 8, function(p)
				tree(m, p, C.Sakura, C.SakuraDeep, rng:NextNumber(1.1, 1.5))
			end)
		elseif a.theme == "BellGate" then
			-- The fallen, cracked bell: half buried, glowing seam, broken frame.
			local bp = ground(a.center[1] + 45, a.center[2] - 30)
			local bell = K.part(m, "FallenBell", Vector3.new(16, 14, 14), CFrame.new(bp + Vector3.new(0, 5, 0)) * CFrame.Angles(math.rad(70), math.rad(20), math.rad(90)), Color3.fromRGB(130, 95, 50), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
			local crack = K.decor(m, "Crack", Vector3.new(0.6, 14, 1), bell.CFrame * CFrame.new(0, 0, -6.8), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
			K.light(crack, Color3.fromRGB(255, 120, 40), 40, 2)
			for _, s in { -1, 1 } do
				K.part(m, "BrokenBeam", Vector3.new(2, 22, 2), CFrame.new(bp + Vector3.new(s * 12, 9, 6)) * CFrame.Angles(0, 0, math.rad(s * 18)), col(C.DarkWood), Enum.Material.Wood)
			end
			torii(m, ground(a.center[1], a.center[2] + 80), 0, 20, 22, "GATE OF THE CRACKED BELL")
			for i = 1, 14 do
				local ang = i / 14 * math.pi * 2
				stoneLantern(m, ground(a.center[1] + math.cos(ang) * a.radius * 0.8, a.center[2] + math.sin(ang) * a.radius * 0.8), 1.5)
			end
		end
		-- Every zone gets falling petals overhead.
		local sky = K.decor(m, "PetalSky", Vector3.new(a.radius * 2, 1, a.radius * 2), CFrame.new(c + Vector3.new(0, 45, 0)), col(C.Sakura))
		sky.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(col(if a.theme == "Gorge" or a.theme == "Village" then C.Maple else C.Sakura))
		e.LightEmission = 0.15
		e.Size = NumberSequence.new(0.45, 0.3)
		e.Lifetime = NumberRange.new(12, 18)
		e.Rate = 6
		e.Speed = NumberRange.new(1, 2)
		e.Acceleration = Vector3.new(1.5, -2.2, 0.8)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Parent = sky
	end
end

-- The roads: flagstones, lanterns, trees along the edges, zone gates; stone stairs on climbs.
local function buildStair(world: Model, a: RP, b: RP, index: number)
	-- Always build from the low end up.
	if a.y > b.y then
		a, b = b, a
	end
	local ax, az, bx, bz = a.at[1], a.at[2], b.at[1], b.at[2]
	local len = K.dist(ax, az, bx, bz)
	local ux, uz = (bx - ax) / len, (bz - az) / len
	local yaw = math.atan2(-ux, -uz)
	local rise = b.y - a.y
	local stepRun, stepRise = 3, 1.25
	local count = math.floor(rise / stepRise)
	local runTotal = math.min(count * stepRun, len - 8)
	stepRun = runTotal / count
	local startD = (len - runTotal) / 2
	local width = math.min(a.half, b.half) * 0.9
	local stair = K.model("Stair" .. index, world)
	-- Flat landings at both ends.
	for _, d in { startD / 2, len - startD / 2 } do
		local y = if d < len / 2 then a.y else b.y
		K.part(stair, "Landing", Vector3.new(width * 1.2, 1, startD + 1), CFrame.new(ax + ux * d, y - 0.4, az + uz * d) * CFrame.Angles(0, yaw, 0), col(C.Flagstone), Enum.Material.Slate)
	end
	for s = 0, count - 1 do
		local d = startD + s * stepRun + stepRun / 2
		local y = a.y + (s + 1) * stepRise
		local cf = CFrame.new(ax + ux * d, y - 4, az + uz * d) * CFrame.Angles(0, yaw, 0)
		K.part(stair, "Step", Vector3.new(width, 8, stepRun + 0.2), cf, col(C.Flagstone), Enum.Material.Slate)
		if s % 10 == 5 then
			torii(stair, Vector3.new(ax + ux * d, y, az + uz * d), yaw, width + 2, 13)
		end
		if s % 5 == 0 then
			for _, side in { -1, 1 } do
				stoneLantern(stair, Vector3.new(ax + ux * d - uz * side * (width * 0.5 + 2), y, az + uz * d + ux * side * (width * 0.5 + 2)), 0.9)
			end
		end
	end
end

local function buildRoad(world: Model)
	local road = K.model("Road", world)
	local trees = K.model("RoadTrees", world)
	local step = MapConfig.Perf.FlagstoneSpacing
	local i = 0
	walkRoute(step, function(x, z, _y, ux, uz, a, b)
		if isStair(a, b) then
			return
		end
		i += 1
		local sx, sz = -uz, ux
		for _, lane in { -1, 1 } do
			local off = lane * 2.6 + (if i % 2 == 0 then 0.7 else -0.7)
			local p = ground(x + sx * off, z + sz * off)
			local w, l = rng:NextNumber(3.4, 4.4), rng:NextNumber(2.6, 3.4)
			local stone = K.part(road, "Flagstone", Vector3.new(w, 0.4, l), CFrame.new(p + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.atan2(ux, uz) + rng:NextNumber(-0.2, 0.2), 0), col(C.Flagstone), Enum.Material.Slate)
			stone.CastShadow = false
		end
	end)
	-- Lanterns every 48 studs, trees on both edges (skipped inside zone clearings, which
	-- dress themselves).
	walkRoute(48, function(x, z, _y, ux, uz, a, b)
		if isStair(a, b) then
			return
		end
		local half = a.half
		for _, side in { -1, 1 } do
			stoneLantern(road, ground(x - uz * side * 7, z + ux * side * 7), 0.9)
		end
		for _, side in { -1, 1 } do
			for k = 0, 1 do
				local along = k * 24 - 12
				local off = half * 0.7 + rng:NextNumber(0, half * 0.25)
				local tx, tz = x + ux * along - uz * side * off, z + uz * along + ux * side * off
				if rng:NextNumber() < 0.75 then
					local maple = rng:NextNumber() < 0.35
					tree(trees, ground(tx, tz), if maple then C.Maple else C.Sakura, if maple then C.MapleGold else C.SakuraDeep, rng:NextNumber(0.9, 1.4))
				end
			end
		end
	end)
	-- Stone stairs on every climb.
	local n = 0
	for _, R in MapConfig.Roads do
		for k = 1, #R - 1 do
			if isStair(R[k], R[k + 1]) then
				n += 1
				buildStair(world, R[k], R[k + 1], n)
			end
		end
	end
	-- Zone entrance gates (where each road crosses a zone edge), with the zone name on the plaque.
	local gates: { Vector3 } = {}
	for _, area in MapConfig.Areas do
		if area.theme ~= "ToriiRoad" and area.theme ~= "Stairs" and area.theme ~= "Springs" then
			for r = 1, #MapConfig.Roads do
				local best, bestD = nil, math.huge
				walkRoute(4, function(x, z, _y, rx, rz, a, b, road)
					if road ~= r or isStair(a, b) then
						return
					end
					local d = math.abs(K.dist(x, z, area.center[1], area.center[2]) - area.radius * 0.95)
					if d < bestD then
						best, bestD = { x, z, rx, rz }, d
					end
				end)
				if best and bestD < 8 then
					local pos = ground(best[1], best[2])
					local dup = false
					for _, g in gates do
						if (g - pos).Magnitude < 40 then
							dup = true
						end
					end
					if not dup then
						table.insert(gates, pos)
						torii(world, pos, math.atan2(-best[3], -best[4]), 16, 17, string.upper(area.name))
					end
				end
			end
		end
	end
end

-- Spawns, arenas, world boss spot -----------------------------------------------------------
local function buildFolders()
	if workspace:FindFirstChild("EnemySpawns") == nil then
		local folder = Instance.new("Folder")
		folder.Name = "EnemySpawns"
		for _, s in MapConfig.EnemySpawns do
			local p = K.part(folder, s.name, Vector3.new(4, 0.2, 4), CFrame.new(ground(s.at[1], s.at[2]) + Vector3.new(0, 0.3, 0)), Color3.new(1, 1, 1))
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p:SetAttribute("EnemyId", s.enemyId)
			p:SetAttribute("Count", s.count)
			p:SetAttribute("RespawnSeconds", s.respawn)
		end
		folder:SetAttribute("Generated", true)
		folder.Parent = workspace
	end
	if workspace:FindFirstChild("BossArenas") == nil then
		local folder = Instance.new("Folder")
		folder.Name = "BossArenas"
		for _, a in MapConfig.BossArenas do
			local base = ground(a.at[1], a.at[2])
			local pad = K.part(folder, a.name, Vector3.new(14, 0.6, 14), CFrame.new(base + Vector3.new(0, 0.3, 0)), Color3.fromRGB(60, 50, 50), Enum.Material.Slate)
			pad:SetAttribute("BossId", a.bossId)
			for k = 0, 3 do
				local rune = K.decor(pad, "Rune", Vector3.new(14.4, 0.1, 0.5), CFrame.new(base + Vector3.new(0, 0.62, 0)) * CFrame.Angles(0, math.rad(90 * k), 0) * CFrame.new(0, 0, 7), Color3.fromRGB(255, 120, 60), Enum.Material.Neon)
				rune.Transparency = 0.1
			end
			K.light(pad, Color3.fromRGB(255, 120, 60), 18, 1)
		end
		folder:SetAttribute("Generated", true)
		folder.Parent = workspace
	end
	if workspace:FindFirstChild("WorldBossSpawns") == nil then
		local folder = Instance.new("Folder")
		folder.Name = "WorldBossSpawns"
		local w = MapConfig.WorldBossSpawn
		local p = K.part(folder, "GorgeClearing", Vector3.new(4, 0.2, 4), CFrame.new(ground(w[1], w[2]) + Vector3.new(0, 0.3, 0)), Color3.new(1, 1, 1))
		p.Transparency = 1
		p.CanCollide = false
		folder:SetAttribute("Generated", true)
		folder.Parent = workspace
	end
end

function ValleyBuilder.Build(parent: Instance): Model
	local world = K.model("World", parent)
	world:SetAttribute("Generated", true)
	sculpt()
	local ok, err = pcall(buildRoad :: any, world)
	if not ok then
		warn("[ValleyBuilder] road:", err)
	end
	local ok2, err2 = pcall(buildZones :: any, world)
	if not ok2 then
		warn("[ValleyBuilder] zones:", err2)
	end
	buildFolders()
	return world
end

return ValleyBuilder
