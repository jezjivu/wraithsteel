--!strict
-- DialogueController: talking to NPCs.
--   * Dialogue box (bottom of the screen): name + title, typewriter text, click / E / Space to
--     continue. Combat input is paused while it is open.
--   * Quest markers over NPCs for the local player: gold "!" = has a quest for you,
--     "?" = ready to hand in, blue "..." = you are meant to talk to them.
-- Driven by StoryEvent kind "Dialogue" (SagaService); markers follow the profile's `saga`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local SagaConfig = require(Config:WaitForChild("SagaConfig"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local DataController = require(script.Parent.DataController)
local InputController = require(script.Parent.InputController)

local DialogueController = { Name = "DialogueController", Priority = 60 }

local player = Players.LocalPlayer
local box: Frame? = nil
local nameLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local textLabel: TextLabel? = nil
local hint: TextLabel? = nil

local queue: { string } = {}
local typing = false
local fullText = ""
local open = false

local function close()
	open = false
	InputController.SetEnabled(true)
	local b = box
	if b then
		TweenService:Create(b, TweenInfo.new(0.2), { Position = UDim2.new(0.5, 0, 1, 260) }):Play()
	end
end

local function showNext()
	local t = textLabel
	if t == nil then
		return
	end
	local line = table.remove(queue, 1)
	if line == nil then
		close()
		return
	end
	fullText = line
	typing = true
	t.Text = ""
	task.spawn(function()
		for i = 1, #line do
			if not typing or fullText ~= line then
				return
			end
			t.Text = string.sub(line, 1, i)
			task.wait(0.018)
		end
		typing = false
	end)
	if hint then
		hint.Text = if #queue > 0 then "Click / E to continue" else "Click / E to close"
	end
end

local function advance()
	if not open then
		return
	end
	if typing then
		typing = false
		if textLabel then
			textLabel.Text = fullText
		end
		return
	end
	showNext()
end

local function onDialogue(e: { [string]: any })
	if nameLabel == nil or titleLabel == nil or box == nil then
		return
	end
	nameLabel.Text = tostring(e.npc or "")
	local sub = tostring(e.title or "")
	if e.quest and e.result == "Start" then
		sub ..= "   ·   New quest: " .. tostring(e.quest)
	elseif e.quest and e.result == "Finish" then
		sub ..= "   ·   Quest complete: " .. tostring(e.quest)
	end
	titleLabel.Text = sub
	queue = {}
	for _, l in e.lines or {} do
		table.insert(queue, tostring(l))
	end
	open = true
	InputController.SetEnabled(false)
	TweenService:Create(box, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -24) }):Play()
	showNext()
end

-- Markers -------------------------------------------------------------------------------------
local function markerFor(npcId: string): (string?, Color3?)
	local saga = DataController.Get("saga")
	if type(saga) ~= "table" then
		return nil, nil
	end
	local q = SagaConfig.Quests[saga.quest]
	if q == nil then
		return nil, nil
	end
	if not saga.started then
		if q.giver == npcId then
			return "!", Color3.fromRGB(255, 210, 80)
		end
		return nil, nil
	end
	local step = q.steps[saga.step]
	if step == nil and q.giver == npcId then
		return "?", Color3.fromRGB(255, 210, 80)
	end
	if step and step.kind == "Talk" and step.npc == npcId then
		return "...", Color3.fromRGB(120, 200, 255)
	end
	return nil, nil
end

local function refreshMarkers()
	for _, model in CollectionService:GetTagged("Npc") do
		if model:IsA("Model") then
			local id = model:GetAttribute("NpcId")
			local text, color = markerFor(tostring(id))
			local existing = model:FindFirstChild("QuestMarker")
			if text == nil then
				if existing then
					existing:Destroy()
				end
			else
				local bb = existing :: BillboardGui?
				if bb == nil then
					local head = model:FindFirstChild("Head") or model.PrimaryPart
					local nb = Instance.new("BillboardGui")
					nb.Name = "QuestMarker"
					nb.Size = UDim2.fromOffset(60, 60)
					nb.StudsOffset = Vector3.new(0, 6, 0)
					nb.AlwaysOnTop = true
					nb.MaxDistance = 250
					nb.Adornee = head :: BasePart
					local l = Instance.new("TextLabel")
					l.Name = "Mark"
					l.Size = UDim2.fromScale(1, 1)
					l.BackgroundTransparency = 1
					l.Font = Enum.Font.GothamBlack
					l.TextScaled = true
					l.TextStrokeTransparency = 0.1
					l.Parent = nb
					local sc = Instance.new("UIScale")
					sc.Parent = l
					TweenService:Create(sc, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.2 }):Play()
					nb.Parent = model
					bb = nb
				end
				local l = (bb :: BillboardGui):FindFirstChild("Mark") :: TextLabel
				l.Text = text
				l.TextColor3 = color :: Color3
			end
		end
	end
end

function DialogueController.Init()
	local gui = Kit.Screen(player:WaitForChild("PlayerGui"), "Dialogue", 15)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 1)
	f.Position = UDim2.new(0.5, 0, 1, 260)
	f.Size = UDim2.new(0.6, 0, 0, 170)
	f.BackgroundColor3 = Kit.Colors.Ink
	f.BackgroundTransparency = 0.08
	f.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Kit.Colors.Gold
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = f
	local n = Instance.new("TextLabel")
	n.Position = UDim2.fromOffset(20, 12)
	n.Size = UDim2.new(1, -40, 0, 28)
	n.BackgroundTransparency = 1
	n.Font = Enum.Font.Antique
	n.TextSize = 28
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.TextColor3 = Kit.Colors.Gold
	n.Parent = f
	local t = n:Clone()
	t.Position = UDim2.fromOffset(20, 40)
	t.Size = UDim2.new(1, -40, 0, 18)
	t.Font = Enum.Font.GothamMedium
	t.TextSize = 13
	t.TextColor3 = Kit.Colors.Muted
	t.Parent = f
	local body = n:Clone()
	body.Position = UDim2.fromOffset(20, 64)
	body.Size = UDim2.new(1, -40, 1, -94)
	body.Font = Enum.Font.Gotham
	body.TextSize = 18
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Kit.Colors.Text
	body.Parent = f
	local h = n:Clone()
	h.AnchorPoint = Vector2.new(1, 1)
	h.Position = UDim2.new(1, -16, 1, -8)
	h.Size = UDim2.fromOffset(240, 18)
	h.Font = Enum.Font.GothamMedium
	h.TextSize = 12
	h.TextXAlignment = Enum.TextXAlignment.Right
	h.TextColor3 = Kit.Colors.Muted
	h.Parent = f
	local click = Instance.new("TextButton")
	click.Size = UDim2.fromScale(1, 1)
	click.BackgroundTransparency = 1
	click.Text = ""
	click.Parent = f
	click.Activated:Connect(advance)
	box, nameLabel, titleLabel, textLabel, hint = f, n, t, body, h
end

function DialogueController.Start()
	Net.Client.On("StoryEvent", function(e)
		if type(e) == "table" and e.kind == "Dialogue" then
			onDialogue(e)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if open and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return) then
			advance()
		end
	end)
	DataController.Changed:Connect(function(key)
		if key == "saga" then
			refreshMarkers()
		end
	end)
	CollectionService:GetInstanceAddedSignal("Npc"):Connect(function()
		task.defer(refreshMarkers)
	end)
	task.delay(3, refreshMarkers)
end

return DialogueController
