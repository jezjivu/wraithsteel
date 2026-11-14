--!strict
-- Map panel: a hand-drawn style chart of the Ashen Valley from MapConfig - roads, regions,
-- waystones (attuned ones lit), shortcut gates (open ones marked), relics you found, the hub
-- and your own position. In another realm it shows that realm's areas (RealmConfig).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local MapConfig = require(Config:WaitForChild("MapConfig"))
local RealmConfig = require(Config:WaitForChild("RealmConfig"))
local WaystoneConfig = require(Config:WaitForChild("WaystoneConfig"))
local HubConfig = require(Config:WaitForChild("HubConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local DataController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("DataController"))

local C = Kit.Colors
local player = Players.LocalPlayer

local SIZE = 560 -- canvas pixels (square)

local function frame(parent: Instance, pos: Vector2, size: Vector2, color: Color3, transparency: number?, z: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(pos.X, pos.Y)
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.ZIndex = z or 2
	f.Parent = parent
	return f
end

local function round(f: Frame)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
end

local function label(parent: Instance, pos: Vector2, text: string, color: Color3, size: number, z: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromOffset(pos.X, pos.Y)
	l.Size = UDim2.fromOffset(150, size + 6)
	l.BackgroundTransparency = 1
	l.Font = Kit.BoldFont
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.35
	l.TextWrapped = true
	l.Text = text
	l.ZIndex = z or 6
	l.Parent = parent
	return l
end

local function line(parent: Instance, a: Vector2, b: Vector2, width: number, color: Color3, z: number?)
	local d = b - a
	local f = frame(parent, (a + b) / 2, Vector2.new(d.Magnitude + width * 0.6, width), color, 0, z)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
end

local Panel: PanelTypes.Panel = {
	Title = "Map",
	WatchKeys = { "waystones", "shortcuts", "relics" },
	Render = function(body, ctx)
		local realm = tostring(player:GetAttribute("Realm") or "japan")
		local holder = Instance.new("Frame")
		holder.Size = UDim2.new(1, -8, 0, SIZE + 10)
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = 1
		holder.Parent = body
		local canvas = Instance.new("Frame")
		canvas.AnchorPoint = Vector2.new(0.5, 0)
		canvas.Position = UDim2.fromScale(0.5, 0)
		canvas.Size = UDim2.fromOffset(SIZE, SIZE)
		canvas.BackgroundColor3 = Color3.fromRGB(42, 36, 32) -- dark parchment
		canvas.BorderSizePixel = 0
		canvas.ClipsDescendants = true
		canvas.Parent = holder
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(Color3.fromRGB(255, 240, 215), Color3.fromRGB(190, 170, 150))
		grad.Rotation = 60
		grad.Parent = canvas
		local st = Instance.new("UIStroke")
		st.Color = C.Steel
		st.Transparency = 0.4
		st.Parent = canvas
		Kit.Brackets(canvas)
		-- Fit to the window width.
		local fit = Instance.new("UIScale")
		fit.Parent = canvas
		local function refit()
			local w = holder.AbsoluteSize.X
			if w > 0 then
				local k = math.clamp(w / SIZE, 0.45, 1)
				fit.Scale = k
				holder.Size = UDim2.new(1, -8, 0, math.ceil(SIZE * k) + 10)
			end
		end
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
		task.defer(refit)

		-- World bounds -> canvas pixels (north = -Z = up).
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		local function grow(x: number, z: number, r: number)
			minX, maxX = math.min(minX, x - r), math.max(maxX, x + r)
			minZ, maxZ = math.min(minZ, z - r), math.max(maxZ, z + r)
		end
		local origin = { 0, 0 }
		local areas: { { name: string, center: { number }, radius: number } } = {}
		if realm == "japan" then
			for _, a in MapConfig.Areas do
				table.insert(areas, { name = a.name, center = a.center, radius = a.radius })
			end
			grow(HubConfig.Origin[1], HubConfig.Origin[3], HubConfig.PlazaRadius + 20)
		else
			local r = RealmConfig.Realms[realm]
			origin = { r.origin[1], r.origin[3] }
			for _, a in r.areas do
				table.insert(areas, { name = a.name, center = a.center, radius = a.radius })
			end
		end
		for _, a in areas do
			grow(a.center[1], a.center[2], a.radius)
		end
		local span = math.max(maxX - minX, maxZ - minZ) * 1.08
		local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
		local k = SIZE / span
		local function px(x: number, z: number): Vector2
			return Vector2.new(SIZE / 2 + (x - cx) * k, SIZE / 2 + (z - cz) * k)
		end

		local ink = Color3.fromRGB(70, 52, 40)
		if realm == "japan" then
			-- Roads (stairs drawn dashed-dark).
			for _, R in MapConfig.Roads do
				for i = 1, #R - 1 do
					local a, b = R[i], R[i + 1]
					local stair = math.abs(a.y - b.y) > 0.5
					line(canvas, px(a.at[1], a.at[2]), px(b.at[1], b.at[2]), math.max(3, a.half * k * 0.9), if stair then Color3.fromRGB(150, 140, 125) else Color3.fromRGB(196, 170, 130), 2)
				end
			end
			line(canvas, px(0, 80), px(HubConfig.Origin[1], HubConfig.Origin[3] - HubConfig.PlazaRadius), 8, Color3.fromRGB(196, 170, 130), 2)
			local hub = frame(canvas, px(HubConfig.Origin[1], HubConfig.Origin[3]), Vector2.new(HubConfig.PlazaRadius * 2 * k, HubConfig.PlazaRadius * 2 * k), Color3.fromRGB(150, 135, 110), 0.2, 3)
			round(hub)
			label(canvas, px(HubConfig.Origin[1], HubConfig.Origin[3]), HubConfig.Name, ink, 12)
		end
		for _, a in areas do
			local f = frame(canvas, px(a.center[1], a.center[2]), Vector2.new(a.radius * 2 * k, a.radius * 2 * k), Color3.fromRGB(120, 140, 90), 0.45, 3)
			round(f)
			label(canvas, px(a.center[1], a.center[2]), a.name, ink, 11)
		end

		-- Waystones (lit when attuned).
		local attuned = DataController.Get("waystones") or {}
		if realm == "japan" then
			for _, w in WaystoneConfig.Waystones do
				if w.id ~= "hub" then
					local d = frame(canvas, px(w.at[1], w.at[2]), Vector2.new(11, 11), if attuned[w.id] then Color3.fromRGB(120, 220, 255) else Color3.fromRGB(90, 90, 100), 0, 7)
					d.Rotation = 45
				end
			end
			-- Shortcut gates.
			local opened = DataController.Get("shortcuts") or {}
			for _, g in MapConfig.Shortcuts do
				local f = frame(canvas, px(g.at[1], g.at[2]), Vector2.new(16, 6), if opened[g.id] then Color3.fromRGB(110, 190, 110) else Color3.fromRGB(170, 50, 45), 0, 7)
				f.Rotation = math.deg(math.atan2(g.dir[1], -g.dir[2]))
			end
			-- Relics you have found (the rest stay secret).
			local found = DataController.Get("relics") or {}
			for _, r in MapConfig.Relics do
				if found[r.id] then
					local d = frame(canvas, px(r.at[1], r.at[2]), Vector2.new(8, 8), Color3.fromRGB(255, 130, 70), 0, 7)
					round(d)
				end
			end
			-- Landmarks.
			local L = MapConfig.Landmarks
			label(canvas, px(L.belfry[1], L.belfry[2]) + Vector2.new(0, -14), "⌂ Great Belfry", Color3.fromRGB(150, 50, 40), 11)
		end

		-- You.
		local ch = player.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local p = root.Position
			local me = frame(canvas, px(p.X - origin[1], p.Z - origin[2]), Vector2.new(12, 12), Color3.fromRGB(230, 40, 40), 0, 9)
			me.Rotation = 45
			local look = root.CFrame.LookVector
			local tip = frame(canvas, px(p.X - origin[1] + look.X * 14 / k, p.Z - origin[2] + look.Z * 14 / k), Vector2.new(5, 5), Color3.fromRGB(255, 230, 200), 0, 9)
			round(tip)
		end

		local relics = 0
		for _ in DataController.Get("relics") or {} do
			relics += 1
		end
		local legend = Kit.Row(body, 40)
		legend.LayoutOrder = 2
		Kit.Label(legend, string.format("◆ you   ◇ waystone (blue = attuned)   ▬ gate (green = open)   ● relic found  ·  Ashen Relics %d/%d", relics, #MapConfig.Relics), { size = 12, color = C.Muted, wrap = true })
		local _ = ctx
	end,
}

return Panel
