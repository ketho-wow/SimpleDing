---@diagnostic disable: undefined-field
local NAME, S = ...
local VERSION = C_AddOns.GetAddOnMetadata(NAME, "Version")

local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local L = S.L
local db

S.lastPlayed = time()
S.totalTPM, S.curTPM = 0, 0
local curTPM2, totalTPM2
local crop = ":64:64:4:60:4:60"
local args = {}

local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

local function GetCompatMaxLevel()
	if isRetail then
		return GetMaxLevelForPlayerExpansion()
	else
		return MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]
	end
end

S.player = {
	name = UnitName("player"),
	level = UnitLevel("player"),
	maxlevel = GetCompatMaxLevel(),
}
local player = S.player

-- not capitalized
local D_SECONDS = strlower(D_SECONDS)
local D_MINUTES = strlower(D_MINUTES)
local D_HOURS = strlower(D_HOURS)
local D_DAYS = strlower(D_DAYS)

-- except for German locale
if GetLocale() == "deDE" then
	D_SECONDS = _G.D_SECONDS
	D_MINUTES = _G.D_MINUTES
	D_HOURS = _G.D_HOURS
	D_DAYS = _G.D_DAYS
end

local b = CreateFrame("Button")

local function Time(v)
	local fsec = format(D_SECONDS, floor(v) % 60)
	local fmin = format(D_MINUTES, floor(v/60) % 60)
	local fhour = format(D_HOURS, floor(v/3600) % 24)
	local fday = format(D_DAYS, floor(v/86400))
	local s
	if v >= 86400 then
		s = format("%s, %s", fday, fhour)
	elseif v >= 3600 then
		s = format("%s, %s", fhour, fmin)
	elseif v >= 60 then
		s = format("%s, %s", fmin, fsec)
	elseif v >= 0 then
		s = fsec
	else
		s = v
	end
	-- sanitize for SendChatMessage by removing any pipe characters
	return b:GetText(b:SetText(s)) or ""
end

local function ReplaceArgs(msg, args)
	for k in gmatch(msg, "%b<>") do
		-- remove <>, make case insensitive
		local s = strlower(gsub(k, "[<>]", ""))
		-- escape special characters
		s = gsub(args[s] or s, "(%p)", "%%%1")
		k = gsub(k, "(%p)", "%%%1")
		msg = msg:gsub(k, s)
	end
	return msg
end

local function LevelText(isPreview)
	local args = args; wipe(args)
	local msg = db.DingMsg

	if isPreview then
		args.level = "|cffADFF2F"..(player.level == player.maxlevel and player.level or player.level + 1).."|r"
		args["level-"] = "|cffF6ADC6"..player.level.."|r"
		args.time = "|cff71D5FF"..Time(S.curTPM + time() - S.lastPlayed).."|r"
		args.total = "|cff71D5FF"..Time(S.totalTPM + time() - S.lastPlayed).."|r"
		-- raid targets
		for k in gmatch(msg, "%b{}") do
			local rt = strlower(gsub(k, "[{}]", ""))
			if ICON_TAG_LIST[rt] and ICON_LIST[ICON_TAG_LIST[rt]] then
				msg = msg:gsub(k, ICON_LIST[ICON_TAG_LIST[rt]].."16:16:0:3|t")
			end
		end
	else
		args.level = player.level
		args["level-"] = player.level - 1
		args.time = Time(S.LevelTime)
		args.total = Time(S.totalTPM)
	end
	return ReplaceArgs(msg, args)
end

local requiresHw = {
	SAY = true,
	YELL = true,
	CHANNEL = true,
}

local function CanSendChatMessage(chatType)
	local _, instanceType = IsInInstance()
	if instanceType == "none" and requiresHw[chatType or "SAY"]  then
		return false
	end
	return true
end

local defaults = {
	db_version = 2, -- update this on savedvars changes
	ChatSay = true,
	DingMsg = L.MSG_PLAYER_DING,
}

local options = {
	type = "group",
	name = format("%s |cffADFF2F%s|r", NAME, VERSION),
	get = function(i) return db[i[#i]] end,
	set = function(i, v) db[i[#i]] = v end,
	args = {
		inline1 = {
			type = "group", order = 1,
			name = " ",
			inline = true,
			args = {
				ChatSay = {
					type = "toggle", order = 1,
					width = "full", desc = "Announces to |cff71D5FF/say|r or |cff71D5FF/emote|r. Otherwise shows a message in the center of your screen",
					name = "|TInterface\\ChatFrame\\UI-ChatIcon-Chat-Up:16:16|t  "..SAY,
				},
				ChatGuild = {
					type = "toggle", order = 2,
					width = "full", desc = "Announces to |cff71D5FF/guild|r",
					name = "|TInterface\\Icons\\inv_shirt_guildtabard_01:16:16:1:0"..crop.."|t  "..GUILD,
				},
				Screenshot = {
					type = "toggle", order = 3,
					width = "full", descStyle = "",
					name = "|TInterface\\Icons\\inv_misc_spyglass_03:16:16:1:0"..crop.."|t  "..BINDING_NAME_SCREENSHOT,
				},
			},
		},
		DingMsg = {
			type = "input", order = 2,
			width = "full",
			name = " ",
			usage = "\n|cffADFF2FLEVEL|r, |cffF6ADC6LEVEL-|r, |cff71D5FFTIME|r, |cff71D5FFTOTAL|r",
			set = function(i, v) db.DingMsg = v
				if strtrim(v) == "" then db.DingMsg = defaults.DingMsg end
			end,
		},
		Preview = {
			type = "description", order = 3,
			name = function() return "  "..LevelText(true) end,
		},
	},
}

local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
	self[event](self, ...)
end

function f:ADDON_LOADED(addon)
	if addon == NAME then
		SimpleDingDB3 = SimpleDingDB3 or CopyTable(defaults)
		db = SimpleDingDB3
		for k, v in pairs(defaults) do
			if db[k] == nil then
				db[k] = v
			end
		end
		ACR:RegisterOptionsTable(NAME, options)
		ACD:AddToBlizOptions(NAME, NAME)
		ACD:SetDefaultSize(NAME, 400, 260)

		-- wait for any other AddOns that want to request /played too
		C_Timer.After(1, function()
			if S.totalTPM == 0 then
				local success = DEFAULT_CHAT_FRAME:UnregisterEvent("TIME_PLAYED_MSG")
				RequestTimePlayed()
				if success then
					C_Timer.After(1, function()
						DEFAULT_CHAT_FRAME:RegisterEvent("TIME_PLAYED_MSG")
					end)
				end
			end
		end)
		self:RegisterEvent("PLAYER_LEVEL_UP")
		self:RegisterEvent("TIME_PLAYED_MSG")
		self:UnregisterEvent("ADDON_LOADED")
	end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)

local playerDinged

function f:PLAYER_LEVEL_UP(level)
	player.level = level -- on another note, UnitLevel is not yet updated
	playerDinged = true
	RequestTimePlayed() -- fires TIME_PLAYED_MSG
end

function f:TIME_PLAYED_MSG(...)
	S.totalTPM, S.curTPM = ...
	S.lastPlayed = time()
	if playerDinged then
		playerDinged = false
		-- undinged LevelTime + (dinged TotalTime - undinged TotalTime)
		S.LevelTime = curTPM2 + (S.totalTPM - totalTPM2)
		local text = LevelText()

		if db.ChatSay then
			if CanSendChatMessage() then
				C_ChatInfo.SendChatMessage(text)
			else
				C_ChatInfo.SendChatMessage(text, "EMOTE")
			end
		else
			RaidNotice_AddMessage(RaidWarningFrame, text, {r=1, g=1, b=0})
		end
		if db.ChatGuild and IsInGuild() then
			C_ChatInfo.SendChatMessage(text, "GUILD")
		end
		if db.Screenshot then
			C_Timer.After(1, function() Screenshot() end)
		end
	end
	-- update for next levelup
	totalTPM2, curTPM2 = S.totalTPM, S.curTPM
end

for i, v in ipairs({"sd", "simpleding"}) do
	_G["SLASH_SIMPLEDING"..i] = "/"..v
end

SlashCmdList.SIMPLEDING = function()
	ACD:Open(NAME)
end
