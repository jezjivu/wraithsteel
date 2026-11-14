--!strict
-- CodeService: redeem codes from ServerConfig/CodeConfig once per profile.
--
-- API:
--   CodeService.Redeem(player, code) -> (ok, message)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local CodeConfig = require(script.Parent.Parent:WaitForChild("ServerConfig"):WaitForChild("CodeConfig"))
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local CodeService = { Name = "CodeService", Priority = 12 }

function CodeService.Normalize(code: string): string
	return (string.upper(code):gsub("%s", ""))
end

function CodeService.Redeem(player: Player, rawCode: string): (boolean, string)
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	local code = CodeService.Normalize(rawCode)
	local def = CodeConfig.Codes[code]
	if def == nil then
		return false, "That code is not valid."
	end
	if def.expiresAt and os.time() > def.expiresAt then
		return false, "That code has expired."
	end
	if def.minLevel and data.level < def.minLevel then
		return false, "Reach level " .. def.minLevel .. " to use this code."
	end
	if data.codesRedeemed[code] then
		return false, "You already used this code."
	end
	data.codesRedeemed[code] = true
	ProgressionService.GrantReward(player, def.reward, "Code:" .. code)
	return true, "Code redeemed!"
end

function CodeService.Init() end

function CodeService.Start()
	Net.Server.OnInvoke("RedeemCode", CodeService.Redeem)
end

return CodeService
