-- engine_mock: just enough fake Roblox engine (Vector3, CFrame, Color3, UDim2, Enum, Instance,
-- workspace) to run world-building code (HubService, WeaponModels) outside Studio so tools can
-- render top/side views. NOT used by unit tests unless a tool bundles it.

local V3 = {}
V3.__index = V3
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif k == "Unit" then
		local m = math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
		return v3(self.X / m, self.Y / m, self.Z / m)
	end
	return V3[k]
end
function V3.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Lerp(a, b, t) return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
Vector3 = { new = v3 }

local function mat(a, b)
	local r = {}
	for i = 1, 3 do
		r[i] = {}
		for j = 1, 3 do
			r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return r
end
local CF = {}
local function s_get(self, i, j) return self.R[i][j] end
local function cf(p, R) return setmetatable({ p = p, R = R }, CF) end
local I3 = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		local p = a.p
		return v3(
			p[1] + a.R[1][1] * b.X + a.R[1][2] * b.Y + a.R[1][3] * b.Z,
			p[2] + a.R[2][1] * b.X + a.R[2][2] * b.Y + a.R[2][3] * b.Z,
			p[3] + a.R[3][1] * b.X + a.R[3][2] * b.Y + a.R[3][3] * b.Z
		)
	end
	local R = mat(a.R, b.R)
	local p = {}
	for i = 1, 3 do
		p[i] = a.p[i] + a.R[i][1] * b.p[1] + a.R[i][2] * b.p[2] + a.R[i][3] * b.p[3]
	end
	return cf(p, R)
end
CF.__add = function(a, b) return cf({ a.p[1] + b.X, a.p[2] + b.Y, a.p[3] + b.Z }, a.R) end
CF.__index = function(self, k)
	if k == "Position" then
		return v3(self.p[1], self.p[2], self.p[3])
	elseif k == "Rotation" then
		return cf({ 0, 0, 0 }, self.R)
	elseif k == "LookVector" then
		return v3(-self.R[1][3], -self.R[2][3], -self.R[3][3])
	elseif k == "RightVector" then
		return v3(self.R[1][1], self.R[2][1], self.R[3][1])
	elseif k == "VectorToWorldSpace" then
		return function(s, v)
			local R = s.R
			return v3(
				R[1][1] * v.X + R[1][2] * v.Y + R[1][3] * v.Z,
				R[2][1] * v.X + R[2][2] * v.Y + R[2][3] * v.Z,
				R[3][1] * v.X + R[3][2] * v.Y + R[3][3] * v.Z
			)
		end
	elseif k == "VectorToObjectSpace" then
		return function(s, v)
			local R = s.R
			return v3(
				R[1][1] * v.X + R[2][1] * v.Y + R[3][1] * v.Z,
				R[1][2] * v.X + R[2][2] * v.Y + R[3][2] * v.Z,
				R[1][3] * v.X + R[2][3] * v.Y + R[3][3] * v.Z
			)
		end
	elseif k == "PointToWorldSpace" then
		return function(s, v)
			return s * v
		end
	elseif k == "UpVector" then
		return v3(s_get(self, 1, 2), s_get(self, 2, 2), s_get(self, 3, 2))
	elseif k == "Inverse" then
		return function(s)
			local Rt = { { s.R[1][1], s.R[2][1], s.R[3][1] }, { s.R[1][2], s.R[2][2], s.R[3][2] }, { s.R[1][3], s.R[2][3], s.R[3][3] } }
			local p = {}
			for i = 1, 3 do
				p[i] = -(Rt[i][1] * s.p[1] + Rt[i][2] * s.p[2] + Rt[i][3] * s.p[3])
			end
			return cf(p, Rt)
		end
	end
	return nil
end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then
			return cf({ x.X, x.Y, x.Z }, I3)
		end
		return cf({ x or 0, y or 0, z or 0 }, I3)
	end,
	Angles = function(rx, ry, rz)
		local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
		local Rx = { { 1, 0, 0 }, { 0, cx, -sx }, { 0, sx, cx } }
		local Ry = { { cy, 0, sy }, { 0, 1, 0 }, { -sy, 0, cy } }
		local Rz = { { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }
		return cf({ 0, 0, 0 }, mat(mat(Rx, Ry), Rz))
	end,
	lookAt = function(pos, target)
		local f = (target - pos).Unit
		local up = v3(0, 1, 0)
		local r = f:Cross(up).Unit
		local u = r:Cross(f)
		-- columns: right, up, back (-look)
		return cf({ pos.X, pos.Y, pos.Z }, {
			{ r.X, u.X, -f.X },
			{ r.Y, u.Y, -f.Y },
			{ r.Z, u.Z, -f.Z },
		})
	end,
}

local C3 = {}
C3.__index = C3
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end
function C3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
Color3 = {
	new = function(r, g, b) return c3(r or 0, g or 0, b or 0) end,
	fromRGB = function(r, g, b) return c3(r / 255, g / 255, b / 255) end,
}
UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
UDim2 = {
	new = function(a, b, c, d) return { a, b, c, d } end,
	fromOffset = function(x, y) return { 0, x, 0, y } end,
	fromScale = function(x, y) return { x, 0, y, 0 } end,
}
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })

local BASEPART = { Part = true, WedgePart = true, SpawnLocation = true, MeshPart = true }
local Inst = {}
local methods = {}
function methods.GetChildren(self) return table.clone(rawget(self, "__children")) end
function methods.GetDescendants(self)
	local out = {}
	local function walk(n)
		for _, c in rawget(n, "__children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name)
	for _, c in rawget(self, "__children") do
		if c.Name == name then return c end
	end
	return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods.FindFirstChildOfClass(self, cls)
	for _, c in rawget(self, "__children") do
		if c.ClassName == cls then return c end
	end
	return nil
end
function methods.IsA(self, cls)
	local cn = self.ClassName
	if cls == "BasePart" then return BASEPART[cn] == true end
	if cls == "PVInstance" then return BASEPART[cn] == true or cn == "Model" end
	return cn == cls
end
function methods.SetAttribute(self, k, v) rawget(self, "__attrs")[k] = v end
function methods.GetAttribute(self, k) return rawget(self, "__attrs")[k] end
function methods.GetAttributes(self) return rawget(self, "__attrs") end
function methods.Destroy(self) self.Parent = nil end
function methods.PivotTo(self, target)
	if BASEPART[self.ClassName] then
		self.CFrame = target
		return
	end
	local primary = self.PrimaryPart
	local current = if primary then primary.CFrame else CFrame.new()
	local delta = target * current:Inverse()
	for _, d in methods.GetDescendants(self) do
		if BASEPART[d.ClassName] then
			d.CFrame = delta * d.CFrame
		end
	end
end
Inst.__index = function(self, k)
	local m = methods[k]
	if m then return m end
	local props = rawget(self, "__props")
	if k == "Position" and props.CFrame then return props.CFrame.Position end
	return props[k]
end
Inst.__newindex = function(self, k, v)
	local props = rawget(self, "__props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local kids = rawget(old, "__children")
			local i = table.find(kids, self)
			if i then table.remove(kids, i) end
		end
		if v then table.insert(rawget(v, "__children"), self) end
	elseif k == "Position" then
		local cur = props.CFrame or CFrame.new()
		props.CFrame = cf({ v.X, v.Y, v.Z }, cur.R)
		return
	end
	props[k] = v
end
local function newInstance(cls)
	local props = { ClassName = cls, Name = cls }
	if BASEPART[cls] then
		props.CFrame = CFrame.new()
		props.Size = v3(4, 1, 2)
		props.Color = c3(0.6, 0.6, 0.6)
		props.Transparency = 0
		props.Material = "Material.Plastic"
		props.CanCollide = true
		props.AssemblyLinearVelocity = v3(0, 0, 0)
		props.AssemblyAngularVelocity = v3(0, 0, 0)
	end
	return setmetatable({ __props = props, __children = {}, __attrs = {} }, Inst)
end
Instance = { new = newInstance }
workspace = newInstance("Workspace")
workspace.Name = "Workspace"

-- Serializes every BasePart under `root` for the Python renderers.
function __dumpParts(root)
	local out = {}
	for _, d in methods.GetDescendants(root) do
		if BASEPART[d.ClassName] then
			local c = d.Color
			table.insert(out, string.format(
				'{"cls":"%s","name":"%s","shape":"%s","size":[%f,%f,%f],"p":[%f,%f,%f],"R":[[%f,%f,%f],[%f,%f,%f],[%f,%f,%f]],"color":[%d,%d,%d],"transparency":%f,"collide":%s,"material":"%s"}',
				d.ClassName, (string.gsub(tostring(d.Name), '"', "'")), tostring(d.Shape or ""),
				d.Size.X, d.Size.Y, d.Size.Z,
				d.CFrame.p[1], d.CFrame.p[2], d.CFrame.p[3],
				d.CFrame.R[1][1], d.CFrame.R[1][2], d.CFrame.R[1][3],
				d.CFrame.R[2][1], d.CFrame.R[2][2], d.CFrame.R[2][3],
				d.CFrame.R[3][1], d.CFrame.R[3][2], d.CFrame.R[3][3],
				math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255),
				d.Transparency or 0, tostring(d.CanCollide ~= false), tostring(d.Material)
			))
		end
	end
	print("[" .. table.concat(out, ",") .. "]")
end

-- Extras for world-building tools (MapService/HubService rendering) ---------------------------
V3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
Vector3.zero = v3(0, 0, 0)

local realTypeof = typeof
typeof = function(v)
	local mt = getmetatable(v)
	if mt == C3 then return "Color3" end
	if mt == V3 then return "Vector3" end
	if mt == CF then return "CFrame" end
	return realTypeof(v)
end

ColorSequence = { new = function(a) return { a } end }
NumberSequence = { new = function(a) return { a } end }
NumberSequenceKeypoint = { new = function(t, v) return { t, v } end }
NumberRange = { new = function(a, b) return { a, b or a } end }
TweenInfo = { new = function() return {} end }
RaycastParams = { new = function() return {} end }
Region3 = { new = function(a, b) return { ExpandToGrid = function(self) return self end } end }

Random = { new = function(seed)
	local state = (seed or 1) % 2147483647
	if state <= 0 then state = state + 2147483646 end
	local function nxt()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_, a, b)
			if a == nil then return nxt() end
			return a + (b - a) * nxt()
		end,
		NextInteger = function(_, a, b) return a + math.floor(nxt() * (b - a + 1)) end,
	}
end }

__terrainFills = {}
local terrain = newInstance("Terrain")
terrain.Name = "Terrain"
local function rec(kind, cf, size, material)
	table.insert(__terrainFills, { kind = kind, p = cf.p, R = cf.R, size = size, material = tostring(material) })
end
methods.FillBlock = function(_, cf, size, material) rec("Block", cf, { size.X, size.Y, size.Z }, material) end
methods.FillBall = function(_, center, radius, material) rec("Ball", CFrame.new(center), { radius }, material) end
methods.FillCylinder = function(_, cf, height, radius, material) rec("Cylinder", cf, { height, radius }, material) end
methods.ReadVoxels = function() return {}, {} end
workspace.Terrain = terrain
methods.Raycast = function(_, origin, dir)
	if #__terrainFills > 0 then
		return { Position = v3(origin.X, 0, origin.Z), Instance = terrain }
	end
	return nil
end

function __dumpTerrain()
	local out = {}
	for _, f in __terrainFills do
		table.insert(out, string.format('{"kind":"%s","p":[%f,%f,%f],"R":[[%f,%f,%f],[%f,%f,%f],[%f,%f,%f]],"size":[%s],"material":"%s"}',
			f.kind, f.p[1], f.p[2], f.p[3],
			f.R[1][1], f.R[1][2], f.R[1][3], f.R[2][1], f.R[2][2], f.R[2][3], f.R[3][1], f.R[3][2], f.R[3][3],
			table.concat(f.size, ","), f.material))
	end
	print("TERRAIN[" .. table.concat(out, ",") .. "]")
end
