--!strict
-- AttackDirector: attack tokens so a player is never swarmed. Each target has N token slots
-- (EnemyConfig.AttackTokensPerPlayer). An enemy must hold a token for its target before it may
-- start an attack; otherwise it circles at its preferred range. Tokens expire automatically,
-- and a released slot cools down briefly so attacks feel staggered rather than chained.
-- Bosses do not use tokens.

local AttackDirector = {}
AttackDirector.__index = AttackDirector

type Slot = { holder: string?, expiresAt: number, freeAt: number }

export type AttackDirector = typeof(setmetatable(
	{} :: {
		slotsPerTarget: number,
		duration: number,
		cooldown: number,
		targets: { [string]: { Slot } },
		holding: { [string]: string }, -- combatantId -> targetId
	},
	AttackDirector
))

function AttackDirector.new(slotsPerTarget: number, duration: number, cooldown: number): AttackDirector
	return setmetatable({
		slotsPerTarget = slotsPerTarget,
		duration = duration,
		cooldown = cooldown,
		targets = {},
		holding = {},
	}, AttackDirector)
end

local function slotsFor(self: AttackDirector, targetId: string): { Slot }
	local slots = self.targets[targetId]
	if slots == nil then
		slots = {}
		for i = 1, self.slotsPerTarget do
			slots[i] = { holder = nil, expiresAt = 0, freeAt = 0 }
		end
		self.targets[targetId] = slots
	end
	return slots
end

local function expire(self: AttackDirector, slots: { Slot }, now: number)
	for _, s in slots do
		if s.holder and now >= s.expiresAt then
			self.holding[s.holder] = nil
			s.holder = nil
			s.freeAt = now + self.cooldown
		end
	end
end

-- Returns true if `combatantId` holds (or was just granted) a token for `targetId`.
function AttackDirector.Request(self: AttackDirector, combatantId: string, targetId: string, now: number): boolean
	local current = self.holding[combatantId]
	if current and current ~= targetId then
		self:Release(combatantId, now)
	end
	local slots = slotsFor(self, targetId)
	expire(self, slots, now)
	for _, s in slots do
		if s.holder == combatantId then
			return true
		end
	end
	for _, s in slots do
		if s.holder == nil and now >= s.freeAt then
			s.holder = combatantId
			s.expiresAt = now + self.duration
			self.holding[combatantId] = targetId
			return true
		end
	end
	return false
end

function AttackDirector.Release(self: AttackDirector, combatantId: string, now: number)
	local targetId = self.holding[combatantId]
	if targetId == nil then
		return
	end
	self.holding[combatantId] = nil
	local slots = self.targets[targetId]
	if slots == nil then
		return
	end
	for _, s in slots do
		if s.holder == combatantId then
			s.holder = nil
			s.freeAt = now + self.cooldown
		end
	end
end

function AttackDirector.RemoveTarget(self: AttackDirector, targetId: string)
	local slots = self.targets[targetId]
	if slots == nil then
		return
	end
	for _, s in slots do
		if s.holder then
			self.holding[s.holder] = nil
		end
	end
	self.targets[targetId] = nil
end

function AttackDirector.HolderCount(self: AttackDirector, targetId: string, now: number): number
	local slots = self.targets[targetId]
	if slots == nil then
		return 0
	end
	expire(self, slots, now)
	local n = 0
	for _, s in slots do
		if s.holder then
			n += 1
		end
	end
	return n
end

return AttackDirector
