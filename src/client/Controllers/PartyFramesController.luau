--!strict
-- PartyFramesController: your party members on the HUD (top left, under the stats plate):
-- name, a health bar read from their character, and how far away they are. Makes co-op
-- readable at a glance: who is hurt, who wandered off. Leader gets a small gold diamond.

local Players = game:GetService("Players")

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local PartyController = require(script.Parent.PartyController)

local PartyFramesController = { Name = "PartyFramesController", Priority = 46 }

local C = Kit.Colors
local localPlayer = Players.LocalPlayer
local holder: Frame? = nil
type FrameUi = { userId: number, fill: Frame, info: TextLabel }
local frames: { FrameUi } = {}

local function build()
	local h = holder
	if h == nil then
		return
	end
	for _, c in h:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	table.clear(frames)
	local st = PartyController.State
	if not st.inParty then
		return
	end
	for i, m in st.members do
		if m.userId ~= localPlayer.UserId then
			local f = Instance.new("Frame")
			f.Size = UDim2.fromOffset(190, 34)
			f.BackgroundColor3 = C.Ink
			f.BackgroundTransparency = 0.25
			f.BorderSizePixel = 0
			f.LayoutOrder = i
			f.Parent = h
			Kit.Corner(f, 8)
			Kit.Stroke(f, C.Line, 0.8, 1)
			local name = Instance.new("TextLabel")
			name.Position = UDim2.fromOffset(10, 3)
			name.Size = UDim2.new(1, -20, 0, 16)
			name.BackgroundTransparency = 1
			name.Font = Kit.BoldFont
			name.TextSize = 14
			name.TextColor3 = C.Text
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Text = m.name
			name.Parent = f
			if m.userId == st.leader then
				local d = Instance.new("Frame")
				d.AnchorPoint = Vector2.new(1, 0)
				d.Position = UDim2.new(1, -10, 0, 8)
				d.Size = UDim2.fromOffset(7, 7)
				d.Rotation = 45
				d.BackgroundColor3 = C.Gold
				d.BorderSizePixel = 0
				d.Parent = f
			end
			local info = Instance.new("TextLabel")
			info.AnchorPoint = Vector2.new(1, 0)
			info.Position = UDim2.new(1, -24, 0, 4)
			info.Size = UDim2.fromOffset(80, 16)
			info.BackgroundTransparency = 1
			info.Font = Kit.MediumFont
			info.TextSize = 12
			info.TextColor3 = C.Muted
			info.TextXAlignment = Enum.TextXAlignment.Right
			info.Text = ""
			info.Parent = f
			local track = Instance.new("Frame")
			track.Position = UDim2.new(0, 10, 1, -10)
			track.Size = UDim2.new(1, -20, 0, 4)
			track.BackgroundColor3 = C.Raised
			track.BorderSizePixel = 0
			track.Parent = f
			Kit.Corner(track, 999)
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = Color3.fromRGB(196, 62, 52)
			fill.BorderSizePixel = 0
			fill.Parent = track
			Kit.Corner(fill, 999)
			table.insert(frames, { userId = m.userId, fill = fill, info = info })
		end
	end
end

local function update()
	local myChar = localPlayer.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	for _, ui in frames do
		local p = Players:GetPlayerByUserId(ui.userId)
		local ch = p and p.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 then
			local frac = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
			ui.fill.Size = UDim2.fromScale(frac, 1)
			ui.fill.BackgroundColor3 = if frac < 0.3 then Color3.fromRGB(240, 90, 70) else Color3.fromRGB(196, 62, 52)
			if root and myRoot and root:IsA("BasePart") and myRoot:IsA("BasePart") then
				local d = (root.Position - myRoot.Position).Magnitude
				ui.info.Text = if d > 60 then string.format("%d studs", math.floor(d)) else ""
			end
		else
			ui.fill.Size = UDim2.fromScale(0, 1)
			ui.info.Text = if p then "down" else "away"
		end
	end
end

function PartyFramesController.Init()
	local gui = Kit.Screen(localPlayer:WaitForChild("PlayerGui"), "PartyFrames", 3)
	local h = Instance.new("Frame")
	h.Name = "Party"
	-- Short screens (phones): top right, above the objective card, clear of the dock.
	local cam = workspace.CurrentCamera
	local short = cam ~= nil and cam.ViewportSize.Y < 520
	h.AnchorPoint = if short then Vector2.new(1, 0) else Vector2.new(0, 0)
	h.Position = if short then UDim2.new(1, -12, 0, 10) else UDim2.fromOffset(12, 82)
	h.Size = UDim2.fromOffset(200, 140)
	h.BackgroundTransparency = 1
	h.Parent = gui
	Kit.AutoScale(h)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = h
	holder = h
end

function PartyFramesController.Start()
	PartyController.Changed:Connect(build)
	build()
	task.spawn(function()
		while true do
			task.wait(0.2)
			update()
		end
	end)
end

return PartyFramesController
