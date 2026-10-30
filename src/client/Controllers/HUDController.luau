--!strict
-- HUDController: PLACEHOLDER debug HUD (Ember, Jade, Level, Power, boss bar text) so the game
-- is playtestable before Agent D builds the real HUD in Studio.
-- TODO(Studio/Agent D): replace with the designed HUD (ScreenGui in StarterGui), keep the same
-- data sources: DataController.Changed, player attributes Power/Level, BossState remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))

local DataController = require(script.Parent.DataController)

local HUDController = { Name = "HUDController", Priority = 41 }

local stats: TextLabel? = nil
local bossBar: TextLabel? = nil

local function refresh()
	local label = stats
	if label == nil then
		return
	end
	local player = Players.LocalPlayer
	label.Text = string.format(
		"Ember %s   Jade %s   Lv %s   Power %s",
		FormatNumber.Short(DataController.Get("ember") or 0),
		FormatNumber.Short(DataController.Get("jade") or 0),
		tostring(DataController.Get("level") or 1),
		FormatNumber.Short(tonumber(player:GetAttribute("Power")) or 0)
	)
end

local function makeLabel(parent: Instance, pos: UDim2, size: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 0.4
	l.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	l.TextColor3 = Color3.fromRGB(240, 220, 180)
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.Text = ""
	l.Parent = parent
	return l
end

function HUDController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugHUD"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	stats = makeLabel(gui, UDim2.new(0, 10, 0, 10), UDim2.new(0, 380, 0, 28))
	local bar = makeLabel(gui, UDim2.new(0.3, 0, 0, 44), UDim2.new(0.4, 0, 0, 26))
	bar.Visible = false
	bossBar = bar
end

function HUDController.Start()
	DataController.Changed:Connect(refresh)
	Players.LocalPlayer:GetAttributeChangedSignal("Power"):Connect(refresh)
	Net.Client.On("BossState", function(s)
		local bar = bossBar
		if bar == nil then
			return
		end
		bar.Visible = s.state ~= "Dead"
		bar.Text = string.format("%s  HP %d%%  Posture %d%%  (phase %d)", s.bossId, math.floor(s.hpFrac * 100), math.floor(s.postureFrac * 100), s.phase)
	end)
	refresh()
end

return HUDController
