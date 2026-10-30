--!strict
-- Spirits panel (Spirit Shrine / menu): equip, lock, select for fusion or release.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local DataController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("DataController"))

local C = Kit.Colors
local selection: { [string]: boolean } = {}

local function selectedList(spirits: { [string]: any }): { string }
	local out = {}
	for uid in selection do
		if spirits[uid] then
			table.insert(out, uid)
		else
			selection[uid] = nil
		end
	end
	table.sort(out)
	return out
end

local function isAway(uid: string): boolean
	for _, e in DataController.Get("expeditions") or {} do
		if table.find(e.spiritUids, uid) then
			return true
		end
	end
	return false
end

local Panel: PanelTypes.Panel = {
	Title = "Spirit Shrine",
	WatchKeys = { "spirits", "equippedSpirits", "expeditions", "ember" },
	Render = function(body, ctx)
		local spirits = DataController.Get("spirits") or {}
		local equipped = DataController.Get("equippedSpirits") or {}
		local list = {}
		for uid, s in spirits do
			table.insert(list, { uid = uid, s = s, power = SpiritConfig.PowerOf(s.id, s.rarity, s.mutation, s.level) })
		end
		table.sort(list, function(a, b)
			return a.power > b.power
		end)
		Kit.Label(body, string.format("Equipped %d / %d   ·   %d Spirits", #equipped, DataController.Get("spiritSlots") or 3, #list), { color = C.Gold })
		if #list == 0 then
			Kit.Label(body, "No Spirits yet - light a lantern at the Lantern Shrine!", { color = C.Muted })
			return
		end

		local chosen = selectedList(spirits)
		local tools = Kit.Row(body, 48)
		Kit.Button(tools, "Fuse selected (" .. #chosen .. ")", C.Accent, function()
			local inst, err = Net.Client.Invoke("FuseSpirits", selectedList(spirits))
			if inst then
				selection = {}
				ctx.notify("Fusion complete: " .. SpiritConfig.Spirits[inst.id].name .. " (" .. inst.rarity .. ")")
			else
				ctx.notify(err or "Fusion failed", true)
			end
		end, 180)
		Kit.Button(tools, "Release selected", C.Bad, function()
			local refund, err = Net.Client.Invoke("ReleaseSpirits", selectedList(spirits))
			if refund then
				selection = {}
				ctx.notify("Released for " .. refund .. " Ember")
			else
				ctx.notify(err or "Release failed", true)
			end
		end, 160)
		Kit.Label(tools, "Fuse: 3 of the same Spirit & rarity (4-5 for Epic+)", { size = 12, color = C.Muted, width = 260 })

		for i, entry in list do
			local s = entry.s
			local def = SpiritConfig.Spirits[s.id]
			local rarity = SpiritConfig.Rarities[s.rarity]
			local row = Kit.Row(body, 64, i % 2 == 0)
			local isSelected = selection[entry.uid] == true
			Kit.Button(row, if isSelected then "[x]" else "[ ]", if isSelected then C.Accent else C.Row, function()
				if isSelected then
					selection[entry.uid] = nil
				else
					selection[entry.uid] = true
				end
				ctx.refresh()
			end, 44)
			local info = Kit.Stack(row)
			local mutation = if s.mutation ~= "None" then s.mutation .. " " else ""
			Kit.Label(info, mutation .. def.name, { bold = true, size = 17, color = Kit.RarityColor(rarity and rarity.color) })
			Kit.Label(info, string.format("%s · Lv %d · Power %.0f%s", s.rarity, s.level, entry.power, if isAway(entry.uid) then " · on expedition" else ""), { size = 13, color = C.Muted })
			local isEquipped = table.find(equipped, entry.uid) ~= nil
			Kit.Button(row, if isEquipped then "Unequip" else "Equip", if isEquipped then C.Good else C.Blue, function()
				local remote = if isEquipped then "UnequipSpirit" else "EquipSpirit"
				local ok, err = Net.Client.Invoke(remote, entry.uid)
				if not ok and err then
					ctx.notify(err, true)
				end
			end, 90)
			Kit.Button(row, if s.locked then "Locked" else "Lock", if s.locked then C.Gold else C.Row, function()
				Net.Client.Invoke("LockSpirit", entry.uid, not s.locked)
			end, 80)
		end
	end,
}

return Panel
