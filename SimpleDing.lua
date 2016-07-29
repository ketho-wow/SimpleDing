-- Author: Ketho (EU-Boulderfist)
-- License: Public Domain

local NAME, S = ...
local VERSION = GetAddOnMetadata(NAME, "Version")
local BUILD = "Release"

local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")

local L = S.L
local db

	-----------------
	--- Time Vars ---
	-----------------

S.lastPlayed = time()
S.totalTPM, S.curTPM = 0, 0
local curTPM2, totalTPM2

	------------
	--- Rest ---
	------------

local filterPlayed

local crop = ":64:64:4:60:4:60"
local args = {}

	--------------
	--- Player ---
	--------------

S.player = {
	name = UnitName("player"),
	level = UnitLevel("player"),
	maxlevel = MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()],
}
local player = S.player

	--------------
	--- Events ---
	--------------

local events = {
	"PLAYER_LEVEL_UP",
	"TIME_PLAYED_MSG",
	"GUILD_ROSTER_UPDATE",
}

	------------
	--- Time ---
	------------

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
	local sec = floor(v) % 60
	local minute = floor(v/60) % 60
	local hour = floor(v/3600) % 24
	local day = floor(v/86400)
	
	local fsec = format(D_SECONDS, sec)
	local fmin = format(D_MINUTES, minute)
	local fhour = format(D_HOURS, hour)
	local fday = format(D_DAYS, day)
	
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

	---------------
	--- Replace ---
	---------------

local function ReplaceArgs(msg, args)
	for k in gmatch(msg, "%b<>") do
		-- remove <>, make case insensitive
		local s = strlower(gsub(k, "[<>]", ""))
		
		-- escape special characters
		-- a maybe better alternative to %p is "[%%%.%-%+%?%*%^%$%(%)%[%]%{%}]"
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

	---------------------
	--- Slash Command ---
	---------------------

for i, v in ipairs({"sd", "simpleding"}) do
	_G["SLASH_SIMPLEDING"..i] = "/"..v
end

SlashCmdList.SIMPLEDING = function(msg, editbox)
	ACD:Open(NAME)
end

	----------------------
	--- Filter /played ---
	----------------------

local old = ChatFrame_DisplayTimePlayed

function ChatFrame_DisplayTimePlayed(...)
	-- using /played manually should still work, including when it's called by other addons
	-- when filterPlayed is true it will just only filter the next upcoming /played message
	if not filterPlayed then
		old(...)
	end
	filterPlayed = false
end

	---------------
	--- Options ---
	---------------

local defaults = {
	db_version = 0.5, -- update this on savedvars changes
	DingMsg = L.MSG_PLAYER_DING,
}

local options = {
	type = "group",
	name = format("%s |cffADFF2Fv%s|r", NAME, VERSION),
	get = function(i) return db[i[#i]] end,
	set = function(i, v) db[i[#i]] = v end,
	args = {
		inline1 = {
			type = "group", order = 1,
			name = " ",
			inline = true,
			args = {
				ChatGuild = {
					type = "toggle", order = 2,
					width = "full", descStyle = "",
					name = "|TInterface\\Icons\\Ability_Warrior_RallyingCry:16:16:1:0"..crop.."|t  "..GUILD.." "..CHAT_ANNOUNCE,
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

	----------------------
	--- Initialization ---
	----------------------

local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
	self[event](self, ...)
end

local delay = 0

-- wait 3 sec first for any other AddOns that want to request /played too
function f:WaitPlayed(elapsed)
	delay = delay + elapsed
	if delay > 3 then
		if S.totalTPM == 0 then
			filterPlayed = true
			RequestTimePlayed()
		end
		self:SetScript("OnUpdate", nil)
	end
end

function f:ADDON_LOADED(addon)
	if addon ~= NAME then return end
	
	if not SimpleDingDB3 or SimpleDingDB3.db_version ~= defaults.db_version then
		SimpleDingDB3 = defaults
	end
	db = SimpleDingDB3
	db.version = VERSION
	
	ACR:RegisterOptionsTable(NAME, options)
	ACD:AddToBlizOptions(NAME, NAME)
	ACD:SetDefaultSize(NAME, 400, 260)
	
	f:SetScript("OnUpdate", f.WaitPlayed)
	
	for _, v in ipairs(events) do
		self:RegisterEvent(v)
	end
	self:UnregisterEvent("ADDON_LOADED")
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)

	----------------
	--- Level Up ---
	----------------

local playerDinged

function f:PLAYER_LEVEL_UP(level)
	player.level = level -- on another note, UnitLevel is not yet updated
	playerDinged, filterPlayed = true, true
	RequestTimePlayed() -- TIME_PLAYED_MSG
end

function f:TIME_PLAYED_MSG(...)
	S.totalTPM, S.curTPM = ...
	S.lastPlayed = time()
	
	if playerDinged then
		playerDinged = false
		
		-- undinged LevelTime + (dinged TotalTime - undinged TotalTime)
		S.LevelTime = curTPM2 + (S.totalTPM - totalTPM2)
		
		local text = LevelText()
		
		-- party/raid
		local isBattleground = select(2, IsInInstance()) == "pvp"
		SendChatMessage(text, (IsPartyLFG() or isBattleground) and "INSTANCE_CHAT" or IsInRaid() and "RAID" or IsInGroup() and "PARTY" or "SAY")
		
		-- guild
		if db.ChatGuild and IsInGuild() then
			SendChatMessage(text, "GUILD")
		end
		
		-- screenshot
		if db.Screenshot then
			C_Timer.After(1, Screenshot)
		end
	end
	
	-- update for next levelup
	totalTPM2, curTPM2 = S.totalTPM, S.curTPM
end

