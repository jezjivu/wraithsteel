--!strict
-- TradeService (STUB, Phase 4): player-to-player Spirit trading.
-- Compliance rules to keep when implementing:
--   * Both players must pass PolicyService.CanTradePaidItems; if either fails, block trades of
--     anything obtainable from paid random items (Jade Lantern spirits) - simplest: block trading.
--   * Two-step confirm with a countdown; server re-validates ownership/locks at confirm time and
--     swaps inside one synchronous block on both profiles (no yields between the two writes).
--   * Locked/equipped spirits cannot be offered. Log every completed trade via AnalyticsService.
-- Planned API: TradeService.Request(player, targetUserId), Update(player, offer), Confirm(player)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local PolicyService = require(script.Parent.PolicyService)

local TradeService = { Name = "TradeService", Priority = 51 }

function TradeService.CanTrade(player: Player): boolean
	return PolicyService.CanTradePaidItems(player)
end

function TradeService.Init() end

function TradeService.Start()
	Net.Server.OnInvoke("TradeRequest", function(player, _targetUserId)
		if not TradeService.CanTrade(player) then
			return false, "Trading is not available for your account."
		end
		return false, "Trading is coming soon."
	end)
	Net.Server.OnInvoke("TradeUpdate", function()
		return false, "Trading is coming soon."
	end)
end

return TradeService
