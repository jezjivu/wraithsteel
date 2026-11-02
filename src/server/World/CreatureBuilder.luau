--!strict
-- CreatureBuilder: part-built beast bosses (no uploaded meshes). Every limb hangs off a
-- Motor6D so clients can animate it (Controllers/CreatureAnimator poses the joints by name).
-- The model still has a HumanoidRootPart + Humanoid, so movement, health and combat work
-- exactly like any other combatant.
--
-- API:
--   CreatureBuilder.Build(kind: "Tiger", look) -> Model?
--   Joint names (Tiger): Spine, Neck, Jaw, Hip_FL/FR/BL/BR, Knee_FL/FR/BL/BR, Tail1..Tail4

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("EnemyConfig"))

local CreatureBuilder = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

type Ctx = { model: Model, s: number }

local function part(ctx: Ctx, name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size * ctx.s
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	if shape then
		p.Shape = shape
	end
	p.Parent = ctx.model
	return p
end

-- Joint: Part1 hangs off Part0. `at` is the pivot in Part0 space, `pivot1` the same point in
-- Part1 space (both unscaled; scaled here).
local function joint(ctx: Ctx, name: string, p0: BasePart, p1: BasePart, at: Vector3, pivot1: Vector3): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = CFrame.new(at * ctx.s)
	m.C1 = CFrame.new(pivot1 * ctx.s)
	m.Parent = p1
	return m
end

-- Rigid attachment (decor glued to a moving part).
local function glue(ctx: Ctx, p0: BasePart, p1: BasePart, offset: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = p0
	w.Part1 = p1
	w.C0 = CFrame.new(offset.Position * ctx.s) * offset.Rotation
	w.Parent = p1
end

local function tiger(look: EnemyConfig.RigLook): Model
	local model = Instance.new("Model")
	model.Name = "Tiger"
	local ctx: Ctx = { model = model, s = look.scale }
	local fur = rgb(look.body)
	local belly = rgb(look.skin)
	local stripe = rgb(look.accent or { 30, 22, 20 })
	local glow = rgb(look.glow or { 255, 120, 40 })
	local rust = Color3.fromRGB(120, 70, 45)

	local root = part(ctx, "HumanoidRootPart", Vector3.new(5, 4, 9), fur)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false

	local torso = part(ctx, "Torso", Vector3.new(4.6, 3.8, 8.6), fur)
	joint(ctx, "Spine", root, torso, Vector3.zero, Vector3.zero)
	local chest = part(ctx, "Chest", Vector3.new(5.2, 4.4, 3.4), fur)
	glue(ctx, torso, chest, CFrame.new(0, 0.3, -3.2))
	local under = part(ctx, "Belly", Vector3.new(3.8, 1, 7.6), belly)
	glue(ctx, torso, under, CFrame.new(0, -1.7, 0))
	-- Stripes over the back and flanks.
	for i = -3, 3 do
		local band = part(ctx, "Stripe", Vector3.new(4.8, 0.3, 0.55), stripe)
		glue(ctx, torso, band, CFrame.new(0, 1.85, i * 1.15) * CFrame.Angles(0, math.rad(i * 6), 0))
		for _, side in { -1, 1 } do
			local flank = part(ctx, "Stripe", Vector3.new(0.3, 2.2, 0.5), stripe)
			glue(ctx, torso, flank, CFrame.new(side * 2.35, 0.4, i * 1.15 + 0.3) * CFrame.Angles(math.rad(18), 0, 0))
		end
	end
	-- Rusted armor plates with glowing seams along the spine.
	for i = 0, 4 do
		local plate = part(ctx, "RustPlate", Vector3.new(2.6, 0.7, 1.5), rust, Enum.Material.CorrodedMetal)
		glue(ctx, torso, plate, CFrame.new(0, 2.25, -3 + i * 1.6) * CFrame.Angles(math.rad(-12), 0, 0))
		local seam = part(ctx, "Seam", Vector3.new(2.7, 0.15, 0.25), glow, Enum.Material.Neon)
		glue(ctx, torso, seam, CFrame.new(0, 2.2, -2.2 + i * 1.6))
	end
	for _, side in { -1, 1 } do
		local spike = Instance.new("WedgePart")
		spike.Name = "ShoulderSpike"
		spike.Size = Vector3.new(0.8, 2.2, 1.6) * ctx.s
		spike.Color = rust
		spike.Material = Enum.Material.CorrodedMetal
		spike.CanCollide = false
		spike.Massless = true
		spike.Parent = model
		glue(ctx, torso, spike, CFrame.new(side * 2.2, 2.4, -3.4) * CFrame.Angles(0, 0, math.rad(side * -20)))
	end

	-- Head + jaw.
	local head = part(ctx, "Head", Vector3.new(3.6, 3, 3.4), fur)
	joint(ctx, "Neck", torso, head, Vector3.new(0, 1.4, -5), Vector3.new(0, -0.6, 1.2))
	local snout = part(ctx, "Snout", Vector3.new(2.2, 1.4, 1.6), belly)
	glue(ctx, head, snout, CFrame.new(0, -0.5, -2.1))
	local nose = part(ctx, "Nose", Vector3.new(0.8, 0.5, 0.4), Color3.fromRGB(30, 25, 25))
	glue(ctx, head, nose, CFrame.new(0, 0.1, -2.95))
	local jaw = part(ctx, "Jaw", Vector3.new(2, 0.6, 2.2), belly)
	joint(ctx, "Jaw", head, jaw, Vector3.new(0, -1.3, -0.6), Vector3.new(0, 0, 1))
	for _, side in { -1, 1 } do
		local eye = part(ctx, "Eye", Vector3.new(0.6, 0.35, 0.2), glow, Enum.Material.Neon)
		glue(ctx, head, eye, CFrame.new(side * 0.9, 0.45, -1.72))
		local ear = Instance.new("WedgePart")
		ear.Name = "Ear"
		ear.Size = Vector3.new(0.4, 1.2, 1) * ctx.s
		ear.Color = fur
		ear.CanCollide = false
		ear.Massless = true
		ear.Parent = model
		glue(ctx, head, ear, CFrame.new(side * 1.3, 1.9, 0.3))
		local fang = Instance.new("WedgePart")
		fang.Name = "Fang"
		fang.Size = Vector3.new(0.25, 0.8, 0.3) * ctx.s
		fang.Color = Color3.fromRGB(240, 230, 210)
		fang.CanCollide = false
		fang.Massless = true
		fang.Parent = model
		glue(ctx, head, fang, CFrame.new(side * 0.6, -1.3, -2.6) * CFrame.Angles(math.rad(180), 0, 0))
		local whisker = part(ctx, "Whisker", Vector3.new(1.6, 0.08, 0.08), Color3.fromRGB(230, 220, 200))
		glue(ctx, head, whisker, CFrame.new(side * 1.6, -0.4, -2.2) * CFrame.Angles(0, 0, math.rad(side * 10)))
	end
	for i = -1, 1 do
		local bandH = part(ctx, "Stripe", Vector3.new(0.4, 0.2, 2.6), stripe)
		glue(ctx, head, bandH, CFrame.new(i * 0.6, 1.52, 0) * CFrame.Angles(0, math.rad(i * 15), 0))
	end
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 16
	light.Brightness = 2
	light.Parent = head

	-- Legs: upper + lower + paw with claws.
	local legs: { [string]: { number } } = { FL = { -1.9, -1.4, -3.3 }, FR = { 1.9, -1.4, -3.3 }, BL = { -1.9, -1.4, 3.3 }, BR = { 1.9, -1.4, 3.3 } }
	for id, at in legs do
		local upper = part(ctx, "Upper_" .. id, Vector3.new(1.5, 3, 1.8), fur)
		joint(ctx, "Hip_" .. id, torso, upper, Vector3.new(at[1], at[2], at[3]), Vector3.new(0, 1.3, 0))
		local lower = part(ctx, "Lower_" .. id, Vector3.new(1.2, 2.6, 1.3), fur)
		joint(ctx, "Knee_" .. id, upper, lower, Vector3.new(0, -1.4, 0), Vector3.new(0, 1.2, 0))
		local paw = part(ctx, "Paw_" .. id, Vector3.new(1.7, 0.7, 2), belly)
		glue(ctx, lower, paw, CFrame.new(0, -1.45, -0.3))
		for c = -1, 1 do
			local claw = part(ctx, "Claw", Vector3.new(0.2, 0.2, 0.7), Color3.fromRGB(235, 225, 210))
			glue(ctx, lower, claw, CFrame.new(c * 0.5, -1.55, -1.5))
		end
		local band = part(ctx, "Stripe", Vector3.new(1.55, 0.3, 1.85), stripe)
		glue(ctx, upper, band, CFrame.new(0, 0.3, 0))
	end

	-- Tail: four segments, each hanging off the previous one.
	local prev: BasePart = torso
	local prevAt = Vector3.new(0, 1.2, 4.3)
	for i = 1, 4 do
		local seg = part(ctx, "Tail" .. i, Vector3.new(0.8 - i * 0.08, 0.8 - i * 0.08, 2), if i % 2 == 0 then stripe else fur)
		joint(ctx, "Tail" .. i, prev, seg, prevAt, Vector3.new(0, 0, -0.9))
		prev = seg
		prevAt = Vector3.new(0, 0, 0.9)
	end
	local tip = part(ctx, "TailFlame", Vector3.new(0.9, 0.9, 0.9), glow, Enum.Material.Neon, Enum.PartType.Ball)
	glue(ctx, prev, tip, CFrame.new(0, 0, 1.1))
	local fire = Instance.new("Fire")
	fire.Color = glow
	fire.SecondaryColor = Color3.fromRGB(255, 220, 140)
	fire.Size = 2 * ctx.s
	fire.Heat = 4
	fire.Parent = tip

	-- Pose the whole thing once so the welds/joints settle before it is parented.
	root.CFrame = CFrame.new()
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") then
			local p0, p1 = d.Part0, d.Part1
			if p0 and p1 then
				p1.CFrame = p0.CFrame * d.C0 * d.C1:Inverse()
			end
		end
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	-- Root center to the ground: hip offset + leg length.
	local legReach = (1.4 + 1.3 + 1.4 + 1.2 + 1.45 + 0.35) * ctx.s
	hum.HipHeight = legReach - root.Size.Y / 2
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("Creature", "Tiger")
	return model
end

-- Hovering security drone: armored sphere, spinning rotor ring, one big glowing eye, a gun.
-- Joints: Body (bob), Rotor (spin), Eye (aim). It "floats" through a tall HipHeight.
local function drone(look: EnemyConfig.RigLook): Model
	local model = Instance.new("Model")
	model.Name = "Drone"
	local ctx: Ctx = { model = model, s = look.scale }
	local shell = rgb(look.body)
	local trim = rgb(look.accent or { 200, 200, 210 })
	local glow = rgb(look.glow or { 60, 230, 255 })
	local root = part(ctx, "HumanoidRootPart", Vector3.new(3, 3, 3), shell)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	local body = part(ctx, "Body", Vector3.new(3.2, 3.2, 3.2), shell, Enum.Material.Metal, Enum.PartType.Ball)
	joint(ctx, "Body", root, body, Vector3.zero, Vector3.zero)
	local band = part(ctx, "Band", Vector3.new(0.5, 3.5, 3.5), trim, Enum.Material.Metal, Enum.PartType.Cylinder)
	glue(ctx, body, band, CFrame.Angles(0, 0, math.rad(90)))
	local rotor = part(ctx, "Rotor", Vector3.new(0.25, 6, 6), glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	rotor.Transparency = 0.35
	joint(ctx, "Rotor", body, rotor, Vector3.new(0, 1.9, 0), Vector3.zero)
	for i = 0, 3 do
		local blade = part(ctx, "Blade", Vector3.new(2.6, 0.12, 0.5), trim, Enum.Material.Metal)
		glue(ctx, rotor, blade, CFrame.Angles(0, math.rad(45 + i * 90), 0) * CFrame.new(1.4, 0, 0))
	end
	local eye = part(ctx, "Eye", Vector3.new(1.3, 1.3, 0.6), glow, Enum.Material.Neon)
	joint(ctx, "Eye", body, eye, Vector3.new(0, 0, -1.45), Vector3.zero)
	local lens = part(ctx, "Lens", Vector3.new(0.6, 0.6, 0.2), Color3.new(1, 1, 1), Enum.Material.Neon)
	glue(ctx, eye, lens, CFrame.new(0, 0, -0.35))
	local gun = part(ctx, "Gun", Vector3.new(0.5, 0.5, 2.2), Color3.fromRGB(40, 40, 48), Enum.Material.Metal)
	glue(ctx, body, gun, CFrame.new(0, -1.5, -0.9))
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 14
	light.Brightness = 2
	light.Parent = eye
	-- Fix the rotor's resting joint so the ring lies flat.
	local rj = rotor:FindFirstChild("Rotor")
	if rj and rj:IsA("Motor6D") then
		rj.C1 = CFrame.Angles(0, 0, math.rad(90))
	end
	root.CFrame = CFrame.new()
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") then
			local p0, p1 = d.Part0, d.Part1
			if p0 and p1 then
				p1.CFrame = p0.CFrame * d.C0 * d.C1:Inverse()
			end
		end
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 5 * ctx.s -- hovers above the ground
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("Creature", "Drone")
	return model
end

-- The Thunderbell Engine: a samurai-armored war machine. Its forearms are rocket pods (four
-- tubes each, a steel fist below), its visor is a laser lance, two thrusters on its back.
-- Biped joints: Root, Waist, Neck, Shoulder_L/R, Elbow_L/R, Hip_L/R, Knee_L/R.
local function mech(look: EnemyConfig.RigLook): Model
	local model = Instance.new("Model")
	model.Name = "Mech"
	local ctx: Ctx = { model = model, s = look.scale }
	local steel = rgb(look.body)
	local dark = rgb(look.legs)
	local trim = rgb(look.accent or { 220, 170, 60 })
	local glow = rgb(look.glow or { 255, 70, 40 })
	local core = rgb(look.skin)

	local root = part(ctx, "HumanoidRootPart", Vector3.new(4, 5, 3), steel)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false

	local pelvis = part(ctx, "Pelvis", Vector3.new(2.8, 1.4, 1.8), dark, Enum.Material.Metal)
	joint(ctx, "Root", root, pelvis, Vector3.new(0, -0.8, 0), Vector3.zero)
	for _, side in { -1, 1 } do
		local skirt = part(ctx, "Tasset", Vector3.new(1.3, 1.4, 0.3), steel, Enum.Material.DiamondPlate)
		glue(ctx, pelvis, skirt, CFrame.new(side * 0.75, -0.8, -0.95) * CFrame.Angles(math.rad(-10), 0, 0))
	end

	local torso = part(ctx, "Torso", Vector3.new(3.6, 3, 2.2), steel, Enum.Material.Metal)
	joint(ctx, "Waist", pelvis, torso, Vector3.new(0, 0.6, 0), Vector3.new(0, -1.5, 0))
	local chest = part(ctx, "ChestArmor", Vector3.new(3.2, 1.8, 0.5), dark, Enum.Material.DiamondPlate)
	glue(ctx, torso, chest, CFrame.new(0, 0.4, -1.1))
	local coreBall = part(ctx, "Core", Vector3.new(1.1, 1.1, 1.1), core, Enum.Material.Neon, Enum.PartType.Ball)
	glue(ctx, torso, coreBall, CFrame.new(0, 0.3, -1.35))
	local coreLight = Instance.new("PointLight")
	coreLight.Color = core
	coreLight.Range = 22
	coreLight.Brightness = 3
	coreLight.Parent = coreBall
	for _, side in { -1, 1 } do
		local stripe = part(ctx, "Stripe", Vector3.new(0.25, 2.6, 0.1), trim, Enum.Material.Neon)
		glue(ctx, torso, stripe, CFrame.new(side * 1.2, 0, -1.16))
		local vent = part(ctx, "Vent", Vector3.new(0.9, 0.5, 0.3), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
		glue(ctx, torso, vent, CFrame.new(side * 1.2, -1.1, -1.12))
		-- Back thrusters.
		local thruster = part(ctx, "Thruster", Vector3.new(2.2, 1, 1), dark, Enum.Material.Metal, Enum.PartType.Cylinder)
		glue(ctx, torso, thruster, CFrame.new(side * 0.9, 0.3, 1.4) * CFrame.Angles(0, 0, math.rad(90)))
		local flame = part(ctx, "ThrusterFlame", Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(120, 180, 255), Enum.Material.Neon, Enum.PartType.Ball)
		glue(ctx, torso, flame, CFrame.new(side * 0.9, -0.85, 1.4))
		local fire = Instance.new("Fire")
		fire.Color = Color3.fromRGB(110, 170, 255)
		fire.SecondaryColor = Color3.fromRGB(255, 255, 255)
		fire.Size = 2.5 * ctx.s
		fire.Heat = -6
		fire.Parent = flame
	end

	local head = part(ctx, "Head", Vector3.new(1.6, 1.3, 1.6), steel, Enum.Material.Metal)
	joint(ctx, "Neck", torso, head, Vector3.new(0, 1.5, -0.1), Vector3.new(0, -0.7, 0))
	local visor = part(ctx, "Visor", Vector3.new(1.4, 0.28, 0.2), glow, Enum.Material.Neon)
	glue(ctx, head, visor, CFrame.new(0, 0.1, -0.82))
	local visorLight = Instance.new("PointLight")
	visorLight.Color = glow
	visorLight.Range = 16
	visorLight.Brightness = 2
	visorLight.Parent = visor
	local jaw = part(ctx, "Faceplate", Vector3.new(1.3, 0.5, 0.3), dark, Enum.Material.DiamondPlate)
	glue(ctx, head, jaw, CFrame.new(0, -0.4, -0.78))
	-- Kabuto crest: two golden crescent horns.
	for _, side in { -1, 1 } do
		local horn = Instance.new("WedgePart")
		horn.Name = "Crest"
		horn.Size = Vector3.new(0.2, 1.8, 0.6) * ctx.s
		horn.Color = trim
		horn.Material = Enum.Material.Metal
		horn.CanCollide = false
		horn.Massless = true
		horn.Parent = model
		glue(ctx, head, horn, CFrame.new(side * 0.55, 1.2, -0.3) * CFrame.Angles(0, 0, math.rad(side * -32)))
	end
	local antenna = part(ctx, "Antenna", Vector3.new(0.12, 1.4, 0.12), dark, Enum.Material.Metal)
	glue(ctx, head, antenna, CFrame.new(0.5, 1, 0.5))

	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local upper = part(ctx, "UpperArm_" .. tag, Vector3.new(1.2, 2.3, 1.2), dark, Enum.Material.Metal)
		joint(ctx, "Shoulder_" .. tag, torso, upper, Vector3.new(side * 2.3, 0.9, 0), Vector3.new(0, 0.9, 0))
		local pauldron = part(ctx, "Pauldron", Vector3.new(2, 0.8, 2), steel, Enum.Material.DiamondPlate)
		glue(ctx, upper, pauldron, CFrame.new(side * 0.15, 1.1, 0) * CFrame.Angles(0, 0, math.rad(side * -18)))
		local pauldronTrim = part(ctx, "PauldronTrim", Vector3.new(2.05, 0.15, 2.05), trim, Enum.Material.Neon)
		glue(ctx, upper, pauldronTrim, CFrame.new(side * 0.15, 0.7, 0) * CFrame.Angles(0, 0, math.rad(side * -18)))
		-- Forearm = rocket pod with four tubes and a fist.
		local pod = part(ctx, "RocketPod_" .. tag, Vector3.new(1.8, 2.4, 1.8), steel, Enum.Material.Metal)
		joint(ctx, "Elbow_" .. tag, upper, pod, Vector3.new(0, -1.15, 0), Vector3.new(0, 1, 0))
		for tx = -1, 1, 2 do
			for tz = -1, 1, 2 do
				local tube = part(ctx, "Tube", Vector3.new(2.5, 0.55, 0.55), Color3.fromRGB(30, 30, 34), Enum.Material.Metal, Enum.PartType.Cylinder)
				glue(ctx, pod, tube, CFrame.new(tx * 0.45, -0.1, tz * 0.45) * CFrame.Angles(0, 0, math.rad(90)))
				local tip = part(ctx, "RocketTip", Vector3.new(0.4, 0.4, 0.4), glow, Enum.Material.Neon, Enum.PartType.Ball)
				glue(ctx, pod, tip, CFrame.new(tx * 0.45, -1.3, tz * 0.45))
			end
		end
		local fist = part(ctx, "Fist_" .. tag, Vector3.new(1.5, 1.1, 1.5), dark, Enum.Material.Metal)
		glue(ctx, pod, fist, CFrame.new(0, -1.75, 0))
		local upperLeg = part(ctx, "UpperLeg_" .. tag, Vector3.new(1.5, 2.3, 1.5), dark, Enum.Material.Metal)
		joint(ctx, "Hip_" .. tag, pelvis, upperLeg, Vector3.new(side * 0.85, -0.6, 0), Vector3.new(0, 1, 0))
		local lowerLeg = part(ctx, "LowerLeg_" .. tag, Vector3.new(1.4, 2.3, 1.6), steel, Enum.Material.Metal)
		joint(ctx, "Knee_" .. tag, upperLeg, lowerLeg, Vector3.new(0, -1.1, 0), Vector3.new(0, 1, 0))
		local kneePad = part(ctx, "KneePad", Vector3.new(1.2, 1, 0.5), trim, Enum.Material.Metal)
		glue(ctx, lowerLeg, kneePad, CFrame.new(0, 0.9, -0.85))
		local foot = part(ctx, "Foot_" .. tag, Vector3.new(1.8, 0.7, 2.6), dark, Enum.Material.Metal)
		glue(ctx, lowerLeg, foot, CFrame.new(0, -1.3, -0.4))
	end

	root.CFrame = CFrame.new()
	for _ = 1, 2 do
		for _, d in model:GetDescendants() do
			if d:IsA("JointInstance") then
				local p0, p1 = d.Part0, d.Part1
				if p0 and p1 then
					p1.CFrame = p0.CFrame * d.C0 * d.C1:Inverse()
				end
			end
		end
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = (6.15 - 2.5) * ctx.s
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("Creature", "Mech")
	return model
end

function CreatureBuilder.Build(kind: string, look: EnemyConfig.RigLook?): Model?
	if look == nil then
		return nil
	end
	if kind == "Tiger" then
		return tiger(look)
	elseif kind == "Drone" then
		return drone(look)
	elseif kind == "Mech" then
		return mech(look)
	end
	return nil
end

return CreatureBuilder
