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

shapes.Jian = function(b, v)
	local w = 0.2 * (v.width or 1)
	rod(b, "Grip", 1.1, 0.16, 0.25, v.grip, Enum.Material.Fabric)
	ball(b, "Pommel", 0.24, -0.35, v.accent)
	part(b, "Guard", Vector3.new(0.75, 0.16, 0.26), CFrame.new(0, 0.86, 0), v.accent)
	local bladeLen = v.length - 0.35
	part(b, "Blade", Vector3.new(w, bladeLen, 0.05), CFrame.new(0, 0.94 + bladeLen / 2, 0), v.blade)
	wedge(b, "TipL", Vector3.new(0.05, 0.35, w / 2), CFrame.new(-w / 4, 0.94 + bladeLen + 0.175, 0) * CFrame.Angles(0, math.rad(90), 0), v.blade)
	wedge(b, "TipR", Vector3.new(0.05, 0.35, w / 2), CFrame.new(w / 4, 0.94 + bladeLen + 0.175, 0) * CFrame.Angles(0, math.rad(-90), 0), v.blade)
	glowStrip(b, v, bladeLen * 0.9, 1.0, 0.04)
	tassel(b, v, -0.45)
end

shapes.Dao = function(b, v)
	local w = 0.38 * (v.width or 1)
	rod(b, "Grip", 1.2, 0.18, 0.3, v.grip, Enum.Material.Wood)
	ball(b, "Pommel", 0.22, -0.32, v.accent)
	part(b, "Guard", Vector3.new(0.14, 0.7, 0.7), CFrame.new(0, 0.94, 0) * CFrame.Angles(0, 0, math.rad(90)), v.accent, Enum.Material.Metal, Enum.PartType.Cylinder)
	local bladeLen = v.length - 0.6
	-- Blade sits slightly forward of the grip line, widening toward the tip.
	part(b, "Blade", Vector3.new(w, bladeLen, 0.06), CFrame.new(w * 0.2, 1.0 + bladeLen / 2, 0), v.blade)
	part(b, "Spine", Vector3.new(0.05, bladeLen, 0.09), CFrame.new(-w * 0.3, 1.0 + bladeLen / 2, 0), v.accent)
	wedge(b, "Tip", Vector3.new(0.06, 0.7, w * 1.15), CFrame.new(w * 0.25, 1.0 + bladeLen + 0.35, 0) * CFrame.Angles(0, math.rad(90), 0), v.blade)
	glowStrip(b, v, bladeLen * 0.9, 1.05, 0.05)
	tassel(b, v, -0.42)
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
	rod(b, "CapTop", 0.4, 0.26, top - 0.2, v.accent)
	rod(b, "CapBottom", 0.4, 0.26, bottom + 0.2, v.accent)
	rod(b, "Wrap", 0.8, 0.22, 0.1, v.grip, Enum.Material.Fabric)
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
