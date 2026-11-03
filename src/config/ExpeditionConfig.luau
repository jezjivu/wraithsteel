--!strict
-- ExpeditionConfig: idle Spirit expeditions. Owner: Agent A (economy) + B (Spirits).
-- Reward = sum(Power of sent Spirits) * emberPerPowerHour * hours, floored.
-- Each sent Spirit gains spiritXpPerHour * hours Spirit XP.

export type RouteDef = {
	name: string,
	chapter: number, -- unlocked at this chapter
	durationSeconds: number,
	emberPerPowerHour: number,
	spiritXpPerHour: number,
	maxSpirits: number,
}

local ExpeditionConfig = {}

ExpeditionConfig.SlotIds = { "slot1", "slot2" }
ExpeditionConfig.ExtraSlotWithPass = "slot3" -- LongExpeditions pass adds a third slot

ExpeditionConfig.Routes = {
	reed_marsh = { name = "Reed Marsh Patrol", chapter = 0, durationSeconds = 15 * 60, emberPerPowerHour = 6, spiritXpPerHour = 40, maxSpirits = 3 },
	cracked_bell_ruins = { name = "Cracked Bell Ruins", chapter = 0, durationSeconds = 60 * 60, emberPerPowerHour = 7, spiritXpPerHour = 50, maxSpirits = 3 },
	rustwood_trail = { name = "Rustwood Trail", chapter = 1, durationSeconds = 4 * 3600, emberPerPowerHour = 8, spiritXpPerHour = 60, maxSpirits = 4 },
} :: { [string]: RouteDef }

return ExpeditionConfig
