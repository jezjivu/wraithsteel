--!strict
-- TradeController: client mirror of the trade state (TradeEvent) for the Trade panel.
-- Opens the Trade panel automatically when a trade session starts.
--
-- API:
--   TradeController.State, TradeController.Changed: Signal(), TradeController.Started: Signal()
--   TradeController.Request(targetUserId) / TradeController.Update(op, uids?) -> (ok, msg?)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local TradeController = {
	Name = "TradeController",
	Priority = 36,
	Changed = Signal.new(),
	Started = Signal.new(),
	State = { active = false, allowed = false, incoming = {} } :: { [string]: any },
}

function TradeController.Request(targetUserId: number): (boolean, string?)
	local ok, msg = Net.Client.Invoke("TradeRequest", targetUserId)
	return ok == true, msg
end

function TradeController.Update(op: string, uids: { string }?): (boolean, string?)
	local ok, msg = Net.Client.Invoke("TradeUpdate", { op = op, uids = uids })
	return ok == true, msg
end

function TradeController.Init()
	Net.Client.On("TradeEvent", function(state)
		local wasActive = TradeController.State.active
		TradeController.State = state
		TradeController.Changed:Fire()
		if state.active and not wasActive then
			TradeController.Started:Fire()
		end
	end)
end

function TradeController.Start() end

return TradeController
