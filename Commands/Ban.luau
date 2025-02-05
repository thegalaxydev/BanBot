local Aloha = require("../Aloha")
local Enum = Aloha.Lib.Enum
local Embed = Aloha.Classes.Embed
local DiscordTypes = Aloha.Lib.DiscordTypes
local Color3 = Aloha.Classes.Color3
local Task = Aloha.Util.Task
local Network = Aloha.Lib.Network
local Objects = Aloha.Classes.Objects
local Snowflake = Aloha.Classes.Snowflake
local Bot = Aloha.Lib.Bot
local Config = require("../Config")
local Misc = Aloha.Util.Misc
local fs = require("@lune/fs")

return {
	Data = {
		name = "ban",
		description = "Ban a user from the game.",
		type = Enum.APPLICATION_COMMAND_TYPE.CHAT_INPUT,
		options = {
			{
				name = "user",
				description = "User ID or Username (if enabled) to ban.",
				type = Enum.APPLICATION_COMMAND_OPTION_TYPE.STRING,
				required = true,
			},
			{
				name = "private-reason",
				description = "Private reason for the ban.",
				type = Enum.APPLICATION_COMMAND_OPTION_TYPE.STRING,
				required = true,
			},
			{
				name = "duration",
				description = "Duration of the ban in seconds.",
				type = Enum.APPLICATION_COMMAND_OPTION_TYPE.NUMBER,
				required = false,
			},
			{
				name = "exclude-alts",
				description = "Exclude alts in the ban. (Default: true)",
				type = Enum.APPLICATION_COMMAND_OPTION_TYPE.BOOLEAN,
				required = false,
			},
			{
				name = "public-reason",
				description = "Public reason for the ban.",
				type = Enum.APPLICATION_COMMAND_OPTION_TYPE.STRING,
				required = false,
			},
			{
				name = "evidence",
				description = "Evidence for the ban.",
				type = Enum.APPLICATION_COMMAND_OPTION_TYPE.STRING,
				required = false,
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
					embeds = {
						Embed.new().setColor(Color3.fromRGB(255, 0, 0)).setDescription("Moderation is currently disabled.").finish()
					},
					flags = Enum.MESSAGE_FLAGS.EPHEMERAL,

				},
			}
		end


		if not options then 
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					embeds = {
						Embed.new().setColor(Color3.fromRGB(255, 0, 0)).setDescription("Command error.").finish()
					},
					flags = Enum.MESSAGE_FLAGS.EPHEMERAL
				}
			}
		end


		if not interaction.member then
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					embeds = {
						Embed.new().setColor(Color3.fromRGB(255, 0, 0)).setDescription("You do not have permission to use this command.").finish()
					},
					flags = Enum.MESSAGE_FLAGS.EPHEMERAL
				}
			}
		end

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
					embeds = {
						Embed.new().setColor(Color3.fromRGB(255, 0, 0)).setDescription("You do not have permission to use this command.").finish()
					},
					flags = Enum.MESSAGE_FLAGS.EPHEMERAL
				}
			}
		end


		local duration = if (Config.DEFAULT_DURATION == -1) then nil else `{Config.DEFAULT_DURATION}s`
		local excludeAlts = true
		local publicReason = Config.PUBLIC_REASON
		local evidence = nil

		for _, option in options do
			if option.name == "evidence" then
				evidence = option.value
				break
			end
		end

		for _, option in options do
			if option.name == "duration" and not duration then
				if option.value == -1 then
					duration = nil
					break
				end

				duration = option.value and `{option.value}s`

				break
			end
		end


		
		if rank == 3 then
			for _, option in options do
				if option.name == "exclude-alts" then
					excludeAlts = option.value
					break
				end
			end
		end

		if rank >= 2 then
			for _, option in options do
				if option.name == "public-reason" then
					publicReason = option.value
					break
				end
			end
		end

		local userId = `{options[1].value}`
		local privateReason = options[2].value
		local user = interaction.member.user

		local tried = userId

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
					userId = result.data[1] and result.data[1].id or nil
				end
			end
		end

		if not userId then
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					embeds = {
						Embed.new().setColor(Color3.fromRGB(255, 0, 0)).setDescription(`Failed to ban **{tried}**. Invalid user ID or username.`).finish()
					},
					flags = Enum.MESSAGE_FLAGS.EPHEMERAL


				}
			}
		end


		local avatarThumbnail = Misc.GetAvatarThumbnail(userId)

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

		if rank == 1 then
			local approvalChannel = Objects.GetChannel(Snowflake.new(Config.APPROVAL_CHANNEL_ID))
			if approvalChannel then
				local fields = {
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
					{
						name = "Duration",
						value = duration and `{duration}` or "Permanent",
						inline = true
					},
					{
						name = "Reason",
						value = privateReason,
						inline = false
					},
				}

				if evidence then
					table.insert(fields, {
						name = "Evidence",
						value = evidence,
						inline = false
					})
				end
				approvalChannel:Send(nil, {
					Embed.new()
					.setTitle("User Ban Request")
					.setColor(Color3.fromRGB(255, 0, 0))
					.setFields(fields)

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
								custom_id = `ban|{userId}|{duration}|{privateReason}|{interaction.channel.name}|{publicReason}{evidence and `|{evidence}` or ``}`
							},

							{
								type = 2,
								label = "Deny",
								style = 4, 
								custom_id = `deny|{user.id}`
							}
						}
					}

				})
			end

			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					embeds = {
						Embed.new().setColor(Color3.fromRGB(0, 255, 0)).setDescription("Ban request sent for approval.").finish()
					},
					flags = Enum.MESSAGE_FLAGS.EPHEMERAL,
				}
			}
		end

		local url = `https://apis.roblox.com/cloud/v2/universes/{Config.UNIVERSE_ID}/user-restrictions/{userId}`
		local gameJoinRestriction = {
			active = true,
			duration = duration,
			privateReason = `(Moderator: {interaction.member.user.id}) {privateReason}`,
			displayReason = publicReason,
			excludeAltAccounts = excludeAlts
		}

		print(gameJoinRestriction)
		local s,r = Network.Patch(url, Network.JsonEncode({
			gameJoinRestriction = gameJoinRestriction
		}), {
			["Content-Type"] = "application/json",
			["x-api-key"] = Config.API_KEY
		})

		print(s,r)

		local fields = {
			{
				name = "Moderator",
				value = `<@{user.id}> ({user.id})`,
				inline = false
			},
			{
				name = "Banned User",
				value = `[{username or userId}](https://www.roblox.com/users/{userId}/profile)`,
				inline = true
			},
			{
				name = "Duration",
				value = duration and `{duration}` or "Permanent",
				inline = true
			},
			{
				name = "Reason",
				value = privateReason,
				inline = false
			},
			{ 
				name = "Channel Ran",
				value = `{interaction.channel.name}`,
				inline = true
			},
		}

		if not excludeAlts then
			table.insert(fields, {
				name = "Include Alts",
				value = "Yes",
				inline = true
			})
		end

		if evidence then
			table.insert(fields, {
				name = "Evidence",
				value = evidence,
				inline = false
			})
		end



		if s and r.ok then
			local logChannel = Objects.GetChannel(Snowflake.new(Config.LOG_CHANNEL_ID))
			if logChannel then
				local _, ret = logChannel:Send(nil, {
					Embed.new()
					.setTitle("User Banned")
					.setColor(Color3.fromRGB(255, 0, 0))
					.setFields(fields)
					.setFooter(os.date("%Y-%m-%d %H:%M:%S") .." - " .. `{userId}_{Bot.GenerateGUID()}`)
					.setThumbnail(avatarThumbnail)
					.finish()
				}, nil, nil, nil, {
					{
						type = 1,	
						components = {
							{
								type = 2,
								label = "Unban",
								style = 1, 
								custom_id = `unban|{userId}|{interaction.channel.name}`
							}
						}
					}
				})

				local message = Objects.GetMessage(ret)
				Task.Delay(300, function()
					message:Edit(nil, {
						Embed.new()
						.setTitle("User Banned")
						.setColor(Color3.fromRGB(255, 0, 0))
						.setFields({
							{
								name = "Moderator",
								value = `<@{user.id}> ({user.id})`,
								inline = false
							},
							{
								name = "Banned User",
								value = `[{username or userId}](https://www.roblox.com/users/{userId}/profile)`,
								inline = true
							},
							{
								name = "Duration",
								value = duration and `{duration}` or "Permanent",
								inline = true
							},
							{
								name = "Reason",
								value = privateReason,
								inline = false
							},
							{ 
								name = "Channel Ran",
								value = `{interaction.channel.name}`,
								inline = true
							},
							(function()
								if not excludeAlts then
									return {
										name = "Include Alts",
										value = "Yes",
										inline = true
									}
								end
	
								return nil
							end)()
						})
						.setFooter(os.date("%Y-%m-%d %H:%M:%S") .." - " .. `{userId}_{Bot.GenerateGUID()}`)
						.setThumbnail(avatarThumbnail)
						.finish()
					}, {})
				end)
			end

			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					embeds = {
						Embed.new().setColor(Color3.fromRGB(255, 0, 0)).setDescription(`[{username}](https://www.roblox.com/users/{userId}) banned successfully.`).finish()
					},
					flags = Enum.MESSAGE_FLAGS.EPHEMERAL,
				}
			}
		end

		return {
			type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
			data = {
				embeds = {
					Embed.new().setColor(Color3.fromRGB(255, 0, 0)).setDescription("Failed to ban user.").finish()
				},
				flags = Enum.MESSAGE_FLAGS.EPHEMERAL,
			},
			
		}
	end			
}