--!strict
-- StoryController: cinematic cards for StoryEvent payloads from the server:
--   BossIntro (letterbox + name/title reveal), BossPhase (enrage warning),
--   BossDefeated (VICTORY + rewards), BossFailed, ChapterUnlocked.
-- Presentation only.
-- TODO(Studio/Agent D): swap fonts/brush art for designed assets; add voice/music stingers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local BossConfig = require(Config:WaitForChild("BossConfig"))
local EffectsConfig = require(Config:WaitForChild("EffectsConfig"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Fx = require(UI:WaitForChild("Fx"))

local StoryController = { Name = "StoryController", Priority = 43 }

local GOLD = Color3.fromRGB(245, 205, 120)
local BLOOD = Color3.fromRGB(200, 40, 35)
local INK = Color3.fromRGB(12, 10, 14)

local gui: ScreenGui? = nil
local busyUntil = 0

local function tween(obj: Instance, seconds: number, props: { [string]: any }, delay: number?)
	TweenService:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0), props):Play()
end

local function gong(pitch: number)
	local s = Instance.new("Sound")
	s.SoundId = EffectsConfig.Sounds.heavy
	s.Volume = 0.8
	s.PlaybackSpeed = pitch
	s.Parent = workspace
	s:Play()
	Debris:AddItem(s, 3)
end

local function label(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3, y: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.new(1, 0, 0, size + 10)
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = 0.2
	l.TextTransparency = 1
	l.Text = text
	l.Parent = parent
	return l
end

-- Black bars sliding in from top and bottom (cinematic framing).
local function letterbox(root: Frame, seconds: number)
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = INK
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, if top then 1 else 0)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.Size = UDim2.fromScale(1, 0.12)
		bar.Parent = root
		tween(bar, 0.4, { Position = UDim2.fromScale(0, if top then 0.12 else 0.88) })
		tween(bar, 0.4, { Position = UDim2.fromScale(0, if top then 0 else 1) }, seconds - 0.4)
	end
end

-- A red brush stroke that sweeps under the title.
local function brush(root: Frame, y: number, color: Color3, delay: number)
	local stroke = Instance.new("Frame")
	stroke.AnchorPoint = Vector2.new(0.5, 0.5)
	stroke.Position = UDim2.fromScale(0.5, y)
	stroke.Size = UDim2.fromScale(0, 0.012)
	stroke.BackgroundColor3 = color
	stroke.BorderSizePixel = 0
	stroke.Parent = root
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1) })
	grad.Parent = stroke
	tween(stroke, 0.5, { Size = UDim2.fromScale(0.5, 0.012) }, delay)
end

local function card(seconds: number): Frame?
	local g = gui
	if g == nil then
		return nil
	end
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = g
	Debris:AddItem(root, seconds + 0.2)
	busyUntil = os.clock() + seconds
	return root
end

local function fadeIn(l: TextLabel, delay: number, hold: number)
	tween(l, 0.35, { TextTransparency = 0, TextStrokeTransparency = 0.2 }, delay)
	tween(l, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 }, delay + hold)
end

local handlers: { [string]: (e: { [string]: any }) -> () } = {}

handlers.BossIntro = function(e)
	local def = BossConfig.Bosses[e.bossId]
	local seconds = 3.6
	local root = card(seconds)
	if root == nil then
		return
	end
	letterbox(root, seconds)
	gong(0.55)
	local name = label(root, string.upper(e.name or (def and def.name) or "?"), Enum.Font.Antique, 64, GOLD, 0.44)
	local title = label(root, e.title or (def and def.title) or "", Enum.Font.GothamMedium, 24, Color3.fromRGB(235, 225, 210), 0.53)
	brush(root, 0.495, BLOOD, 0.25)
	fadeIn(name, 0.15, 2.6)
	fadeIn(title, 0.5, 2.3)
end

handlers.BossPhase = function(e)
	local def = BossConfig.Bosses[e.bossId]
	local root = card(2.4)
	if root == nil then
		return
	end
	gong(0.45)
	Fx.ScreenFlash(BLOOD, 0.25, 0.5)
	local text = label(root, (if def then def.name else "The boss") .. " grows furious!", Enum.Font.Antique, 42, BLOOD, 0.3)
	fadeIn(text, 0, 1.8)
end

handlers.BossDefeated = function(e)
	local root = card(5)
	if root == nil then
		return
	end
	letterbox(root, 5)
	gong(0.8)
	Fx.ScreenFlash(GOLD, 0.35, 0.8)
	local character = Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		Fx.Pillar(hrp.Position - Vector3.new(0, 2.5, 0), GOLD, 50)
	end
	local victory = label(root, "VICTORY", Enum.Font.Antique, 84, GOLD, 0.38)
	local who = label(root, (e.name or "Boss") .. " has fallen", Enum.Font.GothamMedium, 24, Color3.fromRGB(235, 225, 210), 0.47)
	local parts = { "+" .. FormatNumber.Short(e.ember or 0) .. " Ember", "+" .. FormatNumber.Short(e.xp or 0) .. " XP" }
	if (e.jade or 0) > 0 then
		table.insert(parts, "+" .. tostring(e.jade) .. " Jade (first clear)")
	end
	local rewards = label(root, table.concat(parts, "     "), Enum.Font.GothamBold, 22, Kit.Colors.Jade:Lerp(GOLD, 0.5), 0.54)
	brush(root, 0.43, GOLD, 0.2)
	fadeIn(victory, 0.1, 4)
	fadeIn(who, 0.4, 3.7)
	fadeIn(rewards, 0.8, 3.3)
end

handlers.BossFailed = function(e)
	local root = card(3)
	if root == nil then
		return
	end
	local text = label(root, (e.name or "The boss") .. " remains...", Enum.Font.Antique, 40, Color3.fromRGB(200, 190, 180), 0.35)
	fadeIn(text, 0, 2.4)
end

handlers.ChapterUnlocked = function(e)
	local root = card(4)
	if root == nil then
		return
	end
	letterbox(root, 4)
	gong(0.7)
	local head = label(root, "A NEW GATE OPENS", Enum.Font.GothamBold, 22, Color3.fromRGB(235, 225, 210), 0.42)
	local name = label(root, e.name or ("Chapter " .. tostring(e.chapter)), Enum.Font.Antique, 54, GOLD, 0.5)
	brush(root, 0.555, BLOOD, 0.4)
	fadeIn(head, 0.1, 3.2)
	fadeIn(name, 0.3, 3)
end

function StoryController.Init()
	gui = Kit.Screen(Players.LocalPlayer:WaitForChild("PlayerGui"), "StoryCards", 20)
	;(gui :: ScreenGui).IgnoreGuiInset = true
end

function StoryController.Start()
	Net.Client.On("StoryEvent", function(e)
		local h = if type(e) == "table" then handlers[e.kind] else nil
		if h then
			-- Don't stack two big cards on top of each other.
			local wait = math.max(0, busyUntil - os.clock())
			task.delay(if e.kind == "BossPhase" then 0 else wait, h, e)
		end
	end)
end

return StoryController
