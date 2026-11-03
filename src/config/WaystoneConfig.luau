--!strict
-- WaystoneConfig: rest shrines in the world. Resting heals you fully, refills your Spring
-- Flask and Second Breath, makes it your respawn point, and attunes it for fast travel.
-- Positions are {x, z}; the height is found on the ground at runtime.

export type WaystoneDef = { id: string, name: string, at: { number } }

local WaystoneConfig = {}

WaystoneConfig.Waystones = {
	{ id = "hub", name = "Ninefold Crossing", at = { 0, 0 } }, -- placed next to the hub plaza at runtime
	-- Few and far apart: each one is a long stretch of road away from the last.
	{ id = "graves", name = "Lantern Graveyard Waystone", at = { -400, -270 } },
	{ id = "gorge", name = "Red Maple Gorge Waystone", at = { 395, -330 } },
	{ id = "village", name = "Ashen Village Waystone", at = { -355, -735 } },
	{ id = "temple", name = "Temple of the Silent Bell Waystone", at = { 290, -960 } },
} :: { WaystoneDef }

WaystoneConfig.HubOffset = { -18, 18 } -- hub waystone position relative to the hub center
WaystoneConfig.CombatLockSeconds = 6 -- can't travel this soon after taking/dealing damage
WaystoneConfig.TravelCooldown = 5
WaystoneConfig.Color = { 120, 220, 255 }

function WaystoneConfig.Get(id: string): WaystoneDef?
	for _, w in WaystoneConfig.Waystones do
		if w.id == id then
			return w
		end
	end
	return nil
end

return WaystoneConfig
