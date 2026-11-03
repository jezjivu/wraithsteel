--!strict
-- Posture: shared posture meter for players, enemies and bosses.
-- Posture fills as a combatant takes posture damage; when it reaches max the combatant is
-- "broken" (stunned, takes bonus damage). It drains back to 0 after a short delay.

local Posture = {}

export type Posture = {
	value: number,
	max: number,
	regenPerSecond: number,
	regenDelay: number,
	lastHitAt: number,
	brokenUntil: number,
}

function Posture.new(max: number, regenPerSecond: number, regenDelay: number): Posture
	return { value = 0, max = max, regenPerSecond = regenPerSecond, regenDelay = regenDelay, lastHitAt = -math.huge, brokenUntil = -math.huge }
end

function Posture.IsBroken(p: Posture, now: number): boolean
	return now < p.brokenUntil
end

-- Adds posture damage. Returns true if this hit broke posture.
function Posture.Add(p: Posture, amount: number, now: number, brokenSeconds: number): boolean
	if amount <= 0 or Posture.IsBroken(p, now) then
		return false
	end
	p.value = math.min(p.max, p.value + amount)
	p.lastHitAt = now
	if p.value >= p.max then
		p.value = 0
		p.brokenUntil = now + brokenSeconds
		return true
	end
	return false
end

function Posture.Update(p: Posture, now: number, dt: number)
	if p.value > 0 and now - p.lastHitAt >= p.regenDelay then
		p.value = math.max(0, p.value - p.regenPerSecond * dt)
	end
end

function Posture.Fraction(p: Posture): number
	return p.value / p.max
end

return Posture
