--!strict
-- WeaponModels: builds a simple 3D model for any weapon from WeaponConfig `visual` data, out of
-- plain parts (no uploaded meshes needed). Used for held weapons (server), shop racks and UI
-- icons (ViewportFrame). Model layout: PrimaryPart "Handle" at the grip; the blade/shaft points
-- along the Handle's +Y axis.
-- TODO(Studio/Agent B): replace with sculpted models (WeaponDef.modelId) when available.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponConfig"))

local WeaponModels = {}

type Visual = WeaponConfig.WeaponVisual

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

type Builder = {
	model: Model,
	handle: BasePart,
}

-- Adds a part positioned in Handle space (handle at origin, +Y = blade direction).
local function part(
	b: Builder,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: { number },
	material: Enum.Material?,
	shape: Enum.PartType?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = rgb(color)
	p.Material = material or Enum.Material.Metal
	if shape then
		p.Shape = shape
	end
	p.CFrame = cf
	p.Parent = b.model
	return p
end

local function wedge(b: Builder, name: string, size: Vector3, cf: CFrame, color: { number }, material: Enum.Material?): BasePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.Color = rgb(color)
	w.Material = material or Enum.Material.Metal
	w.CFrame = cf
	w.Parent = b.model
	return w
end

-- Cylinder along Y (Roblox cylinders run along X, so rotate).
local function rod(b: Builder, name: string, length: number, diameter: number, centerY: number, color: { number }, material: Enum.Material?): BasePart
	return part(
		b,
		name,
		Vector3.new(length, diameter, diameter),
		CFrame.new(0, centerY, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function ball(b: Builder, name: string, d: number, y: number, color: { number }, material: Enum.Material?): BasePart
	return part(b, name, Vector3.new(d, d, d), CFrame.new(0, y, 0), color, material, Enum.PartType.Ball)
end

local function glowStrip(b: Builder, v: Visual, length: number, startY: number, thickness: number)
	local glow = v.glow
	if glow == nil then
		return
	end
	local strip = part(b, "Glow", Vector3.new(thickness, length, thickness * 1.6), CFrame.new(0, startY + length / 2, 0), glow, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = rgb(glow)
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = strip
end

local function tassel(b: Builder, v: Visual, y: number)
	local t = v.tassel
	if t == nil then
		return
	end
	part(b, "TasselCord", Vector3.new(0.06, 0.5, 0.06), CFrame.new(0, y - 0.25, 0), t, Enum.Material.Fabric)
	part(b, "Tassel", Vector3.new(0.22, 0.45, 0.22), CFrame.new(0, y - 0.7, 0), t, Enum.Material.Fabric)
end

local shapes: { [string]: (Builder, Visual) -> () } = {}

-- Cord wrap on a grip: thin rings every so often (reads as a bound hilt).
local function wrap(b: Builder, fromY: number, toY: number, diameter: number, color: { number })
	local n = math.max(2, math.floor((toY - fromY) / 0.22))
	for i = 0, n - 1 do
		local y = fromY + (i + 0.5) * (toY - fromY) / n
		rod(b, "Wrap", 0.07, diameter, y, color, Enum.Material.Fabric)
	end
end

local function lighter(c: { number }, k: number): { number }
	return { math.min(255, c[1] + (255 - c[1]) * k), math.min(255, c[2] + (255 - c[2]) * k), math.min(255, c[3] + (255 - c[3]) * k) }
end

shapes.Jian = function(b, v)
	local w = 0.2 * (v.width or 1)
	rod(b, "Grip", 1.1, 0.16, 0.25, v.grip, Enum.Material.Fabric)
	wrap(b, -0.2, 0.75, 0.185, v.accent)
	ball(b, "Pommel", 0.24, -0.35, v.accent)
	part(b, "Guard", Vector3.new(0.75, 0.16, 0.26), CFrame.new(0, 0.86, 0), v.accent)
	part(b, "GuardCap", Vector3.new(0.3, 0.1, 0.3), CFrame.new(0, 0.97, 0), v.accent)
	local bladeLen = v.length - 0.35
	part(b, "Blade", Vector3.new(w, bladeLen, 0.05), CFrame.new(0, 0.94 + bladeLen / 2, 0), v.blade)
	-- Raised center ridge catches the light down the whole length.
	part(b, "Ridge", Vector3.new(w * 0.18, bladeLen * 0.96, 0.07), CFrame.new(0, 0.94 + bladeLen * 0.49, 0), lighter(v.blade, 0.35))
	wedge(b, "TipL", Vector3.new(0.05, 0.35, w / 2), CFrame.new(-w / 4, 0.94 + bladeLen + 0.175, 0) * CFrame.Angles(0, math.rad(90), 0), v.blade)
	wedge(b, "TipR", Vector3.new(0.05, 0.35, w / 2), CFrame.new(w / 4, 0.94 + bladeLen + 0.175, 0) * CFrame.Angles(0, math.rad(-90), 0), v.blade)
	glowStrip(b, v, bladeLen * 0.9, 1.0, 0.04)
	tassel(b, v, -0.45)
end

-- Sabre: a single-edged blade built from short segments that curve back toward the spine,
-- with a bright cutting edge, a dark spine and a cord-wrapped grip with a ring pommel.
shapes.Dao = function(b, v)
	local w = 0.38 * (v.width or 1)
	rod(b, "Grip", 1.2, 0.18, 0.3, v.grip, Enum.Material.Wood)
	wrap(b, -0.2, 0.82, 0.2, v.accent)
	part(b, "PommelRing", Vector3.new(0.06, 0.32, 0.32), CFrame.new(0, -0.42, 0) * CFrame.Angles(0, 0, math.rad(90)), v.accent, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(b, "Guard", Vector3.new(0.14, 0.7, 0.7), CFrame.new(0, 0.94, 0) * CFrame.Angles(0, 0, math.rad(90)), v.accent, Enum.Material.Metal, Enum.PartType.Cylinder)
	local bladeLen = v.length - 0.6
	local segs = 4
	local segLen = bladeLen / segs
	local curve = math.rad(4) -- per segment
	local x, y, a = w * 0.2, 1.0, 0
	for i = 1, segs do
		local dx, dy = -math.sin(a), math.cos(a)
		local cx, cy = x + dx * segLen / 2, y + dy * segLen / 2
		local cf = CFrame.new(cx, cy, 0) * CFrame.Angles(0, 0, a)
		local grow = 1 + (i - 1) * 0.06 -- widens toward the tip
		part(b, "Blade", Vector3.new(w * grow, segLen + 0.04, 0.06), cf, v.blade)
		part(b, "Edge", Vector3.new(0.05, segLen + 0.04, 0.07), cf * CFrame.new(w * grow / 2, 0, 0), lighter(v.blade, 0.55))
		part(b, "Spine", Vector3.new(0.05, segLen + 0.04, 0.09), cf * CFrame.new(-w * grow / 2, 0, 0), v.accent)
		x, y = x + dx * segLen, y + dy * segLen
		a += curve
	end
	local tipCf = CFrame.new(x, y, 0) * CFrame.Angles(0, 0, a - curve)
	wedge(b, "Tip", Vector3.new(0.06, 0.7, w * 1.25), tipCf * CFrame.new(0, 0.33, 0) * CFrame.Angles(0, math.rad(90), 0), v.blade)
	glowStrip(b, v, bladeLen * 0.85, 1.05, 0.05)
	tassel(b, v, -0.5)
end

shapes.Spear = function(b, v)
	local shaft = v.length
	rod(b, "Shaft", shaft, 0.18, shaft / 2 - 1.6, v.grip, Enum.Material.Wood)
	ball(b, "Butt", 0.24, -1.65, v.accent)
	local top = shaft - 1.6
	part(b, "Collar", Vector3.new(0.3, 0.25, 0.3), CFrame.new(0, top + 0.1, 0), v.accent)
	if v.tassel then
		part(b, "Tassel", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, top - 0.15, 0), v.tassel, Enum.Material.Fabric, Enum.PartType.Ball)
	end
	wedge(b, "HeadL", Vector3.new(0.05, 0.9, 0.18), CFrame.new(-0.09, top + 0.65, 0) * CFrame.Angles(0, math.rad(90), 0), v.blade)
	wedge(b, "HeadR", Vector3.new(0.05, 0.9, 0.18), CFrame.new(0.09, top + 0.65, 0) * CFrame.Angles(0, math.rad(-90), 0), v.blade)
	part(b, "HeadBase", Vector3.new(0.36, 0.3, 0.05), CFrame.new(0, top + 0.35, 0), v.blade)
	glowStrip(b, v, 0.8, top + 0.25, 0.04)
end

shapes.Fan = function(b, v)
	rod(b, "Grip", 0.5, 0.14, 0, v.grip, Enum.Material.Wood)
	ball(b, "Rivet", 0.2, 0.25, v.accent)
	local ribs = 9
	local spread = 150
	for i = 0, ribs - 1 do
		local angle = math.rad(-spread / 2 + spread * i / (ribs - 1))
		local pivot = CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, angle)
		part(b, "Rib" .. i, Vector3.new(0.06, v.length, 0.04), pivot * CFrame.new(0, v.length / 2, 0), v.accent)
		-- Leaf between ribs (paper/steel), slightly shorter and wider.
		if i < ribs - 1 then
			local mid = CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, angle + math.rad(spread / (ribs - 1) / 2))
			part(b, "Leaf" .. i, Vector3.new(v.length * 0.28, v.length * 0.62, 0.02), mid * CFrame.new(0, v.length * 0.62, 0), v.blade, Enum.Material.SmoothPlastic)
		end
	end
	if v.glow then
		local tip = part(b, "Glow", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0, 0.25, 0), v.glow, Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = rgb(v.glow)
		light.Range = 6
		light.Parent = tip
	end
	tassel(b, v, -0.25)
end

shapes.Staff = function(b, v)
	local len = v.length
	rod(b, "Shaft", len, 0.2, len / 2 - len * 0.35, v.blade, Enum.Material.Wood)
	local bottom = -len * 0.35
	local top = len - len * 0.35
	rod(b, "CapTop", 0.5, 0.32, top - 0.25, v.accent)
	rod(b, "CapBottom", 0.5, 0.32, bottom + 0.25, v.accent)
	rod(b, "Wrap", 0.9, 0.25, 0.1, v.tassel or v.accent, Enum.Material.Fabric)
	if v.glow then
		local g = ball(b, "Glow", 0.3, top + 0.05, v.glow, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = rgb(v.glow)
		light.Range = 8
		light.Parent = g
	end
end

shapes.Greatblade = function(b, v)
	local w = 0.7 * (v.width or 1)
	rod(b, "Grip", 1.6, 0.2, 0.4, v.grip, Enum.Material.Fabric)
	ball(b, "Pommel", 0.3, -0.45, v.accent)
	part(b, "Guard", Vector3.new(1.2, 0.24, 0.34), CFrame.new(0, 1.3, 0), v.accent)
	local bladeLen = v.length - 0.8
	part(b, "Blade", Vector3.new(w, bladeLen, 0.12), CFrame.new(0, 1.42 + bladeLen / 2, 0), v.blade)
	part(b, "Fuller", Vector3.new(w * 0.2, bladeLen * 0.8, 0.13), CFrame.new(0, 1.5 + bladeLen * 0.4, 0), v.accent)
	wedge(b, "Tip", Vector3.new(0.12, 0.8, w), CFrame.new(0, 1.42 + bladeLen + 0.4, 0) * CFrame.Angles(0, math.rad(90), 0), v.blade)
	glowStrip(b, v, bladeLen * 0.85, 1.55, 0.06)
	tassel(b, v, -0.6)
end

-- Blade span in handle space (base -> tip along +Y) per class, for trails and the parry glint.
local function bladeSpan(class: string, v: Visual): (number, number)
	local L = v.length
	if class == "Jian" then
		return 1.0, L + 0.9
	elseif class == "Dao" then
		return 1.05, L + 1.05
	elseif class == "Spear" then
		return L - 1.8, L - 0.5
	elseif class == "Fan" then
		return 0.6, L + 0.2
	elseif class == "Staff" then
		return L * 0.1, L * 0.65
	end
	return 1.5, L + 1.4 -- Greatblade
end

-- Adds TrailBase/TrailTip attachments, a disabled "SwingTrail" (clients enable it during
-- active frames) and a "Glint" attachment at the tip (parry-timing flash).
local function addTrail(handle: BasePart, class: string, v: Visual)
	local baseY, tipY = bladeSpan(class, v)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBase"
	a0.Position = Vector3.new(0, baseY, 0)
	a0.Parent = handle
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.Position = Vector3.new(0, tipY, 0)
	a1.Parent = handle
	local glint = Instance.new("Attachment")
	glint.Name = "Glint"
	glint.Position = Vector3.new(0, tipY - 0.2, 0)
	glint.Parent = handle
	local color = if v.glow then rgb(v.glow) else rgb(v.blade):Lerp(Color3.new(1, 1, 1), 0.6)
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.5))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	trail.LightEmission = 1
	trail.Lifetime = 0.2
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = handle
end

-- Builds the weapon model. anchored = true for displays (racks, viewports); false for held
-- weapons (parts are massless, non-colliding and welded to Handle).
function WeaponModels.Build(weaponId: string, anchored: boolean): Model?
	local def = WeaponConfig.Weapons[weaponId]
	if def == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = def.name
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CFrame = CFrame.new()
	handle.Parent = model
	model.PrimaryPart = handle

	local b: Builder = { model = model, handle = handle }
	local shape = shapes[def.class]
	if shape then
		shape(b, def.visual)
	end
	if not anchored then
		addTrail(handle, def.class, def.visual)
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.CastShadow = anchored
			if d ~= handle and not anchored then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	model:SetAttribute("WeaponId", weaponId)
	return model
end

-- Builds the weapon and welds it into `rig`'s right hand (R15 RightHand or R6 Right Arm),
-- replacing any previous model with the same name. The grip uses only the hand part's own
-- axes: blade (+Y) along the hand's forward (-Z), so a hanging arm points the weapon ahead.
function WeaponModels.AttachToHand(rig: Model, weaponId: string, name: string): Model?
	local old = rig:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local hand = rig:FindFirstChild("RightHand") or rig:FindFirstChild("Right Arm")
	if hand == nil or not hand:IsA("BasePart") then
		return nil
	end
	local model = WeaponModels.Build(weaponId, false)
	if model == nil then
		return nil
	end
	model.Name = name
	local handle = model.PrimaryPart :: BasePart
	local r = WeaponConfig.GripRotation
	local offset = CFrame.new(0, -hand.Size.Y * WeaponConfig.GripDepth, 0) * CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
	model:PivotTo(hand.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Name = "GripWeld"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = offset
	-- Clients swing the weapon by offsetting C0 from this base (AnimationController).
	weld:SetAttribute("BaseC0", offset)
	weld.Parent = handle
	model.Parent = rig
	return model
end

-- Rough bounding length (for camera framing in viewports / rack spacing).
function WeaponModels.Length(weaponId: string): number
	local def = WeaponConfig.Weapons[weaponId]
	if def == nil then
		return 3
	end
	if def.class == "Spear" or def.class == "Staff" then
		return def.visual.length
	end
	return def.visual.length + 1.4
end

return WeaponModels
