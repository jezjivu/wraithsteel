--!strict
-- Spirits panel (Spirit Shrine / menu): equip, lock, select for fusion or release.
-- Shows what each Spirit really does: its stats (Shared/SpiritStats) and combat ability.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))
local SpiritModels = require(Shared:WaitForChild("SpiritModels"))
local SpiritStats = require(Shared:WaitForChild("SpiritStats"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local DataController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("DataController"))

local C = Kit.Colors
local STAT_TEXT = Color3.fromRGB(140, 225, 155)

local function statLine(stats: { [string]: number }): string
	local parts = {}
	for _, stat in SpiritConfig.StatOrder do
		local v = stats[stat]
		if v and v > 0 then
			table.insert(parts, SpiritStats.Format(stat, v) .. " " .. SpiritStats.Label(stat))
		end
	end
	return table.concat(parts, "   ")
end
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

-- Square icon button (lock).
local function iconButton(parent: Instance, icon: string, on: boolean, onClick: () -> ())
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(36, 36)
	b.BackgroundColor3 = if on then C.Gold else C.Raised
	b.BackgroundTransparency = if on then 0.8 else 0.55
	b.Text = ""
	b.AutoButtonColor = false
	b.LayoutOrder = 100000
	b.Parent = parent
	Kit.Corner(b, Kit.Radius)
	Kit.Stroke(b, if on then C.Gold else C.Line, if on then 0.4 else 0.8, 1)
	local i = Kit.Icon(b, icon, 16, if on then C.Gold else C.Muted)
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.Position = UDim2.fromScale(0.5, 0.5)
	b.Activated:Connect(onClick)
	return b
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

		-- Summary: slots, collection size, the exact party bonus the server applies.
		local summary = Kit.Strip(body, 26)
		Kit.Chip(summary, string.format("Equipped %d / %d", #equipped, DataController.Get("spiritSlots") or 3), C.Gold, true)
		Kit.Chip(summary, string.format("%d Spirits", #list), C.Muted)
		local refs = {}
		for _, uid in equipped do
			local s = spirits[uid]
			if s then
				table.insert(refs, { id = s.id, rarity = s.rarity, mutation = s.mutation, level = s.level })
			end
		end
		local totals = SpiritStats.Totals(refs)
		Kit.Section(body, "Party bonus")
		Kit.Label(body, if next(totals) then statLine(totals) else "Equip Spirits to gain stats and companions that fight beside you.", { size = 14, color = STAT_TEXT, wrap = true })
		Kit.Label(body, "Spirits cast their abilities on their own in combat. Press T for a Spirit Burst: all at once, stronger.", { size = 13, color = C.Muted, wrap = true })
		if #list == 0 then
			Kit.Empty(body, "No Spirits yet", "Light a lantern at the Lantern Shrine to call your first one.")
			return
		end

		local chosen = selectedList(spirits)
		local tools = Kit.Strip(body, 40)
		Kit.Button(tools, if #chosen > 0 then "Fuse " .. #chosen .. " selected" else "Fuse", if #chosen > 0 then C.Accent else C.Row, function()
			local inst, err = Net.Client.Invoke("FuseSpirits", selectedList(spirits))
			if inst then
				selection = {}
				ctx.notify("Fusion complete: " .. SpiritConfig.Spirits[inst.id].name .. " (" .. inst.rarity .. ")")
			else
				ctx.notify(err or "Fusion failed", true)
			end
		end, 150)
		Kit.Button(tools, "Release", C.Bad, function()
			local refund, err = Net.Client.Invoke("ReleaseSpirits", selectedList(spirits))
			if refund then
				selection = {}
				ctx.notify("Released for " .. refund .. " Ember")
			else
				ctx.notify(err or "Release failed", true)
			end
		end, 110)
		Kit.Label(tools, "Fuse 3 of the same Spirit and rarity (4-5 for Epic and up)", { size = 13, color = C.Muted, width = 380 })

		Kit.Section(body, "Collection", "strongest first")
		for _, entry in list do
			local s = entry.s
			local def = SpiritConfig.Spirits[s.id]
			local rarity = SpiritConfig.Rarities[s.rarity]
			local rc = Kit.RarityColor(rarity and rarity.color)
			local isEquipped = table.find(equipped, entry.uid) ~= nil
			local row = Kit.Row(body, 104)
			row.BackgroundColor3 = rc:Lerp(C.Row, 0.9)
			local isSelected = selection[entry.uid] == true
			Kit.Toggle(row, isSelected, function()
				if isSelected then
					selection[entry.uid] = nil
				else
					selection[entry.uid] = true
				end
				ctx.refresh()
			end)
			Kit.SpiritViewport(row, SpiritModels.Build(s.id, s.mutation, s.rarity), 72, rc:Lerp(C.Ink, 0.82))
			local info = Kit.Stack(row, -320)
			local mutation = if s.mutation ~= "None" then s.mutation .. " " else ""
			Kit.Label(info, mutation .. def.name, { font = Kit.TitleFont, size = 17, color = C.Text })
			local chips = Kit.Strip(info, 22)
			Kit.Chip(chips, s.rarity, rc, true)
			Kit.Chip(chips, def.element, C.Muted)
			Kit.Chip(chips, "Lv " .. s.level, C.Muted)
			Kit.Chip(chips, string.format("Power %.0f", entry.power), C.Gold)
			if isAway(entry.uid) then
				Kit.Chip(chips, "on expedition", C.Blue)
			end
			Kit.Label(info, statLine(SpiritStats.Of(s.id, s.rarity, s.mutation, s.level)), { size = 13, color = STAT_TEXT })
			local ab = SpiritConfig.Abilities[def.ability]
			if ab then
				Kit.Label(info, string.format("<b>%s</b> · %ds · %s", ab.name, ab.cooldown, ab.text), { size = 13, color = C.Muted })
			end
			Kit.Button(row, if isEquipped then "Equipped" else "Equip", if isEquipped then C.Good else C.Blue, function()
				local remote = if isEquipped then "UnequipSpirit" else "EquipSpirit"
				local ok, err = Net.Client.Invoke(remote, entry.uid)
				if not ok and err then
					ctx.notify(err, true)
				end
			end, 100)
			iconButton(row, "lock", s.locked == true, function()
				Net.Client.Invoke("LockSpirit", entry.uid, not s.locked)
			end)
		end
	end,
}

return Panel
