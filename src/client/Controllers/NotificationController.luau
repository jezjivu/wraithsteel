--!strict
-- NotificationController: shows server Notify messages as simple toasts.
-- PLACEHOLDER visuals (plain TextLabels) so playtests have feedback; Agent D replaces the look.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local NotificationController = { Name = "NotificationController", Priority = 40 }

local TOAST_SECONDS = 4
local MAX_TOASTS = 4

local container: Frame? = nil

function NotificationController.Show(kind: string, text: string)
	local frame = container
	if frame == nil then
		return
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 28)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = if kind == "Error" then Color3.fromRGB(120, 30, 30) else Color3.fromRGB(25, 25, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.Parent = frame
	local labels = {}
	for _, child in frame:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels > MAX_TOASTS then
		labels[1]:Destroy()
	end
	task.delay(TOAST_SECONDS, function()
		label:Destroy()
	end)
end

function NotificationController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Toasts"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 60)
	frame.Size = UDim2.new(0.4, 0, 0, 140)
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame
	container = frame
end

function NotificationController.Start()
	Net.Client.On("Notify", function(kind, text)
		NotificationController.Show(tostring(kind), tostring(text))
	end)
end

return NotificationController
