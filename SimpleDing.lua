-------------------------------------------
--- Author: Ketho (EU-Boulderfist)		---
--- License: Public Domain				---
--- Created: 2011.02.25					---
--- Version: 0.3 [2011.11.30]			---
-------------------------------------------
--- Curse			http://www.curse.com/addons/wow/simpleding
--- WoWInterface	http://www.wowinterface.com/downloads/info19479-SimpleDing.html

local NAME = ...
local VERSION = 0.3
local BUILD = "Release"

local _G = _G
local gsub, time = gsub, time

SimpleDing = LibStub("AceAddon-3.0"):NewAddon(NAME, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
local SD = SimpleDing

local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")

local profile, char

local playerDinged
local playerLevel = UnitLevel("player")
local MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]

local TPM_total, TPM_current = 0, 0	-- event vars
local TPM_total2, TPM_current2		-- backup event vars

local levelTime						-- accurate time on Levelup
local currentTime, totalTime = 0, 0	-- estimated time

local filterPlayed					-- filter SimpleDing's /played requests
local isStopwatch					-- can use the Blizzard Stopwatch

local lastPlayed = time()			-- timestamp of last /played request

local cropped = ":64:64:4:60:4:60"

local function AddedTime()
	return time() - lastPlayed
end

	---------------
	--- Options ---
	---------------

local defaults = {
	profile = {
		dingMsg = "Ding! "..LEVEL.." [LEVEL] in [TIME]"
	}
}

local options = {
	type = "group",
	name = NAME.." |cffADFF2Fv"..VERSION.."|r",
	handler = SD,
	args = {
		inline = {
			type = "group", order = 1,
			name = " ",
			inline = true,
			args = {
				GuildAnnounce = {
					type = "toggle", order = 1,
					width = "full", descStyle = "",
					name = "|TInterface\\Icons\\Ability_Warrior_RallyingCry:16:16:1:0"..cropped.."|t  |cff40FF40"..GUILD.."|r "..CHAT_ANNOUNCE,
					get = "GetValue", set = "SetValue",
				},
				GuildMemberDings = {
					type = "toggle", order = 2,
					descStyle = "",
					name = "|TInterface\\GuildFrame\\GuildLogo-NoLogo:16:16:1:0:64:64:14:51:14:51|t  |cff40FF40"..GUILD.."|r Dings",
					get = "GetValue", set = "SetValue",
				},
				Screenshot = {
					type = "toggle", order = 3,
					width = "full", descStyle = "",
					name = "|TInterface\\Icons\\inv_misc_spyglass_03:16:16:1:0"..cropped.."|t  "..BINDING_NAME_SCREENSHOT,
					get = "GetValue", set = "SetValue",
				},
				Stopwatch = {
					type = "toggle", order = 4,
					desc = TIMEMANAGER_SHOW_STOPWATCH,
					name = "|TInterface\\Icons\\Spell_Holy_BorrowedTime:16:16:2:0"..cropped.."|t  "..STOPWATCH_TITLE,
					get = function(i) return profile.Stopwatch end,
					set = function(i, v) profile.Stopwatch = v
						if v then
							if isStopwatch then
								StopwatchFrame:Show()
								StopwatchTicker.timer = currentTime
								Stopwatch_Play()
							end
						else
							Stopwatch_Clear()
							StopwatchFrame:Hide()
						end
					end,
				},
			},
		},
		DingMessage = {
			type = "input", order = 2,
			width = "full",
			name = " ",
			usage = "\n|cffADFF2F[LEVEL]|r |cffFFFFFF= New "..LEVEL.."|r\n|cff71D5FF[TIME]|r |cffFFFFFF= Level Time|r\n|cff71D5FF[TOTAL]|r |cffFFFFFF= Total Time|r",
			get = function(i) return profile.dingMsg end,
			set = function(i, v) profile.dingMsg = v
				if #strtrim(v) == 0 then profile.dingMsg = defaults.profile.dingMsg end
			end,
		},
		Example = {
			type = "description", order = 3,
			name = function() return "   "..SD:ReplaceText(profile.dingMsg, true) end,
		},
	},
}

function SD:GetValue(i)
	return profile[i[#i]]
end

function SD:SetValue(i, v)
	profile[i[#i]] = v
end

	----------------------
	--- Initialization ---
	----------------------

function SD:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SimpleDingDB", defaults, true)
	profile, char = self.db.profile, self.db.char
	ACR:RegisterOptionsTable("SimpleDing", options)
	self.optionsFrame = ACD:AddToBlizOptions("SimpleDing", NAME)

	self:RegisterChatCommand("sd", "SlashCmd")
	self:RegisterChatCommand("simpleding", "SlashCmd")

	self.db.global.version = VERSION
	self.db.global.build = BUILD

	char.levelTime = char.levelTime or {}
	char.totalTime = char.totalTime or {}
end

function SD:OnEnable()
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("TIME_PLAYED_MSG")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")

	if profile.Stopwatch and playerLevel < 85 then
		StopwatchFrame:Show()
		StopwatchTicker.timer = TPM_current + AddedTime()
		Stopwatch_Play()
	end

	-- grab /played
	self:ScheduleTimer(function()
		if TPM_total == 0 then
			filterPlayed = true
			RequestTimePlayed()
		end
	end, 5)

	-- update guild roster
	self:ScheduleRepeatingTimer(function()
		GuildRoster()
	end, 11)

	-- update estimated time
	self:ScheduleRepeatingTimer(function()
		currentTime = TPM_current + AddedTime()
		totalTime = TPM_total + AddedTime()
		isStopwatch = playerLevel < 85 and currentTime < MAX_TIMER_SEC
	end, 1)
end

function SD:SlashCmd(input)
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end

	--------------
	--- Events ---
	--------------

function SD:PLAYER_LEVEL_UP(event, level)
	playerLevel = level
	playerDinged, filterPlayed = true, true
	RequestTimePlayed()
end

function SD:TIME_PLAYED_MSG(event, ...)
	TPM_total, TPM_current = ...
	lastPlayed = time()

	if playerDinged then
		playerDinged = false

		local prevTime = char.totalTime[playerLevel-1]
		if prevTime then
			levelTime = TPM_total - prevTime
		else
			-- fall back to less accurate data
			levelTime = TPM_current2 + (TPM_total - TPM_total2)
		end

		char.levelTime[playerLevel] = levelTime
		char.totalTime[playerLevel] = TPM_total

		-- announce stuff
		local text = self:ReplaceText(profile.dingMsg)
		SendChatMessage(text, GetNumPartyMembers() > 0 and "PARTY" or "SAY")
		if profile.GuildAnnounce and IsInGuild() then
			SendChatMessage(text, "GUILD")
		end

		if profile.Screenshot then
			self:ScheduleTimer(function() Screenshot() end, 1)
		end

		-- temporarily pause Stopwatch
		if profile.Stopwatch and playerLevel < 85 and TPM_current < MAX_TIMER_SEC then
			Stopwatch_Pause()
			self:ScheduleTimer(function()
				StopwatchTicker.timer = TPM_current + AddedTime()
				Stopwatch_Play()
			end, 30)
		end
	else
		if profile.Stopwatch then
			if playerLevel < 85 and TPM_current < MAX_TIMER_SEC then
				-- currentTime var isn't updated yet
				StopwatchTicker.timer = TPM_current
			else
				Stopwatch_Clear()
				StopwatchFrame:Hide()
			end
		end
	end

	-- update stuff
	TPM_total2, TPM_current2 = TPM_total, TPM_current
	currentTime = TPM_current + AddedTime()
	totalTime = TPM_total + AddedTime()
	if InterfaceOptionsFrame:IsShown() then
		ACR:NotifyChange("SimpleDing")
	end
end

	-----------------------
	--- Time Formatting ---
	-----------------------

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

local function TimetoString(value)
	local seconds = mod(floor(value), 60)
	local minutes = mod(floor(value/60), 60)
	local hours = mod(floor(value/3600), 24)
	local days = floor(value/86400)

	local fseconds = b:GetText(b:SetFormattedText(D_SECONDS, seconds))
	local fminutes = b:GetText(b:SetFormattedText(D_MINUTES, minutes))
	local fhours = b:GetText(b:SetFormattedText(D_HOURS, hours))
	local fdays = b:GetText(b:SetFormattedText(D_DAYS, days))

	if value >= 86400 then
		return hours > 0 and format("%s, %s", fdays, fhours) or fdays
	elseif value >= 3600 then
		return minutes > 0 and format("%s, %s", fhours, fminutes) or fhours
	elseif value >= 60 then
		return seconds > 0 and format("%s, %s", fminutes, fseconds) or fminutes
	elseif value >= 0 then
		return fseconds
	end
end

	-----------------------
	--- Substitute Text ---
	-----------------------

function SD:ReplaceText(msg, example)
	if not msg then return "[ERROR] No Message" end

	if example then
		msg = msg:gsub("%[[Ll][Ee][Vv][Ee][Ll]%]", "|cffADFF2F"..(playerLevel == MAX_PLAYER_LEVEL and "[Max Level]" or playerLevel + 1).."|r")
		msg = msg:gsub("%[[Tt][Ii][Mm][Ee]%]", "|cff71D5FF"..TimetoString(currentTime).."|r")
		msg = msg:gsub("%[[Tt][Oo][Tt][Aa][Ll]%]", "|cff71D5FF"..TimetoString(totalTime).."|r")
	else 
		msg = msg:gsub("%[[Ll][Ee][Vv][Ee][Ll]%]", playerLevel)
		msg = msg:gsub("%[[Tt][Ii][Mm][Ee]%]", TimetoString(levelTime))
		msg = msg:gsub("%[[Tt][Oo][Tt][Aa][Ll]%]", TimetoString(TPM_total))
	end
	return msg
end

	--------------------------
	--- Guild Member Dings ---
	--------------------------

local cache = {}

local function GetClassColor(class)
	if cache[class] then
		return cache[class]
	else
		local color = RAID_CLASS_COLORS[class]
		cache[class] = format("%02X%02X%02X", color.r*255, color.g*255, color.b*255)
		return cache[class]
	end
end

local cd = 0
local guild, msgcolor = {}, {r=1, g=1, b=1}
local playerName = UnitName("player")
local GetGuildRosterInfo = GetGuildRosterInfo

function SD:GUILD_ROSTER_UPDATE()
	if time() > cd then -- throttle
		cd = time() + 2
		if IsInGuild() and profile.GuildMemberDings then
			for i = 1, GetNumGuildMembers() do
				local name, _, _, level, _, _, _, _, _, _, englishClass = GetGuildRosterInfo(i)
				-- sanity checks
				if name and guild[name] and level > guild[name] and name ~= playerName then
					RaidNotice_AddMessage(RaidWarningFrame, format("|cff%s%s|r dinged %s |cffADFF2F%s|r", GetClassColor(englishClass), name, LEVEL, level), msgcolor)
				end
				guild[name] = level
			end
		end
	end
end

	----------------------
	--- Filter /played ---
	----------------------

local oldChatFrame_DisplayTimePlayed = ChatFrame_DisplayTimePlayed

function ChatFrame_DisplayTimePlayed(...)
	-- using /played manually should still work
	if not filterPlayed then
		oldChatFrame_DisplayTimePlayed(...)
	end
	filterPlayed = false
end

	---------------------
	--- LibDataBroker ---
	---------------------

local TIME_PLAYED_TOTAL_TEXT = gsub(TIME_PLAYED_TOTAL, "%%s", "")
local TIME_PLAYED_LEVEL_TEXT = gsub(TIME_PLAYED_LEVEL, "%%s", "")

local function TooltipXPline()
	local curxp = UnitXP("player")
	local maxxp = UnitXPMax("player")
	return format("|cffADFF2F%d|r / |cff71D5FF%d|r = |cffADFF2F%d%%|r", curxp, maxxp, (curxp/maxxp)*100)
end

local dataobject = {
	type = playerLevel < 85 and "data source" or "launcher",
	icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
	OnClick = function(clickedframe, button)
		if InterfaceOptionsFrame:IsShown() and InterfaceOptionsFramePanelContainer.displayedPanel.name == NAME then
			InterfaceOptionsFrame:Hide()
		else
			InterfaceOptionsFrame_OpenToCategory(SD.optionsFrame)
		end
	end,
	OnTooltipShow = function(tt)
		tt:AddLine("|cffFFFFFF"..NAME.."|r")
		tt:AddDoubleLine(EXPERIENCE_COLON, TooltipXPline())
		tt:AddDoubleLine(TIME_PLAYED_LEVEL_TEXT, format("|cffFFFFFF"..TIME_DAYHOURMINUTESECOND.."|r", unpack( {ChatFrame_TimeBreakDown(currentTime)} )))
		tt:AddDoubleLine(TIME_PLAYED_TOTAL_TEXT, format("|cffFFFFFF"..TIME_DAYHOURMINUTESECOND.."|r", unpack( {ChatFrame_TimeBreakDown(TPM_total + AddedTime())} )))
		tt:AddLine("|cffFFFFFFClick|r to open the options menu")
	end,
}

local function TimetoMilitaryTime(value)
	local seconds = mod(floor(value), 60)
	local minutes = mod(floor(value/60), 60)
	local hours = mod(floor(value/3600), 24)
	local days = floor(value/86400)

	if days > 0 then
		return format("%s:%02.f:%02.f:%02.f", days, hours, minutes, seconds)
	elseif hours > 0 then
		return format("%s:%02.f:%02.f", hours, minutes, seconds)
	else
		return format("%02.f:%02.f   ", minutes, seconds)
	end
end

if playerLevel < 85 then
	SD:ScheduleRepeatingTimer(function()
		dataobject.text = TimetoMilitaryTime(TPM_current + AddedTime())
	end, 1)
else
	dataobject.text = NAME
end

LibStub("LibDataBroker-1.1"):NewDataObject("SimpleDing", dataobject)