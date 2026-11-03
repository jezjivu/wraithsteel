--!strict
-- Styles panel (Dojo / menu): pick a fighting style. Shows each style's strengths.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local StyleConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("StyleConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local DataController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("DataController"))

local C = Kit.Colors

local function pct(x: number): string
	local d = math.floor((x - 1) * 100 + 0.5)
	return if d > 0 then "+" .. d .. "%" elseif d < 0 then d .. "%" else "-"
end

local Panel: PanelTypes.Panel = {
	Title = "Dojo of Nine Forms",
	WatchKeys = { "fightingStyle", "level" },
	Render = function(body, ctx)
		local current = DataController.Get("fightingStyle") or StyleConfig.Default
		local level = DataController.Get("level") or 1
		Kit.Label(body, "A style changes how every weapon fights. Switch any time.", { size = 14, color = C.Muted, wrap = true })
		for i, id in StyleConfig.Order do
			local def = StyleConfig.Styles[id]
			local color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
			local row = Kit.Row(body, 96, i % 2 == 0)
			local info = Kit.Stack(row, -150)
			Kit.Label(info, def.name, { bold = true, size = 19, color = color })
			Kit.Label(info, def.description, { size = 13, wrap = true })
			Kit.Label(info, string.format(
				"Speed %s · Damage %s · Posture %s · Knockback %s · Dash %s%s",
				pct(def.speed), pct(def.damage), pct(def.posture), pct(def.knockback), pct(def.dashDistance),
				if def.parryWindowBonus > 0 then " · Parry window +" .. math.floor(def.parryWindowBonus * 1000) .. "ms" else ""
			), { size = 12, color = C.Muted, wrap = true })
			if current == id then
				Kit.Button(row, "Active", C.Good, function() end, 120)
			elseif level < def.unlockLevel then
				Kit.Button(row, "Lv " .. def.unlockLevel, C.Row, function()
					ctx.notify("Reach level " .. def.unlockLevel .. " to learn " .. def.name, true)
				end, 120)
			else
				Kit.Button(row, "Adopt", color:Lerp(C.Ink, 0.4), function()
					local ok, msg = Net.Client.Invoke("SetFightingStyle", id)
					ctx.notify(msg or "Try again", not ok)
				end, 120)
			end
		end
	end,
}

return Panel
