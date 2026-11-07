--!strict
-- PvpConfig: duels in the Proving Ring (DuelService, Logic/DuelLogic). Owner: Agent B.
-- Duels are FAIR: both fighters get the same health, Power/levels/spirit and skill-tree
-- stats are ignored, Qi arts, kunai and Spirit companions are off. What counts is the weapon,
-- the fighting style and your timing (deflects, posture, perilous answers). Nobody dies or
-- drops Ember: a lethal blow ends the round instead.

local PvpConfig = {}

-- Instanced arenas, far from every realm (like boss arenas).
PvpConfig.Origin = { -6000, 300, 0 }
PvpConfig.Spacing = 600
PvpConfig.Slots = 6
PvpConfig.StartDistance = 26 -- studs between the fighters at the start of a round
PvpConfig.FallLimit = 30 -- studs below the floor: put back at your start mark
PvpConfig.Theme = { floor = { 120, 92, 70 }, wall = { 60, 44, 40 }, accent = { 230, 180, 90 }, layout = "Dojo" }

-- Match flow.
PvpConfig.RoundsToWin = 2 -- best of three
PvpConfig.CountdownSeconds = 3
PvpConfig.RoundSeconds = 75 -- then the healthier fighter takes the round (equal = replay)
PvpConfig.BetweenRoundsSeconds = 3
PvpConfig.EndSeconds = 4 -- result screen before you are sent back
PvpConfig.ChallengeSeconds = 30 -- a challenge expires after this
PvpConfig.MaxRounds = 5 -- draws included; after this the healthier total wins

-- Fair stats.
PvpConfig.Health = 300
PvpConfig.DamageScale = 2.2 -- on a move's base damage (no Power): ~15-20 clean light hits win a round
PvpConfig.PostureScale = 1.0
PvpConfig.DeathblowFraction = 0.3 -- a hit on a posture-broken fighter takes this much max health
PvpConfig.FlasksPerRound = 1

-- Rewards (small, so duels are for fun, not farming).
PvpConfig.WinEmber = 150
PvpConfig.LoseEmber = 40
PvpConfig.RewardCooldownSeconds = 600 -- the same pair earns rewards once per this
PvpConfig.ChallengeRadius = 80 -- studs: challenge players near you

return PvpConfig
