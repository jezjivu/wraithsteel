--!strict
-- MapService: generates Ashen Valley, the first realm (World/ValleyBuilder, laid out in
-- MapConfig) when the place has no hand-built map. Skipped entirely if Workspace.World exists
-- or Workspace has attribute UseStudioMap = true (then EnemySpawns/BossArenas come from Studio).
--
-- API:
--   MapService.Build()   -- also callable in edit mode through ServerScriptService.EditTools

local ValleyBuilder = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("ValleyBuilder"))

local MapService = { Name = "MapService", Priority = 27 }

function MapService.Build()
	if workspace:FindFirstChild("World") then
		return
	end
	local ok, err = pcall(function()
		ValleyBuilder.Build(workspace)
	end)
	if not ok then
		warn("[MapService] map generation failed:", err)
	end
end

function MapService.Init() end

function MapService.Start()
	if workspace:GetAttribute("UseStudioMap") == true or workspace:FindFirstChild("World") then
		return
	end
	MapService.Build()
	if game:GetService("RunService"):IsStudio() then
		print("[Wraithsteel] Tip: to see and edit this world without pressing Play, stop the game, open View -> Command Bar and run:  require(game.ServerScriptService.EditTools).BuildWorld()  then File -> Save.")
	end
end

return MapService
