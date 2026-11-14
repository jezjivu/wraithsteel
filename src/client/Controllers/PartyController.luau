--!strict
-- PartyController: client mirror of the player's party (from PartyEvent) for the Party panel.
--
-- API:
--   PartyController.State -> { inParty, leader, members = {{userId, name}}, invites = {{partyId, leaderName}} }
--   PartyController.Changed: Signal()
--   PartyController.Request(action, arg?) -> (ok, message?)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local PartyController = {
	Name = "PartyController",
	Priority = 35,
	Changed = Signal.new(),
	State = {
		inParty = false,
		leader = 0,
		members = {} :: { { userId: number, name: string } },
		invites = {} :: { { partyId: number, leaderName: string } },
	},
}

function PartyController.Request(action: string, arg: number?): (boolean, string?)
	local ok, msg = Net.Client.Invoke("PartyRequest", action, arg)
	return ok == true, msg
end

function PartyController.Init()
	Net.Client.On("PartyEvent", function(state)
		PartyController.State = state
		PartyController.Changed:Fire()
	end)
end

function PartyController.Start()
	PartyController.State.leader = Players.LocalPlayer.UserId
	task.spawn(PartyController.Request, "refresh")
end

return PartyController
