--!strict
-- DuelLogic: pure rules for duels (challenges, rounds, scoring, reward cooldowns).
-- DuelService does the engine work (arena, teleports, health resets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PvpConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PvpConfig"))

local DuelLogic = {}

export type Phase = "Countdown" | "Fight" | "RoundEnd" | "Over"

export type Match = {
	id: number,
	a: number,
	b: number,
	round: number,
	wins: { [number]: number },
	phase: Phase,
	endsAt: number,
	roundWinner: number?, -- nil = draw
	winner: number?,
	reason: string?,
}

export type Challenges = { [number]: { [number]: number } } -- target -> { from -> expiresAt }

function DuelLogic.Challenge(ch: Challenges, from: number, to: number, now: number, busy: (number) -> boolean): (boolean, string?)
	if from == to then
		return false, "You cannot duel yourself"
	end
	if busy(from) or busy(to) then
		return false, "One of you is busy"
	end
	-- They already challenged you: this accepts.
	if ch[from] and (ch[from][to] or 0) > now then
		return true, "accept"
	end
	ch[to] = ch[to] or {}
	ch[to][from] = now + PvpConfig.ChallengeSeconds
	return true, nil
end

function DuelLogic.Accept(ch: Challenges, me: number, from: number, now: number): boolean
	local mine = ch[me]
	if mine and (mine[from] or 0) > now then
		mine[from] = nil
		return true
	end
	return false
end

function DuelLogic.Pending(ch: Challenges, me: number, now: number): { number }
	local out = {}
	local mine = ch[me]
	if mine then
		for from, expires in mine do
			if expires > now then
				table.insert(out, from)
			end
		end
	end
	table.sort(out)
	return out
end

function DuelLogic.NewMatch(id: number, a: number, b: number, now: number): Match
	return {
		id = id,
		a = a,
		b = b,
		round = 1,
		wins = { [a] = 0, [b] = 0 },
		phase = "Countdown",
		endsAt = now + PvpConfig.CountdownSeconds,
		roundWinner = nil,
		winner = nil,
		reason = nil,
	}
end

function DuelLogic.Other(m: Match, userId: number): number
	return if userId == m.a then m.b else m.a
end

local function endRound(m: Match, winner: number?, now: number)
	m.roundWinner = winner
	if winner then
		m.wins[winner] += 1
	end
	if winner and m.wins[winner] >= PvpConfig.RoundsToWin then
		m.phase = "Over"
		m.winner = winner
		m.endsAt = now + PvpConfig.EndSeconds
	else
		m.phase = "RoundEnd"
		m.endsAt = now + PvpConfig.BetweenRoundsSeconds
	end
end

-- A fighter was knocked out (lethal blow, fall, ...). Only counts during the fight.
function DuelLogic.Knockout(m: Match, loser: number, now: number): boolean
	if m.phase ~= "Fight" then
		return false
	end
	endRound(m, DuelLogic.Other(m, loser), now)
	return true
end

-- Leaving / forfeiting ends the whole match at once.
function DuelLogic.Forfeit(m: Match, quitter: number, now: number, reason: string)
	if m.phase == "Over" then
		return
	end
	m.phase = "Over"
	m.winner = DuelLogic.Other(m, quitter)
	m.reason = reason
	m.endsAt = now + PvpConfig.EndSeconds
end

-- Advances the clock. `health(userId)` gives the current health fraction (for timeouts).
-- Returns "Fight" | "NextRound" | "RoundEnd" | "Close" | nil.
function DuelLogic.Advance(m: Match, now: number, health: (number) -> number): string?
	if now < m.endsAt then
		return nil
	end
	if m.phase == "Countdown" then
		m.phase = "Fight"
		m.endsAt = now + PvpConfig.RoundSeconds
		return "Fight"
	elseif m.phase == "Fight" then
		local ha, hb = health(m.a), health(m.b)
		local winner = if math.abs(ha - hb) < 1e-6 then nil elseif ha > hb then m.a else m.b
		if winner == nil and m.round >= PvpConfig.MaxRounds then
			winner = m.a -- a full draw after MaxRounds: the challenged side keeps the ring
		end
		endRound(m, winner, now)
		return "RoundEnd"
	elseif m.phase == "RoundEnd" then
		m.round += 1
		if m.round > PvpConfig.MaxRounds then
			m.phase = "Over"
			m.winner = if m.wins[m.a] >= m.wins[m.b] then m.a else m.b
			m.endsAt = now + PvpConfig.EndSeconds
			return nil
		end
		m.phase = "Countdown"
		m.roundWinner = nil
		m.endsAt = now + PvpConfig.CountdownSeconds
		return "NextRound"
	elseif m.phase == "Over" then
		return "Close"
	end
	return nil
end

-- Reward cooldowns per pair (so two friends cannot farm each other).
function DuelLogic.PairKey(a: number, b: number): string
	return if a < b then a .. ":" .. b else b .. ":" .. a
end

function DuelLogic.Rewards(lastRewarded: { [string]: number }, winner: number, loser: number, now: number): (number, number)
	local key = DuelLogic.PairKey(winner, loser)
	if now - (lastRewarded[key] or -math.huge) < PvpConfig.RewardCooldownSeconds then
		return 0, 0
	end
	lastRewarded[key] = now
	return PvpConfig.WinEmber, PvpConfig.LoseEmber
end

-- Fair PvP hit numbers (no Power, no stat bonuses).
function DuelLogic.HitDamage(moveDamage: number, styleDamage: number, riposteMult: number, critMult: number, targetBroken: boolean, maxHealth: number): number
	local d = moveDamage * PvpConfig.DamageScale * styleDamage * riposteMult * critMult
	if targetBroken then
		d += maxHealth * PvpConfig.DeathblowFraction
	end
	return d
end

return DuelLogic
