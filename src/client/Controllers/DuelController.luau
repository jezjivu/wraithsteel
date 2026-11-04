--!strict
-- DuelController: client side of duels (DuelEvent). Keeps the Duels panel state and shows the
-- duel HUD while you fight: a score pill at the top (round, wins, timer) and big center calls
-- ("Round 2", "Fight!", "Round to Kaito", "Victory").
--
-- API:
--   DuelController.State, DuelController.Changed: Signal()
--   DuelController.Request(op, userId?) -> (ok, msg?)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))

local DuelController = {
	Name = "DuelController",
	Priority = 39,
	Changed = Signal.new(),
	State = { incoming = {}, wins = 0, losses = 0, streak = 0 } :: { [string]: any },
}

local C = Kit.Colors
local pill: Frame? = nil
local pillText: TextLabel? = nil
local call: TextLabel? = nil
local receivedAt = 0
local lastPhase: string? = nil
local lastRound = 0

function DuelController.Request(op: string, userId: number?): (boolean, string?)
	local ok, msg = Net.Client.Invoke("DuelRequest", op, userId)
	return ok == true, msg
end

local function showCall(text: string, color: Color3)
	local l = call
	if l == nil then
		return
	end
	l.Text = text
	l.TextColor3 = color
	l.TextTransparency = 0
	l.TextStrokeTransparency = 0.4
	local scale = l:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 1.25
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	TweenService:Create(l, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

local function onState(st: any)
	DuelController.State = st
	receivedAt = os.clock()
	DuelController.Changed:Fire()
	local d = st.duel
	if pill then
		pill.Visible = d ~= nil and d.phase ~= nil
	end
	if d == nil then
		lastPhase, lastRound = nil, 0
		return
	end
	if d.phase ~= lastPhase or d.round ~= lastRound then
		if d.phase == "Countdown" then
			showCall("Round " .. d.round, C.Gold)
		elseif d.phase == "Fight" then
			showCall("Fight!", C.Accent)
		elseif d.phase == "RoundEnd" then
			showCall(if d.roundWinner == "you" then "Round won" elseif d.roundWinner == "them" then "Round to " .. d.opponent else "Draw - again", if d.roundWinner == "you" then C.Good else C.Text)
		elseif d.phase == "Over" then
			showCall(if d.winner == "you" then "Victory" else "Defeat", if d.winner == "you" then C.Gold else C.Bad)
		end
	end
	lastPhase, lastRound = d.phase, d.round
end

function DuelController.Init()
	local gui = Kit.Screen(Players.LocalPlayer:WaitForChild("PlayerGui"), "DuelHUD", 6)
	local p = Instance.new("Frame")
	p.AnchorPoint = Vector2.new(0.5, 0)
	p.Position = UDim2.new(0.5, 0, 0, 12)
	p.Size = UDim2.fromOffset(0, 38)
	p.AutomaticSize = Enum.AutomaticSize.X
	p.BackgroundColor3 = C.Ink
	p.BackgroundTransparency = 0.15
	p.BorderSizePixel = 0
	p.Visible = false
	p.Parent = gui
	Kit.Corner(p, 999)
	Kit.Stroke(p, C.Gold, 0.5, 1)
	Kit.Pad(p, 18, 0)
	Kit.AutoScale(p)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(0, 0, 1, 0)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.BackgroundTransparency = 1
	t.Font = Kit.BoldFont
	t.TextSize = 16
	t.TextColor3 = C.Text
	t.RichText = true
	t.Parent = p
	pill, pillText = p, t
	local c = Instance.new("TextLabel")
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromScale(0.5, 0.34)
	c.Size = UDim2.fromOffset(700, 80)
	c.BackgroundTransparency = 1
	c.Font = Kit.TitleFont
	c.TextSize = 56
	c.TextColor3 = C.Gold
	c.TextTransparency = 1
	c.TextStrokeTransparency = 1
	c.Parent = gui
	Instance.new("UIScale").Parent = c
	call = c
	Net.Client.On("DuelEvent", onState)
end

function DuelController.Start()
	RunService.Heartbeat:Connect(function()
		local d = DuelController.State.duel
		local t = pillText
		if d and t then
			local left = math.max(0, d.left - (os.clock() - receivedAt))
			local clock = if d.phase == "Fight" then string.format("%d:%02d", left // 60, math.floor(left % 60)) else string.format("%ds", math.ceil(left))
			t.Text = string.format('Round %d   <font color="#%s">You %d</font>  -  %d %s   %s', d.round, C.Gold:ToHex(), d.myWins or 0, d.theirWins or 0, d.opponent or "?", clock)
		end
	end)
	task.delay(3, function()
		DuelController.Request("state")
	end)
end

return DuelController
