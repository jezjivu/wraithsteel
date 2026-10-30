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

GuideConfig.Controls = {
	"Left click - Strike (combo)",
	"R - Heavy attack",
	"F - Parry (perfect timing reflects posture)",
	"Q - Dodge (dash, avoids red ! attacks)",
	"1 / 2 - Skills      G - Ultimate",
	"Tab - Lock on to an enemy",
	"E - Use stations      H - Toggle this card",
}

return GuideConfig
