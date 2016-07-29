local _, S = ...

local L = {
	deDE = {
		MSG_PLAYER_DING = "Ding! Stufe <LEVEL> in <TIME>",
	},
	enUS = {
		MSG_PLAYER_DING = TUTORIAL_TITLE55.." "..LEVEL.." <LEVEL> in <TIME>",
	},
	esES = {
		MSG_PLAYER_DING = "Ding! Nivel <LEVEL> en <TIME>",
	},
	esMX = {
	},
	frFR = {
	},
	itIT = {
	},
	koKR = {
		MSG_PLAYER_DING = "두둥! <LEVEL> 레벨까지 <TIME> 소요",
	},
	ptBR = {
	},
	ruRU = {
	},
	zhCN = {
		MSG_PLAYER_DING = "升级! 等级 <LEVEL> 使用 <TIME>",
	},
	zhTW = {
		MSG_PLAYER_DING = "升級! 等級 <LEVEL> 使用 <TIME>",
	},
}

L.esMX = L.esES -- esMX is empty

S.L = setmetatable(L[GetLocale()] or L.enUS, {__index = function(t, k)
	local v = rawget(L.enUS, k) or k
	rawset(t, k, v)
	return v
end})
