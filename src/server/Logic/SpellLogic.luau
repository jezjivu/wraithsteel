--!strict
-- SpellLogic: pure rules for Qi arts (no Instances; unit-tested in tests/spells.spec.luau).
--   SpellLogic.NewState(qi) -> State
--   SpellLogic.Regen(state, dt, regenBonus)
--   SpellLogic.AddQi(state, amount)
--   SpellLogic.CanCast(state, loadout, level, spellId, now, skills?) -> (ok, reason?)
--   SpellLogic.Commit(state, spellId, now, haste) -> cooldownSeconds
--   SpellLogic.SetLoadout(loadout, slot, spellId, level, skills?) -> (ok, reason?)
--   SpellLogic.InCorridor(ox, oz, dx, dz, length, width, px, pz) -> boolean
--   SpellLogic.ClampPoint(ox, oz, px, pz, range) -> (x, z)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SpellConfig"))
local SkillLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillLogic"))

local SpellLogic = {}

export type State = { qi: number, readyAt: { [string]: number } }

function SpellLogic.NewState(qi: number?): State
	return { qi = qi or SpellConfig.Qi.start, readyAt = {} }
end

function SpellLogic.AddQi(state: State, amount: number)
	state.qi = math.clamp(state.qi + amount, 0, SpellConfig.Qi.max)
end

function SpellLogic.Regen(state: State, dt: number, regenBonus: number)
	SpellLogic.AddQi(state, SpellConfig.Qi.regenPerSecond * (1 + regenBonus) * dt)
end

local function inLoadout(loadout: { string }, spellId: string): boolean
	for i = 1, SpellConfig.Slots do
		if loadout[i] == spellId then
			return true
		end
	end
	return false
end

function SpellLogic.CanCast(state: State, loadout: { string }, level: number, spellId: string, now: number, skills: { [string]: number }?): (boolean, string?)
	local spell = SpellConfig.Spells[spellId]
	if spell == nil then
		return false, "Unknown art"
	end
	if not inLoadout(loadout, spellId) then
		return false, "Not in your art slots"
	end
	if level < spell.unlockLevel then
		return false, "Unlocks at level " .. spell.unlockLevel
	end
	if not SkillLogic.HasArt(skills, spellId) then
		return false, "Learn it in the skill tree"
	end
	if now < (state.readyAt[spellId] or 0) then
		return false, "Cooling down"
	end
	if state.qi < spell.qi then
		return false, "Not enough Qi"
	end
	return true, nil
end

function SpellLogic.Commit(state: State, spellId: string, now: number, haste: number): number
	local spell = SpellConfig.Spells[spellId]
	state.qi -= spell.qi
	local cd = spell.cooldown * (1 - math.clamp(haste, 0, 0.9))
	state.readyAt[spellId] = now + cd
	return cd
end

-- slot 1..Slots; spellId "" empties the slot. A spell already in another slot moves.
function SpellLogic.SetLoadout(loadout: { string }, slot: number, spellId: string, level: number, skills: { [string]: number }?): (boolean, string?)
	if slot ~= math.floor(slot) or slot < 1 or slot > SpellConfig.Slots then
		return false, "Bad slot"
	end
	if spellId ~= "" then
		local spell = SpellConfig.Spells[spellId]
		if spell == nil then
			return false, "Unknown art"
		end
		if level < spell.unlockLevel then
			return false, "Unlocks at level " .. spell.unlockLevel
		end
		if not SkillLogic.HasArt(skills, spellId) then
			return false, "Learn it in the skill tree"
		end
		for i = 1, SpellConfig.Slots do
			if loadout[i] == spellId then
				loadout[i] = ""
			end
		end
	end
	for i = 1, SpellConfig.Slots do
		if loadout[i] == nil then
			loadout[i] = ""
		end
	end
	loadout[slot] = spellId
	return true, nil
end

-- Is point p inside the corridor starting at o, along unit direction d?
function SpellLogic.InCorridor(ox: number, oz: number, dx: number, dz: number, length: number, width: number, px: number, pz: number): boolean
	local rx, rz = px - ox, pz - oz
	local along = rx * dx + rz * dz
	if along < -1 or along > length then
		return false
	end
	local perp = math.abs(rx * dz - rz * dx)
	return perp <= width
end

function SpellLogic.ClampPoint(ox: number, oz: number, px: number, pz: number, range: number): (number, number)
	local dx, dz = px - ox, pz - oz
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= range or d < 1e-6 then
		return px, pz
	end
	return ox + dx / d * range, oz + dz / d * range
end

return SpellLogic
