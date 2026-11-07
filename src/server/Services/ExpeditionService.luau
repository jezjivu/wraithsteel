--!strict
-- ExpeditionService: send idle Spirits on timed expeditions for Ember + Spirit XP.
-- Rules in Logic/ExpeditionLogic; numbers in Config/ExpeditionConfig. Deterministic rewards.
-- TODO(Studio/Agent D): expedition board UI (routes, slots, timers via Shared/Time.FormatDuration).
--
-- API:
--   ExpeditionService.Send(player, slotId, routeId, uids) -> (ok, message?)
--   ExpeditionService.Claim(player, slotId) -> (result?, message?)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ExpeditionLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("ExpeditionLogic"))
local TradeLock = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("TradeLock"))
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local ProgressionService = require(script.Parent.ProgressionService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ExpeditionService = { Name = "ExpeditionService", Priority = 24 }

function ExpeditionService.Send(player: Player, slotId: string, routeId: string, uids: { string }): (boolean, string?)
	if TradeLock.IsLocked(player.UserId) then
		return false, TradeLock.Message
	end
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	local ok, err = ExpeditionLogic.Start(data :: any, slotId, routeId, uids, os.time(), MarketService.HasPass(player, "LongExpeditions"))
	if ok then
		DataService.Changed(player, "expeditions")
	end
	return ok, err
end

function ExpeditionService.Claim(player: Player, slotId: string): (any, string?)
	local data = DataService.GetData(player)
	if data == nil then
		return nil, "Loading..."
	end
	local result, err = ExpeditionLogic.Claim(data :: any, slotId, os.time())
	if result then
		DataService.Changed(player, "expeditions", "spirits", "ember")
		ProgressionService.RefreshPower(player)
		AnalyticsService.Economy(player, "Source", "Ember", result.ember, data.ember, "Gameplay", "Expedition")
	end
	return result, err
end

function ExpeditionService.Init() end

function ExpeditionService.Start()
	Net.Server.OnInvoke("StartExpedition", ExpeditionService.Send)
	Net.Server.OnInvoke("ClaimExpedition", ExpeditionService.Claim)
end

return ExpeditionService
