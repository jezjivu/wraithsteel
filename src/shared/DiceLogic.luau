--!strict
-- DiceLogic: Bell Dice rules. The odds shown at the table and the server's settlement both
-- come from here. Probabilities are exact (all 216 outcomes of three dice are counted).

local Config = script.Parent.Parent:WaitForChild("Config")
local DiceConfig = require(Config:WaitForChild("DiceConfig"))

local DiceLogic = {}

export type Dice = { number } -- three values 1..6

export type BetOdds = {
	id: string,
	wins: number, -- outcomes out of 216
	chance: number, -- 0..1
	percent: number, -- rounded to 2 dp for display
	payout: number, -- chips won per chip staked
	returnPercent: number, -- expected chips back per 100 staked (100 = fair)
}

export type Round = {
	id: number,
	phase: "Betting" | "Rolling" | "Result",
	endsAt: number,
	bets: { [number]: { [string]: number } }, -- userId -> betId -> stake
	dice: Dice?,
}

function DiceLogic.IsTriple(d: Dice): boolean
	return d[1] == d[2] and d[2] == d[3]
end

function DiceLogic.Wins(betId: string, d: Dice): boolean
	local total = d[1] + d[2] + d[3]
	local triple = DiceLogic.IsTriple(d)
	if betId == "Low" then
		return not triple and total >= 4 and total <= 10
	elseif betId == "High" then
		return not triple and total >= 11 and total <= 17
	elseif betId == "Triple" then
		return triple
	end
	return false
end

-- Exact odds for every bet (same order as DiceConfig.BetOrder).
function DiceLogic.Odds(): { BetOdds }
	local out = {}
	for _, id in DiceConfig.BetOrder do
		local wins = 0
		for a = 1, 6 do
			for b = 1, 6 do
				for c = 1, 6 do
					if DiceLogic.Wins(id, { a, b, c }) then
						wins += 1
					end
				end
			end
		end
		local chance = wins / 216
		local payout = DiceConfig.Bets[id].payout
		table.insert(out, {
			id = id,
			wins = wins,
			chance = chance,
			percent = math.floor(chance * 10000 + 0.5) / 100,
			payout = payout,
			returnPercent = math.floor(chance * (payout + 1) * 10000 + 0.5) / 100,
		})
	end
	return out
end

-- Chips paid back for a bet (stake included on a win, 0 on a loss).
function DiceLogic.Payout(betId: string, stake: number, d: Dice): number
	if DiceLogic.Wins(betId, d) then
		return stake * (DiceConfig.Bets[betId].payout + 1)
	end
	return 0
end

function DiceLogic.NewRound(id: number, now: number): Round
	return { id = id, phase = "Betting", endsAt = now + DiceConfig.BettingSeconds, bets = {}, dice = nil }
end

-- Chips a player has reserved on the current round.
function DiceLogic.Reserved(round: Round, userId: number): number
	local total = 0
	local mine = round.bets[userId]
	if mine then
		for _, stake in mine do
			total += stake
		end
	end
	return total
end

-- Validates and records a bet (adds to an existing bet of the same type). `balance` = chips owned.
function DiceLogic.PlaceBet(round: Round, userId: number, betId: string, amount: number, balance: number): (boolean, string?)
	if round.phase ~= "Betting" then
		return false, "Bets are closed - wait for the next round"
	end
	if DiceConfig.Bets[betId] == nil then
		return false, "Unknown bet"
	end
	if amount ~= math.floor(amount) or amount < DiceConfig.MinStake then
		return false, "Stake at least " .. DiceConfig.MinStake .. " chip"
	end
	local mine = round.bets[userId] or {}
	local newStake = (mine[betId] or 0) + amount
	if newStake > DiceConfig.MaxStake then
		return false, "At most " .. DiceConfig.MaxStake .. " chips on one bet"
	end
	if DiceLogic.Reserved(round, userId) + amount > balance then
		return false, "Not enough Fortune Chips"
	end
	mine[betId] = newStake
	round.bets[userId] = mine
	return true, nil
end

-- Net chip change for one player once the dice are known (payouts minus stakes).
function DiceLogic.Settle(round: Round, userId: number): number
	local d = round.dice
	assert(d, "DiceLogic.Settle: round has no dice")
	local net = 0
	local mine = round.bets[userId]
	if mine then
		for betId, stake in mine do
			net += DiceLogic.Payout(betId, stake, d) - stake
		end
	end
	return net
end

-- Advances the round clock. `roll()` returns 1..6 (server RNG). Returns the event that happened:
-- "Rolled" (dice just thrown), "Next" (a new round began) or nil.
function DiceLogic.Advance(round: Round, now: number, roll: () -> number): string?
	if now < round.endsAt then
		return nil
	end
	if round.phase == "Betting" then
		round.phase = "Rolling"
		round.dice = { roll(), roll(), roll() }
		round.endsAt = now + DiceConfig.RollingSeconds
		return "Rolled"
	elseif round.phase == "Rolling" then
		round.phase = "Result"
		round.endsAt = now + DiceConfig.ResultSeconds
		return nil
	end
	return "Next"
end

-- How many chips can be exchanged now: (allowed, ember).
function DiceLogic.Exchange(amount: number, chips: number, exchangedToday: number): (number, number)
	local room = math.max(0, DiceConfig.DailyExchangeChips - exchangedToday)
	local n = math.max(0, math.min(math.floor(amount), chips, room))
	return n, n * DiceConfig.EmberPerChip
end

return DiceLogic
