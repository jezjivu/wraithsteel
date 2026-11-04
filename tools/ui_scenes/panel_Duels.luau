-- Proving Ring (Duels) panel with an incoming challenge, plus the in-duel score pill.
return function()
	__client({ data = function(d)
		d.pvpWins = 7
		d.pvpLosses = 3
		d.pvpStreak = 3
	end })
	local Controllers = game.StarterPlayer.StarterPlayerScripts.Controllers
	local Duel = __require(Controllers.DuelController)
	Duel.Init()
	Duel.Start()
	__fire("DuelEvent", { incoming = { { userId = 2, name = "Kaito" } }, wins = 7, losses = 3, streak = 3 })
	__openPanel("Duels")
end
