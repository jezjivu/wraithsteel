--!strict
-- ZoneService: tracks which named zone each player is in (ZoneConfig circles, or Studio Parts in
-- Workspace.Zones), publishes it as the player attribute "Zone" / "ZoneName" (the client shows a
-- banner) and fires ZoneChanged. Chapter gating of zones is reported via CanEnter for gates.
-- TODO(Studio/Agent D): physical gates between chapter zones that call ZoneService.CanEnter.
--
-- API:
--   ZoneService.GetZone(player) -> string?
--   ZoneService.CanEnter(player, zoneId) -> boolean
--   ZoneService.ZoneChanged: Signal(player, zoneId, previousZoneId?)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Signal = require(Shared:WaitForChild("Signal"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))

local DataService = require(script.Parent.DataService)

local ZoneService = { Name = "ZoneService", Priority = 55, ZoneChanged = Signal.new() }

type Zone = { id: string, name: string, subtitle: string?, chapter: number }

local current: { [Player]: string } = {}

local function studioZones(): { BasePart }
	local folder = workspace:FindFirstChild(ZoneConfig.FolderName)
	local out = {}
	if folder then
		for _, p in folder:GetChildren() do
			if p:IsA("BasePart") and type(p:GetAttribute("ZoneId")) == "string" then
				table.insert(out, p)
			end
		end
	end
	return out
end

local function zoneAt(pos: Vector3): Zone
	for _, part in studioZones() do
		local rel = part.CFrame:PointToObjectSpace(pos)
		local half = part.Size / 2
		if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
			return {
				id = part:GetAttribute("ZoneId") :: string,
				name = (part:GetAttribute("ZoneName") :: string?) or part.Name,
				subtitle = part:GetAttribute("ZoneSubtitle") :: string?,
				chapter = tonumber(part:GetAttribute("Chapter")) or 0,
			}
		end
	end
	for _, z in ZoneConfig.Zones do
		local dx, dz = pos.X - z.center[1], pos.Z - z.center[2]
		if dx * dx + dz * dz <= z.radius * z.radius then
			return z
		end
	end
	return ZoneConfig.Fallback
end

function ZoneService.GetZone(player: Player): string?
	return current[player]
end

function ZoneService.CanEnter(player: Player, zoneId: string): boolean
	local data = DataService.GetData(player)
	if data == nil then
		return false
	end
	for _, z in ZoneConfig.Zones do
		if z.id == zoneId then
			return data.chapter >= z.chapter
		end
	end
	for _, part in studioZones() do
		if part:GetAttribute("ZoneId") == zoneId then
			return data.chapter >= (tonumber(part:GetAttribute("Chapter")) or 0)
		end
	end
	return true
end

function ZoneService.Init() end

function ZoneService.Start()
	Players.PlayerRemoving:Connect(function(player)
		current[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(ZoneConfig.CheckInterval)
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local z = zoneAt(root.Position)
					local prev = current[player]
					if z.id ~= prev then
						current[player] = z.id
						player:SetAttribute("ZoneSubtitle", z.subtitle or "")
						player:SetAttribute("ZoneName", z.name)
						player:SetAttribute("Zone", z.id)
						ZoneService.ZoneChanged:Fire(player, z.id, prev)
					end
				end
			end
		end
	end)
end

return ZoneService
