--!strict
-- Arts panel (menu / Dojo): choose which Qi arts sit on Z / X / C.
-- Arts unlock by level for free; the server re-checks every slot change (SetSpellSlot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local SpellConfig = require(Config:WaitForChild("SpellConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local Controllers = UI.Parent:WaitForChild("Controllers")
local DataController = require(Controllers:WaitForChild("DataController"))
local SpellController = require(Controllers:WaitForChild("SpellController"))

local C = Kit.Colors

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local KIND_TEXT = {
	Projectile = "Projectile",
	Blink = "Movement",
	Barrier = "Defense",
	Seal = "Area stun",
	Storm = "Close range area",
	Lance = "Piercing line",
	Bell = "Ultimate area",
}

local Panel: PanelTypes.Panel = {
	Title = "Qi Arts",
	WatchKeys = { "spellLoadout", "level" },
	Render = function(body, ctx)
		local level = DataController.Get("level") or 1
		local loadout = DataController.Get("spellLoadout") or SpellConfig.DefaultLoadout
		local slots = {}
		for i = 1, SpellConfig.Slots do
			local spell = SpellConfig.Spells[loadout[i] or ""]
			table.insert(slots, SpellConfig.KeyLabels[i] .. ": " .. (if spell then spell.name else "-"))
		end
		Kit.Label(body, table.concat(slots, "     "), { bold = true, color = C.Gold })
		Kit.Label(body, string.format("Arts cost Qi (max %d). Qi refills over time and faster when you land hits (+%d) and perfect parries (+%d).", SpellConfig.Qi.max, SpellConfig.Qi.onHit, SpellConfig.Qi.onParry), { size = 13, color = C.Muted, wrap = true })

		for i, id in SpellConfig.Order do
			local spell = SpellConfig.Spells[id]
			local unlocked = level >= spell.unlockLevel
			local row = Kit.Row(body, 84, i % 2 == 0)
			local info = Kit.Stack(row, -250)
			Kit.Label(info, spell.name, { bold = true, size = 18, color = if unlocked then rgb(spell.color) else C.Muted })
			Kit.Label(info, string.format("%s · %d Qi · %.0fs cooldown%s", KIND_TEXT[spell.kind] or spell.kind, spell.qi, spell.cooldown, if unlocked then "" else " · unlocks at level " .. spell.unlockLevel), { size = 13, color = C.Muted })
			Kit.Label(info, spell.text, { size = 13, color = C.Text, wrap = true })
			for slot = 1, SpellConfig.Slots do
				local here = loadout[slot] == id
				Kit.Button(row, SpellConfig.KeyLabels[slot], if here then C.Good elseif unlocked then C.Blue else C.Row, function()
					if not unlocked then
						ctx.notify("Unlocks at level " .. spell.unlockLevel, true)
						return
					end
					local ok, err = SpellController.SetSlot(slot, if here then "" else id)
					if not ok then
						ctx.notify(err or "Could not set art", true)
					end
				end, 56)
			end
		end
	end,
}

return Panel
