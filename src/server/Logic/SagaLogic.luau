--!strict
-- SagaLogic: pure main-questline progression (SagaConfig). No Instances; tested in
-- tests/saga.spec.luau.
--
-- State lives in the profile as `saga`:
--   quest    - index into SagaConfig.Quests (1-based; > #Quests = finished)
--   step     - current step (1-based); > #steps = "return to the giver"
--   progress - kills toward the current Kill step
--   started  - talked to the giver yet?
--
-- API:
--   SagaLogic.New() -> State
--   SagaLogic.Current(state) -> (QuestDef?, StepDef?)   -- StepDef nil = return to giver / not started
--   SagaLogic.Talk(state, npcId) -> TalkResult
--   SagaLogic.Kill(state, enemyId) -> boolean (progress changed)
--   SagaLogic.Boss(state, bossId) -> boolean
--   SagaLogic.Reach(state, realm, x, z) -> boolean
--   SagaLogic.Objective(state) -> (text, targetKind, target)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SagaConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SagaConfig"))

local SagaLogic = {}

export type State = { quest: number, step: number, progress: number, started: boolean }
export type TalkResult = {
	kind: "Start" | "Finish" | "Step" | "Chatter",
	lines: { string },
	questTitle: string?,
	questId: string?,
	rewards: { ember: number, xp: number, jade: number }?,
}

function SagaLogic.New(): State
	return { quest = 1, step = 1, progress = 0, started = false }
end

function SagaLogic.Current(state: State): (SagaConfig.QuestDef?, SagaConfig.StepDef?)
	local q = SagaConfig.Quests[state.quest]
	if q == nil or not state.started then
		return q, nil
	end
	return q, q.steps[state.step]
end

local function advance(state: State)
	state.step += 1
	state.progress = 0
end

function SagaLogic.Talk(state: State, npcId: string): TalkResult
	local q, step = SagaLogic.Current(state)
	local npc = SagaConfig.Npc(npcId)
	local chatter = { if npc then npc.chatter[math.random(1, #npc.chatter)] else "..." }
	if q == nil then
		return { kind = "Chatter", lines = chatter }
	end
	if not state.started then
		if q.giver == npcId then
			state.started = true
			state.step = 1
			state.progress = 0
			return { kind = "Start", lines = q.intro, questTitle = q.title }
		end
		return { kind = "Chatter", lines = chatter }
	end
	if step and step.kind == "Talk" and step.npc == npcId then
		advance(state)
		return { kind = "Step", lines = step.lines or chatter, questTitle = q.title }
	end
	if step == nil and q.giver == npcId then
		-- All steps done: hand in.
		state.quest += 1
		state.step = 1
		state.progress = 0
		state.started = false
		return { kind = "Finish", lines = q.outro, questTitle = q.title, questId = q.id, rewards = q.rewards }
	end
	if q.giver == npcId and step then
		return { kind = "Chatter", lines = { step.text .. "." } }
	end
	return { kind = "Chatter", lines = chatter }
end

function SagaLogic.Kill(state: State, enemyId: string): boolean
	local _, step = SagaLogic.Current(state)
	if step == nil or step.kind ~= "Kill" or step.enemies == nil or table.find(step.enemies, enemyId) == nil then
		return false
	end
	state.progress += 1
	if state.progress >= (step.count or 1) then
		advance(state)
	end
	return true
end

function SagaLogic.Boss(state: State, bossId: string): boolean
	local _, step = SagaLogic.Current(state)
	if step == nil or step.kind ~= "Boss" or step.bossId ~= bossId then
		return false
	end
	advance(state)
	return true
end

function SagaLogic.Reach(state: State, realm: string, x: number, z: number): boolean
	local _, step = SagaLogic.Current(state)
	if step == nil or step.kind ~= "Reach" or step.realm ~= realm or step.at == nil then
		return false
	end
	local at = step.at :: { number }
	local dx, dz = x - at[1], z - at[2]
	if math.sqrt(dx * dx + dz * dz) > (step.radius or 15) then
		return false
	end
	advance(state)
	return true
end

-- What to show on screen. targetKind: "Npc" (target = npc id), "Boss" (boss id),
-- "Point" (target = {realm, x, z}), "Area" (enemy list: go fight), "Done".
function SagaLogic.Objective(state: State): (string, string, any)
	local q, step = SagaLogic.Current(state)
	if q == nil then
		return "The story so far is complete. More gates await...", "Done", nil
	end
	local giver = SagaConfig.Npc(q.giver)
	local giverName = if giver then giver.name else q.giver
	if not state.started then
		return string.format("%s: talk to %s", q.title, giverName), "Npc", q.giver
	end
	if step == nil then
		return string.format("%s: return to %s", q.title, giverName), "Npc", q.giver
	end
	if step.kind == "Kill" then
		return string.format("%s: %s (%d/%d)", q.title, step.text, state.progress, step.count or 1), "Area", step.enemies
	elseif step.kind == "Boss" then
		return string.format("%s: %s", q.title, step.text), "Boss", step.bossId
	elseif step.kind == "Reach" then
		local at = step.at :: { number }
		local point: { any } = { step.realm, at[1], at[2] }
		return string.format("%s: %s", q.title, step.text), "Point", point
	end
	return string.format("%s: %s", q.title, step.text), "Npc", step.npc
end

return SagaLogic
