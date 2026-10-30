--!strict
-- Kit: tiny code-built UI toolkit (windows, rows, labels, buttons, viewports) so every shop and
-- menu works before Agent D designs the real UI. Consistent dark-ink + gold wuxia palette.
-- TODO(Studio/Agent D): restyle or replace with designed ScreenGuis; panels only use this API.

local Kit = {}

Kit.Colors = {
	Ink = Color3.fromRGB(22, 20, 26),
	Panel = Color3.fromRGB(34, 31, 38),
	Row = Color3.fromRGB(46, 42, 52),
	RowAlt = Color3.fromRGB(52, 47, 58),
	Gold = Color3.fromRGB(240, 200, 120),
	Text = Color3.fromRGB(236, 230, 220),
	Muted = Color3.fromRGB(160, 152, 145),
	Good = Color3.fromRGB(70, 150, 90),
	Bad = Color3.fromRGB(160, 60, 55),
	Accent = Color3.fromRGB(180, 70, 50),
	Jade = Color3.fromRGB(60, 160, 120),
	Blue = Color3.fromRGB(70, 110, 170),
}

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
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
	root.Size = UDim2.fromScale(0.62, 0.74)
	root.BackgroundColor3 = Kit.Colors.Panel
	root.Parent = parent
	corner(root, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, 620)
	limit.MinSize = Vector2.new(300, 260)
	limit.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Color = Kit.Colors.Gold
	stroke.Transparency = 0.5
	stroke.Thickness = 2
	stroke.Parent = root

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 44)
	bar.BackgroundColor3 = Kit.Colors.Ink
	bar.Parent = root
	corner(bar, 12)

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -70, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Kit.Colors.Gold
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.Parent = bar

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -8, 0.5, 0)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundColor3 = Kit.Colors.Bad
	close.Font = Enum.Font.GothamBold
	close.TextColor3 = Kit.Colors.Text
	close.TextSize = 18
	close.Text = "X"
	close.Parent = bar
	corner(close, 8)

	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(0, 48)
	body.Size = UDim2.new(1, 0, 1, -52)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = root
	pad(body, 10)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
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
	row.LayoutOrder = nextOrder()
	row.Parent = parent
	corner(row, 8)
	pad(row, 6)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	return row
end

-- Vertical stack (for name + details inside a row). width: pixel width or nil to fill.
function Kit.Stack(parent: Instance, width: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = if width then UDim2.new(0, width, 1, 0) else UDim2.new(1, -260, 1, 0)
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
	l.Font = if o.bold then Enum.Font.GothamBold else Enum.Font.Gotham
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

function Kit.Button(parent: Instance, text: string, color: Color3, onClick: () -> (), width: number?): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width or 120, 34)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Kit.Colors.Text
	b.TextSize = 15
	b.TextWrapped = true
	b.Text = text
	b.AutoButtonColor = true
	b.LayoutOrder = nextOrder()
	b.Parent = parent
	corner(b, 8)
	local busy = false
	b.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
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
	corner(vp, 8)
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
