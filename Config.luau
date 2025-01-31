return {
	TOKEN = "", -- DISCORD BOT TOKEN
	API_KEY = "", -- ROBLOX API KEY
	UNIVERSE_ID = 0, -- https://apis.roblox.com/universes/v1/places/PLACEID/universe
	PUBLIC_REASON = "Public reason for the ban.", -- Public reason for bans
	LOG_CHANNEL_ID = "", -- Audit log channel where commands are logged
	APPROVAL_CHANNEL_ID = "", -- Approval channel for trial mods
	USE_USERNAME = true, -- Whether to use username or user id for bans/unbans
	DEFAULT_DURATION = -1, -- Default duration for bans (-1 for permanent)
	
	ADMINISTRATOR_ROLES = { -- DISCORD ROLE IDs
		""
	},

	MODERATOR_ROLES = { -- DISCORD ROLE IDs
		""
	},

	TRIAL_MOD_ROLES = { -- DISCORD ROLE IDs
		""
	}
}