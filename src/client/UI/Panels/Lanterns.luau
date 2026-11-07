--!strict
-- Lanterns panel (Lantern Shrine). Compliance: the full odds sheet (Spirit odds incl. Luck,
-- mutation odds, pity) is rendered BEFORE the Open buttons appear, and LanternController only
-- allows opening after MarkOddsShown. Paid lanterns are hidden when policy restricts them.
-- The numbers come straight from the server's odds sheet (same function the server rolls with).

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

local function rarityColor(rarity: string): Color3
	local r = SpiritConfig.Rarities[rarity]
	return Kit.RarityColor(r and r.color)
end

-- One lantern choice: name, price and a free-open chip; the chosen one wears the seal color.
local function lanternCard(parent: Instance, id: string, isSelected: boolean, free: number, onPick: () -> ())
	local def = LanternConfig.Lanterns[id]
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(200, 74)
	b.BackgroundColor3 = if isSelected then C.Accent else C.Row
	b.BackgroundTransparency = if isSelected then 0.82 else 0.1
	b.Text = ""
	b.AutoButtonColor = false
	b.LayoutOrder = #parent:GetChildren()
	b.Parent = parent
	Kit.Corner(b, Kit.Radius)
	Kit.Stroke(b, if isSelected then C.Accent else C.Line, if isSelected then 0.15 else 0.85, if isSelected then 1.5 else 1)
	Kit.Pad(b, 12, 10)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = b
	Kit.Label(b, def.name, { font = Kit.TitleFont, size = 16 })
	local chips = Kit.Strip(b, 22)
	Kit.Chip(chips, FormatNumber.Short(def.price) .. " " .. def.currency, if def.currency == "Jade" then C.Jade else C.Ember)
	if free > 0 then
		Kit.Chip(chips, "free x" .. free, C.Gold, true)
	end
	b.Activated:Connect(onPick)
end

local Panel: PanelTypes.Panel = {
	Title = "Lantern Shrine",
	WatchKeys = { "ember", "jade", "freeLanterns", "lanternPity" },
	Render = function(body, ctx)
		if ctx.lanternId then
			selected = ctx.lanternId
			ctx.lanternId = nil
		end
		Kit.Wallet(body, FormatNumber.Short(DataController.Get("ember") or 0), FormatNumber.Short(DataController.Get("jade") or 0))

		local freeAll = DataController.Get("freeLanterns") or {}
		local picker = Kit.Strip(body, 74)
		local firstVisible: string? = nil
		for _, id in HubConfig.ShrineLanterns do
			if LanternConfig.Lanterns[id] and LanternController.IsVisible(id) then
				firstVisible = firstVisible or id
			end
		end
		if selected == nil or not LanternController.IsVisible(selected) then
			selected = firstVisible
		end
		for _, id in HubConfig.ShrineLanterns do
			if LanternConfig.Lanterns[id] and LanternController.IsVisible(id) then
				lanternCard(picker, id, selected == id, freeAll[id] or 0, function()
					selected = id
					lastResults = {}
					ctx.refresh()
				end)
			end
		end
		local id = selected
		if id == nil then
			Kit.Empty(body, "No lanterns are lit here right now.")
			return
		end
		local def = LanternConfig.Lanterns[id]
		local sheet = LanternController.FetchOdds(id)
		if sheet == nil then
			Kit.Label(body, "Could not load odds. Try again.", { color = C.Bad })
			return
		end

		-- Odds first (always fully visible before any Open button).
		Kit.Section(body, "Spirit odds", if sheet.luck > 1 then string.format("your Luck x%.2f is included", sheet.luck) else "shown before you open")
		for _, r in sheet.spirits do
			local s = SpiritConfig.Spirits[r.id]
			local color = rarityColor(s.rarity)
			Kit.BarLine(body, string.format('%s   <font color="#%s">%s</font>', s.name, color:ToHex(), s.rarity), FormatNumber.Percent(r.percent), r.percent / 100, color)
		end
		Kit.Section(body, "Mutation odds", "rolled separately")
		local muts = Kit.Strip(body, 24)
		for _, r in sheet.mutations do
			Kit.Chip(muts, r.id .. "  " .. FormatNumber.Percent(r.percent), if r.id == "None" then C.Muted else C.Gold)
		end
		if sheet.pity then
			Kit.Section(body, "Guarantee", string.format("%d / %d", sheet.pity.progress, sheet.pity.rolls))
			Kit.Label(body, string.format("A %s or better Spirit at least once every %d opens.", sheet.pity.minRarity, sheet.pity.rolls), { size = 14, color = C.Muted, wrap = true })
			Kit.Progress(body, sheet.pity.progress / math.max(1, sheet.pity.rolls), C.Gold, nil, 4)
			if sheet.pityOdds then
				for _, r in sheet.pityOdds do
					Kit.KeyValue(body, "  on a guaranteed open: " .. SpiritConfig.Spirits[r.id].name, FormatNumber.Percent(r.percent), C.Muted, C.Muted, 13)
				end
			end
		end
		LanternController.MarkOddsShown(id)

		local free = freeAll[id] or 0
		local actions = Kit.Strip(body, 44)
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
		Kit.Button(actions, if free > 0 then "Light it (free)" else "Light it  ·  " .. price, C.Accent, function()
			open(1)
		end, 210)
		Kit.Button(actions, "Light 3", C.Row, function()
			open(3)
		end, 110)
		Kit.Label(actions, "Light 3 needs the Lantern Festival pass", { size = 13, color = C.Muted, width = 260 })

		if #lastResults > 0 then
			-- Hatch reveal: a card per Spirit, rarity-colored, with its 3D model.
			Kit.Section(body, "A Spirit answers the lantern")
			for _, r in lastResults do
				local s = SpiritConfig.Spirits[r.spirit]
				local color = rarityColor(r.rarity)
				local card = Kit.Row(body, 132)
				card.BackgroundColor3 = color:Lerp(C.Panel, 0.8)
				Kit.SpiritViewport(card, SpiritModels.Build(r.spirit, r.mutation, r.rarity), 112, color:Lerp(C.Ink, 0.7))
				local info = Kit.Stack(card, -140)
				local mutation = if r.mutation ~= "None" then r.mutation .. " " else ""
				Kit.Label(info, mutation .. s.name, { font = Kit.TitleFont, size = 24, color = color })
				local chips = Kit.Strip(info, 24)
				Kit.Chip(chips, r.rarity, color, true)
				if r.pity then
					Kit.Chip(chips, "guaranteed", C.Gold)
				end
				Kit.Label(info, "Equip it in Spirits to fight beside you.", { size = 14, color = C.Muted })
			end
		end
	end,
}

return Panel
