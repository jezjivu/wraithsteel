--!strict
-- UIController: opens shop/menu panels (src/client/UI/Panels) from hub stations (proximity
-- prompts on parts with a Station attribute) or from the dock. One panel at a time;
-- panels re-render when the profile keys they watch change. Combat input is paused while a
-- panel is open.
-- The dock (left edge) has five groups; a group's window shows its panels as tabs:
--   Blade (Weapons, Styles, Arts, Skills) · Spirits (Spirits, Lanterns, Expeditions) ·
--   World (Quests, Map, Travel) · Bonds (Party, Raids, Trade) ·
--   Market (Store, Night Market, Bell Dice, Codes)
--
-- API:
--   UIController.Open(panelName, opts?)   panelName = "Weapons" | "Lanterns" | "Spirits" |
--                                          "Expeditions" | "Quests" | "Store" | "Codes" | "Party" | "Trade"
--                                          | "NightMarket" | "Raid"
--   UIController.Close()

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local PanelsFolder = UI:WaitForChild("Panels")

local DataController = require(script.Parent.DataController)
local InputController = require(script.Parent.InputController)
local NotificationController = require(script.Parent.NotificationController)
local TradeController = require(script.Parent.TradeController)

local UIController = { Name = "UIController", Priority = 45 }

-- Hub station kind -> panel name.
local STATION_PANELS = {
	WeaponSmith = "Weapons",
	LanternShrine = "Lanterns",
	SpiritShrine = "Spirits",
	ExpeditionBoard = "Expeditions",
	QuestBoard = "Quests",
	Store = "Store",
	CodeStone = "Codes",
	Dojo = "Styles",
	Waystone = "Travel",
	NightMarket = "NightMarket",
	BellDice = "BellDice",
}

-- Dock groups (available anywhere). Buying weapons / opening lanterns still needs the station.
type Group = { id: string, label: string, icon: string, tabs: { Kit.Tab } }
local GROUPS: { Group } = {
	{ id = "blade", label = "Blade", icon = "blade", tabs = {
		{ id = "Weapons", label = "Weapons" },
		{ id = "Styles", label = "Styles" },
		{ id = "Arts", label = "Arts" },
		{ id = "Skills", label = "Skills" },
	} },
	{ id = "spirits", label = "Spirits", icon = "spirit", tabs = {
		{ id = "Spirits", label = "Spirits" },
		{ id = "Lanterns", label = "Lanterns" },
		{ id = "Expeditions", label = "Expeditions" },
	} },
	{ id = "world", label = "World", icon = "world", tabs = {
		{ id = "Quests", label = "Quests" },
		{ id = "Map", label = "Map" },
		{ id = "Travel", label = "Travel" },
	} },
	{ id = "bonds", label = "Bonds", icon = "bonds", tabs = {
		{ id = "Party", label = "Party" },
		{ id = "Raid", label = "Raids" },
		{ id = "Trade", label = "Trade" },
	} },
	{ id = "market", label = "Market", icon = "market", tabs = {
		{ id = "Store", label = "Store" },
		{ id = "NightMarket", label = "Night Market" },
		{ id = "BellDice", label = "Bell Dice" },
		{ id = "Codes", label = "Codes" },
	} },
}

local function groupOf(panelName: string): Group?
	for _, g in GROUPS do
		for _, t in g.tabs do
			if t.id == panelName then
				return g
			end
		end
	end
	return nil
end

-- Last tab used per group, so the dock reopens where you left off.
local lastTab: { [string]: string } = {}
type DockItem = { button: TextButton, plate: Frame, icon: Frame, label: TextLabel }
local dockButtons: { [string]: DockItem } = {}
local refreshDock: () -> () = function() end

local panels: { [string]: PanelTypes.Panel } = {}
local screen: ScreenGui? = nil

type Open = {
	name: string,
	window: Kit.Window,
	ctx: PanelTypes.Ctx,
	token: number,
}
local current: Open? = nil
local renderToken = 0

local function render(o: Open)
	renderToken += 1
	local token = renderToken
	o.token = token
	task.spawn(function()
		local body = o.window.body
		local scroll = body.CanvasPosition
		Kit.Clear(body)
		local ok, err = pcall(panels[o.name].Render :: any, body, o.ctx)
		if not ok then
			warn("[UIController] panel", o.name, "failed:", err)
			Kit.Label(body, "Something went wrong. Close and try again.", { color = Kit.Colors.Bad })
		end
		if token == renderToken then
			body.CanvasPosition = scroll
		end
	end)
end

function UIController.Close()
	local o = current
	if o then
		current = nil
		o.window.root:Destroy()
		InputController.SetEnabled(true)
	end
	refreshDock()
end

function UIController.Open(name: string, opts: { atStation: boolean?, lanternId: string? }?)
	local panel = panels[name]
	local gui = screen
	if panel == nil or gui == nil then
		return
	end
	UIController.Close()
	local group = groupOf(name)
	if group then
		lastTab[group.id] = name
	end
	local window = Kit.Window(gui, panel.Title, {
		tabs = if group then group.tabs else nil,
		activeTab = name,
		onTab = function(id)
			UIController.Open(id)
		end,
	})
	local o: Open
	local ctx: PanelTypes.Ctx = {
		atStation = (opts and opts.atStation) == true,
		lanternId = opts and opts.lanternId,
		refresh = function()
			if current == o then
				render(o)
			end
		end,
		close = UIController.Close,
		notify = function(text, isError)
			NotificationController.Show(if isError then "Error" else "Info", text)
		end,
	}
	o = { name = name, window = window, ctx = ctx, token = 0 }
	current = o
	window.close.Activated:Connect(UIController.Close)
	if panel.Changed then
		local conn = panel.Changed:Connect(ctx.refresh)
		window.root.Destroying:Connect(function()
			conn:Disconnect()
		end)
	end
	InputController.SetEnabled(false)
	render(o)
	refreshDock()
end

-- The dock: a slim ink rail on the left edge with one icon per group. The open group's icon
-- sits on a vermilion seal.
local function paintIcon(icon: Frame, color: Color3)
	for _, part in icon:GetDescendants() do
		if part:IsA("Frame") and part.BackgroundTransparency < 1 then
			part.BackgroundColor3 = color
		elseif part:IsA("UIStroke") then
			part.Color = color
		end
	end
end

local function buildDock(gui: ScreenGui)
	local C = Kit.Colors
	local ITEM, GAP = 58, 2
	local rail = Instance.new("Frame")
	rail.Name = "Dock"
	rail.AnchorPoint = Vector2.new(0, 0.5)
	rail.Position = UDim2.new(0, 12, 0.5, 0)
	rail.Size = UDim2.fromOffset(ITEM + 12, (ITEM + GAP) * #GROUPS - GAP + 12)
	rail.BackgroundColor3 = C.Ink
	rail.BackgroundTransparency = 0.25
	rail.BorderSizePixel = 0
	rail.Parent = gui
	Kit.AutoScale(rail)
	Kit.Corner(rail, 14)
	Kit.Stroke(rail, C.Line, 0.78, 1)
	Kit.Pad(rail, 6)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, GAP)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = rail
	for i, g in GROUPS do
		local b = Instance.new("TextButton")
		b.Name = g.id
		b.Size = UDim2.fromOffset(ITEM, ITEM)
		b.BackgroundTransparency = 1
		b.Text = ""
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.Parent = rail
		local plate = Instance.new("Frame")
		plate.AnchorPoint = Vector2.new(0.5, 0)
		plate.Position = UDim2.new(0.5, 0, 0, 3)
		plate.Size = UDim2.fromOffset(36, 36)
		plate.BackgroundColor3 = C.Accent
		plate.BackgroundTransparency = 1
		plate.BorderSizePixel = 0
		plate.Parent = b
		Kit.Corner(plate, 9)
		local icon = Kit.Icon(plate, g.icon, 20, C.Muted)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 1, -1)
		label.Size = UDim2.new(1, 0, 0, 14)
		label.BackgroundTransparency = 1
		label.Font = Kit.MediumFont
		label.TextSize = 12
		label.TextColor3 = C.Muted
		label.Text = g.label
		label.Parent = b
		b.MouseEnter:Connect(function()
			if not (current and groupOf(current.name) == g) then
				plate.BackgroundColor3 = C.Raised
				plate.BackgroundTransparency = 0.1
				paintIcon(icon, C.Text)
			end
		end)
		b.MouseLeave:Connect(function()
			refreshDock()
		end)
		b.Activated:Connect(function()
			if current and groupOf(current.name) == g then
				UIController.Close()
			else
				UIController.Open(lastTab[g.id] or g.tabs[1].id)
			end
		end)
		dockButtons[g.id] = { button = b, plate = plate, icon = icon, label = label }
	end
	refreshDock = function()
		local o = current
		local openGroup = if o then groupOf(o.name) else nil
		for _, g in GROUPS do
			local d = dockButtons[g.id]
			local on = openGroup == g
			d.plate.BackgroundColor3 = C.Accent
			d.plate.BackgroundTransparency = if on then 0 else 1
			d.label.TextColor3 = if on then C.Text else C.Muted
			paintIcon(d.icon, if on then C.Text else C.Muted)
		end
	end
	refreshDock()
end

function UIController.Init()
	for _, module in PanelsFolder:GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, panel = pcall(require, module)
			if ok then
				panels[module.Name] = panel
			else
				warn("[UIController] failed to load panel", module.Name, panel)
			end
		end
	end
	local gui = Kit.Screen(Players.LocalPlayer:WaitForChild("PlayerGui"), "Menus", 10)
	screen = gui
	buildDock(gui)
end

function UIController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local part = prompt.Parent
		if part == nil then
			return
		end
		local kind = part:GetAttribute("Station")
		local panelName = if type(kind) == "string" then STATION_PANELS[kind] else nil
		if panelName then
			local lanternId = part:GetAttribute("LanternId")
			UIController.Open(panelName, { atStation = true, lanternId = if type(lanternId) == "string" then lanternId else nil })
		end
	end)

	-- Escape closes the open panel. (Purchases are server-validated either way.)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			UIController.Close()
		end
		-- M toggles the map, K the skill tree.
		if not processed and (input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.K) then
			local name = if input.KeyCode == Enum.KeyCode.M then "Map" else "Skills"
			if current and current.name == name then
				UIController.Close()
			else
				UIController.Open(name)
			end
		end
	end)

	-- A trade session opening pops the Trade panel up for both players.
	TradeController.Started:Connect(function()
		if current == nil or current.name ~= "Trade" then
			UIController.Open("Trade")
		end
	end)

	DataController.Changed:Connect(function(key)
		local o = current
		if o and table.find(panels[o.name].WatchKeys, key) then
			-- Debounce bursts of changes (e.g. opening 3 lanterns).
			local token = renderToken
			task.delay(0.1, function()
				if current == o and token == renderToken then
					render(o)
				end
			end)
		end
	end)
end

return UIController
