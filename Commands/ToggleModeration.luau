local Aloha = require("../Aloha")
local Enum = Aloha.Lib.Enum
local Embed = Aloha.Classes.Embed
local Color3 = Aloha.Classes.Color3
local Snowflake = Aloha.Classes.Snowflake
local Objects = Aloha.Classes.Objects
local Bot = Aloha.Lib.Bot
local Config = require("../Config")
local fs = require("@lune/fs")

return {
	Data = {
		name = "toggle-moderation",
		description = "Toggle the moderation system.",
		type = Enum.APPLICATION_COMMAND_TYPE.CHAT_INPUT,
		options = {
			{
				name = "toggle",
				description = "Toggle the moderation system.",
				type = Enum.APPLICATION_COMMAND_OPTION_TYPE.BOOLEAN,
				required = true,
			},
		}
	},

	Response = function(interaction)
		local data = interaction.data
		local options = data.options

		if not options then 
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					content = " Command error."
				},
				flags = Enum.MESSAGE_FLAGS.EPHEMERAL
			}
		end

		if not interaction.member then
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					content = "You do not have permission to use this command."
				},
				flags = Enum.MESSAGE_FLAGS.EPHEMERAL
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

		if rank < 3 then
			return {
				type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
				data = {
					content = "You do not have permission to use this command."
				},
				flags = Enum.MESSAGE_FLAGS.EPHEMERAL
			}
		end

		fs.writeFile("MODERATION_TOGGLE", options[1].value and "on" or "off")

		local logChannel = Objects.GetChannel(Snowflake.new(Config.LOG_CHANNEL_ID))
		if logChannel then
			logChannel:Send(nil, {
				Embed.new()
				.setTitle("Moderation Toggled")
				.setColor(options.toggle and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0))
				.setFields({
					{
						name = "Administrator",
						value = `<@{interaction.member.user.id}> ({interaction.member.user.id})`,
						inline = false
					},

					{
						name = "Moderation Status",
						value = options.toggle and "Enabled" or "Disabled",
						inline = true
					}
				})
				.setFooter(os.date("%Y-%m-%d %H:%M:%S") .." - " .. `{Bot.GenerateGUID()}`)
				.finish()
			})
		end


		return {
			type = Enum.INTERACTION_CALLBACK_TYPE.CHANNEL_MESSAGE_WITH_SOURCE,
			data = {
				embeds = {
					Embed.new().setColor(Color3.fromRGB(0, 255, 0)).setDescription(`Moderation system toggled to {fs.readFile("MODERATION_TOGGLE"):upper()}.`).finish()
				},
				flags = Enum.MESSAGE_FLAGS.EPHEMERAL,
			}
		}

	end			
}