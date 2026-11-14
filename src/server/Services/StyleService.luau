--!strict
-- StyleService: choosing a fighting style (StyleConfig). Styles unlock by level; the choice is
-- saved in the profile and published as the character attribute "FightingStyle" so every
-- client can tint effects and size the local dash.
--
-- API:
--   StyleService.Set(player, styleId) -> (ok, message)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local StyleConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("StyleConfig"))

local DataService = require(script.Parent.DataService)

local StyleService = { Name = "StyleService", Priority = 26 }

local function publish(player: Player)
	local data = DataService.GetData(player)
	if data then
		player:SetAttribute("FightingStyle", data.fightingStyle)
	end
end

function StyleService.Set(player: Player, styleId: string): (boolean, string)
	local data = DataService.GetData(player)
	local def = StyleConfig.Styles[styleId]
	if data == nil or def == nil then
		return false, "Unknown style"
	end
	if data.level < def.unlockLevel then
		return false, "Reach level " .. def.unlockLevel .. " to learn " .. def.name
	end
	data.fightingStyle = styleId
	DataService.Changed(player, "fightingStyle")
	publish(player)
	return true, "You now fight in the " .. def.name .. " style"
end

function StyleService.Init() end

function StyleService.Start()
	Net.Server.OnInvoke("SetFightingStyle", StyleService.Set)
	DataService.ProfileLoaded:Connect(publish)
	for _, p in Players:GetPlayers() do
		publish(p)
	end
end

return StyleService
