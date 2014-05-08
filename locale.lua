local addonName, _ = 'Stacked'
local addon = _G[addonName]

local L = setmetatable({}, {
	__index = function(self, key)
		local text = rawget(self, key)
		return text or key -- and LocalizeString('<<1>>', text)
	end,
	__call = function(self, key, ...)
		local text = rawget(self, key)
		if not text then return key end

		return LocalizeString(text, ...)
	end,
})
addon.L = L

-- default, english strings
-- L['containers'] = GetString(512)
-- L['events'] = GetString(810)
L['backpack'] = GetString(2258)
L['bank'] = GetString(790)
L['guildbank'] = 'guild bank'

L['fromAToB'] = 'From <<1>> to <<2>>'
L['tradeSucceeded'] = GetString(2073):gsub('%.$', '')
L['attachmentsRetrieved'] = GetString(2014)


local locale = GetCVar('Language.2')
if locale == 'de' then
	-- German
	L['guildbank'] = 'Gildenbank'
	L['fromAToB'] = 'Von <<1>> nach <<2>>'
elseif locale == 'fr' then
	-- French
end

-- some shortcuts
L['BAG_'..BAG_BACKPACK] = L['backpack']
L['BAG_'..BAG_BANK] = L['bank']
L['BAG_'..BAG_GUILDBANK] = L['guildbank']
