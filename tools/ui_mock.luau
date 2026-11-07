-- ui_mock: GUI-side engine shims on top of tests/engine_mock.luau so client UI code (Kit, panels,
-- HUD) can run outside Studio. tools/render_ui.py bundles this, renders a scene, and draws the
-- dumped GUI tree to a PNG. Only for previews - never used by unit tests.

local INST_MT = getmetatable(Instance.new("Frame"))
local baseIndex = INST_MT.__index
local baseNewIndex = INST_MT.__newindex

-- Signals ---------------------------------------------------------------------------------
local function newSignal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end, Connected = true }
	end
	s.Once = s.Connect
	function s:Wait()
		return nil
	end
	function s:Fire(...)
		for _, h in self.handlers do
			if __asyncSignals then
				-- like Roblox: each handler runs in its own thread and may yield
				local co = coroutine.create(h)
				local ok, err = coroutine.resume(co, ...)
				if not ok and __onThreadError then
					__onThreadError(co, err)
				end
			else
				h(...)
			end
		end
	end
	return s
end
__newSignal = newSignal

local EVENTS = {
	MouseEnter = true, MouseLeave = true, Activated = true, MouseButton1Click = true, MouseButton1Down = true,
	MouseButton1Up = true, MouseButton2Click = true, Changed = true, Destroying = true, FocusLost = true,
	Focused = true, InputBegan = true, InputEnded = true, InputChanged = true, MouseMoved = true,
	MouseWheelForward = true, MouseWheelBackward = true, AncestryChanged = true, ChildAdded = true,
	ChildRemoved = true, DescendantAdded = true, DescendantRemoving = true, Triggered = true,
	PromptTriggered = true, Touched = true, Died = true, HealthChanged = true, StateChanged = true,
	Completed = true, ReturnPressedFromOnScreenKeyboard = true, SelectionGained = true, SelectionLost = true,
	AttributeChanged = true, Chatted = true, Idled = true, OnServerEvent = true, OnClientEvent = true,
	Heartbeat = true, PlaybackEnded = true, Ended = true, Played = true, KeyframeReached = true,
}

local GUI_DEFAULTS = {
	BackgroundTransparency = 0,
	BackgroundColor3 = Color3.fromRGB(163, 162, 165),
	Visible = true,
	ZIndex = 1,
	LayoutOrder = 0,
	TextTransparency = 0,
	TextStrokeTransparency = 1,
	TextColor3 = Color3.fromRGB(27, 42, 53),
	TextSize = 14,
	Text = "",
	ImageTransparency = 0,
	Rotation = 0,
	Enabled = true,
	Transparency = 0,
	Thickness = 1,
	Scale = 1,
}

INST_MT.__index = function(self, k)
	local v = baseIndex(self, k)
	if v ~= nil then
		return v
	end
	if EVENTS[k] then
		local props = rawget(self, "__props")
		local s = newSignal()
		props[k] = s
		return s
	end
	local d = GUI_DEFAULTS[k]
	if d ~= nil then
		return d
	end
	if k == "AbsoluteSize" or k == "TextBounds" or k == "AbsolutePosition" then
		return Vector2.new(0, 0)
	end
	return nil
end

-- Destroy really detaches; ClearAllChildren; GetPropertyChangedSignal; misc methods.
local methods = {}
function methods.GetPropertyChangedSignal()
	return newSignal()
end
function methods.GetAttributeChangedSignal()
	return newSignal()
end
function methods.ClearAllChildren(self)
	for _, c in self:GetChildren() do
		c.Parent = nil
	end
end
function methods.GetBoundingBox(self)
	return CFrame.new(), Vector3.new(2, 2, 2)
end
function methods.GetExtentsSize()
	return Vector3.new(2, 2, 2)
end
function methods.ScaleTo() end
function methods.GetFullName(self)
	return tostring(self.Name)
end
function methods.IsDescendantOf(self, other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods.FindFirstChildWhichIsA(self, cls)
	for _, c in self:GetChildren() do
		if c:IsA(cls) then
			return c
		end
	end
	return nil
end
function methods.FindFirstAncestorOfClass(self, cls)
	local p = self.Parent
	while p do
		if p.ClassName == cls then
			return p
		end
		p = p.Parent
	end
	return nil
end
function methods.Clone(self)
	local c = Instance.new(self.ClassName)
	for k, v in rawget(self, "__props") do
		if k ~= "Parent" then
			rawget(c, "__props")[k] = v
		end
	end
	for _, child in self:GetChildren() do
		child:Clone().Parent = c
	end
	return c
end
function methods.SetNetworkOwner() end
function methods.MoveTo(self, pos)
	rawget(self, "__props").__moveTarget = pos
end
function methods.GetState()
	return "HumanoidStateType.Running"
end
function methods.ChangeState() end
function methods.TakeDamage(self, d)
	self.Health = math.max(0, self.Health - d)
end
function methods.Move() end
function methods.EquipTool() end
function methods.UnequipTools() end
function methods.SetExperimentalFeatures() end
function methods.AddTag(self, tag)
	local t = rawget(self, "__tags") or {}
	t[tag] = true
	rawset(self, "__tags", t)
end
function methods.RemoveTag(self, tag)
	local t = rawget(self, "__tags")
	if t then
		t[tag] = nil
	end
end
function methods.HasTag(self, tag)
	local t = rawget(self, "__tags")
	return t ~= nil and t[tag] == true
end
function methods.GetTags(self)
	local out = {}
	for k in rawget(self, "__tags") or {} do
		table.insert(out, k)
	end
	return out
end
function methods.CaptureFocus() end
function methods.ReleaseFocus() end
function methods.TweenSize() end
function methods.TweenPosition() end
local oldIndex = INST_MT.__index
INST_MT.__index = function(self, k)
	local m = methods[k]
	if m then
		return m
	end
	return oldIndex(self, k)
end
local PART = { Part = true, WedgePart = true, SpawnLocation = true, MeshPart = true }
INST_MT.__newindex = function(self, k, v)
	if k == "Position" and not PART[rawget(self, "__props").ClassName] then
		rawget(self, "__props").Position = v
		return
	end
	baseNewIndex(self, k, v)
end

-- Value types missing from engine_mock --------------------------------------------------------
local function seqNew(kpNew)
	return function(a, b)
		if type(a) == "table" and a[1] ~= nil and type(a[1]) == "table" and a[1].Time ~= nil then
			return { Keypoints = a }
		end
		return { Keypoints = { kpNew(0, a), kpNew(1, if b ~= nil then b else a) } }
	end
end
ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
ColorSequence = { new = seqNew(ColorSequenceKeypoint.new) }
NumberSequence = { new = seqNew(NumberSequenceKeypoint.new) }
Rect = { new = function(...) return { ... } end }
Font = {
	new = function(family, weight, style) return { Family = family, Weight = weight, Style = style } end,
	fromEnum = function(e) return { Family = tostring(e) } end,
}
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)
local U2 = {}
U2.__add = function(a, b) return setmetatable({ a[1] + b[1], a[2] + b[2], a[3] + b[3], a[4] + b[4] }, U2) end
U2.__sub = function(a, b) return setmetatable({ a[1] - b[1], a[2] - b[2], a[3] - b[3], a[4] - b[4] }, U2) end
U2.__eq = function(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] end
U2.__index = function(self, k)
	if k == "X" then return UDim.new(self[1], self[2]) end
	if k == "Y" then return UDim.new(self[3], self[4]) end
	if k == "Width" then return UDim.new(self[1], self[2]) end
	if k == "Height" then return UDim.new(self[3], self[4]) end
	if k == "Lerp" then
		return function(a, b, t)
			return setmetatable({ a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t }, U2)
		end
	end
	return nil
end
local function u2(a, b, c, d)
	if type(a) == "table" then -- UDim2.new(UDim, UDim)
		return setmetatable({ a.Scale, a.Offset, b.Scale, b.Offset }, U2)
	end
	return setmetatable({ a or 0, b or 0, c or 0, d or 0 }, U2)
end
UDim2 = {
	new = u2,
	fromOffset = function(x, y) return u2(0, x or 0, 0, y or 0) end,
	fromScale = function(x, y) return u2(x or 0, 0, y or 0, 0) end,
}
local UD = {}
UD.__add = function(a, b) return setmetatable({ Scale = a.Scale + b.Scale, Offset = a.Offset + b.Offset }, UD) end
UD.__index = UD
UDim = { new = function(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD) end }
local V2 = {}
V2.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y }, V2) end
V2.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y }, V2) end
V2.__mul = function(a, b)
	if type(b) == "number" then return setmetatable({ X = a.X * b, Y = a.Y * b }, V2) end
	return setmetatable({ X = a.X * b.X, Y = a.Y * b.Y }, V2)
end
V2.__index = function(self, k)
	if k == "Magnitude" then return math.sqrt(self.X ^ 2 + self.Y ^ 2) end
	return nil
end
Vector2 = { new = function(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end }
local function hsv(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local r, g, b = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i % 6 + 1][1], 0, 0
	local row = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i % 6 + 1]
	r, g, b = row[1], row[2], row[3]
	return Color3.new(r, g, b)
end
Color3.fromHSV = hsv
Color3.fromHex = function(hex)
	hex = hex:gsub("#", "")
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)
DateTime = { now = function() return { UnixTimestamp = 1700000000, UnixTimestampMillis = 1700000000000 } end }


-- task: delays queue and run when the tool flushes them (one level per flush, never loops).
local delayed = {}
task.delay = function(_, f, ...)
	if __freezeDelays then
		return
	end
	table.insert(delayed, { f = f, args = table.pack(...) })
end
-- Inside a spawned coroutine, wait parks it forever (loops stop); on the main thread it
-- returns, but too many in a row means a polling loop: stop it with an error.
local mainWaits = 0
task.wait = function()
	if coroutine.isyieldable() then
		coroutine.yield()
		return 0
	end
	mainWaits += 1
	if mainWaits > 200 then
		error("ui_mock: task.wait loop on the main thread")
	end
	return 0
end
task.cancel = function() end
function __flushDelays(passes)
	for _ = 1, passes or 3 do
		local batch = delayed
		delayed = {}
		for _, d in batch do
			pcall(d.f, table.unpack(d.args, 1, d.args.n))
		end
	end
end

-- Services -------------------------------------------------------------------------------------
local services = {}
local function addService(name, svc)
	services[name] = svc
	rawget(game, "__children")[name] = svc
end

local tween = {}
function tween:Create(inst, _info, goal)
	return {
		Play = function()
			for k, v in goal do
				inst[k] = v
			end
		end,
		Cancel = function() end,
		Pause = function() end,
		Completed = newSignal(),
	}
end
addService("TweenService", tween)

local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
local localPlayer = Instance.new("Player")
localPlayer.Name = "Wanderer"
localPlayer.DisplayName = "Wanderer"
localPlayer.UserId = 1
playerGui.Parent = localPlayer
localPlayer.CharacterAdded = newSignal()
localPlayer.CharacterRemoving = newSignal()
localPlayer.GetMouse = function()
	return { Hit = CFrame.new(), X = 0, Y = 0, Move = newSignal(), Button1Down = newSignal() }
end
local players = {
	LocalPlayer = localPlayer,
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
	GetPlayers = function()
		return { localPlayer }
	end,
	GetPlayerByUserId = function(_, id)
		return if id == 1 then localPlayer else nil
	end,
}
addService("Players", players)
__playerGui = playerGui

addService("UserInputService", {
	TouchEnabled = false,
	KeyboardEnabled = true,
	GamepadEnabled = false,
	MouseEnabled = true,
	InputBegan = newSignal(),
	InputEnded = newSignal(),
	InputChanged = newSignal(),
	JumpRequest = newSignal(),
	TouchStarted = newSignal(),
	TouchEnded = newSignal(),
	TouchMoved = newSignal(),
	TouchTap = newSignal(),
	GamepadConnected = newSignal(),
	LastInputTypeChanged = newSignal(),
	GetLastInputType = function()
		return "UserInputType.Keyboard"
	end,
	IsKeyDown = function()
		return false
	end,
	GetMouseLocation = function()
		return Vector2.new(0, 0)
	end,
})
addService("RunService", {
	IsStudio = function()
		return true
	end,
	IsServer = function()
		return false
	end,
	IsClient = function()
		return true
	end,
	Heartbeat = newSignal(),
	RenderStepped = newSignal(),
	Stepped = newSignal(),
	PreSimulation = newSignal(),
	PostSimulation = newSignal(),
	PreRender = newSignal(),
	PreAnimation = newSignal(),
	BindToRenderStep = function() end,
	UnbindFromRenderStep = function() end,
})
addService("ProximityPromptService", { PromptTriggered = newSignal(), PromptShown = newSignal(), PromptHidden = newSignal() })
addService("GuiService", { MenuOpened = newSignal(), MenuClosed = newSignal(), GetGuiInset = function()
	return Vector2.new(0, 58), Vector2.new(0, 0)
end })
addService("SoundService", {})
addService("ContextActionService", { BindAction = function() end, UnbindAction = function() end, BindActionAtPriority = function() end, SetTitle = function() end, SetImage = function() end, SetPosition = function() end, GetButton = function() return nil end })
addService("KeyframeSequenceProvider", { RegisterKeyframeSequence = function() return "rbxassetid://0" end })
addService("Lighting", Instance.new("Lighting"))
addService("ContentProvider", { PreloadAsync = function() end })
addService("StarterGui", { SetCoreGuiEnabled = function() end, SetCore = function() end })
addService("HttpService", { GenerateGUID = function() return "GUID" end, JSONEncode = function() return "{}" end })
addService("CollectionService", { GetTagged = function() return {} end, GetInstanceAddedSignal = function() return newSignal() end, GetInstanceRemovedSignal = function() return newSignal() end })
addService("Debris", { AddItem = function() end })
addService("TextService", { GetTextSize = function(_, text, size) return Vector2.new(#text * size * 0.5, size) end })
addService("MarketplaceService", { PromptProductPurchase = function() end, PromptGamePassPurchase = function() end })
addService("Workspace", workspace)
workspace.CurrentCamera = Instance.new("Camera")
workspace.CurrentCamera.ViewportSize = Vector2.new(1280, 720)
workspace.CurrentCamera.CFrame = CFrame.new(0, 10, 20)
workspace.CurrentCamera.Focus = CFrame.new(0, 5, 0)
workspace.CurrentCamera.FieldOfView = 70
workspace.CurrentCamera.CameraType = "CameraType.Custom"
workspace.CurrentCamera.WorldToViewportPoint = function(_, p)
	return Vector3.new(640, 360, 10), true
end
workspace.CurrentCamera.WorldToScreenPoint = workspace.CurrentCamera.WorldToViewportPoint
workspace.CurrentCamera.ViewportPointToRay = function()
	return { Origin = Vector3.new(0, 10, 20), Direction = Vector3.new(0, 0, -1) }
end
-- Enum items are plain strings in the mock; a few places read `.Value`
rawset(Enum, "RenderPriority", { First = { Value = 0 }, Input = { Value = 100 }, Camera = { Value = 200 }, Character = { Value = 300 }, Last = { Value = 2000 } })
workspace.GetServerTimeNow = function()
	return 1700000000
end

-- Serializer: GUI tree -> JSON for tools/render_ui.py ---------------------------------------
local function enc(v)
	local t = typeof(v)
	if t == "Color3" then
		return string.format('{"c":[%d,%d,%d]}', math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5))
	elseif type(v) == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return "0"
		end
		return string.format("%.4f", v)
	elseif type(v) == "boolean" then
		return tostring(v)
	elseif type(v) == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", ""):gsub("\t", " ") .. '"'
	elseif type(v) == "table" then
		if rawlen(v) == 4 and type(rawget(v, 1)) == "number" then
			return string.format("[%s,%s,%s,%s]", enc(v[1]), enc(v[2]), enc(v[3]), enc(v[4]))
		end
		if v.Scale ~= nil and v.Offset ~= nil then
			return string.format('{"s":%s,"o":%s}', enc(v.Scale), enc(v.Offset))
		end
		if v.X ~= nil and v.Y ~= nil and v.Z == nil then
			return string.format('{"x":%s,"y":%s}', enc(v.X), enc(v.Y))
		end
		if v.Keypoints then
			local kp = {}
			for _, k in v.Keypoints do
				table.insert(kp, string.format('[%s,%s]', enc(k.Time), enc(k.Value)))
			end
			return '{"seq":[' .. table.concat(kp, ",") .. "]}"
		end
		if #v == 4 and type(v[1]) == "number" then
			return string.format("[%s,%s,%s,%s]", enc(v[1]), enc(v[2]), enc(v[3]), enc(v[4]))
		end
		if v.Family then
			return enc(v.Family)
		end
	end
	return "null"
end

local KEEP = {
	"Name", "Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "Visible", "ZIndex",
	"LayoutOrder", "ClipsDescendants", "Text", "TextColor3", "TextSize", "TextTransparency", "TextStrokeColor3",
	"TextStrokeTransparency", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextScaled", "Font", "FontFace",
	"RichText", "AutomaticSize", "Image", "ImageColor3", "ImageTransparency", "ScaleType", "Rotation",
	"FillDirection", "HorizontalAlignment", "VerticalAlignment", "Padding", "SortOrder", "CellSize", "CellPadding",
	"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight", "CornerRadius", "Color", "Thickness",
	"Transparency", "ApplyStrokeMode", "Enabled", "Offset", "MaxSize", "MinSize", "Scale", "AspectRatio",
	"CanvasSize", "AutomaticCanvasSize", "ScrollBarThickness", "ScrollBarImageColor3", "IgnoreGuiInset",
	"DisplayOrder", "PlaceholderText", "PlaceholderColor3", "MaxTextSize", "MinTextSize", "TextTruncate",
	"LineHeight", "ImageRectSize", "ImageRectOffset", "SliceCenter", "GroupTransparency", "DominantAxis",
	"AspectType",
}

local function dumpNode(inst, out)
	local props = rawget(inst, "__props")
	local fields = { '"cls":' .. enc(inst.ClassName) }
	for _, k in KEEP do
		local v = props[k]
		if v ~= nil then
			local e = enc(v)
			if e ~= "null" then
				table.insert(fields, '"' .. k .. '":' .. e)
			end
		end
	end
	local kids = {}
	for _, c in rawget(inst, "__children") do
		local s = {}
		dumpNode(c, s)
		table.insert(kids, table.concat(s))
	end
	table.insert(fields, '"children":[' .. table.concat(kids, ",") .. "]")
	table.insert(out, "{" .. table.concat(fields, ",") .. "}")
end

function __dumpGui(root)
	local out = {}
	dumpNode(root or playerGui, out)
	print("GUI" .. table.concat(out))
end

-- Color3:ToHex / ToHSV for UI code.
local C3MT = getmetatable(Color3.new(0, 0, 0))
C3MT.ToHex = function(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
