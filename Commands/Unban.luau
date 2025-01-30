local Aloha = require("../Aloha")
local Enum = Aloha.Lib.Enum
local Embed = Aloha.Classes.Embed
local DiscordTypes = Aloha.Lib.DiscordTypes
local Color3 = Aloha.Classes.Color3
local Network = Aloha.Lib.Network
local Objects = Aloha.Classes.Objects
local Snowflake = Aloha.Classes.Snowflake
local Config = require("../Config")
local Misc = Aloha.Util.Misc
local Bot = Aloha.Lib.Bot
local fs = require("@lune/fs")

return {
	Data = {
		name = "unban",
		description = "Unban a user from the game.",
		type = Enum.APPLICATION_COMMAND_TYPE.CHAT_INPUT,
		options = {
			{
				name = "user",
				description = "User ID or username (if enabled) to unban.",
				type = Enum.APPLICATION_COMMAND_OPTION_TYPE.STRING,
				required = true,
			}
		}
	},

	Response = function(interaction)
		local data = interaction.data
		local options = data.options

		local moderationToggle = fs.readFile("MODERATION_TOGGLE")
		print(moderationToggle)

		if moderationToggle == "off" then
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					content = "Moderation is currently disabled."
				},
				flags = Enum.MESSAGE_FLAGS.EPHEMERAL
			}
		end

		if not options then 
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					content = " Command error."
				},
				flags = Enum.MESSAGE_FLAGS.EPHEMERAL
			}
		end

		local canUseRoles = {}
		local rank = 0
		
		for _, role in Config.ADMINISTRATOR_ROLES do
			if interaction.member:HasRole(Snowflake.new(role)) then
				rank = 3
				break
			end
		end

		for _, role in Config.MODERATOR_ROLES do
			if interaction.member:HasRole(Snowflake.new(role)) and rank < 2 then
				rank = 2
				break
			end
		end

		for _, role in Config.TRIAL_MOD_ROLES do
			if interaction.member:HasRole(Snowflake.new(role)) and rank < 1 then
				rank = 1
				break
			end
		end

		if rank == 0 then
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					content = "You do not have permission to use this command."
				},
				flags = Enum.MESSAGE_FLAGS.EPHEMERAL
			}
		end

		local userId = options[1].value
		
		if not tonumber(userId) and Config.USE_USERNAME then
			local s,r = Network.Post(`https://users.roblox.com/v1/usernames/users`, Network.JsonEncode({
				usernames = {
					userId
				},
			}), {
				['Content-Type'] = "application/json",
			})

			if s then
				local result = Network.JsonDecode(r.body)
				if result.data then
					userId = result.data[1].id
				end
			end
		end

		local suc, ret = Network.Get(`https://users.roblox.com/v1/users/{userId}`)
		local username
		if suc then
			local result = Network.JsonDecode(ret.body)
			if result.name ~= result.displayName then
				username = `{result.displayName} (@{result.name})`
			else
				username = result.name
			end
		end

		local user = interaction.member.user
		local avatarThumbnail = Misc.GetAvatarThumbnail(userId)

		if rank == 1 then
			local approvalChannel = Objects.GetChannel(Snowflake.new(Config.APPROVAL_CHANNEL_ID))
			if approvalChannel then
				approvalChannel:Send(nil, {
					Embed.new()
					.setTitle("User Unban Request")
					.setColor(Color3.fromRGB(255, 0, 0))

					.setFields({
						{
							name = "Trial Moderator",
							value = `<@{user.id}> ({user.id})`,
							inline = false
						},
						{
							name = "User",
							value = `[{username or userId}](https://www.roblox.com/users/{userId}/profile)`,
							inline = true
						},
					})
					.setFooter(os.date("%Y-%m-%d %H:%M:%S") .." - " .. `{userId}_{Bot.GenerateGUID()}`)
					.setThumbnail(avatarThumbnail)
					.finish()
				}, nil, nil, nil, {
					{
						type = 1,	
						components = {
							{
								type = 2,
								label = "Approve",
								style = 3, 
								custom_id = `unban_{userId}_{interaction.channel.name}_true`
							},
							{
								type = 2,
								label = "Deny",
								style = 4, 
								custom_id = `deny_{user.id}`
							}
						}
					}

				})
			end

			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					embeds = {
						Embed.new().setColor(Color3.fromRGB(0, 255, 0)).setDescription("Unban request sent for approval.").finish()
					},
					flags = Enum.MESSAGE_FLAGS.EPHEMERAL,

				}
			}
		end

		local url = `https://apis.roblox.com/cloud/v2/universes/{Config.UNIVERSE_ID}/user-restrictions/{userId}`

		local s,r = Network.Patch(url, Network.JsonEncode({
			gameJoinRestriction = {
				active = false,
			}
		}), {
			["Content-Type"] = "application/json",
			["x-api-key"] = Config.API_KEY
		})


		if s and r.ok then
			local logChannel = Objects.GetChannel(Snowflake.new(Config.LOG_CHANNEL_ID))	
			if logChannel then
				logChannel:Send(nil, {
					Embed.new()
					.setTitle("User Unbanned")
					.setColor(Color3.fromRGB(0, 255, 0))
					.setFields({
						{
							name = "Moderator",
							value = `<@{user.id}> ({user.id})`,
							inline = false
						},
						{
							name = "Unbanned User",
							value = `[{username or userId}](https://www.roblox.com/users/{userId}/profile)`,
							inline = true
						},
						{
							name = "Channel Ran",
							value = `{interaction.channel.name}`,
							inline = true
						}
					})
					.setFooter(os.date("%Y-%m-%d %H:%M:%S") .." - " .. `{userId}_{Bot.GenerateGUID()}`)
					.setThumbnail(avatarThumbnail)
					.finish()
				})
			end

			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					embeds = {
						Embed.new().setColor(Color3.fromRGB(255, 0, 0)).setDescription(`({username})[https://www.roblox.com/users/{userId}] unbanned successfully.`).finish()					},
					flags = Enum.MESSAGE_FLAGS.EPHEMERAL,
				}
			}
		end

		return {
			type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
			data = {
				embeds = {
					Embed.new().setColor(Color3.fromRGB(255, 0, 0)).setDescription("Failed to unban user.").finish()
				},
				flags = Enum.MESSAGE_FLAGS.EPHEMERAL,
			},
			
		}
	end			
}