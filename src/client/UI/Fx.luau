--!strict
-- Fx: client-side visual effects ("sauce") built only from engine features and Roblox's
-- built-in particle textures (rbxasset://), so nothing needs uploading.
-- Pure presentation; every function is fire-and-forget and cleans up after itself.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Fx = {}

Fx.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

export type BurstOpts = {
	texture: string?,
	color: Color3,
	count: number?,
	speed: number?,
	size: number?,
	lifetime: number?,
	spread: number?,
	lightEmission: number?,
	drag: number?,
	acceleration: Vector3?,
}

-- One-shot particle burst at a world position.
function Fx.Burst(position: Vector3, o: BurstOpts)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local p = Instance.new("ParticleEmitter")
	p.Texture = o.texture or Fx.Textures.Sparkle
	p.Color = ColorSequence.new(o.color)
	p.LightEmission = o.lightEmission or 1
	p.LightInfluence = 0
	local size = o.size or 0.6
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	local life = o.lifetime or 0.45
	p.Lifetime = NumberRange.new(life * 0.6, life)
	local speed = o.speed or 18
	p.Speed = NumberRange.new(speed * 0.5, speed)
	p.SpreadAngle = Vector2.new(o.spread or 180, o.spread or 180)
	p.Drag = o.drag or 4
	p.Acceleration = o.acceleration or Vector3.new(0, -10, 0)
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-200, 200)
	p.Enabled = false
	p.Parent = holder
	p:Emit(o.count or 16)
	Debris:AddItem(holder, life + 0.2)
end

function Fx.LightFlash(position: Vector3, color: Color3, range: number, seconds: number)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 6
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(seconds), { Brightness = 0 }):Play()
	Debris:AddItem(holder, seconds + 0.05)
end

local function neon(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	return p
end

-- A bright star flash (the "parry now" cue on enemy blades).
function Fx.Glint(position: Vector3, color: Color3)
	local cam = workspace.CurrentCamera
	local face = if cam then CFrame.lookAt(position, cam.CFrame.Position) else CFrame.new(position)
	for _, angle in { 0, 90 } do
		local ray = neon(Vector3.new(0.12, 0.12, 0.12), face * CFrame.Angles(0, 0, math.rad(angle)), color)
		TweenService:Create(ray, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.12, 2.6, 0.12) }):Play()
		TweenService:Create(ray, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.09), { Size = Vector3.new(0.02, 0.2, 0.02), Transparency = 1 }):Play()
		Debris:AddItem(ray, 0.3)
	end
	local core = neon(Vector3.new(0.5, 0.5, 0.5), CFrame.new(position), color, Enum.PartType.Ball)
	TweenService:Create(core, TweenInfo.new(0.25), { Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 }):Play()
	Debris:AddItem(core, 0.3)
	Fx.LightFlash(position, color, 14, 0.25)
end

-- Flat expanding ring on the ground (posture breaks, ultimates, boss slams).
function Fx.Shockwave(position: Vector3, color: Color3, radius: number, seconds: number?)
	local t = seconds or 0.35
	local ring = neon(Vector3.new(0.2, 1, 1), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, t + 0.05)
end

-- Tall column of light (level up, rare hatches).
function Fx.Pillar(position: Vector3, color: Color3, height: number?)
	local h = height or 30
	local col = neon(Vector3.new(h, 3, 3), CFrame.new(position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	col.Transparency = 0.3
	TweenService:Create(col, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(h, 0.2, 0.2), Transparency = 1 }):Play()
	Debris:AddItem(col, 1.2)
	Fx.Burst(position + Vector3.new(0, 2, 0), { color = color, count = 40, speed = 14, size = 0.8, lifetime = 1.2, acceleration = Vector3.new(0, 8, 0) })
end

-- Fades a dead model out with rising embers.
function Fx.Dissolve(model: Model, color: Color3, seconds: number)
	local center = model:GetPivot().Position
	Fx.Burst(center, { texture = Fx.Textures.Fire, color = color, count = 30, speed = 6, size = 1.2, lifetime = 1.2, acceleration = Vector3.new(0, 6, 0) })
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			TweenService:Create(d, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		elseif d:IsA("Decal") then
			TweenService:Create(d, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		end
	end
end

local flashGui: ScreenGui? = nil
-- Full-screen color flash (parry, ultimate). alpha = peak opacity (0..1).
function Fx.ScreenFlash(color: Color3, alpha: number, seconds: number)
	if flashGui == nil then
		local g = Instance.new("ScreenGui")
		g.Name = "FxFlash"
		g.IgnoreGuiInset = true
		g.DisplayOrder = 50
		g.ResetOnSpawn = false
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		flashGui = g
	end
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - alpha
	f.BorderSizePixel = 0
	f.Parent = flashGui
	TweenService:Create(f, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(f, seconds + 0.05)
end

-- Quick field-of-view kick for impact (always returns to the first-seen FOV, so rapid
-- punches cannot drift the camera).
local baseFov: number? = nil
function Fx.CameraPunch(amount: number)
	local cam = workspace.CurrentCamera
	if cam == nil then
		return
	end
	if baseFov == nil then
		baseFov = cam.FieldOfView
	end
	local base = baseFov :: number
	cam.FieldOfView = base + amount
	TweenService:Create(cam, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base }):Play()
end

return Fx
