-- Gameplay HUD: stats plate, meters, dock, objective, arts bar and a toast.
return function()
	__client()
	local Controllers = game.StarterPlayer.StarterPlayerScripts.Controllers
	local list = { "HUDController", "NotificationController", "SpellController", "GuideController", "KunaiController", "PartyController", "PartyFramesController" }
	for _, name in list do
		local ok, err = pcall(function()
			__require(Controllers[name]).Init()
		end)
		if not ok then
			print("[scene] " .. name .. " Init failed: " .. tostring(err))
		end
	end
	for _, name in list do
		local ok, err = pcall(function()
			__require(Controllers[name]).Start()
		end)
		if not ok then
			print("[scene] " .. name .. " Start failed: " .. tostring(err))
		end
	end
	__fire("PartyEvent", { inParty = true, leader = 2, members = { { userId = 1, name = "Wanderer" }, { userId = 2, name = "Kaito" }, { userId = 3, name = "Mirelle" } }, invites = {} })
	__openPanel("Spirits")
	__require(Controllers.UIController).Close()
	__flushDelays(3)
	__freezeDelays = true
	pcall(function()
		local N = __require(Controllers.NotificationController)
		N.Show("Info", "Fusion complete: Reed Fox (Rare)")
		N.Show("LevelUp", "Level 23!")
	end)
end
