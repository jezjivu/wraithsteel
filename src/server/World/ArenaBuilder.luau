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

function ArenaBuilder.Build(center: Vector3, theme: { floor: { number }, wall: { number }, accent: { number } }): Model
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
	m:SetAttribute("Radius", R)
	return m
end

return ArenaBuilder
