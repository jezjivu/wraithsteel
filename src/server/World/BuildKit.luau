--!strict
-- BuildKit: tiny helpers shared by the realm builders (anchored parts, cylinders, signs, lights).

local BuildKit = {}

function BuildKit.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function BuildKit.part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	if math.max(size.X, size.Y, size.Z) < 3 then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

-- Decoration that should never block movement.
function BuildKit.decor(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = BuildKit.part(parent, name, size, cf, color, material, shape)
	p.CanCollide = false
	p.CanQuery = false
	return p
end

function BuildKit.wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.CanTouch = false
	w.Parent = parent
	return w
end

-- Vertical cylinder standing on `base` (Roblox cylinders run along X).
function BuildKit.column(parent: Instance, name: string, height: number, diameter: number, base: Vector3, color: Color3, material: Enum.Material?): Part
	return BuildKit.part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

-- Flat disc lying on the ground, top at base.Y.
function BuildKit.disc(parent: Instance, name: string, diameter: number, thickness: number, base: Vector3, color: Color3, material: Enum.Material?): Part
	return BuildKit.part(parent, name, Vector3.new(thickness, diameter, diameter), CFrame.new(base - Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

function BuildKit.light(p: BasePart, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.5
	l.Parent = p
end

-- Text on both big faces of a part.
function BuildKit.sign(p: BasePart, text: string, color: Color3, font: Enum.Font?, faces: { Enum.NormalId }?)
	local list: { Enum.NormalId } = faces or { Enum.NormalId.Front, Enum.NormalId.Back }
	for _, face in list do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(400, math.max(60, 400 * p.Size.Y / math.max(p.Size.X, 0.1)))
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.Parent = p
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = font or Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = color
		t.Text = text
		t.Parent = gui
	end
end

function BuildKit.dist(x1: number, z1: number, x2: number, z2: number): number
	local dx, dz = x1 - x2, z1 - z2
	return math.sqrt(dx * dx + dz * dz)
end

function BuildKit.model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

return BuildKit
