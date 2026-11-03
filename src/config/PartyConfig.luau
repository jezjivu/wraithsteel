--!strict
-- PartyConfig: co-op party numbers (max size lives in ChapterConfig.MaxPartySize; the Ember
-- bonus per member in EconomyConfig.Multipliers.Ember.PartyBonusPerMember).

local PartyConfig = {}

PartyConfig.InviteSeconds = 60 -- invites expire after this
PartyConfig.ShareRadius = 120 -- party members within this many studs share kill rewards

return PartyConfig
