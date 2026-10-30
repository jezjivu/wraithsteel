--!strict
-- EditTools: build the generated world IN EDIT MODE so you can see and change it in Studio.
--
-- In Roblox Studio open View -> Command Bar, paste this line and press Enter:
--
--     require(game.ServerScriptService.EditTools).BuildWorld()
--
-- It creates Workspace.World (terrain + map), Workspace.Hub (town + shops), EnemySpawns,
-- BossArenas and the lighting. Save the place afterwards (File -> Save). On Play the game
-- uses what you saved instead of generating it again, so every change you make sticks.
-- Undo works (Ctrl+Z). To start over:
--
--     require(game.ServerScriptService.EditTools).ClearWorld()
--
-- Only generated things are removed (they carry the attribute Generated = true).

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Services = script.Parent:WaitForChild("Services")

local EditTools = {}

local GENERATED_FOLDERS = { "World", "Hub", "EnemySpawns", "BossArenas" }

function EditTools.ClearWorld()
	local recording = ChangeHistoryService:TryBeginRecording("Clear Wraithsteel world")
	for _, name in GENERATED_FOLDERS do
		local inst = workspace:FindFirstChild(name)
		if inst and (inst:GetAttribute("Generated") == true or workspace:GetAttribute("WraithsteelGenerated") == true) then
			inst:Destroy()
		end
	end
	if workspace:GetAttribute("WraithsteelGenerated") == true then
		workspace.Terrain:Clear()
		workspace:SetAttribute("WraithsteelGenerated", nil)
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	print("[EditTools] Generated world removed.")
end

function EditTools.BuildWorld()
	if workspace:FindFirstChild("World") or workspace:FindFirstChild("Hub") then
		warn("[EditTools] A World/Hub already exists. Run ClearWorld() first to rebuild it.")
		return
	end
	local recording = ChangeHistoryService:TryBeginRecording("Build Wraithsteel world")
	local AmbienceService = require(Services:WaitForChild("AmbienceService")) :: any
	local MapService = require(Services:WaitForChild("MapService")) :: any
	local HubService = require(Services:WaitForChild("HubService")) :: any
	AmbienceService.Apply()
	MapService.Build()
	HubService.Build()
	workspace:SetAttribute("WraithsteelGenerated", true)
	-- The SpawnLocation lives in the hub; the old test baseplate is no longer needed for spawning.
	local folder = workspace:FindFirstChild("EnemySpawns")
	if folder then
		folder:SetAttribute("Generated", true)
	end
	local arenas = workspace:FindFirstChild("BossArenas")
	if arenas then
		arenas:SetAttribute("Generated", true)
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	print("[EditTools] World built. Change anything you like, then File -> Save. Press Play to test.")
end

return EditTools
