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

-- Brief color-grade pulse (desaturate + contrast), e.g. the perfect-parry "time stop" look.
function Fx.ColorPulse(saturation: number, contrast: number, tint: Color3, seconds: number)
	local Lighting = game:GetService("Lighting")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = saturation
	cc.Contrast = contrast
	cc.TintColor = tint
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Saturation = 0,
		Contrast = 0,
		TintColor = Color3.new(1, 1, 1),
	}):Play()
	Debris:AddItem(cc, seconds + 0.05)
end

local overlay: ScreenGui? = nil
local function overlayGui(): ScreenGui
	if overlay == nil then
		local g = Instance.new("ScreenGui")
		g.Name = "FxOverlay"
		g.IgnoreGuiInset = true
		g.DisplayOrder = 45
		g.ResetOnSpawn = false
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		overlay = g
	end
	return overlay :: ScreenGui
end

-- Radial speed streaks bursting from the screen center.
function Fx.Streaks(color: Color3, count: number?, seconds: number?)
	local g = overlayGui()
	local t = seconds or 0.35
	for i = 1, count or 18 do
		local angle = (i / (count or 18)) * 360 + math.random(-6, 6)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.new(0.05, 0, 0, math.random(2, 4))
		line.Rotation = angle
		line.BackgroundColor3 = color
		line.BorderSizePixel = 0
		line.Parent = g
		local grad = Instance.new("UIGradient")
		grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.1), NumberSequenceKeypoint.new(1, 1) })
		grad.Parent = line
		-- Lines slide outward along their angle.
		local rad = math.rad(angle)
		local dx, dy = math.cos(rad) * 0.45, math.sin(rad) * 0.45
		TweenService:Create(line, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5 + dx * 0.6, 0.5 + dy * 0.6),
			Size = UDim2.new(0.22, 0, 0, 1),
			BackgroundTransparency = 1,
		}):Play()
		Debris:AddItem(line, t + 0.05)
	end
end

-- Big stamped word in the middle of the screen (DEFLECT, RIPOSTE...).
function Fx.CenterText(text: string, color: Color3, size: number, seconds: number)
	local g = overlayGui()
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.36)
	l.Size = UDim2.new(1, 0, 0, size + 10)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Antique
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0.2
	l.Text = text
	l.Parent = g
	local scale = Instance.new("UIScale")
	scale.Scale = 1.6
	scale.Parent = l
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(l, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, seconds), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(l, seconds + 0.35)
end

-- Quick field-of-view kick for impact (always returns to the first-seen FOV, so rapid
-- punches cannot drift the camera).
local baseFov: number? = nil
-- The FOV punches return to (sprinting raises it).
function Fx.SetBaseFov(fov: number)
	baseFov = fov
end
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
