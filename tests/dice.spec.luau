-- Tests for Bell Dice (Shared/DiceLogic + compliance of the chip economy).
local RS = game:GetService("ReplicatedStorage")
local DiceLogic = require(RS.Shared.DiceLogic)
local DiceConfig = require(RS.Config.DiceConfig)
local MonetizationConfig = require(RS.Config.MonetizationConfig)
local CodeConfig = require(game:GetService("ServerScriptService").ServerConfig.CodeConfig)

local cases = {}

cases["Dice: exact odds, every bet returns less than staked on average"] = function()
	local byId = {}
	for _, o in DiceLogic.Odds() do
		byId[o.id] = o
		expectTrue(o.returnPercent < 100, o.id .. " must have a house edge")
		expectTrue(o.returnPercent > 95, o.id .. " edge stays small")
	end
	expectEq(byId.Low.wins, 105)
	expectEq(byId.High.wins, 105)
	expectEq(byId.Triple.wins, 6)
	expectEq(byId.Low.wins + byId.High.wins + byId.Triple.wins, 216, "every outcome is Low, High or a triple")
	expectNear(byId.Triple.chance, 6 / 216, 1e-12)
end

cases["Dice: payouts and settlement"] = function()
	expectEq(DiceLogic.Payout("Low", 10, { 1, 2, 3 }), 20)
	expectEq(DiceLogic.Payout("High", 10, { 1, 2, 3 }), 0)
	expectEq(DiceLogic.Payout("Low", 10, { 2, 2, 2 }), 0, "triples beat Low")
	expectEq(DiceLogic.Payout("Triple", 2, { 4, 4, 4 }), 2 * (DiceConfig.Bets.Triple.payout + 1))
	local r = DiceLogic.NewRound(1, 0)
	expectTrue(DiceLogic.PlaceBet(r, 7, "Low", 10, 100))
	expectTrue(DiceLogic.PlaceBet(r, 7, "Triple", 2, 100))
	r.dice = { 6, 5, 6 }
	expectEq(DiceLogic.Settle(r, 7), -12)
	r.dice = { 1, 1, 1 }
	expectEq(DiceLogic.Settle(r, 7), -10 + 2 * DiceConfig.Bets.Triple.payout)
	expectEq(DiceLogic.Settle(r, 99), 0, "no bets, no change")
end

cases["Dice: bet validation (phase, stake limits, balance incl. reserved)"] = function()
	local r = DiceLogic.NewRound(1, 0)
	expectEq(select(2, DiceLogic.PlaceBet(r, 1, "Nope", 5, 100)), "Unknown bet")
	expectEq(select(2, DiceLogic.PlaceBet(r, 1, "Low", 0, 100)), "Stake at least " .. DiceConfig.MinStake .. " chip")
	expectEq(select(2, DiceLogic.PlaceBet(r, 1, "Low", 1.5, 100)), "Stake at least " .. DiceConfig.MinStake .. " chip")
	expectTrue(DiceLogic.PlaceBet(r, 1, "Low", DiceConfig.MaxStake, 1000))
	expectEq(select(2, DiceLogic.PlaceBet(r, 1, "Low", 1, 1000)), "At most " .. DiceConfig.MaxStake .. " chips on one bet")
	expectEq(select(2, DiceLogic.PlaceBet(r, 2, "High", 8, 10)), nil)
	expectEq(select(2, DiceLogic.PlaceBet(r, 2, "Low", 3, 10)), "Not enough Fortune Chips", "reserved chips count")
	r.phase = "Rolling"
	expectEq(select(2, DiceLogic.PlaceBet(r, 3, "Low", 1, 10)), "Bets are closed - wait for the next round")
end

cases["Dice: round clock Betting -> Rolling -> Result -> Next"] = function()
	local r = DiceLogic.NewRound(1, 0)
	local function four()
		return 4
	end
	expectEq(DiceLogic.Advance(r, 1, four), nil)
	expectEq(DiceLogic.Advance(r, DiceConfig.BettingSeconds, four), "Rolled")
	expectEq(r.phase, "Rolling")
	expectEq(r.dice[1], 4)
	local t = DiceConfig.BettingSeconds + DiceConfig.RollingSeconds
	expectEq(DiceLogic.Advance(r, t, four), nil)
	expectEq(r.phase, "Result")
	expectEq(DiceLogic.Advance(r, t + DiceConfig.ResultSeconds, four), "Next")
end

cases["Dice: exchange is capped per day"] = function()
	local n, ember = DiceLogic.Exchange(500, 1000, 0)
	expectEq(n, DiceConfig.DailyExchangeChips)
	expectEq(ember, n * DiceConfig.EmberPerChip)
	expectEq((DiceLogic.Exchange(10, 1000, DiceConfig.DailyExchangeChips)), 0)
	expectEq((DiceLogic.Exchange(10, 3, 0)), 3, "cannot exchange more than you own")
end

cases["Dice compliance: chips can never be bought or redeemed"] = function()
	for key, p in MonetizationConfig.Products do
		expectTrue(p.kind ~= ("Chips" :: any), key)
		if p.bundle then
			expectEq((p.bundle :: any).chips, nil, key)
		end
	end
	for code, def in CodeConfig.Codes or {} do
		expectEq((def.reward :: any).chips, nil, code)
	end
end

return cases
