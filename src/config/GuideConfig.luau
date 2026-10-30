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
	rustTiger = "Challenge the Rust Tiger: hold E on the rust-colored pad in the Wilds",
	chapterBoss = "Defeat %s (Chapter %d)",
	allDone = "Chapter cleared! Hunt world bosses, fuse Spirits and party up.",
}

-- Objective waypoint: beacon of light + distance label + screen-edge arrow.
GuideConfig.Waypoint = { color = { 255, 215, 120 }, beamHeight = 60, hideWithin = 14 }

GuideConfig.Controls = {
	"Click - Strike combo   R - Heavy",
	"Strike x2 then R - Finisher (launch!)",
	"Ctrl - Dash (in air too)   Ctrl then Click - Dash strike",
	"Space x2 - Double jump   Click in air - Air slam",
	"F - Parry (perfect = DEFLECT + riposte)",
	"Shift - Sprint   Tab - Lock on",
	"1 / 2 - Skills   G - Ultimate   E - Use stations",
	"H - Toggle this card",
}

return GuideConfig
