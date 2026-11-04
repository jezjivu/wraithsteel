--!strict
-- DuelService: fair 1v1 duels in the Proving Ring (rules in Logic/DuelLogic, numbers in
-- PvpConfig).
--   * challenge a player near you (Duels panel) -> they accept -> both are taken to an
--     instanced dojo arena, facing each other
--   * best of three rounds; each round starts with a short countdown (no attacks, no moving)
--   * fair stats: same health for both, no Power / spirit / skill-tree bonuses, no Qi arts,
--     kunai or companions (CombatService/SpellService/KunaiService/SpiritAbilityService check
--     Combatant.duelId); fighting style, weapon and timing decide
--   * a lethal blow ends the round instead of killing (CombatService.OnDuelLethal); leaving,
--     dying any other way or forfeiting loses the match
--   * small Ember rewards, once per pair per PvpConfig.RewardCooldownSeconds; wins/losses saved
--
-- API:
--   DuelService.InDuel(player) -> boolean

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local PvpConfig = require(Config:WaitForChild("PvpConfig"))

local DuelLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("DuelLogic"))
local ArenaBuilder = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("ArenaBuilder"))
local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local ProgressionService = require(script.Parent.ProgressionService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local DuelService = { Name = "DuelService", Priority = 55 }

type Fighter = { player: Player, returnTo: CFrame?, walkSpeed: number, spot: CFrame }
type Live = { match: DuelLogic.Match, slot: number, center: Vector3, arena: Model, fighters: { [number]: Fighter } }

local challenges: DuelLogic.Challenges = {}
local lives: { [number]: Live } = {} -- matchId -> live duel
local duelOf: { [number]: number } = {} -- userId -> matchId
local slotsUsed: { [number]: boolean } = {}
local lastRewarded: { [string]: number } = {}
local counter = 0

local function now(): number
	return os.clock()
end

function DuelService.InDuel(player: Player): boolean
	return duelOf[player.UserId] ~= nil
end

local function busy(userId: number): boolean
	if duelOf[userId] then
		return true
	end
	local p = Players:GetPlayerByUserId(userId)
	return p == nil or p:GetAttribute("InArena") == true
end

local function stateFor(player: Player): { [string]: any }
	local me = player.UserId
	local incoming = {}
	for _, from in DuelLogic.Pending(challenges, me, os.time()) do
		local p = Players:GetPlayerByUserId(from)
		if p then
			table.insert(incoming, { userId = from, name = p.DisplayName })
		end
	end
	local data = DataService.GetData(player)
	local st: { [string]: any } = {
		incoming = incoming,
		wins = if data then data.pvpWins else 0,
		losses = if data then data.pvpLosses else 0,
		streak = if data then data.pvpStreak else 0,
	}
	local id = duelOf[me]
	local live = id and lives[id]
	if live then
		local m = live.match
		local foe = Players:GetPlayerByUserId(DuelLogic.Other(m, me))
		st.duel = {
			round = m.round,
			phase = m.phase,
			left = math.max(0, m.endsAt - now()),
			myWins = m.wins[me],
			theirWins = m.wins[DuelLogic.Other(m, me)],
			opponent = if foe then foe.DisplayName else "?",
			roundWinner = if m.roundWinner == nil then nil elseif m.roundWinner == me then "you" else "them",
			winner = if m.winner == nil then nil elseif m.winner == me then "you" else "them",
			reason = m.reason,
		}
	end
	return st
end

local function push(player: Player?)
	if player and player.Parent == Players then
		Net.Server.Fire("DuelEvent", player, stateFor(player))
	end
end

local function pushLive(live: Live)
	for userId in live.fighters do
		push(Players:GetPlayerByUserId(userId))
	end
end

local function reserveSlot(): (number?, Vector3?)
	for i = 1, PvpConfig.Slots do
		if not slotsUsed[i] then
			slotsUsed[i] = true
			local o = PvpConfig.Origin
			return i, Vector3.new(o[1] + (i - 1) * PvpConfig.Spacing, o[2], o[3])
		end
	end
	return nil, nil
end

local function place(f: Fighter)
	local ch = f.player.Character
	if ch and ch.Parent then
		ch:PivotTo(f.spot)
		local root = ch:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

-- Fresh round: full fair health, clean posture, one flask, no second breath, frozen until
-- the countdown ends.
local function resetFighter(f: Fighter, frozenUntil: number)
	local c = CombatService.GetByPlayer(f.player)
	if c == nil or c.dead then
		return
	end
	c.humanoid.MaxHealth = PvpConfig.Health
	c.humanoid.Health = PvpConfig.Health
	c.posture.value = 0
	c.posture.brokenUntil = 0
	c.model:SetAttribute("Posture", 0)
	c.model:SetAttribute("Broken", false)
	c.shield = 0
	c.flask = PvpConfig.FlasksPerRound
	c.model:SetAttribute("Flask", c.flask)
	c.breath = false
	c.model:SetAttribute("Breath", false)
	c.styleState = nil
	c.model:SetAttribute("StyleStacks", 0)
	local rules = c.rules
	if rules then
		rules.stunnedUntil = frozenUntil
		rules.busyUntil = 0
		rules.ultimateCharge = 0
	end
	c.humanoid.WalkSpeed = 0
	place(f)
end

local function unfreeze(live: Live)
	for _, f in live.fighters do
		local c = CombatService.GetByPlayer(f.player)
		if c and not c.dead then
			c.humanoid.WalkSpeed = f.walkSpeed
			if c.rules then
				c.rules.stunnedUntil = 0
			end
		end
	end
end

local function finish(live: Live)
	local m = live.match
	lives[m.id] = nil
	for userId, f in live.fighters do
		duelOf[userId] = nil
		local p = f.player
		local c = CombatService.GetByPlayer(p)
		if c then
			c.duelId = nil
			c.humanoid.WalkSpeed = f.walkSpeed
			if c.rules then
				c.rules.stunnedUntil = 0
			end
		end
		if p.Parent == Players then
			p:SetAttribute("InArena", false)
			p:SetAttribute("InDuel", false)
			CombatService.RefreshStats(p)
			if c and not c.dead then
				CombatService.Rest(c)
				if f.returnTo then
					local ch = p.Character
					if ch then
						ch:PivotTo(f.returnTo)
					end
				end
			end
		end
	end
	-- Results, stats and (rate-limited) rewards.
	local winner, loser = m.winner, if m.winner then DuelLogic.Other(m, m.winner) else nil
	if winner and loser then
		local wEmber, lEmber = DuelLogic.Rewards(lastRewarded, winner, loser, os.time())
		local results: { { userId: number, won: boolean, ember: number } } = {
			{ userId = winner, won = true, ember = wEmber },
			{ userId = loser, won = false, ember = lEmber },
		}
		for _, r in results do
			local userId, won, ember = r.userId, r.won, r.ember
			local p = Players:GetPlayerByUserId(userId)
			local data = p and DataService.GetData(p)
			if p and data then
				if won then
					data.pvpWins += 1
					data.pvpStreak += 1
				else
					data.pvpLosses += 1
					data.pvpStreak = 0
				end
				DataService.Changed(p, "pvpWins", "pvpLosses", "pvpStreak")
				if ember > 0 then
					ProgressionService.AddEmber(p, ember, "Duel", false)
				end
				Net.Server.Fire("Notify", p, if won then "LevelUp" else "Info", (if won then "Duel won!" else "Duel lost.") .. (if ember > 0 then string.format(" +%d Ember", ember) else ""))
				AnalyticsService.Custom(p, if won then "DuelWon" else "DuelLost", m.round)
			end
		end
	end
	task.delay(1, function()
		slotsUsed[live.slot] = nil
		live.arena:Destroy()
	end)
	pushLive(live)
end

local function start(a: Player, b: Player)
	local slot, center = reserveSlot()
	if slot == nil or center == nil then
		for _, p in { a, b } do
			Net.Server.Fire("Notify", p, "Error", "Every Proving Ring is in use. Try again soon.")
		end
		return
	end
	local ca, cb = CombatService.GetByPlayer(a), CombatService.GetByPlayer(b)
	if ca == nil or cb == nil or ca.dead or cb.dead then
		slotsUsed[slot] = nil
		return
	end
	counter += 1
	local arena = ArenaBuilder.Build(center, PvpConfig.Theme)
	arena.Name = "ProvingRing" .. slot
	arena.Parent = workspace
	local half = PvpConfig.StartDistance / 2
	local spotA = CFrame.lookAt(center + Vector3.new(0, 4, half), center + Vector3.new(0, 4, 0))
	local spotB = CFrame.lookAt(center + Vector3.new(0, 4, -half), center + Vector3.new(0, 4, 0))
	local m = DuelLogic.NewMatch(counter, a.UserId, b.UserId, now())
	local live: Live = { match = m, slot = slot, center = center, arena = arena, fighters = {} }
	local sides: { { p: Player, c: any, spot: CFrame } } = { { p = a, c = ca, spot = spotA }, { p = b, c = cb, spot = spotB } }
	for _, side in sides do
		local p, c, spot = side.p, side.c, side.spot
		live.fighters[p.UserId] = { player = p, returnTo = c.root.CFrame, walkSpeed = c.humanoid.WalkSpeed, spot = spot }
		duelOf[p.UserId] = m.id
		c.duelId = m.id
		p:SetAttribute("InArena", true)
		p:SetAttribute("InDuel", true)
		pcall(function()
			p:RequestStreamAroundAsync(spot.Position, 5)
		end)
	end
	lives[m.id] = live
	for _, f in live.fighters do
		resetFighter(f, m.endsAt)
	end
	pushLive(live)
end

local function request(player: Player, op: string, arg: number?): (boolean, string?)
	local me = player.UserId
	if op == "state" then
		push(player)
		return true, nil
	elseif op == "challenge" then
		local target = if arg then Players:GetPlayerByUserId(arg) else nil
		if target == nil then
			return false, "That player is not here"
		end
		local mine = CombatService.GetByPlayer(player)
		local theirs = CombatService.GetByPlayer(target)
		if mine == nil or theirs == nil or (mine.root.Position - theirs.root.Position).Magnitude > PvpConfig.ChallengeRadius then
			return false, "Stand closer to challenge"
		end
		local ok, err = DuelLogic.Challenge(challenges, me, target.UserId, os.time(), busy)
		if not ok then
			return false, err
		end
		if err == "accept" then
			challenges[me][target.UserId] = nil
			start(target, player)
			return true, "Duel accepted!"
		end
		Net.Server.Fire("Notify", target, "Raid", player.DisplayName .. " challenges you to a duel. Open Duels to accept.")
		push(target)
		return true, "Challenge sent to " .. target.DisplayName
	elseif op == "accept" then
		local from = if arg then Players:GetPlayerByUserId(arg) else nil
		if from == nil or busy(me) or busy(arg :: number) then
			return false, "That challenge is gone"
		end
		if not DuelLogic.Accept(challenges, me, arg :: number, os.time()) then
			return false, "That challenge expired"
		end
		start(from, player)
		return true, "Duel accepted!"
	elseif op == "decline" then
		if arg and challenges[me] then
			challenges[me][arg] = nil
		end
		push(player)
		return true, nil
	elseif op == "forfeit" then
		local id = duelOf[me]
		local live = id and lives[id]
		if live == nil then
			return false, "You are not in a duel"
		end
		DuelLogic.Forfeit(live.match, me, now(), "forfeit")
		pushLive(live)
		return true, "You yielded the duel"
	end
	return false, "Unknown action"
end

-- Called by CombatService when a duel blow would be lethal.
local function onLethal(target: any, _attacker: any)
	local id = target.duelId
	local live = id and lives[id]
	if live == nil or target.player == nil then
		return
	end
	if DuelLogic.Knockout(live.match, target.player.UserId, now()) then
		for _, f in live.fighters do
			local c = CombatService.GetByPlayer(f.player)
			if c and c.rules then
				c.rules.stunnedUntil = live.match.endsAt -- round over: blades down
			end
		end
		pushLive(live)
	end
end

local function healthOf(userId: number): number
	local p = Players:GetPlayerByUserId(userId)
	local c = p and CombatService.GetByPlayer(p)
	if c == nil or c.dead then
		return 0
	end
	return c.humanoid.Health / math.max(1, c.humanoid.MaxHealth)
end

local function tick()
	local t = now()
	for _, live in lives do
		local m = live.match
		-- Somebody left, died outside the rules or fell out: their loss.
		for userId, f in live.fighters do
			local c = CombatService.GetByPlayer(f.player)
			if m.phase ~= "Over" and (f.player.Parent ~= Players or c == nil or c.dead) then
				DuelLogic.Forfeit(m, userId, t, "left")
			elseif c and c.root.Position.Y < live.center.Y - PvpConfig.FallLimit then
				place(f)
			end
		end
		local event = DuelLogic.Advance(m, t, healthOf)
		if event == "Fight" then
			unfreeze(live)
			pushLive(live)
		elseif event == "RoundEnd" then
			for _, f in live.fighters do
				local c = CombatService.GetByPlayer(f.player)
				if c and c.rules then
					c.rules.stunnedUntil = m.endsAt
				end
			end
			pushLive(live)
		elseif event == "NextRound" then
			for _, f in live.fighters do
				resetFighter(f, m.endsAt)
			end
			pushLive(live)
		elseif event == "Close" then
			finish(live)
		end
	end
end

function DuelService.Init()
	CombatService.OnDuelLethal = onLethal
end

function DuelService.Start()
	Net.Server.OnInvoke("DuelRequest", request)
	Players.PlayerRemoving:Connect(function(p)
		challenges[p.UserId] = nil
		local id = duelOf[p.UserId]
		local live = id and lives[id]
		if live then
			DuelLogic.Forfeit(live.match, p.UserId, now(), "left")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			tick()
		end
	end)
end

return DuelService
