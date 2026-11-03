--!strict
-- DiceService: Bell Dice, one shared table per server (rules in Shared/DiceLogic, numbers in
-- DiceConfig). Everyone in the server sees the same round, the other players' bets and the
-- result. Bets are only checked against the balance when placed and settled when the dice
-- land (stake taken and payout given in one step), so leaving mid-round costs nothing.
-- Compliance: Fortune Chips are free (daily gift + time played), never sold, never traded.
-- Refused where PolicyService restricts paid random items. Odds = DiceLogic.Odds().
--
-- API:
--   DiceService.GrantChips(player, amount, source)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Time = require(Shared:WaitForChild("Time"))
local DiceLogic = require(Shared:WaitForChild("DiceLogic"))
local DiceConfig = require(Config:WaitForChild("DiceConfig"))

local DataService = require(script.Parent.DataService)
local PolicyService = require(script.Parent.PolicyService)
local ProgressionService = require(script.Parent.ProgressionService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local DiceService = { Name = "DiceService", Priority = 25 }

local rng = Random.new()
local roundId = 1
local round: DiceLogic.Round
local history: { DiceLogic.Dice } = {}
local lastWinners: { { name: string, net: number } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function allowed(player: Player): boolean
	return PolicyService.CanBuyPaidRandomItems(player)
end

function DiceService.GrantChips(player: Player, amount: number, source: string)
	local data = DataService.GetData(player)
	if data == nil or amount <= 0 then
		return
	end
	local before = data.chips
	data.chips = math.min(DiceConfig.MaxChips, data.chips + amount)
	if data.chips ~= before then
		DataService.Changed(player, "chips")
		AnalyticsService.Custom(player, "ChipsGranted:" .. source, data.chips - before)
	end
end

local function publicState(): { [string]: any }
	local tables = {}
	for _, id in DiceConfig.BetOrder do
		tables[id] = { players = 0, chips = 0 }
	end
	local seated = {}
	for userId, bets in round.bets do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			local list = {}
			for betId, stake in bets do
				tables[betId].players += 1
				tables[betId].chips += stake
				table.insert(list, { bet = betId, stake = stake })
			end
			table.insert(seated, { userId = userId, name = p.DisplayName, bets = list })
		end
	end
	return {
		round = round.id,
		phase = round.phase,
		endsAt = round.endsAt,
		dice = round.dice,
		tables = tables,
		seated = seated,
		history = history,
		winners = lastWinners,
	}
end

local function broadcast()
	local st = publicState()
	for _, p in Players:GetPlayers() do
		if allowed(p) then
			Net.Server.Fire("DiceEvent", p, st)
		end
	end
end

local function settle()
	local dice = round.dice :: DiceLogic.Dice
	table.insert(history, 1, dice)
	while #history > DiceConfig.HistoryLength do
		table.remove(history)
	end
	lastWinners = {}
	for userId in round.bets do
		local p = Players:GetPlayerByUserId(userId)
		local data = p and DataService.GetData(p)
		if p and data and allowed(p) then
			local staked = DiceLogic.Reserved(round, userId)
			if data.chips >= staked then
				local net = DiceLogic.Settle(round, userId)
				data.chips = math.max(0, data.chips + net)
				DataService.Changed(p, "chips")
				if net > 0 then
					table.insert(lastWinners, { name = p.DisplayName, net = net })
				end
				AnalyticsService.Custom(p, "DiceRound", net)
			end
		end
	end
	table.sort(lastWinners, function(a, b)
		return a.net > b.net
	end)
end

local function placeBet(player: Player, betId: string, amount: number): (boolean, string?)
	if not allowed(player) then
		return false, "Bell Dice is not available on this account."
	end
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	local ok, err = DiceLogic.PlaceBet(round, player.UserId, betId, amount, data.chips)
	if ok then
		broadcast()
	end
	return ok, err
end

local function exchange(player: Player, amount: number): (boolean, string?)
	if not allowed(player) then
		return false, "Bell Dice is not available on this account."
	end
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	local today = Time.DayKey(os.time())
	if data.chipsExchangedDay ~= today then
		data.chipsExchangedDay = today
		data.chipsExchanged = 0
	end
	-- Chips on the table this round cannot be exchanged.
	local free = data.chips - DiceLogic.Reserved(round, player.UserId)
	local n, ember = DiceLogic.Exchange(amount, free, data.chipsExchanged)
	if n <= 0 then
		return false, if data.chipsExchanged >= DiceConfig.DailyExchangeChips then "Daily exchange limit reached" else "No chips to exchange"
	end
	data.chips -= n
	data.chipsExchanged += n
	DataService.Changed(player, "chips", "chipsExchanged", "chipsExchangedDay")
	ProgressionService.AddEmber(player, ember, "DiceExchange", false)
	return true, string.format("Exchanged %d chips for %d Ember", n, ember)
end

local function stateFor(player: Player): any
	if not allowed(player) then
		return { allowed = false }
	end
	local st = publicState()
	st.allowed = true
	st.odds = DiceLogic.Odds()
	return st
end

local function dailyGift(player: Player, data: any)
	local today = Time.DayKey(os.time())
	if data.chipsDay ~= today then
		data.chipsDay = today
		DataService.Changed(player, "chipsDay")
		DiceService.GrantChips(player, DiceConfig.DailyChips, "Daily")
	end
end

function DiceService.Init()
	round = DiceLogic.NewRound(roundId, now())
end

function DiceService.Start()
	Net.Server.OnInvoke("DiceState", stateFor)
	Net.Server.OnInvoke("DiceBet", placeBet)
	Net.Server.OnInvoke("DiceExchange", exchange)
	DataService.ProfileLoaded:Connect(dailyGift)
	Players.PlayerRemoving:Connect(function(p)
		if round.phase == "Betting" then
			round.bets[p.UserId] = nil
		end
	end)
	-- Time played earns chips.
	task.spawn(function()
		while true do
			task.wait(DiceConfig.PlayChipSeconds)
			for _, p in Players:GetPlayers() do
				DiceService.GrantChips(p, DiceConfig.PlayChips, "Play")
			end
		end
	end)
	-- The table clock.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local event = DiceLogic.Advance(round, now(), function()
				return rng:NextInteger(1, 6)
			end)
			if event == "Rolled" then
				settle()
				broadcast()
			elseif event == "Next" then
				roundId += 1
				round = DiceLogic.NewRound(roundId, now())
				broadcast()
			elseif round.phase == "Result" and round.endsAt - now() > DiceConfig.ResultSeconds - 0.3 then
				broadcast() -- the dice have landed: show the result
			end
		end
	end)
end

return DiceService
