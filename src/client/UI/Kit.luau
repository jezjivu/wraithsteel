--!strict
-- Kit: code-built UI toolkit (windows, rows, labels, buttons, viewports) with the WRAITHSTEEL
-- look: black lacquer, steel hairlines, wraith-red blade lines and gold corner brackets.
-- Panels only use this API, so a designed Studio UI can replace it later.

local TweenService = game:GetService("TweenService")

local Kit = {}

Kit.Colors = {
	Ink = Color3.fromRGB(12, 11, 14),
	Panel = Color3.fromRGB(20, 18, 22),
	Row = Color3.fromRGB(30, 27, 32),
	RowAlt = Color3.fromRGB(35, 31, 37),
	Gold = Color3.fromRGB(232, 196, 120),
	Text = Color3.fromRGB(236, 230, 220),
	Muted = Color3.fromRGB(150, 142, 136),
	Good = Color3.fromRGB(80, 160, 100),
	Bad = Color3.fromRGB(176, 52, 48),
	Accent = Color3.fromRGB(196, 44, 40), -- wraith red
	Jade = Color3.fromRGB(60, 160, 120),
	Blue = Color3.fromRGB(84, 120, 186),
	Steel = Color3.fromRGB(128, 124, 120),
}

-- WRAITHSTEEL look: black lacquer panels with sharp corners, a thin steel frame, a wraith-red
-- blade line and gold corner brackets. Titles in an old serif, body text in Gotham.
Kit.TitleFont = Enum.Font.Antique
Kit.BodyFont = Enum.Font.Gotham
Kit.BoldFont = Enum.Font.GothamBold

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, math.min(r, 3))
	c.Parent = parent
end

local function pad(parent: Instance, p: number)
	local u = Instance.new("UIPadding")
	u.PaddingTop = UDim.new(0, p)
	u.PaddingBottom = UDim.new(0, p)
	u.PaddingLeft = UDim.new(0, p)
	u.PaddingRight = UDim.new(0, p)
	u.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number?): UIStroke
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = color
	st.Transparency = transparency
	st.Thickness = thickness or 1
	st.Parent = parent
	return st
end

local function bar(parent: Instance, pos: UDim2, size: UDim2, color: Color3, z: number?): Frame
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

-- Gold L-shaped brackets on the four corners of a frame.
function Kit.Brackets(frame: GuiObject, color: Color3?, len: number?, z: number?)
	local c = color or Kit.Colors.Gold
	local l = len or 14
	for _, ax in { 0, 1 } do
		for _, ay in { 0, 1 } do
			local pos = UDim2.new(ax, if ax == 0 then -2 else 2, ay, if ay == 0 then -2 else 2)
			for _, size in { UDim2.fromOffset(l, 2), UDim2.fromOffset(2, l) } do
				local f = bar(frame, pos, size, c, z or 5)
				f.AnchorPoint = Vector2.new(ax, ay)
			end
		end
	end
end

-- A thin red blade line that fades out to the right.
function Kit.BladeLine(parent: Instance, pos: UDim2, width: UDim, color: Color3?): Frame
	local f = bar(parent, pos, UDim2.new(width, UDim.new(0, 2)), color or Kit.Colors.Accent, 3)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	return f
end

function Kit.Screen(parent: Instance, name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = order or 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent
	return gui
end

export type Window = {
	root: Frame,
	body: ScrollingFrame,
	title: TextLabel,
	close: TextButton,
}

-- Centered window with a title bar and a vertically scrolling body.
function Kit.Window(parent: Instance, titleText: string): Window
	local root = Instance.new("Frame")
	root.Name = "Window"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.52)
	root.Size = UDim2.fromScale(0.66, 0.78)
	root.BackgroundColor3 = Kit.Colors.Panel
	root.BackgroundTransparency = 0.04
	root.BorderSizePixel = 0
	root.Parent = parent
	corner(root, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(800, 660)
	limit.MinSize = Vector2.new(300, 260)
	limit.Parent = root
	stroke(root, Kit.Colors.Steel, 0.45, 1)
	-- Lacquer: deep ink with a faint red glow from the top.
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 22, 24)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(22, 19, 23)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 13, 16)),
	})
	grad.Rotation = 90
	grad.Parent = root
	Kit.Brackets(root)

	-- Title bar: red tick, serif title, small realm mark on the right, blade line under it.
	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0, 50)
	head.BackgroundTransparency = 1
	head.Parent = root
	bar(head, UDim2.fromOffset(16, 13), UDim2.fromOffset(4, 24), Kit.Colors.Accent, 2)
	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(30, 0)
	title.Size = UDim2.new(1, -120, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Kit.TitleFont
	title.TextColor3 = Kit.Colors.Gold
	title.TextSize = 28
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = string.upper(titleText)
	title.Parent = head
	local mark = Instance.new("TextLabel")
	mark.AnchorPoint = Vector2.new(1, 0.5)
	mark.Position = UDim2.new(1, -56, 0.5, 0)
	mark.Size = UDim2.fromOffset(120, 20)
	mark.BackgroundTransparency = 1
	mark.Font = Kit.BoldFont
	mark.TextSize = 10
	mark.TextColor3 = Kit.Colors.Steel
	mark.TextXAlignment = Enum.TextXAlignment.Right
	mark.Text = "W R A I T H S T E E L"
	mark.Parent = head
	Kit.BladeLine(head, UDim2.new(0, 14, 1, -2), UDim.new(1, -28))

	-- Pop-in: grow from 94% with a quick fade.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.94
	scale.Parent = root
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -10, 0, 25)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundTransparency = 1
	close.Font = Kit.BoldFont
	close.TextColor3 = Kit.Colors.Muted
	close.TextSize = 20
	close.Text = "✕"
	close.Parent = head
	close.MouseEnter:Connect(function()
		close.TextColor3 = Kit.Colors.Accent
	end)
	close.MouseLeave:Connect(function()
		close.TextColor3 = Kit.Colors.Muted
	end)

	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(0, 56)
	body.Size = UDim2.new(1, 0, 1, -60)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = Kit.Colors.Accent
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = root
	pad(body, 14)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	return { root = root, body = body, title = title, close = close }
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

-- Removes everything except layout/padding objects.
function Kit.Clear(frame: Instance)
	for _, c in frame:GetChildren() do
		if not (c:IsA("UIListLayout") or c:IsA("UIPadding") or c:IsA("UIGridLayout")) then
			c:Destroy()
		end
	end
end

-- A horizontal row card. Children are laid out left to right.
function Kit.Row(parent: Instance, height: number, alt: boolean?): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, height)
	row.BackgroundColor3 = if alt then Kit.Colors.RowAlt else Kit.Colors.Row
	row.BackgroundTransparency = 0.1
	row.BorderSizePixel = 0
	row.LayoutOrder = nextOrder()
	row.Parent = parent
	corner(row, 2)
	pad(row, 8)
	-- A faint wraith-red glow from the left edge and a steel hairline frame.
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 140)),
		ColorSequenceKeypoint.new(0.04, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
	})
	g.Parent = row
	stroke(row, Kit.Colors.Steel, 0.82, 1)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	return row
end

-- Vertical stack (for name + details inside a row).
function Kit.Stack(parent: Instance, width: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	-- width > 0: fixed pixels; width < 0: fill the row minus that many pixels; nil: fill - 260.
	f.Size = if width == nil then UDim2.new(1, -260, 1, 0) elseif width < 0 then UDim2.new(1, width, 1, 0) else UDim2.new(0, width, 1, 0)
	f.LayoutOrder = nextOrder()
	f.Parent = parent
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = f
	return f
end

export type LabelOpts = { size: number?, color: Color3?, bold: boolean?, width: number?, height: number?, wrap: boolean? }

function Kit.Label(parent: Instance, text: string, opts: LabelOpts?): TextLabel
	local o: LabelOpts = opts or {}
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = if o.bold then Kit.BoldFont else Kit.BodyFont
	l.TextSize = o.size or 16
	l.TextColor3 = o.color or Kit.Colors.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = o.wrap == true
	l.RichText = true
	l.Text = text
	l.Size = if o.width then UDim2.fromOffset(o.width, o.height or (o.size or 16) + 6) else UDim2.new(1, -8, 0, o.height or (o.size or 16) + 6)
	if o.wrap then
		l.AutomaticSize = Enum.AutomaticSize.Y
	end
	l.LayoutOrder = nextOrder()
	l.Parent = parent
	return l
end

-- Buttons: dark steel plate tinted by `color`, a bright edge of that color on the left and a
-- thin frame; hover slides the edge wider and lifts the plate.
function Kit.Button(parent: Instance, text: string, color: Color3, onClick: () -> (), width: number?): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width or 120, 34)
	b.BackgroundColor3 = color:Lerp(Kit.Colors.Ink, 0.55)
	b.BorderSizePixel = 0
	b.Font = Kit.BoldFont
	b.TextColor3 = Kit.Colors.Text
	b.TextSize = 14
	b.TextWrapped = true
	b.Text = string.upper(text)
	b.AutoButtonColor = false
	b.LayoutOrder = nextOrder()
	b.Parent = parent
	corner(b, 2)
	local st = stroke(b, color, 0.35, 1)
	local edge = bar(b, UDim2.fromOffset(0, 0), UDim2.new(0, 3, 1, 0), color:Lerp(Color3.new(1, 1, 1), 0.15), 2)
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	sheen.Rotation = 90
	sheen.Parent = b
	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		TweenService:Create(edge, TweenInfo.new(0.1), { Size = UDim2.new(0, 6, 1, 0) }):Play()
		TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = color:Lerp(Kit.Colors.Ink, 0.3) }):Play()
		st.Transparency = 0
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(edge, TweenInfo.new(0.1), { Size = UDim2.new(0, 3, 1, 0) }):Play()
		TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = base }):Play()
		st.Transparency = 0.35
	end)
	local busy = false
	b.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		b.BackgroundColor3 = color
		TweenService:Create(b, TweenInfo.new(0.2), { BackgroundColor3 = base }):Play()
		local ok, err = pcall(onClick :: any)
		if not ok then
			warn("[UI] button error", err)
		end
		busy = false
	end)
	return b
end

-- A ViewportFrame showing `model` (which this takes ownership of), framed to fit.
function Kit.Viewport(parent: Instance, model: Model?, size: number, length: number): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromOffset(size, size)
	vp.BackgroundColor3 = Kit.Colors.Ink
	vp.Ambient = Color3.fromRGB(170, 165, 160)
	vp.LightColor = Color3.fromRGB(255, 245, 230)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.LayoutOrder = nextOrder()
	vp.Parent = parent
	corner(vp, 2)
	stroke(vp, Kit.Colors.Steel, 0.6, 1)
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

-- A ViewportFrame showing a Spirit model (takes ownership) from a 3/4 angle, slowly turning.
function Kit.SpiritViewport(parent: Instance, model: Model?, size: number, background: Color3?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromOffset(size, size)
	vp.BackgroundColor3 = background or Kit.Colors.Ink
	vp.Ambient = Color3.fromRGB(180, 175, 170)
	vp.LightColor = Color3.fromRGB(255, 245, 230)
	vp.LightDirection = Vector3.new(-1, -1, -0.5)
	vp.LayoutOrder = nextOrder()
	vp.Parent = parent
	corner(vp, 2)
	stroke(vp, Kit.Colors.Steel, 0.6, 1)
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
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, height)
	f.LayoutOrder = nextOrder()
	f.Parent = parent
end

-- Color for a rarity name (falls back to text color).
function Kit.RarityColor(rarityColor: Color3?): Color3
	return rarityColor or Kit.Colors.Text
end

return Kit
