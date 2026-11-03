--!strict
-- Weapons panel: Weapon Smith (buy + equip) at the hub stall; equip-only from the menu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))
local ChapterConfig = require(Config:WaitForChild("ChapterConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local DataController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("DataController"))

local C = Kit.Colors

local Panel: PanelTypes.Panel = {
	Title = "Weapon Smith",
	WatchKeys = { "weapons", "equippedWeapon", "ember", "jade", "chapter" },
	Render = function(body, ctx)
		local owned = DataController.Get("weapons") or {}
		local equipped = DataController.Get("equippedWeapon")
		local chapter = DataController.Get("chapter") or 0
		Kit.Label(body, string.format("Ember <b>%s</b>   Jade <b>%s</b>", FormatNumber.Short(DataController.Get("ember") or 0), FormatNumber.Short(DataController.Get("jade") or 0)), { color = C.Gold })
		if not ctx.atStation then
			Kit.Label(body, "Visit the Weapon Smith in Ninefold Crossing to buy new weapons.", { color = C.Muted, size = 14 })
		end
		for i, id in WeaponConfig.ShopOrder do
			local def = WeaponConfig.Weapons[id]
			if def == nil then
				continue
			end
			local row = Kit.Row(body, 92, i % 2 == 0)
			Kit.Viewport(row, WeaponModels.Build(id, true), 78, WeaponModels.Length(id))
			local info = Kit.Stack(row)
			local rarity = SpiritConfig.Rarities[def.rarity]
			Kit.Label(info, def.name, { bold = true, size = 18, color = Kit.RarityColor(rarity and rarity.color) })
			Kit.Label(info, string.format("%s %s  ·  Power +%d", def.rarity, def.class, def.power), { size = 14, color = C.Muted })
			Kit.Label(info, def.description, { size = 13, wrap = true })

			if owned[id] then
				if equipped == id then
					Kit.Button(row, "Equipped", C.Good, function() end, 130)
				else
					Kit.Button(row, "Equip", C.Blue, function()
						Net.Client.Fire("EquipWeapon", id)
					end, 130)
				end
			elseif chapter < def.unlockChapter then
				local ch = ChapterConfig.Chapters[def.unlockChapter]
				Kit.Button(row, "Locked: " .. (if ch then "Ch. " .. def.unlockChapter else "later"), C.Row, function()
					ctx.notify("Unlocks in " .. (if ch then ch.name else "a later chapter"), true)
				end, 130)
			elseif ctx.atStation then
				local label = if def.price == 0 then "Take" else FormatNumber.Short(def.price) .. " " .. def.currency
				Kit.Button(row, "Buy  " .. label, if def.currency == "Jade" then C.Jade else C.Accent, function()
					local ok, msg = Net.Client.Invoke("BuyWeapon", id)
					ctx.notify(msg or "Try again", not ok)
				end, 130)
			else
				Kit.Button(row, FormatNumber.Short(def.price) .. " " .. def.currency, C.Row, function()
					ctx.notify("Buy this at the Weapon Smith in the hub.", true)
				end, 130)
			end
		end
	end,
}

return Panel
