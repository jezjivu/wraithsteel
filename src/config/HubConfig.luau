--!strict
-- HubConfig: the hub town ("Ninefold Crossing") and its stations. Owner: Agent D.
-- HubService builds a placeholder hub from this layout when Workspace.Hub does not exist.
-- A Studio-built hub replaces it: create Workspace.Hub and tag station parts with attribute
-- Station = "<kind>" (and LanternId for lantern pedestals); prompts are wired automatically.
-- TODO(Studio/Agent D): replace the generated blockout with the real hub build.

export type StationKind =
	"WeaponSmith"
	| "LanternShrine"
	| "SpiritShrine"
	| "ExpeditionBoard"
	| "QuestBoard"
	| "Store"
	| "CodeStone"

export type StationDef = {
	kind: StationKind,
	name: string,
	subtitle: string,
	angle: number, -- degrees around the plaza; 0 = toward the Wilds (-Z)
	color: { number }, -- roof / sign color (RGB 0-255)
}

local HubConfig = {}

HubConfig.Name = "Ninefold Crossing"
HubConfig.Origin = { 0, 0, 150 } -- plaza center (studs)
HubConfig.PlazaRadius = 64
HubConfig.StallRing = 44 -- distance of stalls from the center
HubConfig.PromptDistance = 14

HubConfig.Stations = {
	{ kind = "LanternShrine", name = "Lantern Shrine", subtitle = "Light a lantern, call a Spirit", angle = -40, color = { 220, 150, 60 } },
	{ kind = "WeaponSmith", name = "Weapon Smith", subtitle = "Blades, spears, fans & more", angle = -90, color = { 150, 60, 40 } },
	{ kind = "QuestBoard", name = "Quest Board", subtitle = "Daily tasks & rewards", angle = -140, color = { 90, 110, 70 } },
	{ kind = "Store", name = "Jade Merchant", subtitle = "Passes & boosts", angle = 180, color = { 60, 150, 110 } },
	{ kind = "CodeStone", name = "Code Stone", subtitle = "Redeem codes", angle = 140, color = { 110, 110, 130 } },
	{ kind = "ExpeditionBoard", name = "Expedition Board", subtitle = "Send Spirits exploring", angle = 90, color = { 70, 100, 150 } },
	{ kind = "SpiritShrine", name = "Spirit Shrine", subtitle = "Equip & fuse Spirits", angle = 40, color = { 140, 90, 190 } },
} :: { StationDef }

-- Lantern pedestals at the Lantern Shrine (in display order).
HubConfig.ShrineLanterns = { "paper_lantern", "rustwood_lantern", "jade_lantern" }

-- Training yard dummies (EnemyConfig.training_dummy).
HubConfig.TrainingDummies = 3
HubConfig.TrainingYardOffset = { 0, 0, 76 } -- just outside the plaza, behind the Jade Merchant

return HubConfig
