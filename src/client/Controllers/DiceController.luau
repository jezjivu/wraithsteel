--!strict
-- DiceController: client mirror of the Bell Dice table (DiceEvent) for the Bell Dice panel.
-- Keeps the round countdown label ticking without re-rendering the panel.
--
-- API:
--   DiceController.State, DiceController.Changed: Signal()
--   DiceController.Refresh() -> state (asks the server, includes the exact odds)
--   DiceController.Bet(betId, amount) / DiceController.Exchange(amount) -> (ok, msg?)
--   DiceController.TimerLabel: TextLabel?   set by the panel; updated every frame

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local DiceController = {
	Name = "DiceController",
	Priority = 38,
	Changed = Signal.new(),
	State = { allowed = false } :: { [string]: any },
	TimerLabel = nil :: TextLabel?,
}

local odds: any = nil

function DiceController.Refresh(): any
	local st = Net.Client.Invoke("DiceState")
	if type(st) == "table" then
		odds = st.odds or odds
		DiceController.State = st
	end
	return DiceController.State
end

function DiceController.Odds(): any
	return odds
end

function DiceController.Bet(betId: string, amount: number): (boolean, string?)
	local ok, msg = Net.Client.Invoke("DiceBet", betId, amount)
	return ok == true, msg
end

function DiceController.Exchange(amount: number): (boolean, string?)
	local ok, msg = Net.Client.Invoke("DiceExchange", amount)
	return ok == true, msg
end

local function phaseText(st: any): string
	local left = math.max(0, math.ceil((st.endsAt or 0) - workspace:GetServerTimeNow()))
	if st.phase == "Betting" then
		return string.format("Bets close in %ds", left)
	elseif st.phase == "Rolling" then
		return "The dice are rolling..."
	end
	return string.format("Next round in %ds", left)
end
DiceController.PhaseText = phaseText

function DiceController.Init()
	Net.Client.On("DiceEvent", function(st)
		st.allowed = true
		st.odds = odds
		DiceController.State = st
		DiceController.Changed:Fire()
	end)
end

function DiceController.Start()
	RunService.Heartbeat:Connect(function()
		local l = DiceController.TimerLabel
		if l and l.Parent then
			l.Text = phaseText(DiceController.State)
		end
	end)
end

return DiceController
