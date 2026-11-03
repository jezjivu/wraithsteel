--!strict
-- Kit: the code-built UI toolkit. Look: "Ink & Seal".
--   * warm ink surfaces, generous spacing, one thin gold hairline per surface
--   * a vermilion seal stamp (like a signature seal on a scroll) marks titles and active things
--   * geometric icons built from frames (no font glyphs, so they render the same everywhere)
--   * Merriweather for titles, Builder Sans for everything else
-- Panels only use this API (Window, Row, Stack, Label, Button, Section, Chip, Progress, ...),
-- so the whole game restyles from here. Colors/fonts are the only design tokens.

local TweenService = game:GetService("TweenService")

local Kit = {}

-- Design tokens --------------------------------------------------------------------------------
Kit.Colors = {
	-- surfaces
	Ink = Color3.fromRGB(14, 12, 16), -- deepest background
	Panel = Color3.fromRGB(22, 19, 24), -- window
	Row = Color3.fromRGB(31, 27, 33), -- card
	RowAlt = Color3.fromRGB(35, 31, 38),
	Raised = Color3.fromRGB(42, 37, 45), -- hover / inputs
	Line = Color3.fromRGB(201, 164, 92), -- gold hairline (used with high transparency)
	-- text
	Text = Color3.fromRGB(239, 232, 218), -- "paper"
	Muted = Color3.fromRGB(156, 148, 138), -- "mist"
	Faint = Color3.fromRGB(108, 101, 96),
	-- accents
	Gold = Color3.fromRGB(226, 190, 116),
	Accent = Color3.fromRGB(210, 70, 47), -- vermilion seal
	Good = Color3.fromRGB(93, 179, 141),
	Jade = Color3.fromRGB(93, 179, 141),
	Bad = Color3.fromRGB(214, 84, 72),
	Blue = Color3.fromRGB(110, 147, 214),
	Steel = Color3.fromRGB(128, 122, 118),
	Ember = Color3.fromRGB(240, 146, 70),
}

Kit.TitleFont = Enum.Font.Merriweather
Kit.BodyFont = Enum.Font.BuilderSans
Kit.MediumFont = Enum.Font.BuilderSansMedium
Kit.BoldFont = Enum.Font.BuilderSansBold
Kit.HeavyFont = Enum.Font.BuilderSansExtraBold

Kit.Radius = 6 -- cards, buttons
Kit.WindowRadius = 10
Kit.Gap = 10

local C = Kit.Colors
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Small builders ---------------------------------------------------------------------------------
local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end
Kit.Corner = corner

local function pad(parent: Instance, x: number, y: number?)
	local u = Instance.new("UIPadding")
	u.PaddingTop = UDim.new(0, y or x)
	u.PaddingBottom = UDim.new(0, y or x)
	u.PaddingLeft = UDim.new(0, x)
	u.PaddingRight = UDim.new(0, x)
	u.Parent = parent
end
Kit.Pad = pad

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number?): UIStroke
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = color
	st.Transparency = transparency
	st.Thickness = thickness or 1
	st.Parent = parent
	return st
end
Kit.Stroke = stroke

local function frame(parent: Instance, pos: UDim2, size: UDim2, color: Color3, transparency: number?, z: number?): Frame
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

local function text(parent: Instance, str: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = str
	l.RichText = true
	l.Parent = parent
	return l
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

function Kit.Screen(parent: Instance, name: string, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = displayOrder or 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent
	return gui
end

-- A soft vertical ink gradient used by every surface (lighter at the top).
local function inkGradient(parent: Instance, top: number?)
	local g = Instance.new("UIGradient")
	local t = top or 1.18
	g.Color = ColorSequence.new(Color3.new(math.min(1, t), math.min(1, t), math.min(1, t)), Color3.new(0.86, 0.86, 0.86))
	g.Rotation = 90
	g.Parent = parent
	return g
end

-- Signature elements --------------------------------------------------------------------------

-- The vermilion seal: a small stamp with one letter (or a geometric icon) in paper color.
function Kit.Seal(parent: Instance, glyph: string?, size: number?, color: Color3?): Frame
	local s = size or 30
	local f = frame(parent, UDim2.new(), UDim2.fromOffset(s, s), color or C.Accent)
	f.LayoutOrder = nextOrder()
	corner(f, math.max(3, math.floor(s * 0.18)))
	stroke(f, Color3.new(1, 1, 1), 0.82, 1)
	inkGradient(f, 1.25)
	if glyph and #glyph > 0 then
		local l = text(f, glyph, Kit.TitleFont, math.floor(s * 0.56), C.Text)
		l.Size = UDim2.fromScale(1, 1)
		l.ZIndex = f.ZIndex + 1
	end
	return f
end

-- Gold hairline with a small diamond at its center (the "gate" divider).
function Kit.GateLine(parent: Instance, pos: UDim2, width: UDim, alpha: number?): Frame
	local holder = frame(parent, pos, UDim2.new(width, UDim.new(0, 7)), C.Ink, 1)
	holder.AnchorPoint = Vector2.new(0, 0.5)
	local line = frame(holder, UDim2.new(0, 0, 0.5, 0), UDim2.new(1, 0, 0, 1), C.Line, alpha or 0.55)
	line.AnchorPoint = Vector2.new(0, 0.5)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0),
		NumberSequenceKeypoint.new(0.82, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = line
	local d = frame(holder, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(5, 5), C.Gold, 0.1, 2)
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Rotation = 45
	return holder
end

-- Kept for older callers: a short gold hairline that fades to the right.
function Kit.BladeLine(parent: Instance, pos: UDim2, width: UDim, color: Color3?): Frame
	local f = frame(parent, pos, UDim2.new(width, UDim.new(0, 1)), color or C.Line, 0.35, 3)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	return f
end

-- Kept for older callers: now four tiny gold corner ticks instead of heavy brackets.
function Kit.Brackets(target: GuiObject, color: Color3?, len: number?, z: number?)
	local col = color or C.Gold
	local l = math.min(len or 8, 8)
	for _, ax in { 0, 1 } do
		for _, ay in { 0, 1 } do
			for _, size in { UDim2.fromOffset(l, 1), UDim2.fromOffset(1, l) } do
				local f = frame(target, UDim2.fromScale(ax, ay), size, col, 0.35, z or 5)
				f.AnchorPoint = Vector2.new(ax, ay)
			end
		end
	end
end

-- Geometric icons ----------------------------------------------------------------------------------
-- kind: "blade" | "spirit" | "world" | "bonds" | "market" | "close" | "ember" | "jade" | "lock"
--       | "star" | "bell"
function Kit.Icon(parent: Instance, kind: string, size: number, color: Color3?): Frame
	local col = color or C.Text
	local box = frame(parent, UDim2.new(), UDim2.fromOffset(size, size), C.Ink, 1)
	box.LayoutOrder = nextOrder()
	local z = box.ZIndex + 1
	local function bar(x: number, y: number, w: number, h: number, rot: number?, alpha: number?): Frame
		local b = frame(box, UDim2.fromScale(x, y), UDim2.fromScale(w, h), col, alpha or 0, z)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Rotation = rot or 0
		return b
	end
	local function ring(x: number, y: number, d: number, thick: number?, fill: boolean?): Frame
		local r = frame(box, UDim2.fromScale(x, y), UDim2.fromScale(d, d), col, if fill then 0 else 1, z)
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		corner(r, 999)
		if not fill then
			stroke(r, col, 0, thick or math.max(1.5, size / 14))
		end
		return r
	end
	local function diamond(x: number, y: number, d: number, fill: boolean?): Frame
		local r = frame(box, UDim2.fromScale(x, y), UDim2.fromScale(d, d), col, if fill then 0 else 1, z)
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Rotation = 45
		if not fill then
			stroke(r, col, 0, math.max(1.5, size / 14))
		end
		return r
	end
	local t = math.max(2, size / 11) / size -- line thickness as a fraction
	if kind == "blade" then
		bar(0.55, 0.45, t, 0.78, 45) -- blade
		bar(0.3, 0.7, 0.34, t * 1.4, 45) -- guard
		bar(0.2, 0.8, t * 1.6, 0.18, 45) -- grip
	elseif kind == "spirit" then
		ring(0.5, 0.55, 0.62)
		ring(0.5, 0.55, 0.2, nil, true)
		bar(0.5, 0.12, t, 0.16)
	elseif kind == "world" then
		diamond(0.5, 0.5, 0.56)
		bar(0.5, 0.5, t, 0.92)
		bar(0.5, 0.5, 0.92, t)
	elseif kind == "bonds" then
		ring(0.36, 0.5, 0.5)
		ring(0.64, 0.5, 0.5)
	elseif kind == "market" then
		ring(0.5, 0.5, 0.78)
		local hole = frame(box, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.26, 0.26), col, 1, z)
		hole.AnchorPoint = Vector2.new(0.5, 0.5)
		stroke(hole, col, 0, math.max(1.5, size / 14))
	elseif kind == "close" then
		bar(0.5, 0.5, t, 0.62, 45)
		bar(0.5, 0.5, t, 0.62, -45)
	elseif kind == "ember" then
		diamond(0.5, 0.56, 0.5, true)
		diamond(0.5, 0.56, 0.24)
	elseif kind == "jade" then
		ring(0.5, 0.5, 0.66, nil, true)
		local hole = ring(0.5, 0.5, 0.22, nil, true)
		hole.BackgroundColor3 = C.Ink
	elseif kind == "lock" then
		local body = bar(0.5, 0.64, 0.6, 0.42)
		corner(body, 2)
		local shackle = frame(box, UDim2.fromScale(0.5, 0.36), UDim2.fromScale(0.38, 0.42), col, 1, z)
		shackle.AnchorPoint = Vector2.new(0.5, 0.5)
		corner(shackle, 999)
		stroke(shackle, col, 0, math.max(1.5, size / 12))
	elseif kind == "star" then
		diamond(0.5, 0.5, 0.42, true)
		bar(0.5, 0.5, t, 0.9)
		bar(0.5, 0.5, 0.9, t)
	elseif kind == "bell" then
		local dome = frame(box, UDim2.fromScale(0.5, 0.48), UDim2.fromScale(0.56, 0.6), col, 0, z)
		dome.AnchorPoint = Vector2.new(0.5, 0.5)
		corner(dome, 999)
		bar(0.5, 0.78, 0.76, t * 1.3)
		ring(0.5, 0.9, 0.16, nil, true)
	end
	return box
end

-- Window ------------------------------------------------------------------------------------------
export type Tab = { id: string, label: string }

export type Window = {
	root: Frame,
	body: ScrollingFrame,
	title: TextLabel,
	close: TextButton,
	tabs: { [string]: TextButton },
}

export type WindowOpts = {
	glyph: string?, -- letter in the seal (defaults to the title's first letter)
	subtitle: string?,
	tabs: { Tab }?,
	activeTab: string?,
	onTab: ((id: string) -> ())?,
}

-- Centered window: seal + serif title, optional tabs, a scrolling body.
function Kit.Window(parent: Instance, titleText: string, opts: WindowOpts?): Window
	local o: WindowOpts = opts or {}
	local root = frame(parent, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.72, 0.82), C.Panel, 0.03)
	root.Name = "Window"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(root, Kit.WindowRadius)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(880, 640)
	limit.MinSize = Vector2.new(320, 260)
	limit.Parent = root
	stroke(root, C.Line, 0.72, 1)
	inkGradient(root, 1.22)

	-- Header: seal, title, subtitle, close.
	local hasTabs = o.tabs ~= nil and #(o.tabs :: { Tab }) > 1
	local headH = 64
	local head = frame(root, UDim2.new(), UDim2.new(1, 0, 0, headH), C.Ink, 1)
	local seal = Kit.Seal(head, o.glyph or string.sub(titleText, 1, 1), 34)
	seal.Position = UDim2.fromOffset(20, 15)
	local title = text(head, titleText, Kit.TitleFont, 24, C.Text)
	title.Position = UDim2.fromOffset(68, if o.subtitle then 11 else 0)
	title.Size = UDim2.new(1, -140, 0, if o.subtitle then 28 else headH)
	title.TextXAlignment = Enum.TextXAlignment.Left
	if o.subtitle then
		local sub = text(head, o.subtitle, Kit.BodyFont, 14, C.Muted)
		sub.Position = UDim2.fromOffset(68, 38)
		sub.Size = UDim2.new(1, -140, 0, 18)
		sub.TextXAlignment = Enum.TextXAlignment.Left
	end
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -16, 0, headH / 2)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundColor3 = C.Raised
	close.BackgroundTransparency = 1
	close.Text = ""
	close.AutoButtonColor = false
	close.Parent = head
	corner(close, 999)
	local x = Kit.Icon(close, "close", 16, C.Muted)
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.fromScale(0.5, 0.5)
	close.MouseEnter:Connect(function()
		TweenService:Create(close, QUICK, { BackgroundTransparency = 0 }):Play()
	end)
	close.MouseLeave:Connect(function()
		TweenService:Create(close, QUICK, { BackgroundTransparency = 1 }):Play()
	end)

	-- Tabs: quiet text with a gold underline on the active one.
	local tabButtons: { [string]: TextButton } = {}
	local top = headH
	if hasTabs then
		local strip = frame(root, UDim2.fromOffset(0, headH - 4), UDim2.new(1, 0, 0, 38), C.Ink, 1)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Parent = strip
		pad(strip, 18, 0)
		for i, tab in o.tabs :: { Tab } do
			local active = tab.id == o.activeTab
			local b = Instance.new("TextButton")
			b.Size = UDim2.fromOffset(0, 32)
			b.AutomaticSize = Enum.AutomaticSize.X
			b.BackgroundColor3 = C.Raised
			b.BackgroundTransparency = if active then 0.35 else 1
			b.Font = if active then Kit.BoldFont else Kit.MediumFont
			b.TextSize = 15
			b.TextColor3 = if active then C.Text else C.Muted
			b.Text = tab.label
			b.AutoButtonColor = false
			b.LayoutOrder = i
			b.Parent = strip
			corner(b, 999)
			pad(b, 14, 0)
			if active then
				local u = frame(b, UDim2.new(0.5, 0, 1, 2), UDim2.new(0, 18, 0, 2), C.Gold, 0, 2)
				u.AnchorPoint = Vector2.new(0.5, 0)
				corner(u, 1)
			else
				b.MouseEnter:Connect(function()
					b.TextColor3 = C.Text
				end)
				b.MouseLeave:Connect(function()
					b.TextColor3 = C.Muted
				end)
			end
			local onTab = o.onTab
			b.Activated:Connect(function()
				if onTab and not active then
					onTab(tab.id)
				end
			end)
			tabButtons[tab.id] = b
		end
		top = headH + 38
	end
	Kit.GateLine(root, UDim2.fromOffset(0, top + 2), UDim.new(1, 0), 0.6)

	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(0, top + 8)
	body.Size = UDim2.new(1, 0, 1, -(top + 10))
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = C.Gold
	body.ScrollBarImageTransparency = 0.4
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = root
	pad(body, 20, 12)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, Kit.Gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	-- Open: rise and fade in.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.96
	scale.Parent = root
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	return { root = root, body = body, title = title, close = close, tabs = tabButtons }
end

-- Removes everything except layout/padding objects.
function Kit.Clear(target: Instance)
	for _, c in target:GetChildren() do
		if not (c:IsA("UIListLayout") or c:IsA("UIPadding") or c:IsA("UIGridLayout")) then
			c:Destroy()
		end
	end
end

-- Layout pieces -----------------------------------------------------------------------------------

-- A card that lays its children out left to right (vertically centered).
function Kit.Row(parent: Instance, height: number, alt: boolean?): Frame
	local row = frame(parent, UDim2.new(), UDim2.new(1, 0, 0, height), if alt then C.RowAlt else C.Row, 0.08)
	row.LayoutOrder = nextOrder()
	corner(row, Kit.Radius)
	pad(row, 12, 8)
	stroke(row, C.Line, 0.88, 1)
	inkGradient(row, 1.1)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	return row
end

-- A plain horizontal strip without a card (toolbars, button groups).
function Kit.Strip(parent: Instance, height: number): Frame
	local f = frame(parent, UDim2.new(), UDim2.new(1, 0, 0, height), C.Ink, 1)
	f.LayoutOrder = nextOrder()
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	return f
end

-- Vertical stack (name + details inside a row).
-- width > 0: fixed pixels; width < 0: fill the row minus that many pixels; nil: fill - 260.
function Kit.Stack(parent: Instance, width: number?): Frame
	local f = frame(parent, UDim2.new(), if width == nil then UDim2.new(1, -260, 1, 0) elseif width < 0 then UDim2.new(1, width, 1, 0) else UDim2.new(0, width, 1, 0), C.Ink, 1)
	f.LayoutOrder = nextOrder()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 3)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = f
	return f
end

export type LabelOpts = { size: number?, color: Color3?, bold: boolean?, width: number?, height: number?, wrap: boolean?, font: Enum.Font?, align: Enum.TextXAlignment? }

function Kit.Label(parent: Instance, str: string, opts: LabelOpts?): TextLabel
	local o: LabelOpts = opts or {}
	local size = o.size or 16
	local l = text(parent, str, o.font or (if o.bold then Kit.BoldFont else Kit.BodyFont), size, o.color or C.Text)
	l.TextXAlignment = o.align or Enum.TextXAlignment.Left
	l.TextWrapped = o.wrap == true
	l.Size = if o.width then UDim2.fromOffset(o.width, o.height or size + 6) else UDim2.new(1, 0, 0, o.height or size + 6)
	if o.wrap then
		l.AutomaticSize = Enum.AutomaticSize.Y
	end
	l.LayoutOrder = nextOrder()
	return l
end

-- Section header: small caps-style label with a hairline after it.
function Kit.Section(parent: Instance, str: string, right: string?): Frame
	local f = frame(parent, UDim2.new(), UDim2.new(1, 0, 0, 26), C.Ink, 1)
	f.LayoutOrder = nextOrder()
	local l = text(f, string.upper(str), Kit.BoldFont, 13, C.Gold)
	l.Size = UDim2.new(0, 0, 1, 0)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.TextXAlignment = Enum.TextXAlignment.Left
	local line = frame(f, UDim2.new(0, 0, 0.5, 0), UDim2.new(1, 0, 0, 1), C.Line, 0.8)
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.ZIndex = 0
	-- the label sits on a little ink plate so the line runs behind it
	l.BackgroundColor3 = C.Panel
	l.BackgroundTransparency = 0
	local lp = Instance.new("UIPadding")
	lp.PaddingRight = UDim.new(0, 10)
	lp.Parent = l
	if right then
		local r = text(f, right, Kit.MediumFont, 13, C.Muted)
		r.AnchorPoint = Vector2.new(1, 0)
		r.Position = UDim2.fromScale(1, 0)
		r.Size = UDim2.new(0, 0, 1, 0)
		r.AutomaticSize = Enum.AutomaticSize.X
		r.BackgroundColor3 = C.Panel
		r.BackgroundTransparency = 0
		local rp = Instance.new("UIPadding")
		rp.PaddingLeft = UDim.new(0, 10)
		rp.Parent = r
	end
	return f
end

-- A rounded pill with short text (rarity, status, counts).
function Kit.Chip(parent: Instance, str: string, color: Color3?, filled: boolean?): TextLabel
	local col = color or C.Muted
	local l = text(parent, str, Kit.BoldFont, 12, if filled then C.Ink else col)
	l.Size = UDim2.fromOffset(0, 22)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.BackgroundColor3 = col
	l.BackgroundTransparency = if filled then 0 else 0.86
	l.LayoutOrder = nextOrder()
	corner(l, 999)
	pad(l, 9, 0)
	if not filled then
		stroke(l, col, 0.6, 1)
	end
	return l
end

-- A thin rounded progress bar (0..1).
function Kit.Progress(parent: Instance, frac: number, color: Color3?, width: number?, height: number?): Frame
	local h = height or 6
	local track = frame(parent, UDim2.new(), if width then UDim2.fromOffset(width, h) else UDim2.new(1, 0, 0, h), C.Ink, 0.1)
	track.LayoutOrder = nextOrder()
	corner(track, 999)
	local fill = frame(track, UDim2.new(), UDim2.fromScale(math.clamp(frac, 0, 1), 1), color or C.Gold, 0, track.ZIndex + 1)
	corner(fill, 999)
	return track
end

-- Currency / stat pill: icon + value (e.g. Ember 48.2K). Returns the pill and its value label.
function Kit.Currency(parent: Instance, kind: "ember" | "jade" | "power" | "level", value: string): (Frame, TextLabel)
	local col = if kind == "ember" then C.Ember elseif kind == "jade" then C.Jade elseif kind == "power" then C.Gold else C.Text
	local f = frame(parent, UDim2.new(), UDim2.fromOffset(0, 30), C.Ink, 0.25)
	f.AutomaticSize = Enum.AutomaticSize.X
	f.LayoutOrder = nextOrder()
	corner(f, 999)
	stroke(f, C.Line, 0.82, 1)
	pad(f, 10, 0)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	Kit.Icon(f, if kind == "power" then "star" elseif kind == "level" then "bell" else kind, 14, col)
	local l = text(f, value, Kit.BoldFont, 15, C.Text)
	l.Size = UDim2.new(0, 0, 1, 0)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.LayoutOrder = nextOrder()
	return f, l
end

-- Friendly empty state.
function Kit.Empty(parent: Instance, title: string, hint: string?)
	local f = frame(parent, UDim2.new(), UDim2.new(1, 0, 0, if hint then 120 else 90), C.Ink, 1)
	f.LayoutOrder = nextOrder()
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	local d = Kit.Icon(f, "bell", 26, C.Faint)
	d.LayoutOrder = 1
	local t = text(f, title, Kit.MediumFont, 17, C.Muted)
	t.Size = UDim2.new(1, 0, 0, 22)
	t.LayoutOrder = 2
	if hint then
		local h = text(f, hint, Kit.BodyFont, 14, C.Faint)
		h.Size = UDim2.new(1, 0, 0, 18)
		h.LayoutOrder = 3
	end
end

-- Buttons -----------------------------------------------------------------------------------------
-- Style follows the color you pass:
--   Accent           -> primary: filled vermilion
--   Row/Steel/Panel  -> quiet: no fill, light text, hairline
--   anything else    -> tinted: soft fill of that color, colored text
function Kit.Button(parent: Instance, label: string, color: Color3, onClick: () -> (), width: number?): TextButton
	local primary = color == C.Accent
	local quiet = color == C.Row or color == C.Steel or color == C.Panel or color == C.RowAlt
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width or 120, 36)
	b.BorderSizePixel = 0
	b.Font = Kit.BoldFont
	b.TextSize = 15
	b.TextWrapped = true
	b.Text = label
	b.AutoButtonColor = false
	b.LayoutOrder = nextOrder()
	b.Parent = parent
	corner(b, Kit.Radius)
	local baseColor, baseT, textColor
	if primary then
		baseColor, baseT, textColor = color, 0, C.Text
		inkGradient(b, 1.15)
	elseif quiet then
		baseColor, baseT, textColor = C.Raised, 0.55, C.Text
	else
		baseColor, baseT, textColor = color, 0.82, color:Lerp(C.Text, 0.35)
	end
	b.BackgroundColor3 = baseColor
	b.BackgroundTransparency = baseT
	b.TextColor3 = textColor
	local st = stroke(b, if primary then Color3.new(1, 1, 1) elseif quiet then C.Line else color, if primary then 0.85 elseif quiet then 0.8 else 0.55, 1)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, QUICK, { BackgroundTransparency = math.max(0, baseT - 0.2) }):Play()
		st.Transparency = math.max(0, st.Transparency - 0.25)
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, QUICK, { BackgroundTransparency = baseT }):Play()
		st.Transparency = if primary then 0.85 elseif quiet then 0.8 else 0.55
	end)
	local busy = false
	b.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		b.BackgroundTransparency = math.max(0, baseT - 0.4)
		TweenService:Create(b, TweenInfo.new(0.25), { BackgroundTransparency = baseT }):Play()
		local ok, err = pcall(onClick :: any)
		if not ok then
			warn("[UI] button error", err)
		end
		busy = false
	end)
	return b
end

-- A small square toggle (selection checkboxes).
function Kit.Toggle(parent: Instance, on: boolean, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(22, 22)
	b.BackgroundColor3 = if on then C.Accent else C.Ink
	b.BackgroundTransparency = if on then 0 else 0.3
	b.Text = ""
	b.AutoButtonColor = false
	b.LayoutOrder = nextOrder()
	b.Parent = parent
	corner(b, 5)
	stroke(b, if on then C.Accent else C.Line, if on then 0.2 else 0.55, 1)
	if on then
		local tick = Kit.Icon(b, "star", 12, C.Text)
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.5, 0.5)
	end
	b.Activated:Connect(onClick)
	return b
end

-- Viewports ---------------------------------------------------------------------------------------
local function viewportBase(parent: Instance, size: number, background: Color3?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromOffset(size, size)
	vp.BackgroundColor3 = background or C.Ink
	vp.BackgroundTransparency = 0.1
	vp.Ambient = Color3.fromRGB(175, 170, 165)
	vp.LightColor = Color3.fromRGB(255, 244, 228)
	vp.LightDirection = Vector3.new(-1, -1, -0.6)
	vp.LayoutOrder = nextOrder()
	vp.Parent = parent
	corner(vp, Kit.Radius)
	stroke(vp, C.Line, 0.8, 1)
	return vp
end

-- A ViewportFrame showing `model` (which this takes ownership of), framed to fit.
function Kit.Viewport(parent: Instance, model: Model?, size: number, length: number): ViewportFrame
	local vp = viewportBase(parent, size)
	if model then
		-- Tilt diagonally like an inventory icon, centered on the blade's midpoint.
		model:PivotTo(CFrame.Angles(0, 0, math.rad(-45)))
		model.Parent = vp
		local cam = Instance.new("Camera")
		local mid = (CFrame.Angles(0, 0, math.rad(-45)) * CFrame.new(0, length / 2 - 0.8, 0)).Position
		cam.FieldOfView = 30
		cam.CFrame = CFrame.lookAt(mid + Vector3.new(0, 0, length * 1.9 + 1), mid)
		cam.Parent = vp
		vp.CurrentCamera = cam
	end
	return vp
end

-- A ViewportFrame showing a Spirit model (takes ownership) from a 3/4 angle.
function Kit.SpiritViewport(parent: Instance, model: Model?, size: number, background: Color3?): ViewportFrame
	local vp = viewportBase(parent, size, background)
	if model then
		model:PivotTo(CFrame.new())
		model.Parent = vp
		local cam = Instance.new("Camera")
		cam.FieldOfView = 35
		local _, extents = model:GetBoundingBox()
		local radius = math.max(extents.X, extents.Y, extents.Z)
		cam.CFrame = CFrame.lookAt(Vector3.new(radius * 1.3, radius * 0.6, -radius * 1.6), Vector3.new())
		cam.Parent = vp
		vp.CurrentCamera = cam
	end
	return vp
end

function Kit.Spacer(parent: Instance, height: number)
	local f = frame(parent, UDim2.new(), UDim2.new(1, 0, 0, height), C.Ink, 1)
	f.LayoutOrder = nextOrder()
end

-- Color for a rarity name (falls back to text color).
function Kit.RarityColor(rarityColor: Color3?): Color3
	return rarityColor or C.Text
end

return Kit
