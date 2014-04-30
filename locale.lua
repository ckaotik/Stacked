local addonName, _ = 'Stacked'
local addon = _G[addonName]

local locale = GetCVar('Language.2')

-- default, english strings
addon.L = {
	containers = LocalizeString('<<1>>', GetString(512)),
	backpack = GetString(2258),
	bank = GetString(790),
	guildbank = 'guild bank',

	events = GetString(810),
	tradeSucceeded = GetString(2073):gsub('%.$', ''),
	attachmentsRetrieved = GetString(2014),
}

if locale == 'de' then
	-- German
	addon.L['guildbank'] = 'Gildenbank'
elseif locale == 'fr' then
	-- French
end

addon.bagNames = {
	-- [BAG_WORN] = 'Equipped',
	[BAG_BACKPACK] = addon.L['backpack'],
	[BAG_BANK] = addon.L['bank'],
	[BAG_GUILDBANK] = addon.L['guildbank'],
	-- [BAG_BUYBACK] = 'Buy Back',
	-- [BAG_TRANSFER] = 'Transfer',
}
