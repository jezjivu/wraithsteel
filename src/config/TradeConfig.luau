--!strict
-- TradeConfig: player-to-player Spirit trading. Owner: Agent A.
-- Compliance: trading is disabled for any player whose policy disallows paid item trading
-- (PolicyService.CanTradePaidItems), because Spirits can come from paid random lanterns.
-- Only Spirits are tradable (no currencies), which keeps trades simple and limits abuse.

local TradeConfig = {}

TradeConfig.MaxSpiritsPerSide = 8
TradeConfig.ConfirmCountdownSeconds = 5 -- both confirmed -> countdown -> swap
TradeConfig.RequestSeconds = 45 -- trade requests expire
TradeConfig.MaxDistance = 40 -- studs between the two players to start a trade

return TradeConfig
