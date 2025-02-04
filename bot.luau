local fs = require("@lune/fs")
local Aloha = require("./Aloha")
local Config = require("./Config")
local Network = Aloha.Lib.Network
local Endpoints = Aloha.Lib.Endpoints
local Embed = Aloha.Classes.Embed
local Color3 = Aloha.Classes.Color3
local Objects = Aloha.Classes.Objects
local Misc = Aloha.Util.Misc
local Bot = Aloha.Lib.Bot
local Snowflake = Aloha.Classes.Snowflake
local Commands = Aloha.Lib.Commands
local Enum = Aloha.Lib.Enum
local Components = Aloha.Lib.Components
local Task = Aloha.Util.Task
Aloha.Run(Config.TOKEN)

local commandsDirectory = "./Commands"

for _, file in fs.readDir(commandsDirectory) do

	local command = require(`{commandsDirectory}/{file}`)
	local newCommand, ret = Commands.RegisterGlobal(command.Data)

	if command.Response and newCommand then
		newCommand:SetResponse(command.Response)
	end
end

local Interaction_Functions = {
	["ban"] = function(interaction, userId, duration, reason, channelName, publicReason, evidence)
		local moderationToggle = fs.readFile("MODERATION_TOGGLE")

		if moderationToggle == "off" then
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					content = "Moderation is currently disabled."
				}
			}
		end

		if duration == "nil" then
			duration = nil
		end

		if not interaction.member then
			return
		end

		local member = interaction.member
		local user = member.user

		interaction.member = Objects.GetMember(user.id, member.guild.id)

		if not interaction.member then
			return
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

		if rank == 0 then
			return
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

		local url = `https://apis.roblox.com/cloud/v2/universes/{Config.UNIVERSE_ID}/user-restrictions/{userId}`

		local s,r = Network.Patch(url, Network.JsonEncode({
			gameJoinRestriction = {
				active = true,
				duration = duration,
				privateReason = `(Moderator: {interaction.member.user.id}) {reason}`,
				displayReason = publicReason,
				excludeAltAccounts = true
			}
		}), {
			["Content-Type"] = "application/json",
			["x-api-key"] = Config.API_KEY
		})

		if s and r.ok then
			local logChannel = Objects.GetChannel(Snowflake.new(Config.LOG_CHANNEL_ID))
			
			local endpoint = `{Endpoints.CREATE_INTERACTION_RESPONSE:format(interaction.id, interaction.token)}`

			local success, response = Network.Request({
				endpoint = endpoint,
				method = "POST",
				body = {
					type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
					data = {
						embeds = {
							Embed.new().setColor(Color3.fromRGB(255, 0, 0)).setDescription("User banned successfully.").finish()
						},
						flags = Enum.MESSAGE_FLAGS.EPHEMERAL,
					}
				}
			})

			if logChannel and success then
				if logChannel then
					local _, ret = logChannel:Send(nil, {
						Embed.new()
						.setTitle("User Banned")
						.setColor(Color3.fromRGB(255, 0, 0))
						.setFields({
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
								name = "Moderator",
								value = `<@{user.id}> ({user.id})`,
								inline = false
							},
							{
								name = "Reason",
								value = reason,
								inline = true
							},
							{
								name = "Channel Ran",
								value = `{channelName}`,
								inline = true
							},
							(function()
								if evidence then
									return {
										name = "Evidence",
										value = evidence,
										inline = false
									}
								end

								return nil
							end)()
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
									label = "Unban",
									style = 1, 
									custom_id = `unban_{userId}`
								}
							}
						}
					})

					local message = Objects.GetMessage(ret.id)

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
									value = reason,
									inline = false
								},
								{ 
									name = "Channel Ran",
									value = `{interaction.channel.name}`,
									inline = true
								},
							})
							.setFooter(os.date("%Y-%m-%d %H:%M:%S") .." - " .. `{userId}_{Bot.GenerateGUID()}`)
							.setThumbnail(avatarThumbnail)
							.finish()
						}, {})
					end)
				end
			end

			local message = Objects.GetMessageInChannel(interaction.channel.id, Snowflake.new(interaction.message.id))
			message:Delete()
		end

		return
	end,
	["unban"] = function(interaction, userId, channelName, isApproval)
		local moderationToggle = fs.readFile("MODERATION_TOGGLE")

		if moderationToggle == "off" then
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					content = "Moderation is currently disabled."
				}
			}
		end

		if not interaction.member then
			return
		end

		local member = interaction.member
		local user = member.user

		interaction.member = Objects.GetMember(user.id, member.guild.id)

		if not interaction.member then
			return
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


		if rank == 0 then
			return
		end

		local url = `https://apis.roblox.com/cloud/v2/universes/{Config.UNIVERSE_ID}/user-restrictions/{userId}`

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

		local s,r = Network.Patch(url, Network.JsonEncode({
			gameJoinRestriction = {
				active = false,
			}
		}), {
			["Content-Type"] = "application/json",
			["x-api-key"] = Config.API_KEY
		})

		if not s or not r.ok then
			return
		end

		local endpoint = `{Endpoints.CREATE_INTERACTION_RESPONSE:format(interaction.id, interaction.token)}`

		local success, response = Network.Request({
			endpoint = endpoint,
			method = "POST",
			body = {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					embeds = {
						Embed.new().setColor(Color3.fromRGB(0, 255, 0)).setDescription("User unbanned successfully.").finish()
					},
					flags = Enum.MESSAGE_FLAGS.EPHEMERAL,
				}
			}
		})

		if success then
			local user = interaction.member.user
			local avatarThumbnail = Misc.GetAvatarThumbnail(userId)
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
							value = `{channelName}`,
							inline = true
						}
					})
					.setFooter(os.date("%Y-%m-%d %H:%M:%S") .." - " .. `{userId}_{Bot.GenerateGUID()}`)
					.setThumbnail(avatarThumbnail)
					.finish()
				})

			end
		end

		if isApproval then
			local message = Objects.GetMessageInChannel(interaction.channel.id, Snowflake.new(interaction.message.id))
			message:Delete()
		end

		return
	end,

	["deny"] = function(interaction, userId)
		local message = Objects.GetMessageInChannel(interaction.channel.id, Snowflake.new(interaction.message.id))
		message:Delete()
	end
}

Components.GetInteractionSignal(Enum.COMPONENT.BUTTON):Connect(function(interaction, shard_id)
	local custom_id = interaction.data.custom_id

	local args = string.split(custom_id, "|")
	local command = args[1]
	local userId = args[2]


	Interaction_Functions[command](interaction, userId, table.unpack(args, 3))
end)