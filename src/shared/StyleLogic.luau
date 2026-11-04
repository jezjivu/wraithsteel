--!strict
-- StyleLogic: the signature mechanic of each fighting style (StyleConfig.*.mechanic). Pure, so
-- the server (CombatService) and tests share it; the client only displays the stacks the
-- server publishes as character attribute "StyleStacks".

local Config = script.Parent.Parent:WaitForChild("Config")
local StyleConfig = require(Config:WaitForChild("StyleConfig"))
local CombatConfig = require(Config:WaitForChild("CombatConfig"))

local StyleLogic = {}

export type State = { stacks: number, lastGain: number, lastDodge: number }

export type AttackMods = { speed: number, damage: number, posture: number, crit: boolean, critMultiplier: number }

function StyleLogic.New(): State
	return { stacks = 0, lastGain = -math.huge, lastDodge = -math.huge }
end

-- Stacks after fading (call before reading).
function StyleLogic.Stacks(styleId: string, st: State, now: number): number
	local m = StyleConfig.Get(styleId).mechanic
	if m.stackSeconds and st.stacks > 0 and now - st.lastGain > m.stackSeconds then
		st.stacks = 0
	end
	return st.stacks
end

local function gain(styleId: string, st: State, now: number)
	local m = StyleConfig.Get(styleId).mechanic
	StyleLogic.Stacks(styleId, st, now)
	st.stacks = math.min(m.maxStacks or 0, st.stacks + 1)
	st.lastGain = now
end

-- A perfect deflect (River builds Flow).
function StyleLogic.OnParry(styleId: string, st: State, now: number)
	if StyleConfig.Get(styleId).mechanic.kind == "Flow" then
		gain(styleId, st, now)
	end
end

-- You landed a hit (Ember builds Heat).
function StyleLogic.OnLandHit(styleId: string, st: State, now: number)
	if StyleConfig.Get(styleId).mechanic.kind == "Heat" then
		gain(styleId, st, now)
	end
end

-- You took a clean hit (Heat goes out).
function StyleLogic.OnHurt(styleId: string, st: State)
	if StyleConfig.Get(styleId).mechanic.kind == "Heat" then
		st.stacks = 0
	end
end

function StyleLogic.OnDodge(st: State, now: number)
	st.lastDodge = now
end

-- Dash-strike window for this style (Gale doubles it).
function StyleLogic.DashWindow(styleId: string): number
	local m = StyleConfig.Get(styleId).mechanic
	return CombatConfig.DashAttackWindow * (m.dashWindowMultiplier or 1)
end

-- Multipliers for an attack you are starting now (base style numbers included).
function StyleLogic.Attack(styleId: string, st: State, now: number): AttackMods
	local def = StyleConfig.Get(styleId)
	local m = def.mechanic
	local stacks = StyleLogic.Stacks(styleId, st, now)
	local mods: AttackMods = { speed = def.speed, damage = def.damage, posture = def.posture, crit = false, critMultiplier = 1 }
	if m.kind == "Flow" then
		mods.speed *= 1 + stacks * (m.speedPerStack or 0)
		mods.posture *= 1 + stacks * (m.posturePerStack or 0)
	elseif m.kind == "Heat" then
		mods.damage *= 1 + stacks * (m.damagePerStack or 0)
	elseif m.kind == "Gale" and now - st.lastDodge <= (m.critWindow or 0) then
		mods.crit = true
		mods.critMultiplier = m.critMultiplier or 1
	end
	return mods
end

-- Super armor while performing a heavy attack or finisher (Mountain).
function StyleLogic.Armored(styleId: string, action: string, route: string?): boolean
	return StyleConfig.Get(styleId).mechanic.kind == "Unshaken" and (action == "HeavyAttack" or route == "Finisher")
end

-- Posture you take while armored.
function StyleLogic.ArmorPostureTaken(styleId: string): number
	return StyleConfig.Get(styleId).mechanic.postureTaken or 1
end

-- Posture multiplier when your heavy attack is blocked (Mountain guard crush).
function StyleLogic.GuardCrush(styleId: string, action: string, route: string?): number
	local m = StyleConfig.Get(styleId).mechanic
	if m.kind == "Unshaken" and (action == "HeavyAttack" or route == "Finisher") then
		return m.guardCrush or 1
	end
	return 1
end

-- Gale: dodging an attack with i-frames refunds the dash cooldown.
function StyleLogic.DodgeRefund(styleId: string): boolean
	return StyleConfig.Get(styleId).mechanic.dodgeRefund == true
end

return StyleLogic
