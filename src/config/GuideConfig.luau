--!strict
-- GuideConfig: the new-player objective chain and controls card (GuideController).
-- Each step is shown until its condition (evaluated on the client from profile data) is met.

local GuideConfig = {}

GuideConfig.LevelGoal = 2 -- "fight in the Wilds" step lasts until this level
GuideConfig.ControlsCardSeconds = 25 -- controls card auto-hides after this (H toggles it)

GuideConfig.Text = {
	openLantern = "Visit the Lantern Shrine (E) and light your free Paper Lantern",
	equipSpirit = "Equip your new Spirit at the Spirit Shrine or in the Spirits menu",
	fightWilds = "Go north through the red gate and defeat enemies (reach Lv %d)",
	buyWeapon = "Earn %s Ember and buy a new weapon at the Weapon Smith",
	chapterBoss = "Defeat %s (Chapter %d)",
	allDone = "Chapter cleared! Hunt the elites, find every Ashen Relic, fuse Spirits and party up.",
}

-- Objective waypoint: beacon of light + distance label + screen-edge arrow.
GuideConfig.Waypoint = { color = { 255, 215, 120 }, beamHeight = 60, hideWithin = 14 }

GuideConfig.Controls = {
	"Click - Strike combo   R - Heavy",
	"Strike x2 then R - Finisher (launch!)",
	"Ctrl - Dash (in air too)   Ctrl then Click - Dash strike",
	"Space x2 - Double jump   Click in air - Air slam",
	"Hold F - Guard   Tap F as a hit lands - DEFLECT (+ riposte)",
	"PERFECT DEFLECT STOPS EVERYTHING - red attacks, rockets, lasers, shockwaves",
	"Red attacks also: PIERCE = dash in, SWEEP = jump, GRASP = dash away (guard can't block them)",
	"Deflected projectiles fly back. Enemies deflect you too - don't mash!",
	"Break posture, then strike - SEVERING BLOW",
	"Shift - Sprint   Tab - Lock on   Q - Spring Flask (heal)",
	"Z / X / C - Qi arts (spells)   T - Spirit Burst",
	"1 / 2 - Weapon skills   G - Ultimate   E - Use stations",
	"V - Grappling hook (aim at a gold ring on towers)",
	"Menu > Skills - spend skill points (1 per level + Ashen Relics hidden in the valley)",
	"Barred gates open from the other side - find the way around",
	"H - Toggle this card",
}

return GuideConfig
