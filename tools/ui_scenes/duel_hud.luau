-- In a duel: HUD + score pill + round call.
return function()
	__client()
	local Controllers = game.StarterPlayer.StarterPlayerScripts.Controllers
	for _, name in { "HUDController", "SpellController", "DuelController" } do
		local c = __require(Controllers[name])
		c.Init()
		c.Start()
	end
	__flushDelays(3)
	__freezeDelays = true
	__fire("DuelEvent", { incoming = {}, wins = 7, losses = 3, streak = 3, duel = { round = 2, phase = "Countdown", left = 3, myWins = 1, theirWins = 0, opponent = "Kaito" } })
	-- the pill text is filled every frame: run one frame
	game:GetService("RunService").Heartbeat:Fire(0.016)
end
