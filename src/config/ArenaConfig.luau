--!strict
-- ArenaConfig: instanced boss arenas. Challenging a story boss at its shrine teleports the
-- group into a walled arena far outside the open world; the fight stays in there.

local ArenaConfig = {}

ArenaConfig.Origin = { 6000, 300, 0 } -- first arena slot (x, y, z)
ArenaConfig.Spacing = 800 -- studs between arena slots (several fights at once)
ArenaConfig.Slots = 6
ArenaConfig.Radius = 72 -- playable floor radius
ArenaConfig.WallHeight = 36
ArenaConfig.ReturnDelay = 6 -- seconds after victory before you are sent back to the shrine
ArenaConfig.FallLimit = 40 -- studs below the floor: you are put back on the floor
-- Per-boss look (floor/wall/accent RGB); anything missing uses Default.
ArenaConfig.Themes = {
	Default = { floor = { 90, 86, 82 }, wall = { 60, 56, 58 }, accent = { 255, 140, 60 } },
	kagura_9 = { floor = { 30, 30, 40 }, wall = { 20, 20, 28 }, accent = { 255, 60, 200 }, layout = "Foundry" },
	archon_helion = { floor = { 230, 225, 215 }, wall = { 200, 192, 180 }, accent = { 255, 205, 90 } },
	tessai = { floor = { 96, 92, 88 }, wall = { 70, 66, 64 }, accent = { 255, 170, 90 }, layout = "Castle" },
	ashrei = { floor = { 70, 40, 38 }, wall = { 52, 40, 40 }, accent = { 255, 120, 60 }, layout = "Throne" },
} :: { [string]: { floor: { number }, wall: { number }, accent: { number }, layout: string? } }

return ArenaConfig
