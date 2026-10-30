--!strict
-- ZoneService (STUB, Agent D): tracks which story zone each player is in and gates entry by
-- chapter (ChapterService.HasUnlocked). Zones are Studio-built folders named by
-- ChapterConfig.Chapters[n].zone with a "Bounds" part and "Gate" parts.
-- TODO(Studio/Agent D): build zones; implement bounds checks + gate CanCollide per player.
-- Planned API: ZoneService.GetZone(player) -> string?, ZoneService.ZoneChanged: Signal(player, zone)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local ZoneService = { Name = "ZoneService", Priority = 55, ZoneChanged = Signal.new() }

function ZoneService.GetZone(_player: Player): string?
	return nil
end

function ZoneService.Init() end
function ZoneService.Start() end

return ZoneService
