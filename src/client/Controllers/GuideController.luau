--!strict
-- GuideController: new-player guidance. Shows the current objective computed from
-- profile data (right edge), and a controls card at the start (H toggles it). Presentation only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local GuideConfig = require(Config:WaitForChild("GuideConfig"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local ChapterConfig = require(Config:WaitForChild("ChapterConfig"))
local BossConfig = require(Config:WaitForChild("BossConfig"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local DataController = require(script.Parent.DataController)

local GuideController = { Name = "GuideController", Priority = 42 }

local C = Kit.Colors
local objectiveLabel: TextLabel? = nil
local controlsCard: Frame? = nil

local function count(t: { [any]: any }?): number
	local n = 0
	if t then
		for _ in t do
			n += 1
		end
	end
	return n
end

-- Cheapest weapon the player does not own yet (for the "buy a weapon" step).
local function cheapestNewWeapon(owned: { [string]: boolean }): number
	local best = math.huge
	for id, w in WeaponConfig.Weapons do
		if not owned[id] and w.currency == "Ember" and w.unlockChapter == 0 and w.price > 0 then
			best = math.min(best, w.price)
		end
	end
	return if best == math.huge then 0 else best
end

function GuideController.CurrentObjective(): string
	local T = GuideConfig.Text
	if not DataController.IsLoaded() then
		return "Loading..."
	end
	local level = DataController.Get("level") or 1
	local owned = DataController.Get("weapons") or {}
	local defeated = DataController.Get("bossesDefeated") or {}
	if (DataController.Get("hatchedTotal") or 0) == 0 then
		return T.openLantern
	elseif #(DataController.Get("equippedSpirits") or {}) == 0 then
		return T.equipSpirit
	elseif level < GuideConfig.LevelGoal then
		return string.format(T.fightWilds, GuideConfig.LevelGoal)
	elseif count(owned) < 2 then
		return string.format(T.buyWeapon, FormatNumber.Commas(cheapestNewWeapon(owned)))
	elseif (defeated.rust_tiger or 0) == 0 then
		return T.rustTiger
	end
	local chapter = DataController.Get("chapter") or 0
	local def = ChapterConfig.Chapters[chapter]
	if def then
		for _, bossId in def.bosses do
			local boss = BossConfig.Bosses[bossId]
			if boss and (defeated[bossId] or 0) == 0 then
				return string.format(T.chapterBoss, boss.name, chapter)
			end
		end
	end
	return T.allDone
end

local function refresh()
	local label = objectiveLabel
	if label then
		label.Text = GuideController.CurrentObjective()
	end
end

function GuideController.Init()
	local gui = Kit.Screen(Players.LocalPlayer:WaitForChild("PlayerGui"), "Guide", 4)

	local box = Instance.new("Frame")
	-- Right edge, above the middle: clear of Roblox's player list (top right) and chat (top left).
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, -10, 0.36, 0)
	box.Size = UDim2.fromOffset(300, 74)
	box.BackgroundColor3 = C.Ink
	box.BackgroundTransparency = 0.2
	box.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = box
	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(10, 4)
	title.Size = UDim2.new(1, -20, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = C.Gold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Objective"
	title.Parent = box
	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromOffset(10, 24)
	text.Size = UDim2.new(1, -20, 1, -28)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Gotham
	text.TextSize = 14
	text.TextWrapped = true
	text.TextColor3 = C.Text
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Parent = box
	objectiveLabel = text

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(1, 1)
	card.Position = UDim2.new(1, -10, 1, -110)
	card.Size = UDim2.fromOffset(300, 24 * #GuideConfig.Controls + 34)
	card.BackgroundColor3 = C.Ink
	card.BackgroundTransparency = 0.15
	card.Parent = gui
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 8)
	c2.Parent = card
	local head = Instance.new("TextLabel")
	head.Position = UDim2.fromOffset(10, 4)
	head.Size = UDim2.new(1, -20, 0, 24)
	head.BackgroundTransparency = 1
	head.Font = Enum.Font.GothamBold
	head.TextSize = 16
	head.TextColor3 = C.Gold
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Text = "Controls"
	head.Parent = card
	for i, line in GuideConfig.Controls do
		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromOffset(10, 6 + 24 * i)
		l.Size = UDim2.new(1, -20, 0, 22)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Gotham
		l.TextSize = 14
		l.TextColor3 = C.Text
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = line
		l.Parent = card
	end
	controlsCard = card
end

function GuideController.Start()
	DataController.Changed:Connect(refresh)
	refresh()
	task.delay(GuideConfig.ControlsCardSeconds, function()
		if controlsCard then
			controlsCard.Visible = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H and controlsCard then
			controlsCard.Visible = not controlsCard.Visible
		end
	end)
end

return GuideController
