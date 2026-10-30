--!strict
-- UIController: opens shop/menu panels (src/client/UI/Panels) from hub stations (proximity
-- prompts on parts with a Station attribute) or from the menu bar. One panel at a time;
-- panels re-render when the profile keys they watch change. Combat input is paused while a
-- panel is open.
--
-- API:
--   UIController.Open(panelName, opts?)   panelName = "Weapons" | "Lanterns" | "Spirits" |
--                                          "Expeditions" | "Quests" | "Store" | "Codes" | "Party"
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
}

-- Menu bar (available anywhere). Buying weapons / opening lanterns still needs the hub station.
local MENU = {
	{ panel = "Spirits", label = "Spirits" },
	{ panel = "Weapons", label = "Weapons" },
	{ panel = "Quests", label = "Quests" },
	{ panel = "Expeditions", label = "Expeditions" },
	{ panel = "Store", label = "Store" },
	{ panel = "Party", label = "Party" },
	{ panel = "Codes", label = "Codes" },
}

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
end

function UIController.Open(name: string, opts: { atStation: boolean?, lanternId: string? }?)
	local panel = panels[name]
	local gui = screen
	if panel == nil or gui == nil then
		return
	end
	UIController.Close()
	local window = Kit.Window(gui, panel.Title)
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
end

local function buildMenu(gui: ScreenGui)
	local bar = Instance.new("Frame")
	bar.Name = "MenuBar"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 10, 1, -10)
	bar.Size = UDim2.fromOffset(120, 40 * #MENU + 6 * (#MENU - 1))
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bar
	for _, item in MENU do
		local b = Kit.Button(bar, item.label, Kit.Colors.Panel, function()
			if current and current.name == item.panel then
				UIController.Close()
			else
				UIController.Open(item.panel)
			end
		end, 120)
		b.Size = UDim2.fromOffset(120, 40)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Kit.Colors.Gold
		stroke.Transparency = 0.6
		stroke.Parent = b
	end
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
	buildMenu(gui)
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
