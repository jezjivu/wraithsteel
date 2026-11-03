--!strict
-- Skills panel: the skill tree (SkillConfig). Three paths side by side, five tiers each; click a
-- node to see it, then Learn. The server re-checks everything (LearnSkill / ResetSkills).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillConfig = require(Config:WaitForChild("SkillConfig"))
local SpellConfig = require(Config:WaitForChild("SpellConfig"))
local MapConfig = require(Config:WaitForChild("MapConfig"))
local SkillLogic = require(Shared:WaitForChild("SkillLogic"))
local Net = require(Shared:WaitForChild("Net"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local Controllers = UI.Parent:WaitForChild("Controllers")
local DataController = require(Controllers:WaitForChild("DataController"))

local C = Kit.Colors

local COL_W, NODE, ROW_H, TOP = 236, 62, 104, 54
local selected: string? = nil

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function center(pathIndex: number, def: SkillConfig.SkillDef): Vector2
	return Vector2.new((pathIndex - 1) * COL_W + COL_W / 2 + def.col * 74, TOP + (def.tier - 1) * ROW_H + NODE / 2)
end

local function line(parent: Instance, a: Vector2, b: Vector2, color: Color3, lit: boolean)
	local d = b - a
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Size = UDim2.fromOffset(d.Magnitude, if lit then 4 else 2)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
	f.BackgroundColor3 = color
	f.BackgroundTransparency = if lit then 0.05 else 0.6
	f.BorderSizePixel = 0
	f.ZIndex = 1
	f.Parent = parent
end

local function pathIndexOf(pathId: string): number
	for i, p in SkillConfig.Paths do
		if p.id == pathId then
			return i
		end
	end
	return 1
end

local Panel: PanelTypes.Panel = {
	Title = "Skill Tree",
	WatchKeys = { "skills", "level", "relics" },
	Render = function(body, ctx)
		local level = DataController.Get("level") or 1
		local skills: { [string]: number } = DataController.Get("skills") or {}
		local relics = SkillLogic.Count(DataController.Get("relics"))
		local points = SkillLogic.Available(level, skills, relics)

		local head = Kit.Row(body, 44)
		head.BackgroundColor3 = C.Ink
		head.LayoutOrder = 1
		Kit.Label(head, string.format("<b>%d</b> skill point%s to spend", points, if points == 1 then "" else "s"), { size = 18, color = if points > 0 then C.Gold else C.Muted, width = 300 })
		Kit.Label(head, string.format("1 per level, +1 every 5 levels, +1 per Ashen Relic (%d/%d found)", relics, #MapConfig.Relics), { size = 12, color = C.Muted, width = 270, wrap = true })
		Kit.Button(head, "Reset", C.Bad, function()
			local ok, msg = Net.Client.Invoke("ResetSkills")
			ctx.notify(msg or "", ok ~= true)
		end, 90)

		-- The tree canvas.
		local tree = Instance.new("Frame")
		tree.Name = "Tree"
		tree.Size = UDim2.new(1, -8, 0, TOP + 5 * ROW_H)
		tree.BackgroundTransparency = 1
		tree.LayoutOrder = 2
		tree.Parent = body
		local canvas = Instance.new("Frame")
		canvas.AnchorPoint = Vector2.new(0.5, 0)
		canvas.Position = UDim2.fromScale(0.5, 0)
		canvas.Size = UDim2.fromOffset(COL_W * #SkillConfig.Paths, TOP + 5 * ROW_H)
		canvas.BackgroundTransparency = 1
		canvas.Parent = tree

		for pi, path in SkillConfig.Paths do
			local color = rgb(path.color)
			-- Column backdrop + title.
			local col = Instance.new("Frame")
			col.Position = UDim2.fromOffset((pi - 1) * COL_W + 6, 0)
			col.Size = UDim2.fromOffset(COL_W - 12, TOP + 5 * ROW_H - 6)
			col.BackgroundColor3 = color
			col.BackgroundTransparency = 0.9
			col.BorderSizePixel = 0
			col.Parent = canvas
			local cc = Instance.new("UICorner")
			cc.CornerRadius = UDim.new(0, 10)
			cc.Parent = col
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Position = UDim2.fromOffset(0, 4)
			t.Size = UDim2.new(1, 0, 0, 22)
			t.Font = Enum.Font.Antique
			t.TextSize = 22
			t.TextColor3 = color
			t.Text = path.name
			t.Parent = col
			local sub = t:Clone()
			sub.Position = UDim2.fromOffset(0, 26)
			sub.Size = UDim2.new(1, 0, 0, 16)
			sub.Font = Enum.Font.Gotham
			sub.TextSize = 11
			sub.TextColor3 = C.Muted
			sub.Text = path.text
			sub.Parent = col

			local ids = SkillConfig.ForPath(path.id)
			-- Links first (under the nodes).
			for _, id in ids do
				local def = SkillConfig.Skills[id]
				for _, r in def.requires or ({} :: { string }) do
					local rd = SkillConfig.Skills[r]
					if rd then
						line(canvas, center(pi, rd), center(pi, def), color, (skills[r] or 0) > 0 and (skills[id] or 0) > 0)
					end
				end
			end
			for _, id in ids do
				local def = SkillConfig.Skills[id]
				local rank = skills[id] or 0
				local canLearn = SkillLogic.CanLearn(skills, level, id, relics)
				local reach = SkillLogic.Reachable(skills, id)
				local p = center(pi, def)
				local b = Instance.new("TextButton")
				b.AnchorPoint = Vector2.new(0.5, 0.5)
				b.Position = UDim2.fromOffset(p.X, p.Y)
				b.Size = UDim2.fromOffset(NODE, NODE)
				b.Rotation = 45
				b.AutoButtonColor = true
				b.Text = ""
				b.ZIndex = 3
				b.BackgroundColor3 = if rank > 0 then color elseif reach then C.Row else C.Ink
				b.Parent = canvas
				local bc = Instance.new("UICorner")
				bc.CornerRadius = UDim.new(0, 8)
				bc.Parent = b
				local st = Instance.new("UIStroke")
				st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				st.Thickness = if selected == id then 4 elseif canLearn then 3 else 1.5
				st.Color = if selected == id then Color3.new(1, 1, 1) elseif canLearn then C.Gold else color
				st.Transparency = if rank > 0 or canLearn or selected == id then 0 else 0.5
				st.Parent = b
				-- Label (unrotated, on top of the diamond).
				local lab = Instance.new("TextLabel")
				lab.AnchorPoint = Vector2.new(0.5, 0.5)
				lab.Position = UDim2.fromOffset(p.X, p.Y - 2)
				lab.Size = UDim2.fromOffset(NODE + 30, 30)
				lab.BackgroundTransparency = 1
				lab.Font = Enum.Font.GothamBold
				lab.TextSize = 11
				lab.TextWrapped = true
				lab.TextColor3 = if rank > 0 then C.Ink elseif reach then C.Text else C.Muted
				lab.Text = if def.art then "✦ " .. def.name else def.name
				lab.ZIndex = 4
				lab.Parent = canvas
				local pips = Instance.new("TextLabel")
				pips.AnchorPoint = Vector2.new(0.5, 0)
				pips.Position = UDim2.fromOffset(p.X, p.Y + NODE * 0.72)
				pips.Size = UDim2.fromOffset(80, 14)
				pips.BackgroundTransparency = 1
				pips.Font = Enum.Font.GothamBold
				pips.TextSize = 12
				pips.TextColor3 = if rank > 0 then color else C.Muted
				pips.Text = string.rep("●", rank) .. string.rep("○", def.maxRank - rank)
				pips.ZIndex = 4
				pips.Parent = canvas
				b.Activated:Connect(function()
					selected = id
					ctx.refresh()
				end)
			end
		end

		-- Details of the selected skill.
		local id = selected
		local def = if id then SkillConfig.Skills[id] else nil
		local card = Kit.Row(body, 92)
		card.LayoutOrder = 3
		if id and def then
			local rank = skills[id] or 0
			local info = Kit.Stack(card, -150)
			Kit.Label(info, string.format("%s  <font color=\"#a09890\">%d/%d</font>", def.name, rank, def.maxRank), { bold = true, size = 18, color = rgb(SkillConfig.Paths[pathIndexOf(def.path)].color) })
			Kit.Label(info, def.text, { size = 14, wrap = true })
			local extra = "Cost " .. (def.cost or 1) .. " point" .. (if (def.cost or 1) > 1 then "s" else "") .. " per rank"
			if def.minLevel then
				extra ..= " · needs level " .. def.minLevel
			end
			if def.art and SpellConfig.Spells[def.art] then
				local sp = SpellConfig.Spells[def.art]
				extra ..= string.format(" · art: %d Qi, %.0fs cooldown", sp.qi, sp.cooldown)
			end
			Kit.Label(info, extra, { size = 12, color = C.Muted })
			local ok, why = SkillLogic.CanLearn(skills, level, id, relics)
			Kit.Button(card, if ok then "Learn" else (why or "Locked"), if ok then C.Good else C.Row, function()
				local okS, msg = Net.Client.Invoke("LearnSkill", id)
				ctx.notify(msg or "", okS ~= true)
			end, 130)
		else
			Kit.Label(card, "Pick a skill on the tree. Gold outline = you can learn it now. ✦ = unlocks a new blade art.", { size = 14, color = C.Muted, wrap = true })
		end
	end,
}

return Panel
