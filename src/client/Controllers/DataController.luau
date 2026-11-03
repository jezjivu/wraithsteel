--!strict
-- DataController: client-side read-only mirror of the player's public profile data.
-- The server is the source of truth; this only caches ProfileSnapshot/ProfileChanged.
--
-- API:
--   DataController.Get(key) -> any
--   DataController.WaitForSnapshot() -> { [string]: any }
--   DataController.Changed: Signal(key, value)     (fires for every key on snapshot too)
--   DataController.PolicyFlags -> { paidRandomItemsRestricted: boolean, paidItemTradingAllowed: boolean }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local DataController = {
	Name = "DataController",
	Priority = 0,
	Changed = Signal.new(),
	Loaded = Signal.new(),
	-- Restrictive until the server says otherwise (UI hides paid random items meanwhile).
	PolicyFlags = { paidRandomItemsRestricted = true, paidItemTradingAllowed = false },
}

local snapshot: { [string]: any }? = nil

function DataController.Get(key: string): any
	return if snapshot then snapshot[key] else nil
end

function DataController.IsLoaded(): boolean
	return snapshot ~= nil
end

function DataController.WaitForSnapshot(): { [string]: any }
	while snapshot == nil do
		DataController.Loaded:Wait()
	end
	return snapshot :: { [string]: any }
end

function DataController.Init()
	Net.Client.On("ProfileSnapshot", function(data)
		snapshot = data
		for k, v in data do
			DataController.Changed:Fire(k, v)
		end
		DataController.Loaded:Fire()
	end)
	Net.Client.On("ProfileChanged", function(key, value)
		if snapshot then
			snapshot[key] = value
			DataController.Changed:Fire(key, value)
		end
	end)
	Net.Client.On("PolicyFlags", function(flags)
		DataController.PolicyFlags = flags
	end)
end

function DataController.Start()
	-- In case the snapshot fired before our listener connected.
	task.delay(3, function()
		if snapshot == nil then
			Net.Client.Fire("RequestSnapshot")
		end
	end)
end

return DataController
