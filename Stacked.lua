local addonName, addon, _ = 'Stacked', {}

-- GLOBALS: _G, LibStub, ZO_SavedVars, SLASH_COMMANDS, EVENT_TRADE_SUCCEEDED, EVENT_OPEN_BANK, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, LINK_STYLE_DEFAULT, ITEM_LINK_TYPE, BAG_WORN, BAG_BACKPACK, BAG_BANK, BAG_GUILDBANK, BAG_BUYBACK, BAG_TRANSFER
-- GLOBALS: GetSlotStackSize, GetItemLink, CallSecureProtected, ClearCursor, GetMaxBags, GetBagInfo, LocalizeString, GetString, ZO_LinkHandler_CreateLink, ZO_LinkHandler_ParseLink, d, info
-- GLOBALS: string, math, pairs, select, tostring, type

local em = GetEventManager()
-- /script d(coroutine)

local function Print(format, ...)
	if type(info) == 'function' then
		info(format, ...)
	elseif type(format) == 'string' then
		d(format:format(...))
	else
		d(format, ...)
	end
end
local function CleanText(text)
	return LocalizeString('<<1>>', text) -- string.gsub(text or '', '(\^[^ :\124]+)', '')
end

local guildBankName = (GetString(1891)):gsub(GetString(790), '(.+)')
      guildBankName = (GetString(1262)):match(guildBankName)
local bagNames = {
	-- [BAG_WORN] = 'Equipped',
	[BAG_BACKPACK] = GetString(2258) or 'Backpack',
	[BAG_BANK] = GetString(790) or 'Bank',
	[BAG_GUILDBANK] = guildBankName or 'Guild Bank',
	-- [BAG_BUYBACK] = 'Buy Back',
	-- [BAG_TRANSFER] = 'Transfer',
}
local function GetSlotText(bag, slot)
	local result = bagNames[bag]
	if slot then
		result = string.format('%s (Slot %d)', result, slot)
	end
	return result
end

local function GetLinkFromID(linkID, linkType)
	local stub = string.rep(':0', 19)
	return ZO_LinkHandler_CreateLink(linkID, nil, linkType or ITEM_LINK_TYPE, linkID .. stub)
end

local function wipe(object)
	if not object or type(object) ~= 'table' then return end
	for key, value in pairs(object) do
		wipe(value)
		object[key] = nil
	end
	return object
end
local function isNumber(text) return text:match("^(-?%d-%.*%d-)$") end

-- --------------------------------------------------------
--  Settings
-- --------------------------------------------------------
local function GetSetting(setting)
	local value = addon.db and addon.db[setting]
	if value == nil then return end

	if type(value) == 'table' then
		local list = ''
		for k, v in pairs(value) do
			local val = v
			if v == true then
				val = k
			else
				val = string.format('%s: %s', k, tostring(v))
			end
			list = (list ~= '' and list..'\n' or '') .. val
		end
		return list
	else
		return value
	end
end
local function SetSetting(setting, value)
	local old = addon.db and addon.db[setting]
	if old == nil then return end

	if type(old) == 'table' then
		-- remove all entries (will be re-added if needed)
		wipe(old)

		local lines = '([^\n\r]+)' -- (:%s+)?([^\n\r]*)' -- '([^:\n]+)%s*([^\n]+)'
		for k in value:gmatch(lines) do
			local v
			local separator, suffix = k:find(':%s+')
			if separator then
				-- value is supplied
				v = k:sub(suffix+1)
				k = k:sub(0, separator-1)
				v = zo_strtrim(v)
			end

			if not isNumber(k) then
				_, _, _, k = ZO_LinkHandler_ParseLink(k)
			end

			if v == nil or v == '' then v = true
			elseif v == 'true' then v = true
			elseif v == 'false' or v == 'nil' then v = false
			elseif isNumber(v) then v = tonumber(v)
			end
			-- store entries
			old[k] = v
		end
	else
		addon.db[setting] = value
	end
end
local function CreateSettings()
	local LAM = LibStub('LibAddonMenu-1.0')
	local panel = LAM:CreateControlPanel(addonName..'Settings', addonName)

	local descFormat = 'Enable stacking of items in your %s'
	LAM:AddHeader(panel, addonName..'HeaderContainers', CleanText(GetString(512)))
	for bag, name in ipairs(bagNames) do
		LAM:AddCheckbox(panel, addonName..'ToggleContainer'..bag,
			name, descFormat:format(name),
			function() return GetSetting('stackContainer'..bag) end,
			function(value) SetSetting('stackContainer'..bag, value) end
		)
	end

	LAM:AddHeader(panel, addonName..'HeaderEvents', GetString(810))
	LAM:AddCheckbox(panel, addonName..'ToggleTrade',
		GetString(2073), 'Enable stacking after a trade was completed.',
		function() return GetSetting('trade') end, function(value) SetSetting('trade', value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleMail',
		GetString(2014), 'Enable stacking after retrieving mail attachments.',
		function() return GetSetting('mail') end, function(value) SetSetting('mail', value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleBank',
		bagNames[BAG_BANK], 'Enable stacking when opening your bank.',
		function() return GetSetting('bank') end, function(value) SetSetting('bank', value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleGuildBank',
		GetString(2380), 'Enable stacking when opening your guild bank.',
		function() return GetSetting('guildbank') end, function(value) SetSetting('guildbank', value) end)

	LAM:AddHeader(panel, addonName..'HeaderGeneral', GetString(2539))
	LAM:AddCheckbox(panel, addonName..'ToggleMessages',
		GetString(19), 'Enable chat output when an item has been moved.',
		function() return GetSetting('showMessages') end, function(value) SetSetting('showMessages', value) end)
	LAM:AddDropdown(panel, addonName..'MoveTarget',
		'Merge stacks into', 'Select where items should be moved when different locations contain partial stacks.',
		{'None', bagNames[BAG_BACKPACK], bagNames[BAG_BANK]},
		function(...) return GetSetting('moveTarget') end, function(value) SetSetting('moveTarget', value) end)
	LAM:AddEditBox(panel, addonName..'Exclude',
		GetString(152), 'Add items that should not be touched when restacking, one itemID or itemLink per line',
		true,
		function() return GetSetting('exclude') end, function(value) SetSetting('exclude', value) end)
	LAM:AddDescription(panel, addonName..'ExcludeDesc', 'Add a new line with either the item\'s ID or the item\'s link by using "'..GetString(1796)..'"" and copying it into this text box.\nDon\'t know which item an id represents? Use "/stacked list" to get clickable links of all excluded items.', nil)
end

-- --------------------------------------------------------
--  Stack items together after trading
-- --------------------------------------------------------
local function MoveItem(fromBag, fromSlot, toBag, toSlot, count)
	count = count or GetSlotStackSize(fromBag, fromSlot)

	-- TransferToGuildBank(sourceBag, sourceSlot) / TransferFromGuildBank(slotId)

	local success
	if CallSecureProtected('PickupInventoryItem', fromBag, fromSlot, count) then
		success = CallSecureProtected('PlaceInInventory', toBag, toSlot)
	end

	if addon.db.showMessages then
		local itemLink = GetItemLink(fromBag, fromSlot, LINK_STYLE_DEFAULT)
		local template = success and 'Moved %s x%d from %s to %s' or 'Failed to move %s x%d from %s to %s'
		Print(template, CleanText(itemLink), count, GetSlotText(fromBag, fromSlot), GetSlotText(toBag, toSlot))
	end

	-- clear the cursor to avoid issues
	ClearCursor()
end
local positions = {}
local function CheckRestack(event)
	if (event == 'EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS' and not GetSetting('mail'))
		or (event == 'EVENT_TRADE_SUCCEEDED' and not GetSetting('trade'))
		or (event == 'EVENT_OPEN_BANK' and not GetSetting('bank'))
		or (event == 'EVENT_GUILD_BANK_ITEMS_READY' and not GetSetting('guildbank')) then
		return
	end

	wipe(positions)
	local firstBag, lastBag, direction = 1, GetMaxBags(), 1
	if GetSetting('moveTarget') == bagNames[BAG_BANK] then
		-- to put items into bank, we need different traversal
		firstBag = lastBag
		lastBag = 1
		direction = -1
	end

	for bag = firstBag, lastBag, direction do
		local hasAccess = true
		if bag == BAG_GUILDBANK then
			-- TODO: check DoesPlayerHaveGuildPermission(GetSelectedGuildBankId(), )
			hasAccess = not ZO_GuildBank:IsHidden()
		elseif bag == BAG_BANK then
			hasAccess = not ZO_PlayerBank:IsHidden()
		end

		if GetSetting('stackContainer'..bag) and hasAccess then
			local icon, numSlots = GetBagInfo(bag)
			for slot = 0, numSlots do
				local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
				local itemID, level
				if link then
					-- linkName, color, linkType, linkID
					_, _, _, itemID, _, level = ZO_LinkHandler_ParseLink(link)
					itemID = itemID and tonumber(itemID)
				end

				if itemID and not addon.db.exclude[itemID] then
					-- don't touch excluded items
					local count, stackSize = GetSlotStackSize(bag, slot)
					local total = count
					if link and count < stackSize then
						local key = level and (itemID..':'..level) or itemID
						local data = positions[key]
						if data then
							total = total + data.count
							local success = MoveItem(bag, slot, data.bag, data.slot, count)
							if success and total > stackSize then
								data.bag = bag
								data.slot = slot
								data.count = total - stackSize
							end
						else
							-- first time encountering this item
							positions[key] = {
								bag = bag,
								slot = slot,
								count = count,
							}
						end
					end
				end
			end

			if GetSetting('moveTarget') ~= bagNames[bag] then
				-- don't stack from other containers into this one
				for key, position in pairs(positions) do
					if position.bag == bag then
						wipe(positions[key])
						positions[key] = nil
					end
				end
			end
		end
	end
end

-- --------------------------------------------------------
--  Setup
-- --------------------------------------------------------
local function CreateSlashCommands()
	SLASH_COMMANDS['/stacked'] = function(arg)
		if arg == '' or arg == 'help' then
			Print('Stacked command help:'
				..'\n  "|cFFFFFF/stack|r" to start stacking manually'
				..'\n  "|cFFFFFF/stacked stackToBank|r |cFF8040true|r" to stack to bank, |cFF8040false|r to stack to bags'
				..'\n  "|cFFFFFF/stacked showMessages|r |cFF8040true|r" to show, |cFF8040false|r to hide movement notices'
				..'\n  "|cFFFFFF/stacked list|r" to list all items excluded from stacking'
				..'\n  "|cFFFFFF/stacked exclude|r |cFF80401234|r" to exclude the item with id 1234'
				..'\n  "|cFFFFFF/stacked include|r |cFF80401234|r" to re-include the item with id 1234')
			return
		end

		local option, value = string.match(arg, '([%d%a]+)%s*(.*)')
		local optionType = type(addon.db[option])
		if type(addon.db[option]) == 'boolean' then
			addon.db[option] = (value and value ~= 'false') and true or false
			Print('Stacked option "%s" is now set to %s', option, value)
		elseif option == 'list' or (option == 'exclude' and not value) then
			local list = ''
			for itemID, _ in pairs(addon.db.exclude) do
				list = (list ~= '' and list..', ' or '') .. GetLinkFromID(itemID)
			end
			Print('Stacked excludes %s', list ~= '' and list or 'no items')
		elseif option == 'exclude' then
			local _, _, _, itemID = ZO_LinkHandler_ParseLink(value)
			if itemID then value = itemID end

			if not value or value == '' then return end
			addon.db.exclude[value] = true
			Print('Stacked now excludes item %s', GetLinkFromID(value))
		elseif option == 'include' then
			local _, _, _, itemID = ZO_LinkHandler_ParseLink(value)
			if itemID then value = itemID end

			if not value or value == '' then return end
			addon.db.exclude[value] = nil
			Print('Stacked no longer excludes %s', GetLinkFromID(value))
		end
	end
	SLASH_COMMANDS['/stack'] = CheckRestack
end
local function Initialize(eventCode, arg1, ...)
	if arg1 ~= addonName then return end

	-- addon.db = ZO_SavedVars:NewAccountWide(addonName..'DB', 1, nil, {
	addon.db = ZO_SavedVars:New(addonName..'DB', 2, nil, {
		-- default settings
		showMessages = true,
		moveTarget = 'None',
		exclude = {
			[30357] = true, -- lockpicks, item links seem broken
		},
		-- containers
		['stackContainer'..BAG_BACKPACK] = true,
		['stackContainer'..BAG_BANK] = true,
		['stackContainer'..BAG_GUILDBANK] = true,
		-- events
		trade = true,
		mail = true,
		bank = true,
		guildbank = true,
	})

	_G[addonName] = addon

	CreateSlashCommands()
	CreateSettings()

	em:RegisterForEvent(addonName, EVENT_TRADE_SUCCEEDED, function() CheckRestack('EVENT_TRADE_SUCCEEDED') end)
	em:RegisterForEvent(addonName, EVENT_OPEN_BANK, function() CheckRestack('EVENT_OPEN_BANK') end)
	em:RegisterForEvent(addonName, EVENT_GUILD_BANK_ITEMS_READY, function() CheckRestack('EVENT_GUILD_BANK_ITEMS_READY') end)
	em:RegisterForEvent(addonName, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, function() CheckRestack('EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS') end)
end
em:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, Initialize)
