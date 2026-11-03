-- Gameplay HUD with the menu, a toast and the objective tracker.
return function()
	__client()
	local Controllers = game.StarterPlayer.StarterPlayerScripts.Controllers
	for _, name in { "HUDController", "NotificationController", "SpellController", "GuideController", "KunaiController" } do
		local ok, err = pcall(function()
			local c = __require(Controllers[name])
			c.Init()
		end)
		if not ok then
			print("[scene] " .. name .. " Init failed: " .. tostring(err))
		end
	end
	__openPanel("Spirits")
	__require(Controllers.UIController).Close()
	pcall(function()
		__require(Controllers.NotificationController).Show("Info", "Fusion complete: Reed Fox (Rare)")
	end)
end
