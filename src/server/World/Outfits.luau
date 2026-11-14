--!strict
-- Outfits: part-built clothing and armor for procedural R15 rigs (World/RigBuilder).
-- Every piece is welded to a body part, so it moves with the limb animations.
-- Front of every body part is -Z. Sizes are relative to the part they hang on, so the same
-- outfit works on any rig scale (RigBuilder scales the whole model afterwards).
--
-- Outfits: Ronin, Samurai, Monk, Shinobi, Bandit, Archer, Hoplite, Cyber, Robe, Noble
-- Masks:   Oni, Menpo, Kitsune, Cloth, Skull
-- Headwear: Hood, Helm, Horns, Lantern, Sack, Hair, Visor, Crest, Laurel, Bell, Kasa, Kabuto
-- Faces:   Grim (default), Calm, Glow, None (keeps the stock face)

local Outfits = {}

export type Attach = (Model, BasePart, string, Vector3, CFrame, Color3, Enum.Material?, Enum.PartType?) -> Part
type Look = {
	skin: { number },
	body: { number },
	legs: { number },
	accent: { number }?,
	glow: { number }?,
	outfit: string?,
	mask: string?,
	face: string?,
	headwear: string?,
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function shade(c: Color3, k: number): Color3
	return if k < 0 then c:Lerp(Color3.new(0, 0, 0), -k) else c:Lerp(Color3.new(1, 1, 1), k)
end

local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

type Kit = {
	model: Model,
	attach: Attach,
	part: (string) -> BasePart?,
	body: Color3,
	legs: Color3,
	accent: Color3,
	glow: Color3?,
}

-- Shorthand: a piece on body part `name`, sized as a multiple of that part.
local function piece(k: Kit, on: string, label: string, sx: number, sy: number, sz: number, offset: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part?
	local p = k.part(on)
	if not p then
		return nil
	end
	local s = p.Size
	-- Offsets are in units of the part size too.
	local pos = offset.Position
	local rot = offset.Rotation
	local off = CFrame.new(pos.X * s.X, pos.Y * s.Y, pos.Z * s.Z) * rot
	return k.attach(k.model, p, label, Vector3.new(s.X * sx, s.Y * sy, s.Z * sz), off, color, mat, shape)
end

-- Cloth that hangs from a hinge at its top edge (Motor6D "Sway<label>"): the client
-- ClothController swings it with movement. Same sizing/offset rules as piece().
local function hang(k: Kit, on: string, label: string, sx: number, sy: number, sz: number, offset: CFrame, color: Color3, mat: Enum.Material?): Part?
	local base = k.part(on)
	if not base then
		return nil
	end
	local s = base.Size
	local pos = offset.Position
	local center = CFrame.new(pos.X * s.X, pos.Y * s.Y, pos.Z * s.Z) * offset.Rotation
	local size = Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)
	local p = Instance.new("Part")
	p.Name = label
	p.Size = size
	p.Color = color
	p.Material = mat or FABRIC
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = base.CFrame * center
	local hinge = CFrame.new(0, size.Y / 2, 0)
	local m = Instance.new("Motor6D")
	m.Name = "Sway" .. label
	m.Part0 = base
	m.Part1 = p
	m.C0 = center * hinge
	m.C1 = hinge
	m.Parent = p
	p.Parent = k.model
	return p
end

local function both(fn: (string, number) -> ())
	fn("Left", -1)
	fn("Right", 1)
end

-- Pieces shared by several outfits ----------------------------------------------------------
local function obi(k: Kit, color: Color3)
	piece(k, "LowerTorso", "Obi", 1.08, 1.1, 1.12, CFrame.new(0, 0.15, 0), color, FABRIC)
	piece(k, "LowerTorso", "ObiKnot", 0.3, 0.9, 0.25, CFrame.new(0.25, 0.1, -0.6), shade(color, -0.2), FABRIC)
end

local function hakama(k: Kit, color: Color3)
	-- Wide pleated legs: each panel rides its own leg.
	both(function(side, sign)
		piece(k, side .. "UpperLeg", "Hakama", 1.45, 1.05, 1.35, CFrame.new(0.08 * sign, -0.02, 0), color, FABRIC)
		piece(k, side .. "LowerLeg", "HakamaLow", 1.5, 0.9, 1.45, CFrame.new(0.08 * sign, 0.05, 0), color, FABRIC)
	end)
	hang(k, "LowerTorso", "HakamaFront", 1.15, 1.6, 0.2, CFrame.new(0, -0.6, -0.55), shade(color, -0.08), FABRIC)
end

local function kimono(k: Kit, color: Color3, trim: Color3)
	piece(k, "UpperTorso", "Kimono", 1.08, 1.04, 1.12, CFrame.new(0, 0, 0), color, FABRIC)
	-- Crossed collar (left over right) down the chest.
	for _, sign in { -1, 1 } do
		piece(k, "UpperTorso", "Collar", 0.16, 0.95, 0.06, CFrame.new(0.14 * sign, 0.05, -0.58) * CFrame.Angles(0, 0, math.rad(-28 * sign)), trim, FABRIC)
	end
	both(function(side)
		piece(k, side .. "UpperArm", "Sleeve", 1.3, 1.05, 1.3, CFrame.new(0, -0.05, 0), color, FABRIC)
		piece(k, side .. "LowerArm", "SleeveDrop", 1.35, 0.7, 1.5, CFrame.new(0, 0.12, 0.05), color, FABRIC)
	end)
end

local function shoulderPlates(k: Kit, color: Color3, big: number)
	both(function(side, sign)
		local p = piece(k, side .. "UpperArm", "Sode", 1.25 * big, 0.95 * big, 1.35 * big, CFrame.new(0.12 * sign, 0.1, 0) * CFrame.Angles(0, 0, math.rad(-12 * sign)), color, METAL)
		if p then
			-- Lacing stripes across each plate.
			for i = 0, 2 do
				piece(k, side .. "UpperArm", "SodeLace", 1.3 * big, 0.06, 1.4 * big, CFrame.new(0.12 * sign, 0.4 - i * 0.32, 0) * CFrame.Angles(0, 0, math.rad(-12 * sign)), shade(color, 0.35), FABRIC)
			end
		end
	end)
end

local function bracers(k: Kit, color: Color3)
	both(function(side)
		piece(k, side .. "LowerArm", "Kote", 1.18, 0.75, 1.18, CFrame.new(0, -0.1, 0), color, METAL)
	end)
end

local function greaves(k: Kit, color: Color3)
	both(function(side)
		piece(k, side .. "LowerLeg", "Suneate", 1.2, 0.8, 0.35, CFrame.new(0, -0.05, -0.5), color, METAL)
	end)
end

local function wraps(k: Kit, color: Color3, on: string)
	both(function(side)
		for i = 0, 2 do
			piece(k, side .. on, "Wrap", 1.12, 0.12, 1.12, CFrame.new(0, 0.3 - i * 0.3, 0) * CFrame.Angles(0, 0, math.rad(8)), color, FABRIC)
		end
	end)
end

local function cape(k: Kit, color: Color3, length: number)
	hang(k, "UpperTorso", "Cape", 1.15, length, 0.12, CFrame.new(0, 0.5 - length / 2, 0.62) * CFrame.Angles(math.rad(-6), 0, 0), color, FABRIC)
end

-- Outfits -------------------------------------------------------------------------------------
local outfits: { [string]: (Kit) -> () } = {
	-- Wandering swordsman: kimono, hakama, obi.
	Ronin = function(k)
		kimono(k, k.body, k.accent)
		obi(k, k.accent)
		hakama(k, k.legs)
		wraps(k, shade(k.legs, 0.4), "LowerLeg")
	end,
	-- Full lamellar armor: chest plate, big shoulder plates, skirt plates, bracers, greaves.
	Samurai = function(k)
		kimono(k, shade(k.body, -0.35), k.accent)
		local plate = k.accent
		piece(k, "UpperTorso", "Do", 1.18, 0.95, 1.22, CFrame.new(0, -0.02, 0), k.body, METAL)
		for i = 0, 3 do
			piece(k, "UpperTorso", "DoLace", 1.22, 0.05, 1.26, CFrame.new(0, 0.32 - i * 0.22, 0), shade(plate, 0.3), FABRIC)
		end
		piece(k, "UpperTorso", "Crest", 0.35, 0.3, 0.06, CFrame.new(0, 0.2, -0.64), shade(plate, 0.5), METAL)
		shoulderPlates(k, k.body, 1)
		-- Skirt plates (kusazuri): front/back on the hips, sides ride the thighs.
		piece(k, "LowerTorso", "Kusazuri", 0.55, 2.4, 0.12, CFrame.new(-0.24, -0.9, -0.6), k.body, METAL)
		piece(k, "LowerTorso", "Kusazuri", 0.55, 2.4, 0.12, CFrame.new(0.24, -0.9, -0.6), k.body, METAL)
		piece(k, "LowerTorso", "Kusazuri", 1.05, 2.4, 0.12, CFrame.new(0, -0.9, 0.6), k.body, METAL)
		both(function(side, sign)
			piece(k, side .. "UpperLeg", "KusazuriSide", 0.14, 0.75, 1.15, CFrame.new(0.6 * sign, 0.15, 0), k.body, METAL)
		end)
		obi(k, plate)
		hakama(k, k.legs)
		bracers(k, shade(k.body, -0.2))
		greaves(k, shade(k.body, -0.2))
	end,
	-- Robed warrior monk: long robe panels, kesa sash, prayer beads.
	Monk = function(k)
		piece(k, "UpperTorso", "Robe", 1.1, 1.05, 1.14, CFrame.new(), k.body, FABRIC)
		piece(k, "UpperTorso", "Kesa", 0.35, 1.25, 1.18, CFrame.new(0.05, 0, 0) * CFrame.Angles(0, 0, math.rad(35)), k.accent, FABRIC)
		hang(k, "LowerTorso", "RobeFront", 1.12, 4.2, 0.16, CFrame.new(0, -1.9, -0.55), k.body, FABRIC)
		hang(k, "LowerTorso", "RobeBack", 1.12, 4.2, 0.16, CFrame.new(0, -1.9, 0.55), k.body, FABRIC)
		both(function(side, sign)
			piece(k, side .. "UpperLeg", "RobeSide", 0.16, 1.05, 1.1, CFrame.new(0.58 * sign, 0, 0), k.body, FABRIC)
			piece(k, side .. "UpperArm", "Sleeve", 1.35, 1.05, 1.35, CFrame.new(0, -0.05, 0), k.body, FABRIC)
			piece(k, side .. "LowerArm", "SleeveDrop", 1.5, 0.8, 1.6, CFrame.new(0, 0.1, 0.05), k.body, FABRIC)
		end)
		-- Prayer beads around the neck.
		local torso = k.part("UpperTorso")
		if torso then
			for i = 0, 9 do
				local a = i / 10 * math.pi * 2
				local s = torso.Size
				k.attach(k.model, torso, "Bead", Vector3.new(0.22, 0.22, 0.22), CFrame.new(math.cos(a) * s.X * 0.28, s.Y * 0.38 - math.abs(math.sin(a)) * 0.05, math.sin(a) * s.Z * 0.58 - (if math.sin(a) < 0 then 0.06 else 0)), Color3.fromRGB(60, 35, 25), WOOD, Enum.PartType.Ball)
			end
		end
		obi(k, shade(k.accent, -0.2))
	end,
	-- Shinobi: fitted dark wraps, trailing scarf, belt pouches, shin and forearm bindings.
	Shinobi = function(k)
		piece(k, "UpperTorso", "Gi", 1.04, 1.02, 1.08, CFrame.new(), k.body, FABRIC)
		piece(k, "UpperTorso", "Scarf", 1.15, 0.28, 1.2, CFrame.new(0, 0.42, 0), k.accent, FABRIC)
		hang(k, "UpperTorso", "ScarfTail", 0.25, 1.4, 0.08, CFrame.new(0.25, -0.15, 0.6) * CFrame.Angles(math.rad(-10), 0, math.rad(8)), k.accent, FABRIC)
		hang(k, "UpperTorso", "ScarfTail2", 0.22, 1.15, 0.08, CFrame.new(0.05, -0.05, 0.62) * CFrame.Angles(math.rad(-8), 0, math.rad(-6)), shade(k.accent, -0.15), FABRIC)
		piece(k, "LowerTorso", "Belt", 1.08, 0.7, 1.12, CFrame.new(0, 0.1, 0), shade(k.body, 0.12), FABRIC)
		both(function(side, sign)
			piece(k, "LowerTorso", "Pouch", 0.22, 0.9, 0.3, CFrame.new(0.46 * sign, -0.2, -0.45), Color3.fromRGB(70, 55, 40), FABRIC)
		end)
		wraps(k, shade(k.body, 0.25), "LowerArm")
		wraps(k, shade(k.body, 0.25), "LowerLeg")
	end,
	-- Bandit: ragged vest, rope belt, one shoulder plate, leg wraps.
	Bandit = function(k)
		piece(k, "UpperTorso", "Vest", 1.1, 0.95, 1.14, CFrame.new(0, -0.02, 0), k.body, FABRIC)
		piece(k, "UpperTorso", "VestRag", 0.4, 0.35, 0.08, CFrame.new(-0.3, -0.55, -0.58) * CFrame.Angles(0, 0, math.rad(12)), shade(k.body, -0.2), FABRIC)
		piece(k, "LowerTorso", "Rope", 1.1, 0.4, 1.14, CFrame.new(0, 0.2, 0), Color3.fromRGB(170, 140, 90), FABRIC)
		piece(k, "LeftUpperArm", "Pauldron", 1.35, 0.8, 1.4, CFrame.new(-0.1, 0.18, 0) * CFrame.Angles(0, 0, math.rad(10)), shade(k.accent, -0.1), METAL)
		piece(k, "LeftUpperArm", "PauldronStrap", 0.2, 1.3, 1.45, CFrame.new(0.4, 0.4, 0), Color3.fromRGB(70, 50, 35), FABRIC)
		wraps(k, Color3.fromRGB(190, 175, 145), "LowerLeg")
		wraps(k, Color3.fromRGB(190, 175, 145), "LowerArm")
	end,
	-- Archer: chest guard, quiver with arrows, hakama.
	Archer = function(k)
		kimono(k, k.body, k.accent)
		piece(k, "UpperTorso", "MuneAte", 0.55, 0.6, 0.08, CFrame.new(-0.22, 0.12, -0.6), Color3.fromRGB(30, 26, 24), Enum.Material.Leather)
		local q = piece(k, "UpperTorso", "Quiver", 0.3, 1.2, 0.3, CFrame.new(0.2, 0.1, 0.72) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(90, 55, 35), Enum.Material.Leather)
		if q then
			for i = -1, 1 do
				k.attach(k.model, q, "Arrow", Vector3.new(0.06, 0.6, 0.06), CFrame.new(i * 0.08, q.Size.Y * 0.6, 0), Color3.fromRGB(240, 235, 225), FABRIC)
			end
		end
		obi(k, k.accent)
		hakama(k, k.legs)
	end,
	-- Hoplite: bronze cuirass, leather strip skirt, greaves, round shield, red cloak.
	Hoplite = function(k)
		local bronze = Color3.fromRGB(185, 125, 60)
		piece(k, "UpperTorso", "Cuirass", 1.16, 1.0, 1.2, CFrame.new(), bronze, METAL)
		piece(k, "UpperTorso", "Pecs", 0.8, 0.12, 0.05, CFrame.new(0, 0.12, -0.62), shade(bronze, 0.25), METAL)
		for i = -2, 2 do
			piece(k, "LowerTorso", "Pteruges", 0.17, 2.3, 1.15, CFrame.new(i * 0.2, -0.85, 0), Color3.fromRGB(120, 80, 45), Enum.Material.Leather)
		end
		greaves(k, bronze)
		local arm = k.part("LeftLowerArm")
		if arm then
			k.attach(k.model, arm, "Aspis", Vector3.new(0.35, arm.Size.Y * 3.2, arm.Size.Y * 3.2), CFrame.new(-arm.Size.X * 0.8, 0, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(90), 0), bronze, METAL, Enum.PartType.Cylinder)
			k.attach(k.model, arm, "AspisBoss", Vector3.new(0.4, arm.Size.Y * 1.1, arm.Size.Y * 1.1), CFrame.new(-arm.Size.X * 0.95, 0, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(90), 0), k.accent, METAL, Enum.PartType.Cylinder)
		end
		cape(k, k.accent, 2.2)
	end,
	-- Cyber: armored chest rig with glowing strips, shoulder and knee plates.
	Cyber = function(k)
		local glow = k.glow or Color3.fromRGB(60, 230, 255)
		piece(k, "UpperTorso", "ChestRig", 1.14, 0.9, 1.18, CFrame.new(0, 0.02, 0), shade(k.body, -0.2), METAL)
		both(function(_, sign)
			piece(k, "UpperTorso", "NeonStrip", 0.08, 0.75, 0.04, CFrame.new(0.32 * sign, 0, -0.62), glow, NEON)
		end)
		piece(k, "UpperTorso", "Core", 0.22, 0.22, 0.05, CFrame.new(0, 0.18, -0.62), glow, NEON)
		both(function(side, sign)
			piece(k, side .. "UpperArm", "ShoulderPlate", 1.3, 0.7, 1.35, CFrame.new(0.1 * sign, 0.25, 0), k.accent, METAL)
			piece(k, side .. "LowerLeg", "KneePlate", 1.1, 0.35, 0.3, CFrame.new(0, 0.38, -0.55), k.accent, METAL)
			piece(k, side .. "LowerArm", "ArmLight", 1.12, 0.06, 1.12, CFrame.new(0, -0.2, 0), glow, NEON)
		end)
		piece(k, "LowerTorso", "Belt", 1.1, 0.6, 1.14, CFrame.new(0, 0.1, 0), Color3.fromRGB(30, 30, 36), METAL)
	end,
	-- Robe: Greek chiton with a draped mantle and a sash.
	Robe = function(k)
		piece(k, "UpperTorso", "Chiton", 1.08, 1.03, 1.12, CFrame.new(), k.body, FABRIC)
		piece(k, "UpperTorso", "Mantle", 0.55, 1.1, 1.2, CFrame.new(-0.25, 0, 0) * CFrame.Angles(0, 0, math.rad(-20)), k.accent, FABRIC)
		piece(k, "LowerTorso", "Skirt", 1.12, 4.0, 1.16, CFrame.new(0, -1.75, 0), k.legs, FABRIC)
		piece(k, "LowerTorso", "Sash", 1.15, 0.5, 1.2, CFrame.new(0, 0.3, 0), shade(k.accent, -0.15), FABRIC)
	end,
	-- Noble / elder: a long haori jacket over a kimono.
	Noble = function(k)
		kimono(k, k.body, k.accent)
		piece(k, "UpperTorso", "Haori", 1.18, 1.08, 1.2, CFrame.new(0, -0.02, 0.03), shade(k.body, -0.25), FABRIC)
		hang(k, "LowerTorso", "HaoriTail", 1.18, 2.6, 0.14, CFrame.new(0, -1.1, 0.6), shade(k.body, -0.25), FABRIC)
		piece(k, "UpperTorso", "Crest", 0.2, 0.2, 0.05, CFrame.new(0, 0.25, 0.64), k.accent, FABRIC, Enum.PartType.Ball)
		obi(k, k.accent)
		hakama(k, k.legs)
	end,
}


local function light(part: BasePart, color: Color3, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1.5
	l.Parent = part
end

-- Headwear (look.headwear) ------------------------------------------------------------------
local headwear: { [string]: (Model, BasePart, Look, Attach) -> () } = {
	Hood = function(model, head, look, attach)
		local c = rgb(look.accent or look.body)
		local s = head.Size
		attach(model, head, "Hood", Vector3.new(s.X * 1.25, s.Y * 0.7, s.Z * 1.2), CFrame.new(0, s.Y * 0.3, s.Z * 0.12), c, Enum.Material.Fabric)
		attach(model, head, "HoodBack", Vector3.new(s.X * 1.2, s.Y * 1.1, s.Z * 0.35), CFrame.new(0, 0, s.Z * 0.6), c, Enum.Material.Fabric)
	end,
	Helm = function(model, head, look, attach)
		local c = rgb(look.accent or { 90, 90, 100 })
		local s = head.Size
		attach(model, head, "Helm", Vector3.new(s.X * 1.15, s.Y * 0.55, s.Z * 1.15), CFrame.new(0, s.Y * 0.35, 0), c, Enum.Material.Metal)
		attach(model, head, "Brim", Vector3.new(s.X * 1.6, s.Y * 0.1, s.Z * 1.6), CFrame.new(0, s.Y * 0.12, 0), c, Enum.Material.Metal)
	end,
	Horns = function(model, head, look, attach)
		local c = rgb(look.accent or { 40, 30, 25 })
		local s = head.Size
		for _, side in { -1, 1 } do
			attach(model, head, "Horn", Vector3.new(s.X * 0.18, s.Y * 0.8, s.Z * 0.18), CFrame.new(side * s.X * 0.4, s.Y * 0.75, 0) * CFrame.Angles(0, 0, math.rad(-25 * side)), c, Enum.Material.SmoothPlastic)
		end
	end,
	Lantern = function(model, head, look, attach)
		local c = rgb(look.glow or look.accent or { 255, 190, 90 })
		local s = head.Size
		attach(model, head, "LanternStem", Vector3.new(0.1, s.Y * 0.6, 0.1), CFrame.new(0, s.Y * 0.8, 0), Color3.fromRGB(40, 35, 30), Enum.Material.Metal)
		local lamp = attach(model, head, "Lantern", Vector3.new(s.X * 0.5, s.Y * 0.6, s.Z * 0.5), CFrame.new(0, s.Y * 1.35, 0), c, Enum.Material.Neon)
		light(lamp, c, 12)
	end,
	Sack = function(model, head, look, attach)
		local s = head.Size
		attach(model, head, "Sack", Vector3.new(s.X * 1.15, s.Y * 1.15, s.Z * 1.15), CFrame.new(), rgb(look.skin), Enum.Material.Fabric)
	end,
	Hair = function(model, head, look, attach)
		local c = rgb(look.accent or { 30, 20, 20 })
		local s = head.Size
		attach(model, head, "Hair", Vector3.new(s.X * 1.08, s.Y * 0.45, s.Z * 1.08), CFrame.new(0, s.Y * 0.35, s.Z * 0.05), Color3.fromRGB(25, 18, 18), Enum.Material.SmoothPlastic)
		attach(model, head, "Bun", Vector3.new(s.X * 0.5, s.X * 0.5, s.X * 0.5), CFrame.new(0, s.Y * 0.75, s.Z * 0.25), c, Enum.Material.Neon, Enum.PartType.Ball)
	end,
	-- Cyber visor: a glowing slit band and a chrome jaw plate.
	Visor = function(model, head, look, attach)
		local s = head.Size
		local glow = rgb(look.glow or { 60, 230, 255 })
		attach(model, head, "VisorBand", Vector3.new(s.X * 1.12, s.Y * 0.28, s.Z * 1.12), CFrame.new(0, s.Y * 0.08, 0), Color3.fromRGB(25, 25, 32), Enum.Material.Metal)
		local slit = attach(model, head, "VisorGlow", Vector3.new(s.X * 0.9, s.Y * 0.1, 0.05), CFrame.new(0, s.Y * 0.08, -s.Z * 0.57), glow, Enum.Material.Neon)
		light(slit, glow, 10)
		attach(model, head, "JawPlate", Vector3.new(s.X * 0.9, s.Y * 0.3, s.Z * 0.3), CFrame.new(0, -s.Y * 0.32, -s.Z * 0.42), rgb(look.accent or { 160, 160, 175 }), Enum.Material.Metal)
	end,
	-- Hoplite helmet with a tall horsehair crest.
	Crest = function(model, head, look, attach)
		local s = head.Size
		local bronze = Color3.fromRGB(180, 120, 60)
		attach(model, head, "Helmet", Vector3.new(s.X * 1.18, s.Y * 1.05, s.Z * 1.18), CFrame.new(0, s.Y * 0.08, 0), bronze, Enum.Material.Metal)
		attach(model, head, "Crest", Vector3.new(s.X * 0.22, s.Y * 0.8, s.Z * 1.5), CFrame.new(0, s.Y * 0.85, s.Z * 0.1), rgb(look.accent or { 170, 30, 30 }), Enum.Material.Fabric)
		attach(model, head, "EyeSlit", Vector3.new(s.X * 0.7, s.Y * 0.12, 0.05), CFrame.new(0, s.Y * 0.1, -s.Z * 0.6), Color3.fromRGB(10, 10, 10), Enum.Material.SmoothPlastic)
	end,
	-- Laurel wreath (Greek nobles / the Archon).
	Laurel = function(model, head, look, attach)
		local s = head.Size
		local gold = rgb(look.glow or { 255, 205, 90 })
		attach(model, head, "Laurel", Vector3.new(s.Y * 0.18, s.X * 1.2, s.X * 1.2), CFrame.new(0, s.Y * 0.38, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Neon, Enum.PartType.Cylinder)
	end,
	Bell = function(model, head, look, attach)
		local c = rgb(look.body)
		local s = head.Size
		attach(model, head, "BellCrown", Vector3.new(s.Y * 2.2, s.X * 2.2, s.X * 2.2), CFrame.new(0, s.Y * 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), c, Enum.Material.Metal, Enum.PartType.Cylinder)
		local slit = attach(model, head, "BellSlit", Vector3.new(s.X * 1.2, s.Y * 0.15, 0.05), CFrame.new(0, 0, -s.Z * 1.11), rgb(look.glow or { 255, 200, 120 }), Enum.Material.Neon)
		light(slit, rgb(look.glow or { 255, 200, 120 }), 14)
	end,
	-- Straw kasa: a wide conical hat (stacked discs) with a chin cord.
	Kasa = function(model, head, look, attach)
		local s = head.Size
		local straw = Color3.fromRGB(196, 168, 110)
		for i, k in { { 2.6, 0.12 }, { 1.9, 0.14 }, { 1.2, 0.16 }, { 0.5, 0.2 } } do
			attach(model, head, "Kasa", Vector3.new(s.Y * k[2], s.X * k[1], s.X * k[1]), CFrame.new(0, s.Y * (0.5 + i * 0.09), 0) * CFrame.Angles(0, 0, math.rad(90)), straw:Lerp(Color3.new(0, 0, 0), i * 0.05), Enum.Material.Fabric, Enum.PartType.Cylinder)
		end
		attach(model, head, "KasaCord", Vector3.new(0.06, s.Y * 0.9, 0.06), CFrame.new(s.X * 0.46, 0, -s.Z * 0.1), rgb(look.accent or { 120, 40, 35 }), Enum.Material.Fabric)
	end,
	-- Samurai kabuto: lamellar bowl, neck guard flaps and a gold crescent crest.
	Kabuto = function(model, head, look, attach)
		local s = head.Size
		local iron = rgb(look.accent or { 50, 48, 54 })
		local gold = Color3.fromRGB(220, 180, 80)
		attach(model, head, "KabutoBowl", Vector3.new(s.X * 1.16, s.Y * 0.62, s.Z * 1.16), CFrame.new(0, s.Y * 0.36, 0), iron, Enum.Material.Metal)
		attach(model, head, "KabutoBrim", Vector3.new(s.X * 1.3, s.Y * 0.08, s.Z * 0.4), CFrame.new(0, s.Y * 0.1, -s.Z * 0.55) * CFrame.Angles(math.rad(-14), 0, 0), iron, Enum.Material.Metal)
		for i = 0, 2 do
			attach(model, head, "Shikoro", Vector3.new(s.X * (1.3 + i * 0.12), s.Y * 0.14, s.Z * (1.2 + i * 0.1)), CFrame.new(0, s.Y * (0.05 - i * 0.16), s.Z * (0.12 + i * 0.05)) * CFrame.Angles(math.rad(10 + i * 6), 0, 0), iron:Lerp(Color3.new(0, 0, 0), i * 0.12), Enum.Material.Metal)
		end
		for _, sign in { -1, 1 } do
			attach(model, head, "Kuwagata", Vector3.new(s.X * 0.1, s.Y * 0.85, s.Z * 0.06), CFrame.new(sign * s.X * 0.22, s.Y * 0.95, -s.Z * 0.5) * CFrame.Angles(0, 0, math.rad(-22 * sign)), gold, Enum.Material.Metal)
		end
		attach(model, head, "Maedate", Vector3.new(s.X * 0.22, s.Y * 0.22, s.Z * 0.06), CFrame.new(0, s.Y * 0.58, -s.Z * 0.6), gold, Enum.Material.Neon)
	end,
}

-- Masks ---------------------------------------------------------------------------------------
local masks: { [string]: (Kit, BasePart) -> () } = {
	-- Red demon face plate with fangs and brow ridges.
	Oni = function(k, head)
		local s = head.Size
		local red = Color3.fromRGB(170, 30, 25)
		k.attach(k.model, head, "OniMask", Vector3.new(s.X * 0.95, s.Y * 0.9, 0.25), CFrame.new(0, -s.Y * 0.02, -s.Z * 0.55), red, PLASTIC)
		k.attach(k.model, head, "OniBrow", Vector3.new(s.X * 0.95, s.Y * 0.16, 0.3), CFrame.new(0, s.Y * 0.2, -s.Z * 0.62) * CFrame.Angles(math.rad(-12), 0, 0), shade(red, -0.35), PLASTIC)
		for _, sign in { -1, 1 } do
			k.attach(k.model, head, "OniFang", Vector3.new(0.12, s.Y * 0.22, 0.12), CFrame.new(sign * s.X * 0.2, -s.Y * 0.32, -s.Z * 0.7), Color3.fromRGB(240, 235, 220), PLASTIC)
			k.attach(k.model, head, "OniEye", Vector3.new(s.X * 0.18, s.Y * 0.07, 0.05), CFrame.new(sign * s.X * 0.2, s.Y * 0.08, -s.Z * 0.69) * CFrame.Angles(0, 0, math.rad(-15 * sign)), k.glow or Color3.fromRGB(255, 200, 80), NEON)
		end
	end,
	-- Iron half mask covering mouth and jaw.
	Menpo = function(k, head)
		local s = head.Size
		local iron = Color3.fromRGB(40, 38, 42)
		k.attach(k.model, head, "Menpo", Vector3.new(s.X * 0.95, s.Y * 0.42, 0.28), CFrame.new(0, -s.Y * 0.26, -s.Z * 0.53), iron, METAL)
		k.attach(k.model, head, "MenpoNose", Vector3.new(s.X * 0.18, s.Y * 0.18, 0.25), CFrame.new(0, -s.Y * 0.05, -s.Z * 0.66), iron, METAL)
		for i = -1, 1 do
			k.attach(k.model, head, "MenpoTeeth", Vector3.new(s.X * 0.08, s.Y * 0.1, 0.05), CFrame.new(i * s.X * 0.12, -s.Y * 0.28, -s.Z * 0.69), Color3.fromRGB(220, 210, 190), PLASTIC)
		end
	end,
	-- White fox mask with red markings.
	Kitsune = function(k, head)
		local s = head.Size
		local white = Color3.fromRGB(240, 236, 228)
		local red = Color3.fromRGB(200, 40, 40)
		k.attach(k.model, head, "Kitsune", Vector3.new(s.X * 0.9, s.Y * 0.85, 0.25), CFrame.new(0, 0, -s.Z * 0.55), white, PLASTIC)
		k.attach(k.model, head, "KitsuneSnout", Vector3.new(s.X * 0.35, s.Y * 0.3, s.Z * 0.35), CFrame.new(0, -s.Y * 0.15, -s.Z * 0.78), white, PLASTIC)
		k.attach(k.model, head, "KitsuneNose", Vector3.new(s.X * 0.12, s.Y * 0.08, 0.05), CFrame.new(0, -s.Y * 0.1, -s.Z * 0.97), Color3.fromRGB(20, 20, 20), PLASTIC)
		for _, sign in { -1, 1 } do
			k.attach(k.model, head, "KitsuneEar", Vector3.new(s.X * 0.22, s.Y * 0.4, 0.15), CFrame.new(sign * s.X * 0.32, s.Y * 0.55, -s.Z * 0.35) * CFrame.Angles(0, 0, math.rad(-14 * sign)), white, PLASTIC)
			k.attach(k.model, head, "KitsuneMark", Vector3.new(s.X * 0.2, s.Y * 0.06, 0.05), CFrame.new(sign * s.X * 0.2, s.Y * 0.1, -s.Z * 0.69) * CFrame.Angles(0, 0, math.rad(-20 * sign)), red, NEON)
		end
	end,
	-- Dark cloth wrap over the lower face.
	Cloth = function(k, head)
		local s = head.Size
		k.attach(k.model, head, "FaceWrap", Vector3.new(s.X * 1.08, s.Y * 0.5, s.Z * 1.08), CFrame.new(0, -s.Y * 0.24, 0), shade(k.body, -0.1), FABRIC)
	end,
	-- Bone-white skull face.
	Skull = function(k, head)
		local s = head.Size
		local bone = Color3.fromRGB(225, 218, 200)
		k.attach(k.model, head, "Skull", Vector3.new(s.X * 0.95, s.Y * 0.95, 0.22), CFrame.new(0, 0, -s.Z * 0.54), bone, PLASTIC)
		for _, sign in { -1, 1 } do
			k.attach(k.model, head, "Socket", Vector3.new(s.X * 0.24, s.Y * 0.2, 0.05), CFrame.new(sign * s.X * 0.2, s.Y * 0.08, -s.Z * 0.66), Color3.fromRGB(15, 12, 12), PLASTIC)
		end
		k.attach(k.model, head, "Jaw", Vector3.new(s.X * 0.55, s.Y * 0.08, 0.05), CFrame.new(0, -s.Y * 0.3, -s.Z * 0.66), Color3.fromRGB(30, 25, 25), PLASTIC)
	end,
}

-- Faces: replaces the stock smile with simple part-built eyes and brows.
local function face(k: Kit, head: BasePart, kind: string)
	local stock = head:FindFirstChildOfClass("Decal")
	if stock then
		stock:Destroy()
	end
	local s = head.Size
	local z = -s.Z * 0.505
	local eye = if kind == "Glow" and k.glow then k.glow else Color3.fromRGB(20, 16, 16)
	local mat = if kind == "Glow" and k.glow then NEON else PLASTIC
	for _, sign in { -1, 1 } do
		if kind == "Calm" then
			k.attach(k.model, head, "Eye", Vector3.new(s.X * 0.1, s.Y * 0.12, 0.04), CFrame.new(sign * s.X * 0.18, s.Y * 0.05, z), eye, mat)
			k.attach(k.model, head, "Brow", Vector3.new(s.X * 0.2, s.Y * 0.04, 0.04), CFrame.new(sign * s.X * 0.18, s.Y * 0.2, z), Color3.fromRGB(40, 30, 28), PLASTIC)
		else
			k.attach(k.model, head, "Eye", Vector3.new(s.X * 0.18, s.Y * 0.06, 0.04), CFrame.new(sign * s.X * 0.18, s.Y * 0.06, z) * CFrame.Angles(0, 0, math.rad(-10 * sign)), eye, mat)
			k.attach(k.model, head, "Brow", Vector3.new(s.X * 0.24, s.Y * 0.06, 0.05), CFrame.new(sign * s.X * 0.18, s.Y * 0.18, z) * CFrame.Angles(0, 0, math.rad(-22 * sign)), Color3.fromRGB(30, 22, 20), PLASTIC)
		end
	end
	k.attach(k.model, head, "Mouth", Vector3.new(s.X * (if kind == "Calm" then 0.16 else 0.26), s.Y * 0.03, 0.04), CFrame.new(0, -s.Y * 0.22, z), Color3.fromRGB(60, 35, 32), PLASTIC)
end

function Outfits.Apply(model: Model, look: Look, attach: Attach)
	local function part(name: string): BasePart?
		local p = model:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end
	local k: Kit = {
		model = model,
		attach = attach,
		part = part,
		body = rgb(look.body),
		legs = rgb(look.legs),
		accent = rgb(look.accent or look.body),
		glow = if look.glow then rgb(look.glow) else nil,
	}
	local head = part("Head")
	if head then
		local f = look.face or (if look.glow then "Glow" else "Grim")
		if look.mask and masks[look.mask] then
			local stock = head:FindFirstChildOfClass("Decal")
			if stock then
				stock:Destroy()
			end
			masks[look.mask](k, head)
		elseif f ~= "None" then
			face(k, head, f)
		end
	end
	if head and look.headwear and headwear[look.headwear] then
		local hb = headwear[look.headwear]
		local h = head
		local ok, err = pcall(function()
			hb(model, h, look, attach)
		end)
		if not ok then
			warn("[Outfits] headwear", look.headwear, err)
		end
	end
	local build = if look.outfit then outfits[look.outfit] else nil
	if build then
		local fn = build
		local ok, err = pcall(function()
			fn(k)
		end)
		if not ok then
			warn("[Outfits]", look.outfit, err)
		end
	end
end

Outfits.Names = {}
for name in outfits do
	table.insert(Outfits.Names, name)
end
Outfits.Headwear = {}
for name in headwear do
	table.insert(Outfits.Headwear, name)
end
Outfits.Masks = {}
for name in masks do
	table.insert(Outfits.Masks, name)
end

return Outfits
