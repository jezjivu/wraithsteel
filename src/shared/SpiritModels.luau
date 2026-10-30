--!strict
-- SpiritModels: part-built companion models for Spirits (no uploaded assets), from
-- SpiritConfig visual data + mutation look + rarity. Model faces -Z with its pivot at the body
-- center. Parts tagged with attribute "Flap" (=-1/1, wings) or "Tail" (=1) are animated by
-- SpiritFollowerController. Used for followers, lantern hatch reveals and inventory icons.
-- TODO(Studio/Agent B): replace with sculpted Spirit models (SpiritDef.modelId).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpiritConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SpiritConfig"))

local SpiritModels = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

type Ctx = { model: Model, body: Color3, accent: Color3, size: number, features: { string } }

local function part(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size * ctx.size
	p.CFrame = CFrame.new(cf.Position * ctx.size) * cf.Rotation
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = ctx.model
	return p
end

local function wedge(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size * ctx.size
	w.CFrame = CFrame.new(cf.Position * ctx.size) * cf.Rotation
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.CastShadow = false
	w.Parent = ctx.model
	return w
end

local function eyes(ctx: Ctx, z: number, y: number, spread: number)
	for _, side in { -1, 1 } do
		part(ctx, "Eye", Vector3.new(0.12, 0.12, 0.05), CFrame.new(side * spread, y, z), ctx.accent, Enum.Material.Neon)
	end
end

local shapes: { [string]: (Ctx) -> BasePart } = {}

shapes.Winged = function(ctx)
	local body = part(ctx, "Body", Vector3.new(0.55, 0.55, 1.1), CFrame.new(), ctx.body, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(ctx, "Head", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 0.12, -0.6), ctx.body, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	eyes(ctx, -0.8, 0.2, 0.12)
	wedge(ctx, "Beak", Vector3.new(0.1, 0.12, 0.25), CFrame.new(0, 0.08, -0.92) * CFrame.Angles(0, math.rad(180), 0), ctx.accent)
	for _, side in { -1, 1 } do
		local wing = part(ctx, "Wing", Vector3.new(1.3, 0.06, 0.8), CFrame.new(side * 0.85, 0.12, 0), ctx.body:Lerp(ctx.accent, 0.35), Enum.Material.SmoothPlastic)
		wing:SetAttribute("Flap", side)
		local tip = part(ctx, "WingTip", Vector3.new(0.35, 0.07, 0.5), CFrame.new(side * 1.45, 0.12, 0.05), ctx.accent, Enum.Material.Neon)
		tip:SetAttribute("Flap", side)
	end
	local tail = wedge(ctx, "Tail", Vector3.new(0.3, 0.08, 0.5), CFrame.new(0, 0, 0.75), ctx.accent)
	tail:SetAttribute("Tail", 1)
	return body
end

shapes.Beast = function(ctx)
	local f: { [string]: boolean } = {}
	for _, name in ctx.features do
		f[name] = true
	end
	local dark = ctx.body:Lerp(Color3.new(0, 0, 0), 0.25)
	if f.Toad then
		-- Wide, low, big-eyed.
		local body = part(ctx, "Body", Vector3.new(1.1, 0.55, 1.0), CFrame.new(0, -0.1, 0), ctx.body)
		part(ctx, "Head", Vector3.new(0.9, 0.4, 0.5), CFrame.new(0, 0.05, -0.6), ctx.body)
		for _, side in { -1, 1 } do
			part(ctx, "EyeBulb", Vector3.new(0.3, 0.3, 0.3), CFrame.new(side * 0.3, 0.32, -0.62), ctx.body, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			part(ctx, "Eye", Vector3.new(0.14, 0.14, 0.14), CFrame.new(side * 0.3, 0.36, -0.76), ctx.accent, Enum.Material.Neon, Enum.PartType.Ball)
			part(ctx, "Leg", Vector3.new(0.35, 0.2, 0.45), CFrame.new(side * 0.55, -0.35, 0.25), dark)
		end
		part(ctx, "Cap", Vector3.new(0.8, 0.15, 0.7), CFrame.new(0, 0.25, 0.05), ctx.accent, Enum.Material.Neon)
		return body
	end
	local body = part(ctx, "Body", Vector3.new(0.75, 0.6, 1.2), CFrame.new(), ctx.body)
	part(ctx, "Head", Vector3.new(0.6, 0.55, 0.55), CFrame.new(0, 0.3, -0.75), ctx.body)
	part(ctx, "Snout", Vector3.new(0.3, 0.22, 0.25), CFrame.new(0, 0.2, -1.1), ctx.accent)
	eyes(ctx, -1.03, 0.4, 0.15)
	for _, side in { -1, 1 } do
		if f.Ears then
			wedge(ctx, "Ear", Vector3.new(0.12, 0.3, 0.2), CFrame.new(side * 0.2, 0.7, -0.7), ctx.accent)
		end
		if f.Horns then
			part(ctx, "Horn", Vector3.new(0.09, 0.45, 0.09), CFrame.new(side * 0.15, 0.8, -0.8) * CFrame.Angles(math.rad(-25), 0, math.rad(-12 * side)), ctx.accent, Enum.Material.Neon)
		end
		if f.Tusks then
			part(ctx, "Tusk", Vector3.new(0.07, 0.07, 0.3), CFrame.new(side * 0.12, 0.12, -1.25) * CFrame.Angles(math.rad(30), 0, 0), Color3.fromRGB(240, 235, 220))
		end
		for _, z in { -0.4, 0.4 } do
			part(ctx, "Leg", Vector3.new(0.18, 0.4, 0.18), CFrame.new(side * 0.25, -0.45, z), dark)
		end
	end
	if f.Scales then
		for i = 0, 3 do
			part(ctx, "Scale", Vector3.new(0.85, 0.12, 0.28), CFrame.new(0, 0.32, -0.4 + i * 0.28) * CFrame.Angles(math.rad(-15), 0, 0), ctx.body:Lerp(ctx.accent, 0.3), Enum.Material.Metal)
		end
	end
	if f.Mane then
		part(ctx, "Mane", Vector3.new(0.7, 0.35, 0.3), CFrame.new(0, 0.55, -0.45), ctx.accent, Enum.Material.Neon)
	end
	local tailSize = if f.BushyTail then Vector3.new(0.32, 0.32, 0.8) else Vector3.new(0.14, 0.14, 0.5)
	local tail = part(ctx, "Tail", tailSize, CFrame.new(0, 0.2, 0.9) * CFrame.Angles(math.rad(25), 0, 0), ctx.accent, Enum.Material.Neon)
	tail:SetAttribute("Tail", 1)
	return body
end

shapes.Fish = function(ctx)
	local body = part(ctx, "Body", Vector3.new(0.5, 0.75, 1.3), CFrame.new(), ctx.body, Enum.Material.Metal)
	part(ctx, "Belly", Vector3.new(0.45, 0.25, 1.0), CFrame.new(0, -0.3, 0), ctx.accent, Enum.Material.SmoothPlastic)
	eyes(ctx, -0.55, 0.15, 0.26)
	local tail = wedge(ctx, "TailFin", Vector3.new(0.06, 0.8, 0.55), CFrame.new(0, 0, 0.9), ctx.accent, Enum.Material.Neon)
	tail:SetAttribute("Tail", 1)
	wedge(ctx, "Dorsal", Vector3.new(0.05, 0.35, 0.6), CFrame.new(0, 0.5, 0.1), ctx.accent, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		local fin = part(ctx, "Fin", Vector3.new(0.35, 0.05, 0.25), CFrame.new(side * 0.35, -0.1, -0.2), ctx.accent)
		fin:SetAttribute("Flap", side)
	end
	return body
end

shapes.Wraith = function(ctx)
	local body = part(ctx, "Robe", Vector3.new(1.2, 0.9, 0.9), CFrame.new(0, -0.1, 0), ctx.body, Enum.Material.Fabric)
	part(ctx, "RobeLow", Vector3.new(0.9, 0.7, 0.7), CFrame.new(0, -0.8, 0.05), ctx.body:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Fabric)
	part(ctx, "Hood", Vector3.new(0.75, 0.7, 0.75), CFrame.new(0, 0.65, -0.05), ctx.body, Enum.Material.Fabric)
	part(ctx, "Face", Vector3.new(0.5, 0.45, 0.05), CFrame.new(0, 0.6, -0.42), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	eyes(ctx, -0.45, 0.65, 0.12)
	part(ctx, "BellCore", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, -0.05, -0.47), ctx.accent, Enum.Material.Neon, Enum.PartType.Ball)
	for i, side in { -1, 1, -1 } do
		local strip = part(ctx, "Tatter", Vector3.new(0.2, 0.7, 0.05), CFrame.new(side * 0.25 * i, -1.35, 0.1), ctx.accent:Lerp(ctx.body, 0.5), Enum.Material.Neon)
		strip:SetAttribute("Tail", 1)
	end
	return body
end

-- Particle aura per Spirit (built-in rbxasset textures only).
local AURA_TEXTURE = {
	Embers = "rbxasset://textures/particles/fire_main.dds",
	Sparks = "rbxasset://textures/particles/sparkles_main.dds",
	Mist = "rbxasset://textures/particles/smoke_main.dds",
	Leaves = "rbxasset://textures/particles/sparkles_main.dds",
	Bubbles = "rbxasset://textures/particles/sparkles_main.dds",
	Void = "rbxasset://textures/particles/smoke_main.dds",
	Glimmer = "rbxasset://textures/particles/sparkles_main.dds",
}

local function aura(core: BasePart, kind: string, color: Color3, size: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura"
	e.Texture = AURA_TEXTURE[kind] or AURA_TEXTURE.Glimmer
	e.Color = ColorSequence.new(color)
	e.LightEmission = if kind == "Void" then 0.2 else 1
	e.LightInfluence = 0
	local s = if kind == "Mist" or kind == "Void" then 0.9 else 0.22
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, if kind == "Mist" or kind == "Void" then 0.6 else 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Rate = if kind == "Mist" or kind == "Void" then 8 else 14
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = if kind == "Embers" or kind == "Sparks" then Vector3.new(0, 3, 0) elseif kind == "Leaves" then Vector3.new(0, -2, 0) else Vector3.zero
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = core
end

local function crest(ctx: Ctx, kind: string)
	if kind == "Halo" then
		local ring = part(ctx, "Halo", Vector3.new(0.08, 1.1, 1.1), CFrame.new(0, 1.05, 0.1) * CFrame.Angles(0, 0, math.rad(90)), ctx.accent, Enum.Material.Neon, Enum.PartType.Cylinder)
		ring.Transparency = 0.25
		ring:SetAttribute("Spin", 1)
	elseif kind == "Crown" then
		for i = -1, 1 do
			local spike = wedge(ctx, "Crown", Vector3.new(0.08, 0.32, 0.14), CFrame.new(i * 0.18, 0.95, -0.15) * CFrame.Angles(0, 0, math.rad(i * -15)), ctx.accent, Enum.Material.Neon)
			spike.Transparency = 0.05
		end
	elseif kind == "Flame" then
		local f = wedge(ctx, "Flame", Vector3.new(0.12, 0.45, 0.25), CFrame.new(0, 0.8, -0.1), Color3.fromRGB(255, 200, 90), Enum.Material.Neon)
		f:SetAttribute("Tail", 1)
	elseif kind == "Orbit" then
		for i = 1, 2 do
			local orb = part(ctx, "Orbit", Vector3.new(0.2, 0.2, 0.2), CFrame.new(if i == 1 then 0.9 else -0.9, 0.2, 0), ctx.accent, Enum.Material.Neon, Enum.PartType.Ball)
			orb:SetAttribute("Orbit", i)
		end
	end
end

-- Builds a companion model. Returns nil for unknown spirits.
function SpiritModels.Build(spiritId: string, mutation: string?, rarity: string?): Model?
	local def = SpiritConfig.Spirits[spiritId]
	if def == nil then
		return nil
	end
	local v = def.visual
	local model = Instance.new("Model")
	model.Name = def.name
	local bodyColor = rgb(v.color)
	local accent = rgb(v.accent)
	local mlook = mutation and SpiritConfig.MutationLooks[mutation]
	if mlook then
		bodyColor = bodyColor:Lerp(rgb(mlook.tint), mlook.tintAmount)
		accent = rgb(mlook.glow)
	end
	local ctx: Ctx = { model = model, body = bodyColor, accent = accent, size = v.size, features = v.features or {} }
	local build = shapes[v.shape] or shapes.Beast
	local core = build(ctx)
	model.PrimaryPart = core

	local light = Instance.new("PointLight")
	light.Color = accent
	light.Range = 7
	light.Brightness = 1.2
	light.Parent = core

	-- Rarity gem floating above Rare-and-better Spirits.
	local r = SpiritConfig.Rarities[rarity or def.rarity]
	if r and r.order >= 3 and r.color then
		local gem = part(ctx, "RarityGem", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 1.15, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), r.color, Enum.Material.Neon)
		gem.Transparency = 0.1
	end
	if v.aura then
		aura(core, v.aura, accent, v.size)
	end
	if v.crest then
		crest(ctx, v.crest)
	end
	-- Legendary and better leave a glowing streak as they fly.
	if r and r.order >= 5 then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.25 * v.size, 0)
		a0.Parent = core
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.25 * v.size, 0)
		a1.Parent = core
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(accent)
		trail.LightEmission = 1
		trail.Lifetime = 0.35
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.FaceCamera = true
		trail.Parent = core
	end
	model:SetAttribute("SpiritId", spiritId)
	model:SetAttribute("Accent", accent)
	return model
end

return SpiritModels
