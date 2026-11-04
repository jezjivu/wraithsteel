--!strict
-- SecurityConfig: anti-exploit telemetry thresholds. Server-only (clients cannot read it).
-- SecurityService turns Net.Rejected events and movement samples into a decaying suspicion
-- score per player. Flags go to analytics + Output; kicks only at a very high score.
-- TODO(playtest): tune after real sessions (watch the "SecurityFlag" analytics events).

local SecurityConfig = {}

-- Suspicion score (decays by half every HalfLifeSeconds).
SecurityConfig.HalfLifeSeconds = 60
SecurityConfig.Weights = {
	rate = 1, -- a remote fired faster than its rate limit (lag bursts can do this)
	invalid = 4, -- arguments that fail NetValidate (the real client never sends these)
	speed = 6, -- sustained impossible movement speed
}
SecurityConfig.FlagScore = 40 -- report once per session (analytics + warn)
SecurityConfig.KickScore = 400 -- kick (only reachable with sustained garbage traffic)
SecurityConfig.KickEnabled = true
SecurityConfig.KickMessage = "Connection problem detected. Please rejoin."

-- Movement telemetry (flag only; the server does not move players back yet).
SecurityConfig.MoveSampleSeconds = 0.25
SecurityConfig.MaxHorizontalSpeed = 200 -- studs/s; grapple pull is 120, dashes ~60-100
SecurityConfig.MaxRiseSpeed = 150 -- studs/s upward (falling is not limited)
SecurityConfig.SustainedSamples = 3 -- consecutive fast samples; single jumps are teleports

return SecurityConfig
