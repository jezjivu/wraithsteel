-- ui_fixture: fake client state for UI previews (tools/render_ui.py). Builds a believable
-- mid-game profile with the real ProfileTemplate/SpiritLogic, stubs Net.Client, and feeds the
-- DataController snapshot. Scenes call __client() and then open panels / build the HUD.

__netHandlers = {}
__invokes = {}

local function profile()
	local SSS = game:GetService("ServerScriptService")
	local ProfileTemplate = __require(SSS.Logic.ProfileTemplate)
	local SpiritLogic = __require(SSS.Logic.SpiritLogic)
	local d = ProfileTemplate.New()
	d.ember = 48250
	d.jade = 340
	d.level = 23
	d.xp = 1200
	d.chapter = 1
	d.spiritStorage = 60
	local list = {
		{ "jade_qilin_cub", "Legendary", "Moonlit", 18 },
		{ "thunder_pangolin", "Epic", "Stormforged", 14 },
		{ "mist_heron", "Rare", "None", 11 },
		{ "brass_carp", "Rare", "Gilded", 9 },
		{ "reed_fox", "Uncommon", "None", 7 },
		{ "reed_fox", "Uncommon", "None", 3 },
		{ "lantern_moth", "Common", "Ashen", 5 },
		{ "ember_sparrow", "Common", "None", 2 },
	}
	for i, e in list do
		local s = SpiritLogic.Create(d, e[1], e[2], e[3], 0)
		s.level = e[4]
		if i <= 3 then
			table.insert(d.equippedSpirits, s.uid)
		end
		if i == 1 then
			s.locked = true
		end
	end
	d.freeLanterns = { paper_lantern = 1 }
	d.dailyStreak = 4
	return d
end

function __client(opts)
	opts = opts or {}
	local RS = game:GetService("ReplicatedStorage")
	local Net = __require(RS.Shared.Net)
	Net.Client.Fire = function() end
	Net.Client.On = function(name, handler)
		__netHandlers[name] = __netHandlers[name] or {}
		table.insert(__netHandlers[name], handler)
		return { Disconnect = function() end }
	end
	Net.Client.Invoke = function(name, ...)
		local f = __invokes[name]
		if type(f) == "function" then
			return f(...)
		end
		return f
	end
	local Controllers = game.StarterPlayer.StarterPlayerScripts.Controllers
	local DataController = __require(Controllers.DataController)
	DataController.Init()
	local data = profile()
	if opts.data then
		opts.data(data)
	end
	for _, h in __netHandlers.ProfileSnapshot or {} do
		h(data)
	end
	DataController.PolicyFlags = { paidRandomItemsRestricted = false, paidItemTradingAllowed = true }
	game:GetService("Players").LocalPlayer:SetAttribute("Power", 1840)
	return data
end

-- Fires a client event to every registered handler (e.g. "TradeEvent", "RaidEvent").
function __fire(name, ...)
	for _, h in __netHandlers[name] or {} do
		h(...)
	end
end

-- Opens a panel through the real UIController (menu + window).
function __openPanel(name, opts)
	local Controllers = game.StarterPlayer.StarterPlayerScripts.Controllers
	local UIController = __require(Controllers.UIController)
	if not __uiInit then
		__uiInit = true
		UIController.Init()
	end
	UIController.Open(name, opts)
end
