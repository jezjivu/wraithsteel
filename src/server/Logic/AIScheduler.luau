--!strict
-- AIScheduler: batched, staggered AI ticks. Every agent thinks at `tickRate` Hz, but agents are
-- spread across frames (staggered start + round-robin cursor) and at most `maxPerStep` agents
-- think per Step, so 100 enemies never all think on the same frame.
-- EnemyService calls Step(now) from RunService.Heartbeat.

local AIScheduler = {}
AIScheduler.__index = AIScheduler

type Agent = { id: string, think: (dt: number, now: number) -> (), nextAt: number, lastAt: number }

export type AIScheduler = typeof(setmetatable(
	{} :: { interval: number, maxPerStep: number, agents: { Agent }, index: { [string]: Agent }, cursor: number },
	AIScheduler
))

function AIScheduler.new(tickRate: number, maxPerStep: number): AIScheduler
	return setmetatable({ interval = 1 / tickRate, maxPerStep = maxPerStep, agents = {}, index = {}, cursor = 1 }, AIScheduler)
end

function AIScheduler.Add(self: AIScheduler, id: string, think: (dt: number, now: number) -> (), now: number)
	if self.index[id] then
		self:Remove(id)
	end
	-- Stagger: offset first think by a fraction of the interval based on population.
	local offset = (#self.agents % 10) / 10 * self.interval
	local agent = { id = id, think = think, nextAt = now + offset, lastAt = now }
	table.insert(self.agents, agent)
	self.index[id] = agent
end

function AIScheduler.Remove(self: AIScheduler, id: string)
	local agent = self.index[id]
	if agent == nil then
		return
	end
	self.index[id] = nil
	local i = table.find(self.agents, agent)
	if i then
		table.remove(self.agents, i)
		if self.cursor > i then
			self.cursor -= 1
		end
	end
end

function AIScheduler.Count(self: AIScheduler): number
	return #self.agents
end

-- Runs due agents, at most maxPerStep. Errors in one agent never stop the others.
function AIScheduler.Step(self: AIScheduler, now: number): number
	local n = #self.agents
	if n == 0 then
		return 0
	end
	local ran = 0
	local checked = 0
	while checked < n and ran < self.maxPerStep do
		if self.cursor > #self.agents then
			self.cursor = 1
		end
		local agent = self.agents[self.cursor]
		self.cursor += 1
		checked += 1
		if agent and now >= agent.nextAt then
			local dt = now - agent.lastAt
			agent.lastAt = now
			agent.nextAt = now + self.interval
			ran += 1
			local ok, err = pcall(agent.think :: any, dt, now)
			if not ok then
				warn("[AIScheduler] agent", agent.id, "errored:", err)
			end
		end
	end
	return ran
end

return AIScheduler
