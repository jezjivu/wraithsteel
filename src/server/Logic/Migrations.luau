--!strict
-- Migrations: upgrades saved profiles to EconomyConfig.DataVersion.
-- Rules: never delete a migration; each migration takes data at version N-1 and returns it at N.
-- Add a new one by bumping EconomyConfig.DataVersion and appending Steps[newVersion].

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("EconomyConfig"))

local Migrations = {}

Migrations.Steps = {
	-- v0 -> v1: profiles saved before dataVersion existed (pre-release test data).
	[1] = function(data: { [string]: any })
		data.receipts = data.receipts or {}
		data.receiptOrder = data.receiptOrder or {}
		if type(data.equippedSpirits) ~= "table" then
			data.equippedSpirits = {}
		end
	end,
	-- v1 -> v2: fighting styles.
	[2] = function(data: { [string]: any })
		if type(data.fightingStyle) ~= "string" then
			data.fightingStyle = "river"
		end
	end,
} :: { [number]: (data: { [string]: any }) -> () }

-- Returns true if data was migrated. Errors if data is from a NEWER version (a newer server
-- wrote it); DataService must then kick the player rather than risk overwriting newer data.
function Migrations.Run(data: { [string]: any }): boolean
	local from = data.dataVersion or 0
	local target = EconomyConfig.DataVersion
	if from > target then
		error(string.format("profile dataVersion %d is newer than server %d", from, target))
	end
	if from == target then
		return false
	end
	for v = from + 1, target do
		local step = Migrations.Steps[v]
		assert(step, "missing migration step " .. v)
		step(data)
		data.dataVersion = v
	end
	return true
end

return Migrations
