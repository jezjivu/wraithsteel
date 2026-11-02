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

-- The Bell Oni: a towering horned demon in rusted armor, swinging a hammer whose head is a
-- cracked temple bell. Biped joints: Root, Waist, Neck, Jaw, Shoulder_L/R, Elbow_L/R,
-- Hip_L/R, Knee_L/R, Grip (hammer in the right hand).
local function oni(look: EnemyConfig.RigLook): Model
	local model = Instance.new("Model")
	model.Name = "Oni"
	local ctx: Ctx = { model = model, s = look.scale }
	local skin = rgb(look.skin)
	local armor = rgb(look.body)
	local cloth = rgb(look.legs)
	local glow = rgb(look.glow or { 255, 120, 40 })
	local bone = Color3.fromRGB(235, 225, 205)
	local bronze = Color3.fromRGB(150, 110, 55)

	local root = part(ctx, "HumanoidRootPart", Vector3.new(4, 5, 3), skin)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false

	local pelvis = part(ctx, "Pelvis", Vector3.new(2.6, 1.3, 1.6), cloth, Enum.Material.Fabric)
	joint(ctx, "Root", root, pelvis, Vector3.new(0, -0.8, 0), Vector3.zero)
	-- Loincloth flaps + rope belt.
	local flap = part(ctx, "Loincloth", Vector3.new(1.4, 2, 0.2), cloth:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Fabric)
	glue(ctx, pelvis, flap, CFrame.new(0, -1.3, -0.82))
	local belt = part(ctx, "Belt", Vector3.new(2.8, 0.4, 1.8), Color3.fromRGB(200, 180, 120), Enum.Material.Fabric)
	glue(ctx, pelvis, belt, CFrame.new(0, 0.5, 0))

	local torso = part(ctx, "Torso", Vector3.new(3.4, 2.8, 1.9), skin)
	joint(ctx, "Waist", pelvis, torso, Vector3.new(0, 0.6, 0), Vector3.new(0, -1.4, 0))
	-- Rusted chest plate with a glowing crack, shoulder pauldrons, prayer beads.
	local plate = part(ctx, "ChestPlate", Vector3.new(3, 1.9, 0.4), armor, Enum.Material.CorrodedMetal)
	glue(ctx, torso, plate, CFrame.new(0, 0.2, -0.98))
	local crack = part(ctx, "PlateCrack", Vector3.new(0.18, 1.6, 0.1), glow, Enum.Material.Neon)
	glue(ctx, torso, crack, CFrame.new(0.3, 0.2, -1.2) * CFrame.Angles(0, 0, math.rad(15)))
	for i = -4, 4 do
		local bead = part(ctx, "Bead", Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(60, 35, 25), Enum.Material.Wood, Enum.PartType.Ball)
		local a = math.rad(i * 18)
		glue(ctx, torso, bead, CFrame.new(math.sin(a) * 1.6, 0.9 - math.abs(i) * 0.12, -math.cos(a) * 1.05))
	end

	local head = part(ctx, "Head", Vector3.new(1.8, 1.8, 1.8), skin)
	joint(ctx, "Neck", torso, head, Vector3.new(0, 1.4, -0.1), Vector3.new(0, -0.9, 0))
	local jaw = part(ctx, "Jaw", Vector3.new(1.5, 0.5, 1.2), skin)
	joint(ctx, "Jaw", head, jaw, Vector3.new(0, -0.85, -0.2), Vector3.new(0, 0.1, 0.5))
	for _, side in { -1, 1 } do
		local eye = part(ctx, "Eye", Vector3.new(0.4, 0.22, 0.1), glow, Enum.Material.Neon)
		glue(ctx, head, eye, CFrame.new(side * 0.42, 0.2, -0.92) * CFrame.Angles(0, 0, math.rad(side * -12)))
		local brow = part(ctx, "Brow", Vector3.new(0.6, 0.18, 0.2), skin:Lerp(Color3.new(0, 0, 0), 0.4))
		glue(ctx, head, brow, CFrame.new(side * 0.42, 0.45, -0.92) * CFrame.Angles(0, 0, math.rad(side * 22)))
		local horn = Instance.new("WedgePart")
		horn.Name = "Horn"
		horn.Size = Vector3.new(0.4, 1.6, 0.6) * ctx.s
		horn.Color = bone
		horn.CanCollide = false
		horn.Massless = true
		horn.Parent = model
		glue(ctx, head, horn, CFrame.new(side * 0.6, 1.4, 0) * CFrame.Angles(0, 0, math.rad(side * -20)))
		local tusk = Instance.new("WedgePart")
		tusk.Name = "Tusk"
		tusk.Size = Vector3.new(0.18, 0.6, 0.25) * ctx.s
		tusk.Color = bone
		tusk.CanCollide = false
		tusk.Massless = true
		tusk.Parent = model
		glue(ctx, jaw, tusk, CFrame.new(side * 0.5, 0.45, -0.45))
	end
	local hair = part(ctx, "Hair", Vector3.new(2.2, 1.2, 2.2), Color3.fromRGB(235, 235, 240), Enum.Material.Fabric)
	glue(ctx, head, hair, CFrame.new(0, 0.75, 0.35))
	local mane = part(ctx, "Mane", Vector3.new(2.4, 2, 0.8), Color3.fromRGB(225, 225, 230), Enum.Material.Fabric)
	glue(ctx, head, mane, CFrame.new(0, -0.2, 1))
	local headLight = Instance.new("PointLight")
	headLight.Color = glow
	headLight.Range = 18
	headLight.Brightness = 2
	headLight.Parent = head

	local hands: { [string]: BasePart } = {}
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local upper = part(ctx, "UpperArm_" .. tag, Vector3.new(1.1, 2.3, 1.1), skin)
		joint(ctx, "Shoulder_" .. tag, torso, upper, Vector3.new(side * 2.1, 0.9, 0), Vector3.new(0, 0.9, 0))
		local pauldron = part(ctx, "Pauldron", Vector3.new(1.7, 0.7, 1.6), armor, Enum.Material.CorrodedMetal)
		glue(ctx, upper, pauldron, CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(side * -15)))
		local lower = part(ctx, "LowerArm_" .. tag, Vector3.new(1, 2.1, 1), skin)
		joint(ctx, "Elbow_" .. tag, upper, lower, Vector3.new(0, -1.15, 0), Vector3.new(0, 0.95, 0))
		local bracer = part(ctx, "Bracer", Vector3.new(1.15, 1, 1.15), armor, Enum.Material.CorrodedMetal)
		glue(ctx, lower, bracer, CFrame.new(0, -0.4, 0))
		local hand = part(ctx, "Hand_" .. tag, Vector3.new(1.2, 1, 1.2), skin)
		glue(ctx, lower, hand, CFrame.new(0, -1.3, 0))
		hands[tag] = hand
		local upperLeg = part(ctx, "UpperLeg_" .. tag, Vector3.new(1.3, 2.3, 1.3), skin)
		joint(ctx, "Hip_" .. tag, pelvis, upperLeg, Vector3.new(side * 0.75, -0.6, 0), Vector3.new(0, 1, 0))
		local lowerLeg = part(ctx, "LowerLeg_" .. tag, Vector3.new(1.15, 2.3, 1.15), skin)
		joint(ctx, "Knee_" .. tag, upperLeg, lowerLeg, Vector3.new(0, -1.1, 0), Vector3.new(0, 1, 0))
		local greave = part(ctx, "Greave", Vector3.new(1.25, 1.2, 1.25), armor, Enum.Material.CorrodedMetal)
		glue(ctx, lowerLeg, greave, CFrame.new(0, 0.1, 0))
		local foot = part(ctx, "Foot_" .. tag, Vector3.new(1.4, 0.6, 2), skin)
		glue(ctx, lowerLeg, foot, CFrame.new(0, -1.3, -0.3))
	end

	-- The bell-hammer: long iron-bound shaft, a cracked temple bell for a head.
	local shaft = part(ctx, "HammerShaft", Vector3.new(0.5, 6.4, 0.5), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
	local grip = joint(ctx, "Grip", hands.R, shaft, Vector3.new(0, -0.35, 0), Vector3.new(0, -2.4, 0))
	grip.C0 = CFrame.new(0, -0.35 * ctx.s, 0) * CFrame.Angles(math.rad(-100), 0, 0)
	for _, y in { -1.6, 0.4, 2.2 } do
		local band = part(ctx, "ShaftBand", Vector3.new(0.6, 0.3, 0.6), Color3.fromRGB(90, 85, 80), Enum.Material.Metal)
		glue(ctx, shaft, band, CFrame.new(0, y, 0))
	end
	local bell = part(ctx, "BellHead", Vector3.new(2.6, 2.6, 2.6), bronze, Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	glue(ctx, shaft, bell, CFrame.new(0, 3.6, 0))
	local lip = part(ctx, "BellLip", Vector3.new(0.4, 3.1, 3.1), bronze:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Metal, Enum.PartType.Cylinder)
	glue(ctx, shaft, lip, CFrame.new(1.25, 3.6, 0))
	local bellCrack = part(ctx, "BellCrack", Vector3.new(2.62, 0.2, 0.25), glow, Enum.Material.Neon)
	glue(ctx, shaft, bellCrack, CFrame.new(0, 3.6, -1.25))
	local bellLight = Instance.new("PointLight")
	bellLight.Color = glow
	bellLight.Range = 20
	bellLight.Brightness = 2.5
	bellLight.Parent = bell
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxasset://textures/particles/fire_main.dds"
	embers.Color = ColorSequence.new(glow)
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.6, 0)
	embers.Lifetime = NumberRange.new(0.6, 1.2)
	embers.Rate = 25
	embers.Speed = NumberRange.new(1, 3)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Acceleration = Vector3.new(0, 6, 0)
	embers.Parent = bell

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
	-- Root center to the soles: pelvis 0.8 + hip 0.6 + thigh 2.1 + shin 1 + foot 1.6.
	hum.HipHeight = (6.1 - 2.5) * ctx.s
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("Creature", "Oni")
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
	elseif kind == "Oni" then
		return oni(look)
	end
	return nil
end

return CreatureBuilder
