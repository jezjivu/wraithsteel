--!strict
-- Codes panel (Code Stone / menu).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))

local C = Kit.Colors

local Panel: PanelTypes.Panel = {
	Title = "Code Stone",
	WatchKeys = {},
	Render = function(body, ctx)
		Kit.Label(body, "Enter a code carved by the bell-keepers:", { color = C.Muted })
		local row = Kit.Row(body, 52)
		local box = Instance.new("TextBox")
		box.Size = UDim2.fromOffset(260, 36)
		box.BackgroundColor3 = C.Ink
		box.TextColor3 = C.Text
		box.PlaceholderText = "CODE"
		box.PlaceholderColor3 = C.Muted
		box.Font = Enum.Font.GothamBold
		box.TextSize = 18
		box.ClearTextOnFocus = false
		box.Text = ""
		box.Parent = row
		Kit.Button(row, "Redeem", C.Accent, function()
			local text = box.Text
			if #text == 0 or #text > 64 then
				ctx.notify("Type a code first", true)
				return
			end
			local ok, msg = Net.Client.Invoke("RedeemCode", text)
			ctx.notify(msg or "Try again", not ok)
			if ok then
				box.Text = ""
			end
		end, 120)
	end,
}

return Panel
