--!strict
-- SpellFx: visuals for Qi arts and Spirit abilities (client only, no uploaded assets).
-- Everything is neon parts, beams and built-in particles; each call cleans up after itself.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Fx = require(script.Parent:WaitForChild("Fx"))

local SpellFx = {}

-- One-shot positional sound.
function SpellFx.Sound(id: string, position: Vector3, pitch: number?, volume: number?)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = (pitch or 1) * (0.94 + math.random() * 0.12)
	s.RollOffMaxDistance = 140
	s.Parent = holder
	s:Play()
	Debris:AddItem(holder, 3)
end

local function neon(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	return p
end

local function tween(inst: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end

local function ground(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("World") or workspace.Terrain, workspace:FindFirstChild("Hub") or workspace.Terrain }
	local hit = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else pos - Vector3.new(0, 3, 0)
end
SpellFx.Ground = ground

-- Glowing orb flying from a to b over `seconds`, with a particle tail; bursts on arrival.
function SpellFx.Bolt(from: Vector3, to: Vector3, color: Color3, seconds: number, size: number?)
	local s = size or 1.2
	local orb = neon(Vector3.new(s, s, s), CFrame.new(from), color, Enum.PartType.Ball)
	local core = neon(Vector3.new(s * 0.5, s * 0.5, s * 0.5), CFrame.new(from), Color3.new(1, 1, 1), Enum.PartType.Ball)
	local att = Instance.new("Attachment")
	att.Parent = orb
	local tail = Instance.new("ParticleEmitter")
	tail.Texture = Fx.Textures.Fire
	tail.Color = ColorSequence.new(color)
	tail.LightEmission = 1
	tail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.9), NumberSequenceKeypoint.new(1, 0) })
	tail.Transparency = NumberSequence.new(0.2, 1)
	tail.Lifetime = NumberRange.new(0.2, 0.35)
	tail.Rate = 80
	tail.Speed = NumberRange.new(0, 1)
	tail.Parent = att
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 3
	light.Parent = orb
	local t = math.max(0.05, seconds)
	tween(orb, t, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
	tween(core, t, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
	task.delay(t, function()
		orb:Destroy()
		core:Destroy()
		Fx.Burst(to, { texture = Fx.Textures.Fire, color = color, count = 26, speed = 24, size = 1.4, lifetime = 0.45 })
		Fx.Burst(to, { color = Color3.new(1, 1, 1), count = 12, speed = 30, size = 0.4, lifetime = 0.3 })
		Fx.LightFlash(to, color, 18, 0.3)
	end)
end

-- Jagged lightning bolt between two points (segments of thin neon parts).
function SpellFx.Lightning(from: Vector3, to: Vector3, color: Color3, seconds: number?)
	local life = seconds or 0.25
	local segs = 7
	local prev = from
	for i = 1, segs do
		local t = i / segs
		local p = from:Lerp(to, t)
		if i < segs then
			p += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.4
		end
		local len = (p - prev).Magnitude
		local seg = neon(Vector3.new(0.22, 0.22, len), CFrame.lookAt((prev + p) / 2, p), color)
		local glow = neon(Vector3.new(0.6, 0.6, len), seg.CFrame, color)
		glow.Transparency = 0.7
		tween(seg, life, { Transparency = 1 })
		tween(glow, life, { Transparency = 1, Size = Vector3.new(1.2, 1.2, len) })
		Debris:AddItem(seg, life + 0.05)
		Debris:AddItem(glow, life + 0.05)
		prev = p
	end
	Fx.Burst(to, { color = color, count = 14, speed = 26, size = 0.4, lifetime = 0.3 })
	Fx.LightFlash(to, color, 16, 0.2)
end

-- Expanding sphere + ground ring (spirit novas, blasts).
function SpellFx.Nova(pos: Vector3, color: Color3, radius: number, seconds: number?)
	local t = seconds or 0.45
	local sphere = neon(Vector3.new(2, 2, 2), CFrame.new(pos), color, Enum.PartType.Ball, Enum.Material.ForceField)
	sphere.Transparency = 0.1
	tween(sphere, t, { Size = Vector3.new(radius * 2, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(sphere, t + 0.05)
	Fx.Shockwave(ground(pos) + Vector3.new(0, 0.2, 0), color, radius, t)
	Fx.Burst(pos, { color = color, count = 30, speed = radius * 2.2, size = 0.6, lifetime = 0.5, drag = 2, acceleration = Vector3.zero })
	Fx.LightFlash(pos, color, radius * 1.6, t)
end

-- Telegraph circle on the ground that fills, then (after `delay`) the strike.
function SpellFx.Telegraph(pos: Vector3, color: Color3, radius: number, delay: number)
	local g = ground(pos) + Vector3.new(0, 0.15, 0)
	local ring = neon(Vector3.new(0.1, radius * 2, radius * 2), CFrame.new(g) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	ring.Transparency = 0.75
	local fill = neon(Vector3.new(0.12, 0.5, 0.5), ring.CFrame, color, Enum.PartType.Cylinder)
	fill.Transparency = 0.45
	tween(fill, delay, { Size = Vector3.new(0.12, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	Debris:AddItem(ring, delay + 0.05)
	Debris:AddItem(fill, delay + 0.05)
end

-- Thunder Seal / Rolling Thunder: bolts from the sky + glyph ring.
function SpellFx.Seal(pos: Vector3, color: Color3, radius: number, delay: number)
	SpellFx.Telegraph(pos, color, radius, delay)
	local g = ground(pos)
	-- Rotating seal glyph: two squares at 45 degrees.
	for i = 0, 1 do
		local sq = neon(Vector3.new(radius * 1.3, 0.1, radius * 1.3), CFrame.new(g + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(45 * i), 0), color)
		sq.Transparency = 0.85
		tween(sq, delay + 0.4, { CFrame = sq.CFrame * CFrame.Angles(0, math.rad(90), 0), Transparency = 1 }, Enum.EasingStyle.Linear)
		Debris:AddItem(sq, delay + 0.45)
	end
	task.delay(delay, function()
		for _ = 1, 4 do
			local off = Vector3.new((math.random() - 0.5) * radius, 0, (math.random() - 0.5) * radius)
			SpellFx.Lightning(g + off + Vector3.new(0, 40, 0), g + off, color, 0.3)
		end
		SpellFx.Lightning(g + Vector3.new(0, 45, 0), g, Color3.new(1, 1, 1), 0.35)
		SpellFx.Nova(g + Vector3.new(0, 1, 0), color, radius, 0.4)
		Fx.ScreenFlash(color, 0.75, 0.15)
		Fx.CameraPunch(5)
	end)
end

-- Bright line attack (Mist Lance): a spear flies along the corridor.
function SpellFx.Lance(origin: Vector3, dir: Vector3, length: number, color: Color3)
	local start = origin + dir * 2
	local spear = neon(Vector3.new(0.6, 0.6, 6), CFrame.lookAt(start, start + dir), color)
	local tip = neon(Vector3.new(1.2, 1.2, 1.2), spear.CFrame * CFrame.new(0, 0, -3), Color3.new(1, 1, 1), Enum.PartType.Ball)
	local endPos = origin + dir * length
	tween(spear, 0.18, { CFrame = CFrame.lookAt(endPos, endPos + dir) }, Enum.EasingStyle.Linear)
	tween(tip, 0.18, { CFrame = CFrame.lookAt(endPos, endPos + dir) * CFrame.new(0, 0, -3) }, Enum.EasingStyle.Linear)
	Debris:AddItem(spear, 0.2)
	Debris:AddItem(tip, 0.2)
	-- Frost streak along the path.
	local streak = neon(Vector3.new(2.4, 0.2, length), CFrame.lookAt(origin + dir * length / 2, endPos) * CFrame.new(0, -1.8, 0), color)
	streak.Transparency = 0.4
	tween(streak, 0.6, { Transparency = 1, Size = Vector3.new(0.2, 0.1, length) })
	Debris:AddItem(streak, 0.65)
	for i = 1, 6 do
		Fx.Burst(origin + dir * (length * i / 6), { texture = Fx.Textures.Smoke, color = color, count = 5, speed = 4, size = 2, lifetime = 0.7, lightEmission = 0.3, acceleration = Vector3.new(0, 2, 0) })
	end
end

-- Jade Barrier / Brass Ward: a sphere that hugs the character for `seconds`.
function SpellFx.Barrier(model: Model, color: Color3, seconds: number)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local sphere = neon(Vector3.new(1, 1, 1), root.CFrame, color, Enum.PartType.Ball, Enum.Material.ForceField)
	sphere.Transparency = 0.2
	tween(sphere, 0.25, { Size = Vector3.new(8, 8, 8) }, Enum.EasingStyle.Back)
	local hex = neon(Vector3.new(0.1, 7, 7), root.CFrame, color, Enum.PartType.Cylinder)
	hex.Transparency = 0.6
	local conn = RunService.RenderStepped:Connect(function()
		if root.Parent then
			sphere.CFrame = root.CFrame
			hex.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, os.clock() * 2, math.rad(90))
		end
	end)
	task.delay(seconds, function()
		conn:Disconnect()
		tween(sphere, 0.3, { Transparency = 1, Size = Vector3.new(10, 10, 10) })
		tween(hex, 0.3, { Transparency = 1 })
		Debris:AddItem(sphere, 0.35)
		Debris:AddItem(hex, 0.35)
	end)
	Fx.Burst(root.Position, { color = color, count = 30, speed = 12, size = 0.5, lifetime = 0.7, acceleration = Vector3.new(0, 6, 0) })
end

-- Healing motes rising around a model.
function SpellFx.Heal(model: Model, color: Color3)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		Fx.Burst(root.Position - Vector3.new(0, 2, 0), { color = color, count = 26, speed = 4, size = 0.5, lifetime = 1.1, spread = 30, acceleration = Vector3.new(0, 10, 0), drag = 1 })
		Fx.Shockwave(root.Position - Vector3.new(0, 2.8, 0), color, 5, 0.5)
	end
end

-- Petal Storm: a ring of petals whirling around the model for `seconds`.
function SpellFx.Storm(model: Model, color: Color3, radius: number, seconds: number)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local petals: { Part } = {}
	for i = 1, 18 do
		local p = neon(Vector3.new(0.9, 0.12, 0.5), root.CFrame, if i % 3 == 0 then Color3.new(1, 1, 1) else color)
		p.Transparency = 0.1
		table.insert(petals, p)
	end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > seconds or root.Parent == nil then
			conn:Disconnect()
			for _, p in petals do
				tween(p, 0.3, { Transparency = 1 })
				Debris:AddItem(p, 0.35)
			end
			return
		end
		local grow = math.min(1, t / 0.25)
		for i, p in petals do
			local a = t * 7 + i * (math.pi * 2 / #petals)
			local r = radius * grow * (0.45 + 0.55 * ((i % 3) / 2))
			local h = math.sin(t * 5 + i) * 1.5
			local pos = root.Position + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)
			p.CFrame = CFrame.lookAt(pos, root.Position) * CFrame.Angles(0, 0, a * 2)
		end
	end)
	Fx.Burst(root.Position, { color = color, count = 30, speed = 18, size = 0.6, lifetime = 0.7 })
end

-- Nine Bells / Ninth Toll: a giant bell falls from the sky and slams down.
function SpellFx.BellDrop(pos: Vector3, color: Color3, radius: number, delay: number)
	SpellFx.Telegraph(pos, color, radius, delay)
	local g = ground(pos)
	local scale = radius / 6
	local bell = Instance.new("Model")
	bell.Name = "PhantomBell"
	local bronze = Color3.fromRGB(150, 110, 50):Lerp(color, 0.3)
	local function bp(size: Vector3, offset: CFrame, c: Color3, shape: Enum.PartType?, mat: Enum.Material?)
		local p = neon(size * scale, offset, c, shape, mat or Enum.Material.Metal)
		p.Parent = bell
		return p
	end
	local body = bp(Vector3.new(7, 6, 6), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), bronze, Enum.PartType.Cylinder)
	bp(Vector3.new(1, 8, 8), CFrame.new(0, -3.2 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), bronze, Enum.PartType.Cylinder)
	bp(Vector3.new(4, 4.5, 4.5), CFrame.new(0, 4.2 * scale, 0), bronze, Enum.PartType.Ball)
	bp(Vector3.new(1.2, 1.4, 1.2), CFrame.new(0, 6.6 * scale, 0), bronze)
	local band = bp(Vector3.new(0.6, 6.4, 6.4), CFrame.new(0, 1.6 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder, Enum.Material.Neon)
	band.Transparency = 0.1
	bell.PrimaryPart = body
	local high = CFrame.new(g + Vector3.new(0, 60, 0))
	local low = CFrame.new(g + Vector3.new(0, 4 * scale, 0))
	bell:PivotTo(high)
	bell.Parent = workspace
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / delay)
		local k = t * t * t
		bell:PivotTo(high:Lerp(low, k) * CFrame.Angles(0, t * math.pi, 0))
		if t >= 1 then
			conn:Disconnect()
		end
	end)
	task.delay(delay, function()
		Fx.Shockwave(g + Vector3.new(0, 0.3, 0), color, radius * 1.2, 0.6)
		Fx.Shockwave(g + Vector3.new(0, 0.5, 0), Color3.new(1, 1, 1), radius * 0.8, 0.4)
		Fx.Burst(g, { texture = Fx.Textures.Smoke, color = Color3.fromRGB(200, 190, 170), count = 50, speed = radius * 2, size = 4, lifetime = 1, lightEmission = 0, acceleration = Vector3.new(0, 4, 0) })
		Fx.Burst(g + Vector3.new(0, 3, 0), { color = color, count = 60, speed = 40, size = 0.8, lifetime = 0.7 })
		Fx.Pillar(g, color, 40)
		Fx.LightFlash(g, color, radius * 3, 0.6)
		Fx.ScreenFlash(color, 0.6, 0.25)
		Fx.CameraPunch(10)
		for _, d in bell:GetDescendants() do
			if d:IsA("BasePart") then
				tween(d, 0.8, { Transparency = 1 })
			end
		end
		Debris:AddItem(bell, 0.85)
	end)
end

-- Ghost Step: fading silhouette line between two points.
function SpellFx.BlinkTrail(from: Vector3, to: Vector3, color: Color3)
	local len = (to - from).Magnitude
	if len < 0.5 then
		return
	end
	local beam = neon(Vector3.new(1.4, 4.5, len), CFrame.lookAt((from + to) / 2, to), color)
	beam.Transparency = 0.55
	tween(beam, 0.35, { Transparency = 1, Size = Vector3.new(0.1, 5, len) })
	Debris:AddItem(beam, 0.4)
	Fx.Burst(from, { texture = Fx.Textures.Smoke, color = color, count = 18, speed = 6, size = 2.5, lifetime = 0.6, lightEmission = 0.5, acceleration = Vector3.new(0, 3, 0) })
	Fx.Burst(to, { color = color, count = 24, speed = 20, size = 0.5, lifetime = 0.4 })
	Fx.Shockwave(to - Vector3.new(0, 2.6, 0), color, 7, 0.3)
end

return SpellFx
