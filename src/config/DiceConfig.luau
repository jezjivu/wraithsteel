--!strict
-- DiceConfig: Bell Dice, a shared game of chance at the Night Market. Owner: Agent A.
-- COMPLIANCE (read before changing anything):
--   * Played ONLY with Fortune Chips. Chips are never sold for Robux, never sold for Ember or
--     Jade, never tradeable, and never part of a bundle, pass or code reward. They come only
--     from playing (daily gift + time played). Do not add a Robux path in, ever.
--   * Exact odds and payouts are shown at the table and come from Shared/DiceLogic, the same
--     code the server uses to settle bets. Every bet has a small house edge (shown as return).
--   * Hidden and refused where PolicyService restricts paid random items (conservative).
--   * Chips can be exchanged for a capped amount of Ember per day (prizes have no real value).
--   * Declare "simulated gambling" in the Roblox experience questionnaire (TODO Agent A).

export type BetDef = { label: string, description: string, payout: number } -- payout: chips won per chip staked (plus the stake back)

local DiceConfig = {}

DiceConfig.BettingSeconds = 20
DiceConfig.RollingSeconds = 3
DiceConfig.ResultSeconds = 6
DiceConfig.MinStake = 1
DiceConfig.MaxStake = 50 -- per bet type per round
DiceConfig.HistoryLength = 8

-- Three six-sided dice. Low = total 4-10, High = 11-17; any triple loses Low and High.
DiceConfig.Bets = {
	Low = { label = "Low", description = "Total 4-10 (not a triple)", payout = 1 },
	High = { label = "High", description = "Total 11-17 (not a triple)", payout = 1 },
	Triple = { label = "Bell Triple", description = "All three dice the same", payout = 34 },
} :: { [string]: BetDef }
DiceConfig.BetOrder = { "Low", "High", "Triple" }

-- Free chips (the only sources).
DiceConfig.DailyChips = 25 -- first visit each UTC day
DiceConfig.PlayChips = 5 -- every PlayChipSeconds of time in game
DiceConfig.PlayChipSeconds = 600
DiceConfig.MaxChips = 500 -- chips stop accruing above this

-- Exchange: chips -> Ember, capped per day.
DiceConfig.EmberPerChip = 15
DiceConfig.DailyExchangeChips = 100

return DiceConfig
