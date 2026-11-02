--!strict
-- AeloriaBuilder: builds Aeloria, the ancient-Greek realm (RealmConfig.Realms.greek): a
-- terrain island in a green sea, a marble agora with colonnades and statues, olive terraces,
-- a theatre carved into a hill, a sunken harbor of broken columns, three cliff shrines for the
-- Oracle, and the Temple of the Sun-Archon with its golden sun disc.
--
-- API:
--   AeloriaBuilder.Build(origin: Vector3, parent: Instance) -> Model
--   AeloriaBuilder.ShrinePoints -> { {x, z} } (local) used by the Oracle quest

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RealmConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RealmConfig"))
local K = require(script.Parent:WaitForChild("BuildKit"))

local AeloriaBuilder = {}

AeloriaBuilder.ShrinePoints = { { -250, 60 }, { 230, 110 }, { 220, -170 } }

local MARBLE = Color3.fromRGB(236, 232, 222)
local MARBLE_SHADE = Color3.fromRGB(205, 198, 186)
local BRONZE = Color3.fromRGB(180, 120, 60)
local GOLD = Color3.fromRGB(255, 205, 90)
local TERRACOTTA = Color3.fromRGB(190, 90, 55)
local OLIVE = Color3.fromRGB(120, 140, 90)

-- Fluted column with base and capital.
local function column(parent: Instance, base: Vector3, height: number, diameter: number, broken: boolean?)
	local h = if broken then height * (0.3 + math.random() * 0.4) else height
	K.part(parent, "ColumnBase", Vector3.new(diameter + 1.2, 0.8, diameter + 1.2), CFrame.new(base + Vector3.new(0, 0.4, 0)), MARBLE_SHADE, Enum.Material.Marble)
	K.column(parent, "Column", h - 1.6, diameter, base + Vector3.new(0, 0.8, 0), MARBLE, Enum.Material.Marble)
	if not broken then
		K.part(parent, "Capital", Vector3.new(diameter + 1.6, 0.8, diameter + 1.6), CFrame.new(base + Vector3.new(0, h - 0.4, 0)), MARBLE_SHADE, Enum.Material.Marble)
	end
end

-- Statue: pedestal + a robed figure built from parts (arm raised).
local function statue(parent: Instance, base: Vector3, facing: number, scale: number, material: Enum.Material, color: Color3)
	local cf = CFrame.new(base) * CFrame.Angles(0, math.rad(facing), 0)
	local s = scale
	K.part(parent, "Pedestal", Vector3.new(4, 3, 4) * s, cf * CFrame.new(0, 1.5 * s, 0), MARBLE_SHADE, Enum.Material.Marble)
	K.part(parent, "Robe", Vector3.new(2.4, 4.6, 1.6) * s, cf * CFrame.new(0, 5.3 * s, 0), color, material)
	K.part(parent, "Chest", Vector3.new(2.2, 2, 1.4) * s, cf * CFrame.new(0, 8.6 * s, 0), color, material)
	K.part(parent, "Head", Vector3.new(1.3, 1.4, 1.3) * s, cf * CFrame.new(0, 10.4 * s, 0), color, material)
	K.part(parent, "ArmUp", Vector3.new(0.6, 3, 0.6) * s, cf * CFrame.new(1.5 * s, 10 * s, 0) * CFrame.Angles(0, 0, math.rad(-20)), color, material)
	K.part(parent, "ArmDown", Vector3.new(0.6, 2.6, 0.6) * s, cf * CFrame.new(-1.4 * s, 7.6 * s, 0), color, material)
end

local function olive(parent: Instance, base: Vector3, rng: Random)
	local m = K.model("OliveTree", parent)
	local lean = rng:NextNumber(-20, 20)
	local trunk = K.part(m, "Trunk", Vector3.new(6, 1.1, 1.1), CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(lean)) * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(110, 90, 70), Enum.Material.Wood, Enum.PartType.Cylinder)
	local top = (trunk.CFrame * CFrame.new(3, 0, 0)).Position
	for _ = 1, 4 do
		local c = K.decor(m, "Leaves", Vector3.new(1, 0.7, 1) * rng:NextNumber(4, 6), CFrame.new(top + Vector3.new(rng:NextNumber(-2.5, 2.5), rng:NextNumber(0, 1.5), rng:NextNumber(-2.5, 2.5))), OLIVE, Enum.Material.Grass, Enum.PartType.Ball)
		c.CanCollide = false
	end
end

local function cypress(parent: Instance, base: Vector3, rng: Random)
	local h = rng:NextNumber(12, 20)
	K.column(parent, "CypressTrunk", 2, 0.8, base, Color3.fromRGB(90, 70, 50), Enum.Material.Wood)
	local body = K.decor(parent, "Cypress", Vector3.new(3.4, h, 3.4), CFrame.new(base + Vector3.new(0, 1.5 + h / 2, 0)), Color3.fromRGB(45, 80, 45), Enum.Material.Grass, Enum.PartType.Ball)
	body.CanCollide = false
end

local function amphora(parent: Instance, base: Vector3)
	K.part(parent, "Amphora", Vector3.new(1.4, 2, 1.4), CFrame.new(base + Vector3.new(0, 1, 0)), TERRACOTTA, Enum.Material.Slate, Enum.PartType.Ball)
	K.column(parent, "AmphoraNeck", 0.9, 0.6, base + Vector3.new(0, 1.8, 0), TERRACOTTA, Enum.Material.Slate)
end

-- Greek temple: stepped base, ring of columns, roof slab, two pediment wedges.
local function temple(parent: Instance, center: Vector3, w: number, d: number, colH: number, facing: number)
	local m = K.model("Temple", parent)
	local cf = CFrame.new(center) * CFrame.Angles(0, math.rad(facing), 0)
	for i = 0, 2 do
		K.part(m, "Step", Vector3.new(w + 6 - i * 2, 1, d + 6 - i * 2), cf * CFrame.new(0, 0.5 + i, 0), MARBLE_SHADE, Enum.Material.Marble)
	end
	local top = 3
	local nx = math.max(2, math.floor(w / 6))
	local nz = math.max(2, math.floor(d / 6))
	for ix = 0, nx do
		for iz = 0, nz do
			if ix == 0 or ix == nx or iz == 0 or iz == nz then
				local x = -w / 2 + w * ix / nx
				local z = -d / 2 + d * iz / nz
				column(m, (cf * CFrame.new(x, top, z)).Position, colH, 2.2)
			end
		end
	end
	K.part(m, "Entablature", Vector3.new(w + 4, 2.2, d + 4), cf * CFrame.new(0, top + colH + 1.1, 0), MARBLE, Enum.Material.Marble)
	local band = K.decor(m, "Frieze", Vector3.new(w + 4.2, 0.6, d + 4.2), cf * CFrame.new(0, top + colH + 0.5, 0), Color3.fromRGB(90, 120, 170), Enum.Material.SmoothPlastic)
	band.CanCollide = false
	-- Pediment: two wedges forming the gable along the length.
	local gableH = w * 0.18
	for _, s in { -1, 1 } do
		K.wedge(m, "Pediment", Vector3.new(d + 4, gableH, (w + 4) / 2), cf * CFrame.new(s * (w + 4) / 4, top + colH + 2.2 + gableH / 2, 0) * CFrame.Angles(0, math.rad(90 * -s), 0), MARBLE, Enum.Material.Marble)
	end
	-- Inner chamber walls (cella) with an open front.
	K.part(m, "CellaBack", Vector3.new(w * 0.6, colH, 1), cf * CFrame.new(0, top + colH / 2, d * 0.3), MARBLE_SHADE, Enum.Material.Marble)
	for _, s in { -1, 1 } do
		K.part(m, "CellaSide", Vector3.new(1, colH, d * 0.6), cf * CFrame.new(s * w * 0.3, top + colH / 2, 0), MARBLE_SHADE, Enum.Material.Marble)
	end
	return m
end

function AeloriaBuilder.Build(origin: Vector3, parent: Instance): Model
	local rng = Random.new(480)
	local realm = RealmConfig.Realms.greek
	local m = K.model("Aeloria", parent)
	local function at(x: number, z: number, y: number?): Vector3
		return origin + Vector3.new(x, y or 0, z)
	end
	local T = workspace.Terrain
	local half = realm.half

	-- Island terrain: sea, sand beach, grass top at y = 0, rocky cliffs around.
	pcall(function()
		T:FillBlock(CFrame.new(at(0, 0, -7)), Vector3.new(half * 2 + 400, 12, half * 2 + 400), Enum.Material.Water)
		T:FillBlock(CFrame.new(at(0, 0, -20)), Vector3.new(half * 2 + 400, 14, half * 2 + 400), Enum.Material.Sand)
		T:FillCylinder(CFrame.new(at(0, 0, -6)), 12, half + 15, Enum.Material.Sand)
		T:FillCylinder(CFrame.new(at(0, 0, -6)), 12, half - 5, Enum.Material.Grass)
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2 + 0.3
			if i ~= 3 then -- leave the harbor side open
				T:FillBall(at(math.cos(a) * (half - 10), math.sin(a) * (half - 10), -12), rng:NextNumber(40, 60), Enum.Material.Rock)
			end
		end
		-- Sunken harbor basin.
		local h = realm.areas[4].center
		T:FillCylinder(CFrame.new(at(h[1], h[2], -3)), 8, 45, Enum.Material.Air)
		T:FillCylinder(CFrame.new(at(h[1], h[2], -6.5)), 3, 45, Enum.Material.Sand)
		T:FillCylinder(CFrame.new(at(h[1], h[2], -2.5)), 4, 45, Enum.Material.Water)
		-- Paved paths from the agora.
		for _, to in { realm.areas[2].center, realm.areas[3].center, realm.areas[4].center, realm.areas[5].center } do
			local a, b = at(0, 0, -1), at(to[1], to[2], -1)
			local len = (b - a).Magnitude
			T:FillBlock(CFrame.lookAt((a + b) / 2, b), Vector3.new(10, 2, len), Enum.Material.Limestone)
		end
	end)

	-- Agora: marble plaza, two stoas, statues, fountain.
	do
		local ag = K.model("Agora", m)
		local c = at(0, 0)
		K.part(ag, "Plaza", Vector3.new(96, 0.6, 96), CFrame.new(c + Vector3.new(0, 0.3, 0)), MARBLE_SHADE, Enum.Material.Marble)
		K.part(ag, "Inlay", Vector3.new(40, 0.62, 40), CFrame.new(c + Vector3.new(0, 0.31, 0)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(180, 160, 130), Enum.Material.Marble)
		for _, s in { -1, 1 } do
			-- Stoa: a long colonnade with a roof.
			for i = -4, 4 do
				column(ag, c + Vector3.new(s * 42, 0.6, i * 9), 14, 1.8)
			end
			K.part(ag, "StoaRoof", Vector3.new(10, 1.2, 84), CFrame.new(c + Vector3.new(s * 44, 15.2, 0)), TERRACOTTA, Enum.Material.Slate)
			K.part(ag, "StoaWall", Vector3.new(1, 14, 84), CFrame.new(c + Vector3.new(s * 48, 7.6, 0)), MARBLE, Enum.Material.Marble)
			statue(ag, c + Vector3.new(s * 22, 0.6, -36), if s < 0 then 30 else -30, 1.1, Enum.Material.Marble, MARBLE)
			statue(ag, c + Vector3.new(s * 22, 0.6, 36), if s < 0 then 150 else -150, 1.1, Enum.Material.Metal, BRONZE)
		end
		-- Fountain.
		K.disc(ag, "FountainBasin", 16, 1.4, c + Vector3.new(0, 1.8, 0), MARBLE, Enum.Material.Marble)
		local water = K.disc(ag, "FountainWater", 14, 0.2, c + Vector3.new(0, 2, 0), Color3.fromRGB(80, 170, 190), Enum.Material.Glass)
		water.Transparency = 0.3
		water.CanCollide = false
		K.column(ag, "FountainPillar", 5, 1.6, c + Vector3.new(0, 1.8, 0), MARBLE, Enum.Material.Marble)
		local spout = K.decor(ag, "Spout", Vector3.new(1, 1, 1), CFrame.new(c + Vector3.new(0, 7.2, 0)), GOLD, Enum.Material.Neon, Enum.PartType.Ball)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
		e.Size = NumberSequence.new(0.4, 0.1)
		e.Lifetime = NumberRange.new(0.8, 1.2)
		e.Rate = 40
		e.Speed = NumberRange.new(6, 9)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = Vector3.new(0, -20, 0)
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = spout
		for i = 1, 8 do
			amphora(ag, c + Vector3.new(rng:NextNumber(-36, 36), 0.6, if i % 2 == 0 then 44 else -44))
		end
	end

	-- Olive terraces: stepped stone walls with olive trees.
	do
		local ol = K.model("OliveTerraces", m)
		local c = realm.areas[2].center
		for t = 0, 2 do
			local z = c[2] - 30 + t * 30
			K.part(ol, "TerraceWall", Vector3.new(110, 2.2 + t, 2), CFrame.new(at(c[1], z, 1.1 + t * 0.5)), Color3.fromRGB(170, 160, 140), Enum.Material.Cobblestone)
			for i = -4, 4 do
				olive(ol, at(c[1] + i * 12 + rng:NextNumber(-3, 3), z + 10 + rng:NextNumber(-3, 3)), rng)
			end
		end
	end

	-- Theatre of Echoes: semicircular tiers facing a stage.
	do
		local th = K.model("Theatre", m)
		local c = realm.areas[3].center
		local stage = at(c[1], c[2] + 10)
		K.part(th, "Stage", Vector3.new(30, 1.4, 12), CFrame.new(stage + Vector3.new(0, 0.7, 0)), MARBLE_SHADE, Enum.Material.Marble)
		for i = -2, 2 do
			column(th, stage + Vector3.new(i * 7, 1.4, 6), 10, 1.4)
		end
		for row = 0, 7 do
			local r = 18 + row * 4.5
			local steps = 16 + row * 2
			for k = 0, steps do
				local a = math.rad(200 + k / steps * 140)
				local p = stage + Vector3.new(math.cos(a) * r, row * 1.4 + 0.7, math.sin(a) * r)
				K.part(th, "Seat", Vector3.new(4.6, 1.4 + row * 1.4, 4.4), CFrame.lookAt(p - Vector3.new(0, row * 0.7, 0), stage + Vector3.new(0, p.Y - row * 0.7, 0)), MARBLE, Enum.Material.Marble)
			end
		end
	end

	-- Sunken harbor: broken columns standing in water, a wrecked hull, a lighthouse.
	do
		local hb = K.model("SunkenHarbor", m)
		local c = realm.areas[4].center
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			column(hb, at(c[1] + math.cos(a) * 30, c[2] + math.sin(a) * 30, -5), 16, 2.2, true)
		end
		K.part(hb, "Hull", Vector3.new(10, 6, 30), CFrame.new(at(c[1] + 12, c[2] + 8, -2)) * CFrame.Angles(math.rad(10), math.rad(30), math.rad(25)), Color3.fromRGB(100, 75, 50), Enum.Material.WoodPlanks)
		K.column(hb, "Lighthouse", 34, 7, at(c[1] - 50, c[2] + 40, 0), MARBLE, Enum.Material.Marble)
		local fire = K.decor(hb, "LighthouseFire", Vector3.new(4, 4, 4), CFrame.new(at(c[1] - 50, c[2] + 40, 36)), Color3.fromRGB(255, 170, 60), Enum.Material.Neon, Enum.PartType.Ball)
		K.light(fire, Color3.fromRGB(255, 170, 60), 60, 2)
		local f = Instance.new("Fire")
		f.Size = 8
		f.Heat = 10
		f.Parent = fire
	end

	-- Temple of the Sun-Archon (boss), with a golden sun disc.
	do
		local c = realm.areas[5].center
		local tm = temple(m, at(c[1], c[2] - 30), 34, 50, 18, 0)
		local sun = K.decor(tm, "SunDisc", Vector3.new(1, 14, 14), CFrame.new(at(c[1], c[2] - 30, 34)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Neon, Enum.PartType.Cylinder)
		K.light(sun, GOLD, 60, 2.5)
		for _, s in { -1, 1 } do
			statue(m, at(c[1] + s * 16, c[2] + 5), 180, 1.5, Enum.Material.Metal, BRONZE)
		end
	end

	-- Small temples and cliff shrines for the Oracle.
	temple(m, at(-70, 80), 14, 20, 10, 90)
	for i, p in AeloriaBuilder.ShrinePoints do
		local sh = K.model("OracleShrine" .. i, m)
		local base = at(p[1], p[2])
		K.part(sh, "ShrineFloor", Vector3.new(14, 1, 14), CFrame.new(base + Vector3.new(0, 0.5, 0)), MARBLE_SHADE, Enum.Material.Marble)
		for _, o in { { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } } do
			column(sh, base + Vector3.new(o[1], 1, o[2]), 9, 1.2)
		end
		K.part(sh, "ShrineRoof", Vector3.new(14, 1, 14), CFrame.new(base + Vector3.new(0, 10.5, 0)), MARBLE, Enum.Material.Marble)
		local flame = K.decor(sh, "SacredFlame", Vector3.new(1.4, 1.4, 1.4), CFrame.new(base + Vector3.new(0, 3.5, 0)), GOLD, Enum.Material.Neon, Enum.PartType.Ball)
		local f = Instance.new("Fire")
		f.Color = GOLD
		f.Size = 4
		f.Parent = flame
		K.light(flame, GOLD, 24, 1.6)
		K.part(sh, "Altar", Vector3.new(3, 2, 3), CFrame.new(base + Vector3.new(0, 2, 0)), MARBLE, Enum.Material.Marble)
	end

	-- Scattered cypress and olive trees across open ground.
	local placed, tries = 0, 0
	while placed < 70 and tries < 600 do
		tries += 1
		local x, z = rng:NextNumber(-half + 40, half - 40), rng:NextNumber(-half + 40, half - 40)
		local free = (Vector2.new(x, z)).Magnitude < half - 40
		for _, a in realm.areas do
			if (Vector2.new(x, z) - Vector2.new(a.center[1], a.center[2])).Magnitude < a.radius + 10 then
				free = false
			end
		end
		for _, p in AeloriaBuilder.ShrinePoints do
			if (Vector2.new(x, z) - Vector2.new(p[1], p[2])).Magnitude < 14 then
				free = false
			end
		end
		if free then
			placed += 1
			if rng:NextNumber() < 0.5 then
				cypress(m, at(x, z), rng)
			else
				olive(m, at(x, z), rng)
			end
		end
	end
	return m
end

return AeloriaBuilder
