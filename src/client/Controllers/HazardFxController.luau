--!strict
-- HazardFxController: draws HazardService attacks (client only, the server decides hits).
--   HazardProjectile: glowing orb flying in a straight line (deflectable orbs pulse gold -
--                     tap F as it reaches you to send it back)
--   HazardEnd:        orb impact / block / reflect / fizzle burst
--   HazardWave:       expanding ground ring with a wall of light (jump it)
--   HazardRain:       red warning circles, then eruptions (get out)
--   Returned:         "RETURNED!" cue when you deflect an orb back

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage:WaitForChild("Config")
local EffectsConfig = require(Config:WaitForChild("EffectsConfig"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Fx = require(UI:WaitForChild("Fx"))
local SpellFx = require(UI:WaitForChild("SpellFx"))
local CombatController = require(script.Parent.CombatController)
local EffectsController = require(script.Parent.EffectsController)

local HazardFxController = { Name = "HazardFxController", Priority = 52 }

local function rgb(c: any): Color3
	if type(c) == "table" then
		return Color3.fromRGB(c[1] or 255, c[2] or 255, c[3] or 255)
	end
	return Color3.fromRGB(255, 140, 60)
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

type Orb = { part: Part, core: Part, from: Vector3, vel: Vector3, start: number, range: number, deflectable: boolean }
local orbs: { [number]: Orb } = {}

local function onProjectile(e: { [string]: any })
	local from: Vector3 = e.from
	local vel: Vector3 = e.velocity
	local color = rgb(e.color)
	local size = tonumber(e.size) or 2
	local orb = neon(Vector3.new(size, size, size), CFrame.new(from), color, Enum.PartType.Ball)
	orb.Transparency = 0.15
	local core = neon(Vector3.new(size * 0.5, size * 0.5, size * 0.5), CFrame.new(from), Color3.new(1, 1, 1), Enum.PartType.Ball)
	local att = Instance.new("Attachment")
	att.Parent = orb
	local tail = Instance.new("ParticleEmitter")
	tail.Texture = Fx.Textures.Fire
	tail.Color = ColorSequence.new(color)
	tail.LightEmission = 1
	tail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	tail.Transparency = NumberSequence.new(0.2, 1)
	tail.Lifetime = NumberRange.new(0.25, 0.4)
	tail.Rate = 60
	tail.Speed = NumberRange.new(0, 1)
	tail.Parent = att
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 3
	light.Parent = orb
	if e.deflectable and not e.reflected then
		-- Deflectable: gold ring around it so players learn "this one goes back".
		local ring = Instance.new("SelectionSphere")
		ring.Adornee = orb
		ring.Color3 = Color3.fromRGB(255, 225, 120)
		ring.SurfaceTransparency = 1
		ring.Transparency = 0
		ring.Parent = orb
	end
	orbs[e.id] = { part = orb, core = core, from = from, vel = vel, start = os.clock(), range = tonumber(e.range) or 80, deflectable = e.deflectable == true }
	Fx.Burst(from, { texture = Fx.Textures.Fire, color = color, count = 14, speed = 14, size = 1.2, lifetime = 0.3 })
	SpellFx.Sound(EffectsConfig.Sounds.cast, from, if e.reflected then 1.6 else 0.7, 0.6)
end

local function onEnd(e: { [string]: any })
	local o = orbs[e.id]
	orbs[e.id] = nil
	local pos: Vector3 = if typeof(e.pos) == "Vector3" then e.pos elseif o then o.part.Position else Vector3.zero
	local color = rgb(e.color)
	if o then
		o.part:Destroy()
		o.core:Destroy()
	end
	if e.how == "Fizzle" then
		Fx.Burst(pos, { color = color, count = 10, speed = 8, size = 0.6, lifetime = 0.4 })
		return
	end
	if e.how == "Reflected" then
		Fx.Glint(pos, Color3.fromRGB(255, 235, 170))
		Fx.Shockwave(pos, Color3.fromRGB(255, 235, 170), 6, 0.25)
		SpellFx.Sound(EffectsConfig.Sounds.parry, pos, 1.4, 0.9)
		return
	end
	Fx.Burst(pos, { texture = Fx.Textures.Fire, color = color, count = 30, speed = 26, size = 1.4, lifetime = 0.5 })
	Fx.Burst(pos, { texture = Fx.Textures.Smoke, color = Color3.fromRGB(90, 70, 60), count = 12, speed = 10, size = 2.5, lifetime = 0.8, lightEmission = 0 })
	Fx.LightFlash(pos, color, 20, 0.3)
	SpellFx.Sound(EffectsConfig.Sounds.boom, pos, if e.how == "Blocked" then 1.6 else 1.1, 0.7)
end

local function onWave(e: { [string]: any })
	local origin: Vector3 = e.origin
	local speed = tonumber(e.speed) or 35
	local maxR = tonumber(e.maxRadius) or 50
	local color = rgb(e.color)
	-- A HOLLOW ring of glowing segments rolling outward (jump over it). It used to be a filled
	-- translucent disc, which read as a giant cylinder around the boss.
	local segments = 36
	local parts: { Part } = {}
	for k = 1, segments do
		local seg = neon(Vector3.new(1, 3, 0.8), CFrame.new(origin), color)
		seg.Transparency = 0.15
		parts[k] = seg
	end
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local r = math.max(1, t * speed)
		if r > maxR then
			conn:Disconnect()
			for _, seg in parts do
				seg:Destroy()
			end
			return
		end
		local len = 2 * math.pi * r / segments + 0.4
		local fade = math.clamp((r / maxR - 0.7) / 0.3, 0, 1)
		for k, seg in parts do
			local a = k / segments * math.pi * 2
			local p = origin + Vector3.new(math.cos(a) * r, 1.5, math.sin(a) * r)
			seg.Size = Vector3.new(len, 3, 0.8)
			seg.CFrame = CFrame.lookAt(p, Vector3.new(origin.X, p.Y, origin.Z)) * CFrame.Angles(0, math.rad(90), 0)
			seg.Transparency = 0.15 + fade * 0.85
		end
	end)
	Fx.Burst(origin, { texture = Fx.Textures.Smoke, color = Color3.fromRGB(150, 120, 100), count = 30, speed = 30, size = 3, lifetime = 0.8, lightEmission = 0 })
	Fx.CameraPunch(4)
	SpellFx.Sound(EffectsConfig.Sounds.boom, origin, 0.6, 1)
end

local function onRain(e: { [string]: any })
	local color = rgb(e.color)
	local radius = tonumber(e.radius) or 7
	local delay = tonumber(e.delay) or 1
	for _, at in e.points or {} do
		if typeof(at) == "Vector3" then
			SpellFx.Telegraph(at, Color3.fromRGB(255, 50, 40), radius, delay)
			task.delay(delay, function()
				local g = SpellFx.Ground(at)
				-- Rust spikes burst out of the ground.
				for i = 1, 5 do
					local a = i / 5 * math.pi * 2
					local off = Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.45
					local spike = neon(Vector3.new(1.2, 0.5, 1.2), CFrame.new(g + off), color)
					spike.Material = Enum.Material.CorrodedMetal
					spike.Color = Color3.fromRGB(150, 80, 50)
					TweenService:Create(spike, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = Vector3.new(1.4, 7, 1.4), CFrame = CFrame.new(g + off + Vector3.new(0, 3.5, 0)) * CFrame.Angles(math.rad(math.random(-15, 15)), 0, math.rad(math.random(-15, 15))) }):Play()
					TweenService:Create(spike, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6), { Transparency = 1 }):Play()
					Debris:AddItem(spike, 1.2)
				end
				Fx.Burst(g, { texture = Fx.Textures.Fire, color = color, count = 24, speed = 24, size = 1.6, lifetime = 0.6, acceleration = Vector3.new(0, 10, 0) })
				Fx.Shockwave(g + Vector3.new(0, 0.2, 0), color, radius, 0.3)
				SpellFx.Sound(EffectsConfig.Sounds.boom, g, 1.3, 0.6)
			end)
		end
	end
end

function HazardFxController.Init() end

function HazardFxController.Start()
	CombatController.EventReceived:Connect(function(e)
		if e.kind == "HazardProjectile" then
			onProjectile(e)
		elseif e.kind == "HazardEnd" then
			onEnd(e)
		elseif e.kind == "HazardWave" then
			onWave(e)
		elseif e.kind == "HazardRain" then
			onRain(e)
		elseif e.kind == "Returned" then
			local model = EffectsController.ModelFor(e.targetId)
			if model and model == game:GetService("Players").LocalPlayer.Character then
				Fx.CenterText("RETURNED!", Color3.fromRGB(255, 225, 140), 56, 0.6)
				Fx.Streaks(Color3.fromRGB(255, 225, 140), 16, 0.3)
			end
		end
	end)
	-- Move orbs along their straight line (same path the server simulates).
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for id, o in orbs do
			local t = now - o.start
			local pos = o.from + o.vel * t
			if (pos - o.from).Magnitude > o.range * 2.2 then
				o.part:Destroy()
				o.core:Destroy()
				orbs[id] = nil
				continue
			end
			local pulse = if o.deflectable then 1 + math.sin(now * 14) * 0.12 else 1
			o.part.CFrame = CFrame.new(pos)
			o.core.CFrame = CFrame.new(pos)
			o.core.Size = Vector3.new(1, 1, 1) * (o.part.Size.X * 0.5 * pulse)
		end
	end)
end

return HazardFxController
