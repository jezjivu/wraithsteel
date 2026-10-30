--!strict
-- LanternController: client side of Spirit Lanterns.
-- Compliance guard: Open() refuses unless the odds panel for that lantern was shown first in
-- this session (UI calls MarkOddsShown after rendering FormatOdds). The server additionally
-- enforces PolicyService gating; the client hides paid lanterns when policy restricts them.
--
-- API:
--   LanternController.FetchOdds(lanternId) -> OddsSheet?      (server-computed, luck included)
--   LanternController.FormatOdds(sheet) -> { string }          lines for the odds panel
--   LanternController.MarkOddsShown(lanternId)
--   LanternController.IsVisible(lanternId) -> boolean          false for restricted paid lanterns
--   LanternController.Open(lanternId, count) -> (results?, reason?)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local LanternConfig = require(Config:WaitForChild("LanternConfig"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))

local DataController = require(script.Parent.DataController)

local LanternController = { Name = "LanternController", Priority = 30 }

local oddsShown: { [string]: boolean } = {}

function LanternController.IsVisible(lanternId: string): boolean
	local def = LanternConfig.Lanterns[lanternId]
	if def == nil then
		return false
	end
	return not (def.paid and DataController.PolicyFlags.paidRandomItemsRestricted)
end

function LanternController.FetchOdds(lanternId: string): any
	return Net.Client.Invoke("GetLanternOdds", lanternId)
end

function LanternController.FormatOdds(sheet: any): { string }
	local lines = {}
	local lantern = LanternConfig.Lanterns[sheet.lanternId]
	table.insert(lines, string.format("%s - %s %s", lantern.name, FormatNumber.Commas(lantern.price), lantern.currency))
	if sheet.luck > 1 then
		table.insert(lines, string.format("Your Luck: x%.2f (already included below)", sheet.luck))
	end
	table.insert(lines, "Spirit chances:")
	for _, r in sheet.spirits do
		local def = SpiritConfig.Spirits[r.id]
		table.insert(lines, string.format("  %s (%s): %s", def.name, def.rarity, FormatNumber.Percent(r.percent)))
	end
	table.insert(lines, "Mutation chances (rolled separately):")
	for _, r in sheet.mutations do
		table.insert(lines, string.format("  %s: %s", r.id, FormatNumber.Percent(r.percent)))
	end
	if sheet.pity then
		table.insert(lines, string.format("Guarantee: a %s or better Spirit at least once every %d opens (%d/%d).", sheet.pity.minRarity, sheet.pity.rolls, sheet.pity.progress, sheet.pity.rolls))
		if sheet.pityOdds then
			table.insert(lines, "Chances on a guaranteed open:")
			for _, r in sheet.pityOdds do
				table.insert(lines, string.format("  %s: %s", SpiritConfig.Spirits[r.id].name, FormatNumber.Percent(r.percent)))
			end
		end
	end
	return lines
end

function LanternController.MarkOddsShown(lanternId: string)
	oddsShown[lanternId] = true
end

function LanternController.Open(lanternId: string, count: number): (any, string?)
	if not oddsShown[lanternId] then
		return nil, "Show the odds first."
	end
	if not LanternController.IsVisible(lanternId) then
		return nil, "Unavailable"
	end
	return Net.Client.Invoke("OpenLantern", lanternId, count)
end

function LanternController.Init() end
function LanternController.Start() end

return LanternController
