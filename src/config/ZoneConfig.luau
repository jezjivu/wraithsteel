--!strict
-- ZoneConfig: named areas players move between (banner on entry, analytics, future gating).
-- Zones are checked in order; the first match wins; Fallback applies when none match.
-- Circle zones use {x, z} centers; Studio-built zones can instead be Parts in Workspace.Zones
-- with attributes ZoneId/ZoneName/Chapter (box bounds = the part's size).
-- TODO(Studio/Agent D): add one Part per chapter zone in Workspace.Zones.

export type ZoneDef = {
	id: string,
	name: string,
	subtitle: string?,
	center: { number }, -- {x, z}
	radius: number,
	chapter: number, -- chapter required to enter (0 = always)
}

local ZoneConfig = {}

ZoneConfig.CheckInterval = 1 -- seconds
ZoneConfig.FolderName = "Zones"

ZoneConfig.Zones = {
	{ id = "hub", name = "Ninefold Crossing", subtitle = "Where the Cracked Bell hums", center = { 0, 150 }, radius = 80, chapter = 0 },
} :: { ZoneDef }

ZoneConfig.Fallback = { id = "wilds", name = "The Wilds", subtitle = "Rust and lantern-light", chapter = 0 }

return ZoneConfig
