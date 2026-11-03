--!strict
-- SagaConfig: the story. NPCs you can talk to, and the main questline that runs through all
-- four realms (Ashen Valley -> Neon Verge -> Aeloria -> Ironcrow Keep). All characters and text
-- are original.
--
-- Positions: {x, z} local to the NPC's realm (RealmConfig). Ashen Valley NPCs with hub = true
-- are relative to the hub center instead.
-- Quest steps:
--   Kill  { enemies = {id...}, count }   any listed enemy you help defeat counts
--   Boss  { bossId }
--   Reach { realm, at, radius }          walk there
--   Talk  { npc }                        speak to that NPC
-- After the last step you return to the giver to finish the quest.

local EnemyConfig = require(script.Parent.EnemyConfig)

export type NpcDef = {
	id: string,
	name: string,
	title: string,
	realm: string,
	at: { number },
	hub: boolean?,
	facing: number?, -- degrees
	look: EnemyConfig.RigLook,
	chatter: { string }, -- lines when they have nothing for you
}

export type StepDef = {
	kind: "Kill" | "Boss" | "Reach" | "Talk",
	text: string, -- objective shown on screen
	enemies: { string }?,
	count: number?,
	bossId: string?,
	realm: string?,
	at: { number }?,
	radius: number?,
	npc: string?,
	lines: { string }?, -- Talk step: what that NPC says
}

export type QuestDef = {
	id: string,
	title: string,
	realm: string,
	giver: string,
	intro: { string },
	steps: { StepDef },
	outro: { string },
	rewards: { ember: number, xp: number, jade: number },
}

local SagaConfig = {}

SagaConfig.Npcs = {
	-- Ashen Valley ---------------------------------------------------------------------------
	{
		id = "shirane", name = "Elder Shirane", title = "Keeper of the Cracked Bell", realm = "japan", hub = true, at = { -10, -26 }, facing = 180,
		look = { skin = { 220, 190, 160 }, body = { 90, 60, 110 }, legs = { 60, 45, 70 }, headwear = "Hair", accent = { 230, 230, 230 }, outfit = "Noble", face = "Calm", scale = 1 },
		chatter = { "The bell still hums at night. Listen, and you will hear it counting.", "Nine gates. One bell. And you, carrying its echo." },
	},
	{
		id = "oto", name = "Gravekeeper Oto", title = "Lantern-tender", realm = "japan", at = { -445, -275 }, facing = 90,
		look = { skin = { 200, 175, 150 }, body = { 60, 60, 55 }, legs = { 45, 45, 40 }, headwear = "Hood", accent = { 80, 75, 65 }, glow = { 255, 190, 90 }, outfit = "Monk", face = "Calm", scale = 1 },
		chatter = { "The dead keep their lanterns lit. I just make sure they stay where they are." },
	},
	{
		id = "sabaki", name = "Sabaki", title = "Ronin of the Ashen Village", realm = "japan", at = { -340, -720 }, facing = 200,
		look = { skin = { 210, 180, 150 }, body = { 50, 40, 40 }, legs = { 35, 30, 30 }, headwear = "Kasa", accent = { 160, 40, 40 }, weapon = "dao_rustcutter", outfit = "Ronin", face = "Calm", scale = 1 },
		chatter = { "I owe a debt to a woman with a crane on her sleeve. One day I'll pay it in steel." },
	},
	{
		id = "hana", name = "Hana", title = "Noodle seller", realm = "japan", hub = true, at = { 22, -30 }, facing = 200,
		look = { skin = { 230, 200, 175 }, body = { 200, 80, 80 }, legs = { 60, 50, 50 }, headwear = "Hair", accent = { 240, 200, 120 }, outfit = "Ronin", face = "Calm", scale = 0.95 },
		chatter = { "Broth's warm, prices are fair, and I don't ask where you got the rust on your boots.", "They say the gate by the plaza glows blue now. Spooky." },
	},
	-- Neon Verge -----------------------------------------------------------------------------
	{
		id = "juno", name = "Juno-7", title = "Fixer of Circuit Square", realm = "neon", at = { -14, 22 }, facing = 160,
		look = { skin = { 190, 160, 140 }, body = { 40, 30, 60 }, legs = { 25, 25, 35 }, headwear = "Visor", accent = { 60, 230, 255 }, glow = { 60, 230, 255 }, outfit = "Cyber", face = "Calm", scale = 1 },
		chatter = { "Everything has a price in the Verge. Even silence. Especially silence.", "You came through a bell-gate? Cute. Don't tell the Spire." },
	},
	{
		id = "pell", name = "Pell", title = "Rail mechanic", realm = "neon", at = { 110, 80 }, facing = 90,
		look = { skin = { 160, 120, 100 }, body = { 200, 150, 40 }, legs = { 60, 60, 70 }, headwear = "Helm", accent = { 90, 90, 100 }, outfit = "Cyber", face = "Calm", scale = 1.05 },
		chatter = { "Mag-rails don't sleep. Neither do I. Coincidence? Absolutely not." },
	},
	{
		id = "kiri", name = "Kiri", title = "Street hacker", realm = "neon", at = { -130, 70 }, facing = 0,
		look = { skin = { 220, 195, 175 }, body = { 255, 60, 200 }, legs = { 30, 30, 40 }, headwear = "Hair", accent = { 60, 230, 255 }, outfit = "Cyber", face = "Calm", scale = 0.95 },
		chatter = { "Drones run on bell-frequency firmware. Funny, right? No? Okay.", "Kagura-9 used to protect this city. Now she just protects the Spire." },
	},
	-- Aeloria ----------------------------------------------------------------------------------
	{
		id = "ithea", name = "Oracle Ithea", title = "Voice of the Three Flames", realm = "greek", at = { 0, -28 }, facing = 0,
		look = { skin = { 225, 200, 175 }, body = { 245, 240, 230 }, legs = { 230, 225, 215 }, headwear = "Laurel", accent = { 200, 170, 90 }, glow = { 255, 215, 120 }, outfit = "Robe", face = "Calm", scale = 1 },
		chatter = { "I saw you before you arrived. You were taller in the vision.", "The sun here is not a star. It is a prisoner. Remember that." },
	},
	{
		id = "dorian", name = "Captain Dorian", title = "Last of the Harbor Guard", realm = "greek", at = { -120, -10 }, facing = 90,
		look = { skin = { 210, 170, 130 }, body = { 170, 40, 35 }, legs = { 180, 120, 60 }, headwear = "Crest", accent = { 40, 40, 140 }, weapon = "spear_reedline", outfit = "Hoplite", face = "Calm", scale = 1.05 },
		chatter = { "My men marched into the olive groves. Their armor marched back out. Without them." },
	},
	{
		id = "lysander", name = "Lysander", title = "Philosopher (unpaid)", realm = "greek", at = { 30, 26 }, facing = 200,
		look = { skin = { 215, 185, 155 }, body = { 220, 210, 190 }, legs = { 200, 190, 170 }, headwear = "Hair", accent = { 120, 110, 100 }, outfit = "Robe", face = "Calm", scale = 1 },
		chatter = { "If a bell cracks and no one hears it, does the world still end? I have a pamphlet.", "The statues argue at night. I've been taking notes." },
	},
	-- Ironcrow Keep ---------------------------------------------------------------------------
	{
		id = "hanabusa", name = "Hanabusa", title = "Deserter of the Ironcrow", realm = "keep", at = { 14, 300 }, facing = 200,
		look = { skin = { 200, 170, 145 }, body = { 70, 60, 55 }, legs = { 45, 40, 38 }, headwear = "Kasa", accent = { 150, 40, 40 }, weapon = "spear_crimson_tassel", outfit = "Ronin", face = "Calm", scale = 1 },
		chatter = { "I carried the regent's banner for nine years. Then I saw what she did with the embers.", "The bridge crows have eyes. Real ones. Don't ask how I know." },
	},
} :: { NpcDef }

-- Oracle shrines in Aeloria (local) - must match World/AeloriaBuilder.ShrinePoints.
local SHRINES = { { -250, 60 }, { 230, 110 }, { 220, -170 } }

SagaConfig.Quests = {
	-- Ashen Valley ---------------------------------------------------------------------------
	{
		id = "ashes", title = "Ashes of the Bell", realm = "japan", giver = "shirane",
		intro = {
			"So the bell found you. It always finds someone, when it cracks.",
			"Rustbound bandits pick over the valley like crows. They grow bold on the Bamboo Path.",
			"Drive them off. Learn to read their blades - when the steel flashes, meet it with yours.",
		},
		steps = { { kind = "Kill", enemies = { "rustbound_bandit" }, count = 5, text = "Defeat Rustbound Bandits on the Bamboo Path" } },
		outro = { "Good. Your parries ring true. The bell heard that too.", "Gravekeeper Oto has been asking for help. Find him among the lanterns." },
		rewards = { ember = 120, xp = 150, jade = 5 },
	},
	{
		id = "lantern_wake", title = "Lantern Wake", realm = "japan", giver = "oto",
		intro = {
			"The dead are restless since the bell cracked. Some of them got up and kept their lanterns.",
			"Put the Lantern Ghouls back to rest. Careful - when they glow red and reach for you, do not block. Dash.",
		},
		steps = {
			{ kind = "Kill", enemies = { "lantern_ghoul" }, count = 4, text = "Lay Lantern Ghouls to rest" },
			{ kind = "Reach", realm = "japan", at = { 420, -360 }, radius = 45, text = "Cross the river at Red Maple Gorge" },
		},
		outro = { "The temple was quiet? Good. Quiet is rare now.", "A ronin in the Ashen Village has been staring at the road for days. He might need a second blade." },
		rewards = { ember = 180, xp = 220, jade = 5 },
	},
	{
		id = "duelists_debt", title = "The Duelist's Debt", realm = "japan", giver = "sabaki",
		intro = {
			"You fight well. Then fight her students first: the Ashen Duelists. They deflect everything. Break their posture, not their skin.",
			"Then, if you still stand, put down Gravelord Ishiki in the Lantern Graveyard. He buried my brothers alive.",
		},
		steps = {
			{ kind = "Kill", enemies = { "ashen_duelist" }, count = 3, text = "Defeat Ashen Duelists" },
			{ kind = "Kill", enemies = { "gravelord" }, count = 1, text = "Defeat Gravelord Ishiki (Lantern Graveyard)" },
		},
		outro = { "Ishiki is dust? ...Then my debt is paid. Thank you, bell-bearer.", "Elder Shirane will want to hear of this. The Warden stirs." },
		rewards = { ember = 300, xp = 350, jade = 10 },
	},
	{
		id = "warden", title = "The Bell's Guardians", realm = "japan", giver = "shirane",
		intro = {
			"Four guardians hold the valley now that the bell is cracked. Two of them stand between you and the high gate.",
			"The Crimson Oni Captain prowls the Ashen Village. Masked Kurogiri watches the temple. Break them both.",
			"Then climb to the Gate of the Cracked Bell and see what it shows you.",
		},
		steps = {
			{ kind = "Kill", enemies = { "oni_captain" }, count = 1, text = "Defeat the Crimson Oni Captain (Ashen Village)" },
			{ kind = "Kill", enemies = { "masked_retainer" }, count = 1, text = "Defeat Masked Retainer Kurogiri (Temple)" },
			{ kind = "Reach", realm = "japan", at = { 0, -1050 }, radius = 50, text = "Climb to the Gate of the Cracked Bell" },
		},
		outro = {
			"The first gate is open. Can you feel it? East of the plaza, the portal hums blue.",
			"Beyond it lies a city that never stopped ringing. Find a fixer called Juno-7. Go.",
		},
		rewards = { ember = 500, xp = 600, jade = 20 },
	},
	-- Neon Verge -----------------------------------------------------------------------------
	{
		id = "static_line", title = "Static on the Line", realm = "neon", giver = "juno",
		intro = {
			"A bell-bearer. In my square. Okay, new plan: you work for me now.",
			"The Lantern Wire Market's crawling with Chrome Ronin and drones. They're jamming my feeds.",
			"Clear them. Ronin deflect like it's a religion - pressure their posture. Drones shoot - guard or dash through.",
		},
		steps = {
			{ kind = "Reach", realm = "neon", at = { -150, 40 }, radius = 30, text = "Go to the Lantern Wire Market" },
			{ kind = "Kill", enemies = { "chrome_ronin", "drone_sentry" }, count = 6, text = "Clear Chrome Ronin and Drone Sentries" },
		},
		outro = { "Feeds are clean. You're expensive to replace, so don't die.", "Pell at the Mag-Rail Yards owes me. Collect for me, would you?" },
		rewards = { ember = 700, xp = 800, jade = 10 },
	},
	{
		id = "rail_rats", title = "Rail Rats", realm = "neon", giver = "pell",
		intro = {
			"Juno sent you? Then I'm paying in labor. Rail Brutes broke into my yard.",
			"They stomp - the ground shakes in a ring. Jump it. If one reaches for you, dash away.",
		},
		steps = {
			{ kind = "Kill", enemies = { "rail_brute" }, count = 2, text = "Scrap the Rail Brutes" },
			{ kind = "Reach", realm = "neon", at = { 0, -150 }, radius = 30, text = "Scout the Skyline Overpass" },
		},
		outro = { "Overpass clear? Then the Spire's next. Tell Juno the debt is paid. Mostly." },
		rewards = { ember = 800, xp = 900, jade = 10 },
	},
	{
		id = "static_spire", title = "The Static Spire", realm = "neon", giver = "juno",
		intro = {
			"Kagura-9 holds the second gate at the Spire. She's faster than you. She's better than you.",
			"But she throws plasma, and plasma can be thrown back. Make her eat her own light.",
		},
		steps = { { kind = "Boss", bossId = "kagura_9", text = "Defeat Kagura-9 at the Static Spire" } },
		outro = {
			"...You did it. The Spire's dark. The city's quiet for the first time in years.",
			"A new gate opened by the square. Gold light. Smells like olives and old arguments. Go see who's on the other side.",
		},
		rewards = { ember = 1500, xp = 1600, jade = 30 },
	},
	-- Aeloria ----------------------------------------------------------------------------------
	{
		id = "three_flames", title = "The Oracle's Three Flames", realm = "greek", giver = "ithea",
		intro = {
			"You carry the bell's echo. The flames told me you would. They tell me a great many things.",
			"Light your echo at each of the three cliff shrines. Then the flames will speak to you as well.",
		},
		steps = {
			{ kind = "Reach", realm = "greek", at = SHRINES[1], radius = 12, text = "Visit the western cliff shrine" },
			{ kind = "Reach", realm = "greek", at = SHRINES[2], radius = 12, text = "Visit the northern cliff shrine" },
			{ kind = "Reach", realm = "greek", at = SHRINES[3], radius = 12, text = "Visit the eastern cliff shrine" },
		},
		outro = { "The flames burn brighter. They say: the sun is chained beneath the temple, and its jailer has forgotten why.", "Captain Dorian guards the terraces. He needs a sword more than a prophecy." },
		rewards = { ember = 1200, xp = 1300, jade = 10 },
	},
	{
		id = "bronze_song", title = "Bronze and Song", realm = "greek", giver = "dorian",
		intro = {
			"The Archon's bronze soldiers hold the terraces, and sirens sing arrows from the rocks.",
			"Hoplites charge with the spear - dash INTO the charge. Sirens' slow notes can be deflected back. Statues... just don't stand still.",
		},
		steps = {
			{ kind = "Kill", enemies = { "bronze_hoplite" }, count = 4, text = "Break the Bronze Hoplites" },
			{ kind = "Kill", enemies = { "siren_archer" }, count = 3, text = "Silence the Siren Archers" },
			{ kind = "Kill", enemies = { "marble_sentinel" }, count = 1, text = "Topple a Marble Sentinel" },
		},
		outro = { "The terraces are ours again. My men can rest. Go to the Oracle - she's been staring at the temple all day." },
		rewards = { ember = 1800, xp = 2000, jade = 15 },
	},
	{
		id = "noon", title = "Noon of the Archon", realm = "greek", giver = "ithea",
		intro = {
			"Helion, the Sun-Archon. He chained the sun to keep the island warm. Then he forgot how to let go.",
			"His captive sun will be hurled at you. Return it. Every gate you've opened has led here.",
		},
		steps = { { kind = "Boss", bossId = "archon_helion", text = "Defeat Helion in the Temple of the Sun-Archon" } },
		outro = {
			"The sun is free. Look - it's setting. It hasn't set in four hundred years.",
			"Three gates open, bell-bearer. Six remain. The bell is still counting.",
			"West of the agora a fourth gate smokes like a forge. Beyond it: a castle that tried to keep the toll out.",
		},
		rewards = { ember = 3000, xp = 3500, jade = 50 },
	},
	-- Ironcrow Keep ---------------------------------------------------------------------------
	{
		id = "iron_gate", title = "The Iron Gate", realm = "keep", giver = "hanabusa",
		intro = {
			"You came through the smoke gate? Then you are either brave or lost. Both are useful here.",
			"The garrison still marches as if the regent lived. Footmen guard behind their shields - break the guard, then strike.",
			"Tessai holds the bailey. He was my captain. He does not remember me. Free him.",
		},
		steps = {
			{ kind = "Reach", realm = "keep", at = { 0, 160 }, radius = 30, text = "Pass under the Ironcrow Gatehouse" },
			{ kind = "Kill", enemies = { "keep_footman" }, count = 4, text = "Break the Ironcrow Footmen" },
			{ kind = "Boss", bossId = "tessai", text = "Defeat Tessai, the Iron Ward (Outer Bailey)" },
		},
		outro = { "...He thanked you? Before the end? Then some of him was still there.", "The inner keep is past the Crow Bridge. Clear the walls first, or the archers will pin you on it." },
		rewards = { ember = 3200, xp = 3800, jade = 20 },
	},
	{
		id = "crows_over_ash", title = "Crows over Ash", realm = "keep", giver = "hanabusa",
		intro = {
			"Two ways to the bridge: the High Ramparts or the Chapel of Ash. The Castellan walks the ramparts. He rises twice.",
			"Crow Knights deflect like duelists - press them until their posture cracks. Ember arrows can be sent back.",
		},
		steps = {
			{ kind = "Kill", enemies = { "crow_knight" }, count = 3, text = "Defeat Crow Knights" },
			{ kind = "Kill", enemies = { "ember_archer" }, count = 2, text = "Silence the Ember Archers" },
			{ kind = "Kill", enemies = { "castellan" }, count = 1, text = "Defeat Castellan Gorou (High Ramparts)" },
			{ kind = "Reach", realm = "keep", at = { 0, -150 }, radius = 20, text = "Cross the Crow Bridge" },
		},
		outro = { "You crossed. Good. The regent will have felt it - every stone here reports to her." },
		rewards = { ember = 3800, xp = 4200, jade = 20 },
	},
	{
		id = "ember_throne", title = "The Ember Throne", realm = "keep", giver = "hanabusa",
		intro = {
			"Ashrei crowned herself with the bell's embers. She fights like fire: fast, then everywhere.",
			"Her crescents can be turned back. When she raises the crown, get away from her - or deflect the ring.",
		},
		steps = { { kind = "Boss", bossId = "ashrei", text = "Defeat Ashrei, the Ember-Crowned Regent (Inner Keep)" } },
		outro = {
			"The embers are out. The keep is just stone again. Stone I can live with.",
			"Four gates open, bell-bearer. Five remain. The bell is still counting. (To be continued...)",
		},
		rewards = { ember = 6000, xp = 6500, jade = 60 },
	},
} :: { QuestDef }

function SagaConfig.Npc(id: string): NpcDef?
	for _, n in SagaConfig.Npcs do
		if n.id == id then
			return n
		end
	end
	return nil
end

return SagaConfig
