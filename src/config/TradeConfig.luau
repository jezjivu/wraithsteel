--!strict
-- TradeConfig: player-to-player Spirit trading. Owner: Agent A.
-- Compliance (paid-flag rule): Spirits flagged `paid` (bought with Robux-purchasable currency
-- from a paid lantern, or fused from one) can only be traded when BOTH players' policy allows
-- paid item trading (PolicyService.CanTradePaidItems). Free Spirits can be traded by anyone.
-- Only Spirits are tradable (no currencies), which keeps trades simple and limits abuse.
-- Crash safety: every swap goes through the escrow ledger (Logic/TradeLedger).

local TradeConfig = {}

TradeConfig.MaxSpiritsPerSide = 8
TradeConfig.ConfirmCountdownSeconds = 5 -- both confirmed -> countdown -> swap
TradeConfig.RequestSeconds = 45 -- trade requests expire
TradeConfig.MaxDistance = 40 -- studs between the two players to start a trade

-- Escrow ledger (DataStore). Bump the store name only together with a migration plan.
TradeConfig.LedgerStoreName = "WraithsteelTradeLedger_v1"
TradeConfig.LedgerRetries = 3 -- attempts per ledger step before giving up
TradeConfig.LedgerHistoryLimit = 200 -- trade ids remembered per profile (idempotency)

return TradeConfig
