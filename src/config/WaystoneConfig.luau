--!strict
-- WaystoneConfig: rest shrines in the world. Resting heals you fully, refills your Spring
-- Flask and Second Breath, makes it your respawn point, and attunes it for fast travel.
-- Positions are {x, z}; the height is found on the ground at runtime.

export type WaystoneDef = { id: string, name: string, at: { number } }

local WaystoneConfig = {}

WaystoneConfig.Waystones = {
	{ id = "hub", name = "Ninefold Crossing", at = { 0, 0 } }, -- placed next to the hub plaza at runtime
	{ id = "bamboo", name = "Bamboo Path Waystone", at = { 14, -30 } },
	{ id = "graves", name = "Lantern Graveyard Waystone", at = { 60, 4 } },
	{ id = "temple", name = "Temple Steps Waystone", at = { 62, -62 } },
	{ id = "village", name = "Ashen Village Waystone", at = { -128, -82 } },
	{ id = "springs", name = "Steaming Springs Waystone", at = { 122, 30 } },
	{ id = "hollow", name = "Carillon Hollow Waystone", at = { 22, -150 } },
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
