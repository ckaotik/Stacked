local addonName, addon, _ = 'Stacked', {}
_G[addonName] = addon

-- GLOBALS: _G, LibStub, ZO_SavedVars, SLASH_COMMANDS, LINK_STYLE_DEFAULT, ITEM_LINK_TYPE, BAG_WORN, BAG_BACKPACK, BAG_BANK, BAG_GUILDBANK, BAG_BUYBACK, BAG_TRANSFER, SI_TOOLTIP_ITEM_NAME
-- GLOBALS: EVENT_TRADE_SUCCEEDED, EVENT_OPEN_BANK, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, EVENT_CLOSE_GUILD_BANK, EVENT_GUILD_BANK_ITEMS_READY, EVENT_GUILD_BANK_ITEM_ADDED, EVENT_GUILD_BANK_ITEM_REMOVED
-- GLOBALS: GetSlotStackSize, GetItemLink, CallSecureProtected, ClearCursor, GetMaxBags, GetBagInfo, LocalizeString, GetString, ZO_LinkHandler_CreateLink, ZO_LinkHandler_ParseLink, TransferToGuildBank, TransferFromGuildBank, GetSelectedGuildBankId, DoesPlayerHaveGuildPermission, CheckInventorySpaceSilently, GetNextGuildBankSlotId, SplitString, IsItemConsumable
-- GLOBALS: string, math, pairs, select, tostring, type, table, tonumber, ipairs, zo_strformat, zo_strtrim, d, info

function addon.wipe(object)
	if not object or type(object) ~= 'table' then return end
	for key, value in pairs(object) do
		addon.wipe(value)
		object[key] = nil
	end
	return object
end

function addon.Print(format, ...)
	if type(info) == 'function' then
		info(format, ...)
	elseif type(format) == 'string' then
		d(format:format(...))
	else
		d(format, ...)
	end
end

addon.bindings = { alignment = KEYBIND_STRIP_ALIGN_LEFT }
ZO_CreateStringId('SI_BINDING_NAME_STACKED_STACK', 'Stack')

-- --------------------------------------------------------
--  Setup
-- --------------------------------------------------------
local function Initialize(eventCode, arg1, ...)
	if arg1 ~= addonName then return end

	-- TODO: split settings & pull from their modules
	addon.db = ZO_SavedVars:New(addonName..'DB', 3, nil, {
		-- default settings
		showMessages = true,
		showSlot = true,
		showGBStackDetail = true,
		exclude = {
			[30357] = true, -- lockpicks
		},

		-- containers
		['stackContainer'..BAG_BACKPACK] = true,
		['stackContainer'..BAG_BANK] = true,
		['stackContainer'..BAG_GUILDBANK..'1'] = false,
		['stackContainer'..BAG_GUILDBANK..'2'] = false,
		['stackContainer'..BAG_GUILDBANK..'3'] = false,
		['stackContainer'..BAG_GUILDBANK..'4'] = false,
		['stackContainer'..BAG_GUILDBANK..'5'] = false,

		-- move stacks
		['moveTarget'..BAG_BACKPACK] = false,
		['moveTarget'..BAG_BANK] = false,
		['moveTarget'..BAG_GUILDBANK] = false, -- applies to any GB with stacking allowed

		-- events
		trade = true,
		mail = true,
		bank = true,
		guildbank = false,
	})

	addon.CreateSlashCommands()
	addon.CreateSettings()
end
GetEventManager():RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, Initialize)
