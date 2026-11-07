--!strict
-- NotificationController: server Notify messages as toasts in the Kit "Ink & Seal" look:
-- centered ink pills under the top bar with a small colored diamond for the kind
-- (Error = vermilion, LevelUp/Pass = gold, everything else = jade). Newest at the bottom.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local NotificationController = { Name = "NotificationController", Priority = 40 }

local TOAST_SECONDS = 4
local MAX_TOASTS = 4
local C = Kit.Colors

local container: Frame? = nil
local counter = 0

local function accentFor(kind: string): Color3
	if kind == "Error" then
		return C.Bad
	elseif kind == "LevelUp" or kind == "Pass" or kind == "Raid" then
		return C.Gold
	end
	return C.Jade
end

function NotificationController.Show(kind: string, text: string)
	local frame = container
	if frame == nil then
		return
	end
	counter += 1
	local pill = Instance.new("Frame")
	pill.Name = "Toast"
	pill.Size = UDim2.fromOffset(0, 36)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = C.Ink
	pill.BackgroundTransparency = 0.12
	pill.BorderSizePixel = 0
	pill.LayoutOrder = counter
	pill.Parent = frame
	Kit.Corner(pill, 999)
	local accent = accentFor(kind)
	Kit.Stroke(pill, accent, 0.6, 1)
	Kit.Pad(pill, 16, 0)
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 10)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = pill
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(7, 7)
	dot.Rotation = 45
	dot.BackgroundColor3 = accent
	dot.BorderSizePixel = 0
	dot.LayoutOrder = 1
	dot.Parent = pill
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 0, 1, 0)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 1
	label.TextColor3 = if kind == "Error" then Color3.fromRGB(255, 176, 166) else C.Text
	label.TextSize = 16
	label.Font = Kit.MediumFont
	label.Text = text
	label.LayoutOrder = 2
	label.Parent = pill
	local scale = Instance.new("UIScale")
	scale.Scale = 0.9
	scale.Parent = pill
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local toasts = {}
	for _, child in frame:GetChildren() do
		if child.Name == "Toast" then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return (a :: Frame).LayoutOrder < (b :: Frame).LayoutOrder
	end)
	if #toasts > MAX_TOASTS then
		toasts[1]:Destroy()
	end
	task.delay(TOAST_SECONDS, function()
		TweenService:Create(pill, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		task.delay(0.26, function()
			pill:Destroy()
		end)
	end)
end

function NotificationController.Init()
	local gui = Kit.Screen(Players.LocalPlayer:WaitForChild("PlayerGui"), "Toasts", 12)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 12)
	frame.Size = UDim2.new(0.6, 0, 0, 180)
	frame.Parent = gui
	Kit.AutoScale(frame, nil, 0.75)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	container = frame
end

function NotificationController.Start()
	Net.Client.On("Notify", function(kind, text)
		NotificationController.Show(tostring(kind), tostring(text))
	end)
end

return NotificationController
