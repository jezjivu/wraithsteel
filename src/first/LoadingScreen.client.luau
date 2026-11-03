--!strict
-- LoadingScreen (ReplicatedFirst): replaces Roblox's default loading screen with a WRAITHSTEEL
-- title card (ink background, gold title, drifting lantern lights) until the game and the
-- player's character are ready, then fades out. Runs before anything else on the client.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MIN_SECONDS = 2.5
local MAX_SECONDS = 25

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(14, 11, 16)
bg.BorderSizePixel = 0
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(40, 20, 22), Color3.fromRGB(10, 8, 14))
grad.Rotation = 90
grad.Parent = bg

local function text(t: string, font: Enum.Font, size: number, color: Color3, y: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.new(1, 0, 0, size + 8)
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = t
	l.Parent = bg
	return l
end

local title = text("WRAITHSTEEL", Enum.Font.Antique, 76, Color3.fromRGB(245, 205, 120), 0.42)
local sub = text("Bell of Nine Gates", Enum.Font.GothamMedium, 26, Color3.fromRGB(230, 220, 205), 0.51)
local status = text("Lighting the lanterns...", Enum.Font.Gotham, 18, Color3.fromRGB(170, 160, 150), 0.8)
local TIPS = {
	"A perfect deflect stops everything - even the red attacks.",
	"Strike an enemy that hasn't seen you: one clean cut ends it.",
	"Barred gates open from the other side. Find the way around.",
	"Gold rings on towers: press V to hook up and look over the valley.",
	"Ashen Relics hide in every region. Each one is a skill point.",
	"Die, and a quarter of your Ember stays where you fell. Go back for it.",
	"Mash attacks and enemies start deflecting you. Read them, then cut.",
}
local tip = text(TIPS[math.random(1, #TIPS)], Enum.Font.GothamMedium, 16, Color3.fromRGB(200, 185, 160), 0.86)

local line = Instance.new("Frame")
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.Position = UDim2.fromScale(0.5, 0.465)
line.Size = UDim2.fromScale(0.36, 0.006)
line.BackgroundColor3 = Color3.fromRGB(200, 40, 35)
line.BorderSizePixel = 0
line.Parent = bg
local lineGrad = Instance.new("UIGradient")
lineGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
lineGrad.Parent = line

-- Drifting lantern lights.
local lights = {}
for i = 1, 14 do
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(6 + i % 4 * 2, 6 + i % 4 * 2)
	dot.BackgroundColor3 = Color3.fromRGB(255, 180 + i * 4, 100)
	dot.BackgroundTransparency = 0.3
	dot.BorderSizePixel = 0
	dot.Position = UDim2.fromScale(math.random(), 1 + math.random() * 0.3)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = dot
	dot.Parent = bg
	table.insert(lights, { frame = dot, speed = 0.03 + math.random() * 0.05, sway = math.random() * 6 })
end
local conn = RunService.RenderStepped:Connect(function(dt)
	for _, l in lights do
		local p = l.frame.Position
		local y = p.Y.Scale - l.speed * dt
		if y < -0.05 then
			y = 1.05
		end
		l.frame.Position = UDim2.fromScale(p.X.Scale + math.sin(os.clock() + l.sway) * 0.0004, y)
	end
end)

local start = os.clock()
if not game:IsLoaded() then
	game.Loaded:Wait()
end
status.Text = "Waking your spirit..."
while (player.Character == nil or player.Character:FindFirstChild("HumanoidRootPart") == nil) and os.clock() - start < MAX_SECONDS do
	task.wait(0.1)
end
local remaining = MIN_SECONDS - (os.clock() - start)
if remaining > 0 then
	task.wait(remaining)
end

status.Text = ""
local fade = TweenInfo.new(0.8)
TweenService:Create(bg, fade, { BackgroundTransparency = 1 }):Play()
for _, l in { title, sub, status, tip } do
	TweenService:Create(l, fade, { TextTransparency = 1 }):Play()
end
TweenService:Create(line, fade, { BackgroundTransparency = 1 }):Play()
for _, l in lights do
	TweenService:Create(l.frame, fade, { BackgroundTransparency = 1 }):Play()
end
task.wait(0.9)
conn:Disconnect()
gui:Destroy()
