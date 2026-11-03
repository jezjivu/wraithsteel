--!strict
-- RaidController: client mirror of raid lobbies (RaidEvent) for the Raid panel.
--
-- API:
--   RaidController.State, RaidController.Changed: Signal()
--   RaidController.Request(op, arg?) -> (ok, msg?)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local RaidController = {
	Name = "RaidController",
	Priority = 37,
	Changed = Signal.new(),
	State = { raidServer = false, lobbies = {}, mine = nil } :: { [string]: any },
}

function RaidController.Request(op: string, arg: string?): (boolean, string?)
	local ok, msg = Net.Client.Invoke("RaidRequest", op, arg)
	return ok == true, msg
end

function RaidController.Init()
	Net.Client.On("RaidEvent", function(state)
		RaidController.State = state
		RaidController.Changed:Fire()
	end)
end

function RaidController.Start()
	task.delay(3, function()
		RaidController.Request("state")
	end)
end

return RaidController
