--!strict
-- ArenaBuilder: builds a closed, circular boss arena (floor, rune ring, wall ring with pillars,
-- braziers, banners) at a given center. Pure Instance construction, no services.
--
-- API:
--   ArenaBuilder.Build(center: Vector3, theme) -> Model

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ArenaConfig"))

local ArenaBuilder = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function fire(p: BasePart, color: Color3)
	local f = Instance.new("Fire")
	f.Color = color
	f.SecondaryColor = Color3.new(1, 0.9, 0.6)
	f.Heat = 9
	f.Size = 5
	f.Parent = p
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 26
	l.Brightness = 2
	l.Parent = p
end

-- Foundry layout: a ruined bell foundry. Cover pillars to hide from rockets and
-- lasers, molten channels in the floor, steam vents, pipes on the walls, the cracked bell.
local function foundry(m: Model, center: Vector3, R: number, accent: Color3)
	local steel = Color3.fromRGB(70, 68, 72)
	-- Cover: eight thick pillars (half of them broken short) in a ring.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		local p = center + Vector3.new(math.cos(a) * R * 0.55, 0, math.sin(a) * R * 0.55)
		local h = if i % 2 == 0 then 22 else 9
		part(m, "CoverPillar", Vector3.new(6, h, 6), CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, a, 0), steel, Enum.Material.CorrodedMetal)
		part(m, "PillarBand", Vector3.new(6.4, 0.8, 6.4), CFrame.new(p + Vector3.new(0, h - 1.5, 0)) * CFrame.Angles(0, a, 0), accent, Enum.Material.Neon).CanCollide = false
	end
	-- Molten channels crossing the floor (just glowing; safe to walk on).
	for i = 0, 2 do
		local cf = CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.rad(60 * i + 15), 0)
		local lava = part(m, "MoltenChannel", Vector3.new(2.4, 0.1, R * 1.7), cf, Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
		lava.CanCollide = false
		lava.Transparency = 0.1
	end
	-- Steam vents.
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * R * 0.82, 0.3, math.sin(a) * R * 0.82)
		local grate = part(m, "Vent", Vector3.new(5, 0.4, 5), CFrame.new(p), Color3.fromRGB(40, 40, 44), Enum.Material.DiamondPlate)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(230, 230, 230))
		e.Transparency = NumberSequence.new(0.6, 1)
		e.Size = NumberSequence.new(2, 7)
		e.Lifetime = NumberRange.new(2, 3.5)
		e.Rate = 8
		e.Speed = NumberRange.new(6, 10)
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = grate
	end
	-- Pipes along the wall and the giant cracked bell behind the boss.
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * (R + 1.5), 14, math.sin(a) * (R + 1.5))
		part(m, "Pipe", Vector3.new(20, 2.2, 2.2), CFrame.lookAt(p, center + Vector3.new(0, 14, 0)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(110, 80, 50), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	end
	local bellPos = center + Vector3.new(0, 0, -R * 0.82)
	local bell = part(m, "CrackedBell", Vector3.new(20, 18, 18), CFrame.new(bellPos + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(130, 95, 50), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	local crack = part(m, "BellCrack", Vector3.new(0.5, 18, 1), bell.CFrame * CFrame.new(0, 0, 8.8), accent, Enum.Material.Neon)
	crack.CanCollide = false
	local l = Instance.new("PointLight")
	l.Color = accent
	l.Range = 50
	l.Brightness = 2
	l.Parent = crack
end

-- Courtyard layout: a moonlit courtyard. Sakura ring, stone lanterns, a broken torii, a moon.
local function courtyard(m: Model, center: Vector3, R: number, accent: Color3)
	local wood = Color3.fromRGB(60, 40, 32)
	local pink = Color3.fromRGB(255, 180, 205)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.3
		local p = center + Vector3.new(math.cos(a) * R * 0.85, 0, math.sin(a) * R * 0.85)
		part(m, "Trunk", Vector3.new(11, 1.6, 1.6), CFrame.new(p + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, a, math.rad(90)), wood, Enum.Material.Wood, Enum.PartType.Cylinder)
		for k = 1, 4 do
			local off = Vector3.new(math.cos(k * 1.7) * 3, 11 + (k % 2) * 2, math.sin(k * 1.7) * 3)
			local c = part(m, "Blossom", Vector3.new(7, 5.5, 7), CFrame.new(p + off), pink, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			c.CanCollide = false
		end
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * R * 0.6, 0, math.sin(a) * R * 0.6)
		part(m, "LanternBase", Vector3.new(2.4, 4, 2.4), CFrame.new(p + Vector3.new(0, 2, 0)), Color3.fromRGB(150, 146, 138), Enum.Material.Slate)
		local box = part(m, "LanternLight", Vector3.new(1.6, 1.6, 1.6), CFrame.new(p + Vector3.new(0, 4.8, 0)), Color3.fromRGB(255, 190, 110), Enum.Material.Neon)
		box.CanCollide = false
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 180, 100)
		l.Range = 20
		l.Brightness = 1.2
		l.Parent = box
		part(m, "LanternRoof", Vector3.new(3.2, 0.6, 3.2), CFrame.new(p + Vector3.new(0, 5.9, 0)), Color3.fromRGB(150, 146, 138), Enum.Material.Slate)
	end
	-- Broken torii at the back.
	local back = center + Vector3.new(0, 0, -R * 0.78)
	for _, x in { -11, 11 } do
		local h = if x < 0 then 20 else 12
		part(m, "ToriiPillar", Vector3.new(h, 2, 2), CFrame.new(back + Vector3.new(x, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 40, 30), Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	part(m, "ToriiBeam", Vector3.new(30, 1.6, 2.2), CFrame.new(back + Vector3.new(-2, 19, 0)) * CFrame.Angles(0, 0, math.rad(-14)), Color3.fromRGB(30, 25, 25), Enum.Material.Wood)
	-- A huge moon in the sky.
	local moon = part(m, "Moon", Vector3.new(1, 60, 60), CFrame.new(center + Vector3.new(0, 120, -260)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 235, 225), Enum.Material.Neon, Enum.PartType.Cylinder)
	moon.CanCollide = false
	-- Falling petals over the whole courtyard.
	local sky = part(m, "PetalSky", Vector3.new(R * 2, 1, R * 2), CFrame.new(center + Vector3.new(0, 30, 0)), pink, Enum.Material.SmoothPlastic)
	sky.Transparency = 1
	sky.CanCollide = false
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(pink)
	e.Size = NumberSequence.new(0.5, 0.3)
	e.Lifetime = NumberRange.new(8, 12)
	e.Rate = 30
	e.Speed = NumberRange.new(1, 2)
	e.Acceleration = Vector3.new(1.5, -2.5, 0.5)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Parent = sky
	local _ = accent
end

function ArenaBuilder.Build(center: Vector3, theme: { floor: { number }, wall: { number }, accent: { number }, layout: string? }): Model
	local m = Instance.new("Model")
	m.Name = "BossArena"
	local R = ArenaConfig.Radius
	local H = ArenaConfig.WallHeight
	local floor, wall, accent = rgb(theme.floor), rgb(theme.wall), rgb(theme.accent)
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X

	-- Floor: big stone disc + inner pattern + glowing rune ring.
	part(m, "Floor", Vector3.new(6, (R + 12) * 2, (R + 12) * 2), CFrame.new(center - Vector3.new(0, 3, 0)) * up, floor, Enum.Material.Slate, Enum.PartType.Cylinder)
	local ring = part(m, "RuneRing", Vector3.new(0.1, R * 1.16, R * 1.16), CFrame.new(center + Vector3.new(0, 0.05, 0)) * up, accent, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.3
	ring.CanCollide = false
	local inner = part(m, "Inner", Vector3.new(0.1, R * 1.1, R * 1.1), CFrame.new(center + Vector3.new(0, 0.1, 0)) * up, floor:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Cobblestone, Enum.PartType.Cylinder)
	inner.CanCollide = false
	-- Cross paths on the floor.
	for i = 0, 3 do
		local cf = CFrame.new(center + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, math.rad(45 * i), 0)
		local strip = part(m, "FloorLine", Vector3.new(1.2, 0.1, R * 2), cf * CFrame.new(0, 0.15, 0), accent, Enum.Material.Neon)
		strip.Transparency = 0.6
		strip.CanCollide = false
	end

	-- Wall ring: segments + pillars with braziers, banners between.
	local segments = 32
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = center + dir * (R + 4) + Vector3.new(0, H / 2, 0)
		local segLen = 2 * math.pi * (R + 4) / segments + 1
		part(m, "Wall", Vector3.new(segLen, H, 4), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0), wall, Enum.Material.Slate)
		if i % 4 == 0 then
			local pp = center + dir * (R + 1)
			part(m, "Pillar", Vector3.new(H + 6, 5, 5), CFrame.new(pp + Vector3.new(0, (H + 6) / 2, 0)) * up, wall:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Basalt, Enum.PartType.Cylinder)
			local bowl = part(m, "Brazier", Vector3.new(2, 4, 4), CFrame.new(pp + Vector3.new(0, H + 7, 0)) * up, Color3.fromRGB(60, 50, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
			fire(bowl, accent)
		elseif i % 4 == 2 then
			local bp = center + dir * (R + 1.8) + Vector3.new(0, H * 0.55, 0)
			local banner = part(m, "Banner", Vector3.new(6, H * 0.6, 0.3), CFrame.lookAt(bp, bp - dir), accent:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Fabric)
			banner.CanCollide = false
		end
	end
	-- Invisible ceiling-high barrier so nobody double-jumps out.
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = center + dir * (R + 6) + Vector3.new(0, H + 40, 0)
		local barrier = part(m, "Barrier", Vector3.new(2 * math.pi * (R + 6) / 16 + 2, 80, 2), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0), wall, Enum.Material.ForceField)
		barrier.Transparency = 1
	end
	-- Central glow so the arena reads at night.
	local glow = part(m, "CenterGlow", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 30, 0)), accent, Enum.Material.Neon)
	glow.Transparency = 1
	glow.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.new(1, 0.95, 0.85)
	light.Range = 60
	light.Brightness = 1.2
	light.Parent = glow
	-- Drifting embers.
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(accent)
	e.LightEmission = 0.8
	e.Size = NumberSequence.new(0.3, 0)
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = 25
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	local sky = part(m, "EmberSky", Vector3.new(R * 2, 1, R * 2), CFrame.new(center + Vector3.new(0, 4, 0)), accent, Enum.Material.SmoothPlastic)
	sky.Transparency = 1
	sky.CanCollide = false
	sky.CanQuery = false
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = sky
	if theme.layout == "Foundry" then
		foundry(m, center, R, accent)
	elseif theme.layout == "Courtyard" then
		courtyard(m, center, R, accent)
	end
	m:SetAttribute("Radius", R)
	return m
end

return ArenaBuilder
