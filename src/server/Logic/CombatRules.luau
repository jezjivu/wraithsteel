--!strict
-- CombatRules: pure, server-authoritative combat validation (guide §8.2 rule 3).
-- The client only REQUESTS actions; this module decides whether a request is legal right now,
-- which move it maps to, whether a hit connects geometrically, and how a hit resolves against
-- the defender's parry/block/dodge state. No Instances here so it is unit-testable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local CombatConfig = require(Config:WaitForChild("CombatConfig"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))

local CombatRules = {}

local BLOCK_HOLD_SECONDS = 0.6 -- after the parry window, the guard stays up as a block this long

export type State = {
	lastSeq: number,
	busyUntil: number, -- in a move's windup/active/recovery
	cancelable: boolean, -- current move can be dodge-canceled
	stunnedUntil: number,
	cooldowns: { [string]: number }, -- moveId -> readyAt
	comboIndex: number,
	lastLightAt: number,
	parryUntil: number, -- perfect-parry window end
	blockUntil: number, -- block window end
	parryReadyAt: number,
	whiffStreak: number,
	dodgeReadyAt: number,
	iframeUntil: number,
	counterUntil: number, -- counter stance (treated as perfect parry)
	ultimateCharge: number,
	recentActions: { number }, -- timestamps in the last second
	lastDodgeAt: number, -- for dash attacks
	airUsed: boolean, -- one air attack per jump
	riposteUntil: number, -- empowered counter-attack window after a perfect parry
}

function CombatRules.NewState(): State
	return {
		lastSeq = 0,
		busyUntil = 0,
		cancelable = false,
		stunnedUntil = 0,
		cooldowns = {},
		comboIndex = 0,
		lastLightAt = -math.huge,
		parryUntil = 0,
		blockUntil = 0,
		parryReadyAt = 0,
		whiffStreak = 0,
		dodgeReadyAt = 0,
		iframeUntil = 0,
		counterUntil = 0,
		ultimateCharge = 0,
		recentActions = {},
		lastDodgeAt = -math.huge,
		airUsed = false,
		riposteUntil = 0,
	}
end

local function rateOk(state: State, now: number): boolean
	local kept = {}
	for _, t in state.recentActions do
		if now - t < 1 then
			table.insert(kept, t)
		end
	end
	state.recentActions = kept
	return #kept < CombatConfig.Validation.MaxActionsPerSecond
end

export type Decision = {
	ok: boolean,
	reason: string?,
	action: string,
	moveId: string?,
	kind: ("Finisher" | "Air" | "Dash")?, -- special routes (for effects / analytics)
}

export type Opts = { airborne: boolean?, dashWindow: number? }

-- Fighting-style modifiers used by Commit (StyleConfig).
export type Mods = { speed: number?, parryWindowBonus: number? }

-- Validates a request. Does not change state except seq/rate bookkeeping; call Commit after.
function CombatRules.Validate(state: State, weaponId: string, action: string, seq: number, now: number, opts: Opts?): Decision
	local weapon = WeaponConfig.Weapons[weaponId]
	if weapon == nil then
		return { ok = false, reason = "NoWeapon", action = action }
	end
	if type(seq) ~= "number" or seq < state.lastSeq + CombatConfig.Validation.MinSeqStep then
		return { ok = false, reason = "Seq", action = action }
	end
	state.lastSeq = seq
	-- Releasing the guard is always allowed (a stuck guard would be worse than a lost press).
	if action == "GuardRelease" then
		return { ok = true, action = action }
	end
	if not rateOk(state, now) then
		return { ok = false, reason = "Rate", action = action }
	end
	if now < state.stunnedUntil then
		return { ok = false, reason = "Stunned", action = action }
	end
	local busy = now < state.busyUntil

	if action == "Dodge" then
		if now < state.dodgeReadyAt then
			return { ok = false, reason = "Cooldown", action = action }
		end
		if busy and not state.cancelable then
			return { ok = false, reason = "Busy", action = action }
		end
		return { ok = true, action = action }
	end

	if busy then
		return { ok = false, reason = "Busy", action = action }
	end

	if action == "Parry" then
		if now < state.parryReadyAt then
			return { ok = false, reason = "Cooldown", action = action }
		end
		return { ok = true, action = action }
	elseif action == "LightAttack" then
		local airborne = opts ~= nil and opts.airborne == true
		if not airborne then
			state.airUsed = false
		end
		if airborne and not state.airUsed then
			return { ok = true, action = action, moveId = weapon.air, kind = "Air" }
		end
		if now - state.lastDodgeAt <= ((opts and opts.dashWindow) or CombatConfig.DashAttackWindow) then
			return { ok = true, action = action, moveId = weapon.dash, kind = "Dash" }
		end
		local idx = 1
		if now - state.lastLightAt <= CombatConfig.Validation.ComboResetSeconds and state.comboIndex < #weapon.lightCombo then
			idx = state.comboIndex + 1
		end
		return { ok = true, action = action, moveId = weapon.lightCombo[idx] }
	elseif action == "HeavyAttack" then
		-- Heavy right after 2+ light hits becomes the class finisher.
		if now - state.lastLightAt <= CombatConfig.Validation.ComboResetSeconds and state.comboIndex >= 2 then
			return { ok = true, action = action, moveId = weapon.finisher, kind = "Finisher" }
		end
		return { ok = true, action = action, moveId = weapon.heavy }
	elseif action == "Skill1" or action == "Skill2" or action == "Ultimate" then
		local moveId = weapon.skills[action]
		if moveId == nil then
			return { ok = false, reason = "NoSkill", action = action }
		end
		if now < (state.cooldowns[moveId] or 0) then
			return { ok = false, reason = "Cooldown", action = action }
		end
		if action == "Ultimate" and state.ultimateCharge < WeaponConfig.UltimateChargeMax then
			return { ok = false, reason = "NoCharge", action = action }
		end
		return { ok = true, action = action, moveId = moveId }
	end
	-- SpiritCall is handled by SpiritAbilityService before validation; anything else is unknown.
	return { ok = false, reason = "Unavailable", action = action }
end

-- Applies a validated decision to the state. Returns the move's total duration (0 for non-moves).
function CombatRules.Commit(state: State, d: Decision, now: number, dodgeCooldownMult: number?, mods: Mods?): number
	table.insert(state.recentActions, now)
	local speed = (mods and mods.speed) or 1
	if d.action == "Dodge" then
		state.busyUntil = now + CombatConfig.DodgeDuration
		state.cancelable = false
		state.iframeUntil = now + CombatConfig.DodgeIFrames
		state.dodgeReadyAt = now + CombatConfig.DodgeCooldown * (dodgeCooldownMult or 1)
		state.lastDodgeAt = now
		return CombatConfig.DodgeDuration
	elseif d.action == "GuardRelease" then
		-- Letting go keeps the deflect window that is already running, but drops the block.
		state.blockUntil = math.min(state.blockUntil, math.max(now, state.parryUntil) + BLOCK_HOLD_SECONDS * 0.25)
		return 0
	elseif d.action == "Parry" then
		local window = CombatConfig.ParryWindow + ((mods and mods.parryWindowBonus) or 0)
		state.parryUntil = now + window
		-- Hold-to-guard: the block lasts until GuardRelease (or GuardMaxHold).
		state.blockUntil = now + math.max(window + BLOCK_HOLD_SECONDS, CombatConfig.GuardMaxHold)
		-- Assume a whiff; ResolveIncoming resets the streak on a successful parry.
		state.parryReadyAt = now + CombatConfig.ParryCooldown + state.whiffStreak * CombatConfig.ParrySpamPenalty
		state.whiffStreak += 1
		return 0
	end
	local move = d.moveId and WeaponConfig.Moves[d.moveId]
	if not move then
		return 0
	end
	local total = move.windup / speed + move.active + move.recovery / speed
	state.busyUntil = now + total
	state.blockUntil = 0 -- attacking drops your guard
	state.cancelable = move.dodgeCancelable == true
	if d.kind == "Air" then
		state.airUsed = true
		state.comboIndex = 0
	elseif d.kind == "Dash" then
		state.lastDodgeAt = -math.huge -- one dash strike per dash
		state.comboIndex = 0
	elseif d.kind == "Finisher" then
		state.comboIndex = 0
	elseif d.action == "LightAttack" then
		local weapon = nil
		for _, w in WeaponConfig.Weapons do
			if table.find(w.lightCombo, d.moveId :: string) then
				weapon = w
				break
			end
		end
		state.comboIndex = if weapon then table.find(weapon.lightCombo, d.moveId :: string) or 1 else 1
		state.lastLightAt = now
	end
	if move.cooldown then
		state.cooldowns[d.moveId :: string] = now + move.cooldown
	end
	if d.action == "Ultimate" then
		state.ultimateCharge = 0
	end
	if WeaponConfig.CounterStanceMoves[d.moveId :: string] then
		state.counterUntil = now + move.windup + move.active
	end
	return total
end

-- 2D (XZ-plane) hit test: is target within range (+tolerance) and inside the arc around look?
function CombatRules.InArc(ax: number, az: number, lookX: number, lookZ: number, tx: number, tz: number, range: number, arcDegrees: number): boolean
	local dx, dz = tx - ax, tz - az
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist > range + CombatConfig.Validation.RangeTolerance then
		return false
	end
	if dist < 1e-3 or arcDegrees >= 360 then
		return true
	end
	local ll = math.sqrt(lookX * lookX + lookZ * lookZ)
	if ll < 1e-6 then
		return false
	end
	local cos = (dx * lookX + dz * lookZ) / (dist * ll)
	local half = math.rad(math.min(arcDegrees, CombatConfig.Validation.FacingConeDegrees * 2) / 2)
	return cos >= math.cos(half)
end

export type Incoming = { damage: number, postureDamage: number, perilous: boolean?, perilousKind: string? }
-- What the defender was doing (filled by CombatService from server positions).
export type Context = { airborne: boolean?, dashedToward: boolean? }
export type Resolution = {
	outcome: "Hit" | "Blocked" | "Parried" | "Dodged" | "Countered" | "Jumped" | "Deflected",
	damage: number, -- health damage to defender
	postureDamage: number, -- posture damage to defender
	reflectPosture: number, -- posture damage back to attacker (parry)
}

-- Resolves an incoming attack against a defender's state at `now`.
function CombatRules.IsGuarding(state: State, now: number): boolean
	return now < state.blockUntil
end

function CombatRules.ResolveIncoming(state: State, hit: Incoming, now: number, ctx: Context?): Resolution
	-- Perilous answers come first (a dash into a thrust also has i-frames, but it is a counter).
	if hit.perilous and ctx then
		local kind = hit.perilousKind or "Grasp"
		if kind == "Pierce" and ctx.dashedToward then
			state.riposteUntil = now + CombatConfig.RiposteWindow
			state.ultimateCharge = math.min(WeaponConfig.UltimateChargeMax, state.ultimateCharge + WeaponConfig.UltimateChargePerParry * 2)
			return { outcome = "Countered", damage = 0, postureDamage = 0, reflectPosture = hit.postureDamage * CombatConfig.Counter.reflectPosture }
		elseif kind == "Sweep" and ctx.airborne then
			state.riposteUntil = now + CombatConfig.RiposteWindow
			return { outcome = "Jumped", damage = 0, postureDamage = 0, reflectPosture = 0 }
		end
	end
	if now < state.iframeUntil then
		return { outcome = "Dodged", damage = 0, postureDamage = 0, reflectPosture = 0 }
	end
	-- A perfectly timed deflect stops EVERYTHING - perilous attacks, projectiles, shockwaves -
	-- and perilous ones hurt the attacker's posture even more. Holding guard (block) only works
	-- against normal attacks.
	if now < state.parryUntil or now < state.counterUntil then
		state.whiffStreak = 0
		state.riposteUntil = now + CombatConfig.RiposteWindow
		state.parryReadyAt = now -- successful parry refunds the cooldown
		state.ultimateCharge = math.min(WeaponConfig.UltimateChargeMax, state.ultimateCharge + WeaponConfig.UltimateChargePerParry)
		local bonus = if hit.perilous then CombatConfig.PerilousParryBonus else 1
		return {
			outcome = "Parried",
			damage = 0,
			postureDamage = hit.postureDamage * CombatConfig.ParryPostureTaken,
			reflectPosture = hit.postureDamage * CombatConfig.ParryPostureReflect * bonus,
		}
	end
	if not hit.perilous then
		if now < state.blockUntil then
			return {
				outcome = "Blocked",
				damage = hit.damage * CombatConfig.BlockDamageMultiplier,
				postureDamage = hit.postureDamage * CombatConfig.BlockPostureMultiplier,
				reflectPosture = 0,
			}
		end
	end
	return { outcome = "Hit", damage = hit.damage, postureDamage = hit.postureDamage * 0.5, reflectPosture = 0 }
end

-- Outgoing damage scaled by attacker Power. `roll` in [0,1) supplies the variance.
function CombatRules.ScaleDamage(base: number, power: number, roll: number): number
	local variance = 1 + (roll * 2 - 1) * CombatConfig.DamageVariance
	return base * (1 + power / CombatConfig.PowerToDamageScale) * variance
end

return CombatRules
