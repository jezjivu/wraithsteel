--!strict
-- Lanterns panel (Lantern Shrine). Compliance: the full odds sheet (Spirit odds incl. Luck,
-- mutation odds, pity) is rendered BEFORE the Open buttons appear, and LanternController only
-- allows opening after MarkOddsShown. Paid lanterns are hidden when policy restricts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local LanternConfig = require(Config:WaitForChild("LanternConfig"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))
local HubConfig = require(Config:WaitForChild("HubConfig"))
local SpiritModels = require(Shared:WaitForChild("SpiritModels"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local Controllers = UI.Parent:WaitForChild("Controllers")
local DataController = require(Controllers:WaitForChild("DataController"))
local LanternController = require(Controllers:WaitForChild("LanternController"))

local C = Kit.Colors

local selected: string? = nil
local lastResults: { any } = {}

local Panel: PanelTypes.Panel = {
	Title = "Lantern Shrine",
	WatchKeys = { "ember", "jade", "freeLanterns", "lanternPity" },
	Render = function(body, ctx)
		if ctx.lanternId then
			selected = ctx.lanternId
			ctx.lanternId = nil
		end
		Kit.Label(body, string.format("Ember <b>%s</b>   Jade <b>%s</b>", FormatNumber.Short(DataController.Get("ember") or 0), FormatNumber.Short(DataController.Get("jade") or 0)), { color = C.Gold })

		local picker = Kit.Row(body, 46)
		for _, id in HubConfig.ShrineLanterns do
			local def = LanternConfig.Lanterns[id]
			if def and LanternController.IsVisible(id) then
				Kit.Button(picker, def.name, if selected == id then C.Accent else C.Row, function()
					selected = id
					lastResults = {}
					ctx.refresh()
				end, 170)
			end
		end
		local id = selected
		if id == nil or not LanternController.IsVisible(id) then
			Kit.Label(body, "Choose a lantern to see its odds.", { color = C.Muted })
			return
		end
		local def = LanternConfig.Lanterns[id]
		local sheet = LanternController.FetchOdds(id)
		if sheet == nil then
			Kit.Label(body, "Could not load odds. Try again.", { color = C.Bad })
			return
		end
		Kit.Label(body, "Odds (shown before you open):", { bold = true, color = C.Gold })
		for _, line in LanternController.FormatOdds(sheet) do
			Kit.Label(body, line, { size = 14 })
		end
		LanternController.MarkOddsShown(id)

		local free = (DataController.Get("freeLanterns") or {})[id] or 0
		local actions = Kit.Row(body, 48)
		local price = FormatNumber.Short(def.price) .. " " .. def.currency
		local function open(count: number)
			local results, err = LanternController.Open(id, count)
			if results == nil then
				ctx.notify(err or "Could not open", true)
				return
			end
			lastResults = results
			ctx.refresh()
		end
		Kit.Button(actions, if free > 0 then "Open (free x" .. free .. ")" else "Open  " .. price, C.Accent, function()
			open(1)
		end, 190)
		Kit.Button(actions, "Open x3", C.Row, function()
			open(3)
		end, 120)
		Kit.Label(actions, "x3 needs the Lantern Festival pass", { size = 12, color = C.Muted, width = 220 })

		if #lastResults > 0 then
			-- Hatch reveal: a big card for each Spirit, rarity-colored, with its 3D model.
			Kit.Label(body, "A Spirit answers the lantern!", { bold = true, size = 20, color = C.Gold })
			for _, r in lastResults do
				local s = SpiritConfig.Spirits[r.spirit]
				local rarity = SpiritConfig.Rarities[r.rarity]
				local color = Kit.RarityColor(rarity and rarity.color)
				local card = Kit.Row(body, 132)
				card.BackgroundColor3 = color:Lerp(C.Panel, 0.75)
				Kit.SpiritViewport(card, SpiritModels.Build(r.spirit, r.mutation, r.rarity), 118, color:Lerp(C.Ink, 0.6))
				local info = Kit.Stack(card, -140)
				local mutation = if r.mutation ~= "None" then r.mutation .. " " else ""
				Kit.Label(info, mutation .. s.name, { bold = true, size = 24, color = color })
				Kit.Label(info, r.rarity .. (if r.pity then "  ·  guaranteed!" else ""), { size = 16, color = color })
				Kit.Label(info, "Equip it at the Spirit Shrine to boost your Power.", { size = 13, color = C.Muted })
			end
		end
	end,
}

return Panel
