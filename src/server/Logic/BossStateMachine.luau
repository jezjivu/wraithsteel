--!strict
-- BossStateMachine: data-driven boss brain shared by every boss in BossConfig.
-- Pure: time, rng and target info are passed in; effects are emitted through `emit` so
-- BossService (which owns the model, hitboxes and animations) reacts to them.
--
-- States: Idle -> Chase <-> Windup -> Active -> Recovery -> Chase ...
--         any -> Broken (posture break) -> Chase
--         any -> Transition (phase change, invulnerable) -> Chase
--         any -> Dead
-- Events: StateChanged(state), MoveStarted(moveId, perilous), MoveActive(moveId),
--         MoveEnded(moveId), PhaseChanged(index), Died()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossConfig = require(Config:WaitForChild("BossConfig"))
local Odds = require(Shared:WaitForChild("Odds"))

local BossStateMachine = {}
BossStateMachine.__index = BossStateMachine

export type BossState = "Idle" | "Chase" | "Windup" | "Active" | "Recovery" | "Broken" | "Transition" | "Dead"

export type Context = {
	hasTarget: boolean,
	targetDistance: number,
	hpFraction: number,
}

export type Machine = typeof(setmetatable(
	{} :: {
		bossId: string,
		def: BossConfig.BossDef,
		state: BossState,
		stateEndsAt: number,
		phase: number,
		move: string?,
		cooldowns: { [string]: number },
		nextMoveAt: number,
		invulnerable: boolean,
		rng: () -> number,
		emit: (event: string, ...any) -> (),
	},
	BossStateMachine
))

function BossStateMachine.new(bossId: string, rng: () -> number, emit: (string, ...any) -> ()): Machine
	local def = BossConfig.Bosses[bossId]
	assert(def, "unknown boss " .. bossId)
	return setmetatable({
		bossId = bossId,
		def = def,
		state = "Idle" :: BossState,
		stateEndsAt = 0,
		phase = 1,
		move = nil,
		cooldowns = {},
		nextMoveAt = 0,
		invulnerable = false,
		rng = rng,
		emit = emit,
	}, BossStateMachine)
end

local function setState(self: Machine, state: BossState, endsAt: number)
	self.state = state
	self.stateEndsAt = endsAt
	self.invulnerable = state == "Transition" or state == "Dead"
	self.emit("StateChanged", state)
end

local function speed(self: Machine): number
	return self.def.phases[self.phase].speedMultiplier
end

-- Picks a move usable at this distance, honoring cooldowns, range and minRange.
function BossStateMachine.ChooseMove(self: Machine, distance: number, now: number): string?
	local entries = {}
	for _, moveId in self.def.phases[self.phase].moves do
		local m = self.def.moves[moveId]
		if m and now >= (self.cooldowns[moveId] or 0) and distance <= m.range and distance >= (m.minRange or 0) then
			table.insert(entries, { id = moveId, weight = m.weight })
		end
	end
	if #entries == 0 then
		return nil
	end
	return Odds.Roll(entries, 1, self.rng)
end

local function checkPhase(self: Machine, ctx: Context, now: number): boolean
	local nextPhase = self.def.phases[self.phase + 1]
	if nextPhase and ctx.hpFraction <= nextPhase.hpThreshold then
		self.phase += 1
		if self.move then
			self.emit("MoveEnded", self.move)
			self.move = nil
		end
		self.emit("PhaseChanged", self.phase)
		setState(self, "Transition", now + nextPhase.transitionSeconds)
		return true
	end
	return false
end

function BossStateMachine.Update(self: Machine, now: number, ctx: Context)
	if self.state == "Dead" then
		return
	end
	if ctx.hpFraction <= 0 then
		self.move = nil
		setState(self, "Dead", math.huge)
		self.emit("Died")
		return
	end
	if self.state ~= "Transition" and checkPhase(self, ctx, now) then
		return
	end

	local st = self.state
	if st == "Idle" then
		if ctx.hasTarget then
			setState(self, "Chase", 0)
		end
	elseif st == "Transition" or st == "Broken" then
		if now >= self.stateEndsAt then
			setState(self, "Chase", 0)
		end
	elseif st == "Chase" then
		if not ctx.hasTarget then
			setState(self, "Idle", 0)
		elseif now >= self.nextMoveAt then
			local moveId = self:ChooseMove(ctx.targetDistance, now)
			if moveId then
				local m = self.def.moves[moveId]
				self.move = moveId
				self.cooldowns[moveId] = now + m.cooldown
				setState(self, "Windup", now + m.windup / speed(self))
				self.emit("MoveStarted", moveId, m.perilous == true)
			end
		end
	elseif st == "Windup" then
		if now >= self.stateEndsAt and self.move then
			local m = self.def.moves[self.move]
			setState(self, "Active", now + m.active)
			self.emit("MoveActive", self.move)
		end
	elseif st == "Active" then
		if now >= self.stateEndsAt and self.move then
			local m = self.def.moves[self.move]
			setState(self, "Recovery", now + m.recovery / speed(self))
		end
	elseif st == "Recovery" then
		if now >= self.stateEndsAt then
			if self.move then
				self.emit("MoveEnded", self.move)
			end
			self.move = nil
			self.nextMoveAt = now + self.def.idleBetweenMoves / speed(self)
			setState(self, "Chase", 0)
		end
	end
end

-- Called by BossService when the boss's posture breaks.
function BossStateMachine.Break(self: Machine, now: number)
	if self.state == "Dead" or self.state == "Transition" then
		return
	end
	if self.move then
		self.emit("MoveEnded", self.move)
		self.move = nil
	end
	setState(self, "Broken", now + self.def.postureBrokenSeconds)
end

-- Health for a party of `players` (co-op scaling).
function BossStateMachine.ScaledHealth(bossId: string, players: number): number
	local def = BossConfig.Bosses[bossId]
	return math.floor(def.maxHealth * (1 + math.max(0, players - 1) * def.healthPerExtraPlayer) + 0.5)
end

return BossStateMachine
