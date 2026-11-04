--!strict
-- NetSchema: every remote in the game, declared once. Net creates/validates from this table.
-- FROZEN CONTRACT: add remotes freely; never change an existing remote's args without updating
-- both the server handler and every client caller in the same commit.
--
-- kind:      "Event" (RemoteEvent) or "Function" (RemoteFunction)
-- direction: "ToServer" (client -> server), "ToClient" (server -> client)
-- args:      type spec per argument for ToServer remotes (server-side validation). Supported:
--            "string" (<= 64 chars), "longstring" (<= 512), "number" (finite), "integer",
--            "boolean", "table", "Vector3", "uidList" (array of <= 64 short strings),
--            "any"; suffix "?" makes it optional.
-- rate:      { burst, perSecond } token bucket per player (ToServer only).

export type RemoteDef = {
	kind: "Event" | "Function",
	direction: "ToServer" | "ToClient",
	args: { string }?,
	rate: { burst: number, perSecond: number }?,
}

local NetSchema: { [string]: RemoteDef } = {
	-- Data ---------------------------------------------------------------------------------
	ProfileSnapshot = { kind = "Event", direction = "ToClient" },
	ProfileChanged = { kind = "Event", direction = "ToClient" }, -- (key: string, value: any)
	RequestSnapshot = { kind = "Event", direction = "ToServer", args = {}, rate = { burst = 2, perSecond = 0.2 } },

	-- Generic UI notifications ---------------------------------------------------------------
	Notify = { kind = "Event", direction = "ToClient" }, -- (kind: string, text: string)
	PolicyFlags = { kind = "Event", direction = "ToClient" }, -- (flags: table)

	-- Combat -------------------------------------------------------------------------------
	CombatAction = { kind = "Event", direction = "ToServer", args = { "table" }, rate = { burst = 12, perSecond = 8 } },
	CombatEvent = { kind = "Event", direction = "ToClient" }, -- (DamageEvent | state table)
	EquipWeapon = { kind = "Event", direction = "ToServer", args = { "string" }, rate = { burst = 3, perSecond = 1 } },
	SetFightingStyle = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 3, perSecond = 1 } },
	BuyWeapon = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 3, perSecond = 1 } },
	-- Waystones: fast travel to an attuned waystone.
	TravelWaystone = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 3, perSecond = 0.5 } },
	-- Qi arts: (spellId, aim direction?, target point?) / (slot, spellId or "")
	CastSpell = { kind = "Event", direction = "ToServer", args = { "string", "Vector3?", "Vector3?" }, rate = { burst = 4, perSecond = 3 } },
	SetSpellSlot = { kind = "Function", direction = "ToServer", args = { "integer", "string" }, rate = { burst = 6, perSecond = 3 } },
	-- Shadow Kunai: throw toward an aim direction (server re-validates charges/cooldown/targets).
	ThrowKunai = { kind = "Event", direction = "ToServer", args = { "Vector3" }, rate = { burst = 3, perSecond = 3 } },
	-- Skill tree: learn one rank / reset every skill (points come back).
	LearnSkill = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 6, perSecond = 3 } },
	ResetSkills = { kind = "Function", direction = "ToServer", args = {}, rate = { burst = 2, perSecond = 0.2 } },

	-- Enemies / bosses ---------------------------------------------------------------------
	EnemyState = { kind = "Event", direction = "ToClient" }, -- (batched states table)
	BossState = { kind = "Event", direction = "ToClient" }, -- (bossId, phase, hpFrac, posture)

	-- Spirits ------------------------------------------------------------------------------
	EquipSpirit = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 6, perSecond = 3 } },
	UnequipSpirit = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 6, perSecond = 3 } },
	LockSpirit = { kind = "Function", direction = "ToServer", args = { "string", "boolean" }, rate = { burst = 6, perSecond = 3 } },
	ReleaseSpirits = { kind = "Function", direction = "ToServer", args = { "uidList" }, rate = { burst = 3, perSecond = 1 } },
	FuseSpirits = { kind = "Function", direction = "ToServer", args = { "uidList" }, rate = { burst = 3, perSecond = 1 } },

	-- Spirit Lanterns (eggs) ----------------------------------------------------------------
	GetLanternOdds = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 6, perSecond = 2 } },
	OpenLantern = { kind = "Function", direction = "ToServer", args = { "string", "integer" }, rate = { burst = 4, perSecond = 2 } },

	-- Expeditions --------------------------------------------------------------------------
	StartExpedition = { kind = "Function", direction = "ToServer", args = { "string", "string", "uidList" }, rate = { burst = 4, perSecond = 1 } },
	ClaimExpedition = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 4, perSecond = 1 } },

	-- Market -------------------------------------------------------------------------------
	PromptProduct = { kind = "Event", direction = "ToServer", args = { "string" }, rate = { burst = 3, perSecond = 0.5 } },
	PromptPass = { kind = "Event", direction = "ToServer", args = { "string" }, rate = { burst = 3, perSecond = 0.5 } },
	PrepareGift = { kind = "Function", direction = "ToServer", args = { "integer", "string" }, rate = { burst = 3, perSecond = 0.5 } },
	GetStoreInfo = { kind = "Function", direction = "ToServer", args = {}, rate = { burst = 3, perSecond = 0.5 } },

	-- Night Market (rotating fixed-price stock) ---------------------------------------------
	GetNightMarket = { kind = "Function", direction = "ToServer", args = {}, rate = { burst = 4, perSecond = 1 } },
	BuyNightMarket = { kind = "Function", direction = "ToServer", args = { "integer", "integer" }, rate = { burst = 4, perSecond = 1 } },

	-- Duels: (op "state"|"challenge"|"accept"|"decline"|"forfeit", userId?)
	DuelRequest = { kind = "Function", direction = "ToServer", args = { "string", "integer?" }, rate = { burst = 4, perSecond = 1 } },
	DuelEvent = { kind = "Event", direction = "ToClient" },

	-- Bell Dice (shared chance table, free chips only) ---------------------------------------
	DiceState = { kind = "Function", direction = "ToServer", args = {}, rate = { burst = 4, perSecond = 1 } },
	DiceBet = { kind = "Function", direction = "ToServer", args = { "string", "integer" }, rate = { burst = 6, perSecond = 3 } },
	DiceExchange = { kind = "Function", direction = "ToServer", args = { "integer" }, rate = { burst = 2, perSecond = 0.5 } },
	DiceEvent = { kind = "Event", direction = "ToClient" },

	-- Rewards / quests / codes ---------------------------------------------------------------
	ClaimDaily = { kind = "Function", direction = "ToServer", args = {}, rate = { burst = 2, perSecond = 0.5 } },
	ClaimPlaytime = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 4, perSecond = 1 } },
	ClaimOffline = { kind = "Function", direction = "ToServer", args = {}, rate = { burst = 2, perSecond = 0.5 } },
	ClaimQuest = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 4, perSecond = 1 } },
	RedeemCode = { kind = "Function", direction = "ToServer", args = { "string" }, rate = { burst = 3, perSecond = 0.2 } },

	-- Trading (Phase 4; gated by PolicyService) ---------------------------------------------
	TradeRequest = { kind = "Function", direction = "ToServer", args = { "integer" }, rate = { burst = 3, perSecond = 0.3 } },
	TradeUpdate = { kind = "Function", direction = "ToServer", args = { "table" }, rate = { burst = 8, perSecond = 2 } },
	TradeEvent = { kind = "Event", direction = "ToClient" },

	-- Party / story --------------------------------------------------------------------------
	PartyRequest = { kind = "Function", direction = "ToServer", args = { "string", "integer?" }, rate = { burst = 4, perSecond = 1 } },
	PartyEvent = { kind = "Event", direction = "ToClient" },
	-- Raids: (op "state"|"create"|"join"|"leave"|"launch", raidId or lobbyId)
	RaidRequest = { kind = "Function", direction = "ToServer", args = { "string", "string?" }, rate = { burst = 4, perSecond = 1 } },
	RaidEvent = { kind = "Event", direction = "ToClient" },
	StoryEvent = { kind = "Event", direction = "ToClient" }, -- (cutscene/dialogue ids)
	StoryAdvance = { kind = "Event", direction = "ToServer", args = { "string" }, rate = { burst = 4, perSecond = 2 } },
}

return NetSchema
