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
		MSG_PLAYER_DING = "\235\145\144\235\145\165! <LEVEL> \235\160\136\235\178\168\234\185\140\236\167\128 <TIME> \236\134\140\236\154\148",
	},
	ptBR = {
	},
	ruRU = {
	},
	zhCN = {
	},
	zhTW = {
	},
}

L.esMX = L.esES -- esMX is empty

S.L = setmetatable(L[GetLocale()] or L.enUS, {__index = function(t, k)
	local v = rawget(L.enUS, k) or k
	rawset(t, k, v)
	return v
end})
