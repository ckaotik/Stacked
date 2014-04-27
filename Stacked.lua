local addonName, addon, _ = 'Stacked', {}

-- GLOBALS: _G, LibStub, ZO_SavedVars, SLASH_COMMANDS, LINK_STYLE_DEFAULT, ITEM_LINK_TYPE, BAG_WORN, BAG_BACKPACK, BAG_BANK, BAG_GUILDBANK, BAG_BUYBACK, BAG_TRANSFER, SI_TOOLTIP_ITEM_NAME
-- GLOBALS: EVENT_TRADE_SUCCEEDED, EVENT_OPEN_BANK, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, EVENT_CLOSE_GUILD_BANK, EVENT_GUILD_BANK_ITEMS_READY, EVENT_GUILD_BANK_ITEM_ADDED, EVENT_GUILD_BANK_ITEM_REMOVED
-- GLOBALS: GetSlotStackSize, GetItemLink, CallSecureProtected, ClearCursor, GetMaxBags, GetBagInfo, LocalizeString, GetString, ZO_LinkHandler_CreateLink, ZO_LinkHandler_ParseLink, TransferToGuildBank, TransferFromGuildBank, GetSelectedGuildBankId, DoesPlayerHaveGuildPermission, CheckInventorySpaceSilently, GetNextGuildBankSlotId, d, info
-- GLOBALS: string, math, pairs, select, tostring, type, table, tonumber, ipairs, zo_strformat, zo_strtrim

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
	-- return string.gsub(text or '', '(\^[^ :\124]+)', '')
	-- return LocalizeString('<<1>>', text)
	return zo_strformat(SI_TOOLTIP_ITEM_NAME, text)
end

local bagNames = {
	-- [BAG_WORN] = 'Equipped',
	[BAG_BACKPACK] = GetString(2258) or 'Backpack',
	[BAG_BANK] = GetString(790) or 'Bank',
	[BAG_GUILDBANK] = (GetString(1262)):match((GetString(1891)):gsub(GetString(790), '(.+)')) or 'Guild Bank',
	-- [BAG_BUYBACK] = 'Buy Back',
	-- [BAG_TRANSFER] = 'Transfer',
}
local function GetSlotText(bag, slot)
	local result = bagNames[bag]
	if slot and addon.db.showSlot then
		result = string.format('%s (Slot %d)', result, slot)
	end
	return result
end

-- generate a unique key for indexing in tables
local function GetKey(itemID, level, uniqueID)
	return string.format('%d:%d:%d', itemID or 0, level or 0, uniqueID or 0)
end
local function GetKeyData(key)
	return SplitString(':', key)
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

	local descFormat, bag = 'Enable stacking of items in your %s'
	LAM:AddHeader(panel, addonName..'HeaderContainers', CleanText(GetString(512)))
	bag = BAG_BACKPACK
	LAM:AddCheckbox(panel, addonName..'ToggleContainer'..bag,
		bagNames[bag], descFormat:format(bagNames[bag]),
		function() return GetSetting('stackContainer'..bag) end, function(value) SetSetting('stackContainer'..bag, value) end
	)
	bag = BAG_BANK
	LAM:AddCheckbox(panel, addonName..'ToggleContainer'..bag,
		bagNames[bag], descFormat:format(bagNames[bag]),
		function() return GetSetting('stackContainer'..bag) end, function(value) SetSetting('stackContainer'..bag, value) end
	)
	bag = BAG_GUILDBANK
	for i = 1, 5 do
		LAM:AddCheckbox(panel, addonName..'ToggleContainer'..bag..i,
			bagNames[bag]..' '..i, descFormat:format(bagNames[bag]..' '..i),
			function() return GetSetting('stackContainer'..bag..i) end, function(value) SetSetting('stackContainer'..bag..i, value) end
		)
	end

	LAM:AddHeader(panel, addonName..'HeaderMoveTarget', 'Move to other bag')
	LAM:AddDescription(panel, addonName..'MoveTargetDesc', 'When multiple locations contain the same item in incomplete stacks, those stacks may be merged together into one location.', nil)

	descFormat = 'Enable moving partial stacks into your %s.'
	bag = BAG_BACKPACK
	LAM:AddCheckbox(panel, addonName..'ToggleMoveTarget'..bag,
		bagNames[bag], descFormat:format(bagNames[bag]),
		function() return GetSetting('moveTarget'..bag) end, function(value) SetSetting('moveTarget'..bag, value) end,
		true, ('If enabled make sure to disable %s and %s!'):format(bagNames[BAG_BANK], bagNames[BAG_GUILDBANK])
	)
	bag = BAG_BANK
	LAM:AddCheckbox(panel, addonName..'ToggleMoveTarget'..bag,
		bagNames[bag], descFormat:format(bagNames[bag]),
		function() return GetSetting('moveTarget'..bag) end, function(value) SetSetting('moveTarget'..bag, value) end
	)
	bag = BAG_GUILDBANK
	LAM:AddCheckbox(panel, addonName..'ToggleMoveTarget'..bag,
		bagNames[bag], descFormat:format(bagNames[bag]),
		function() return GetSetting('moveTarget'..bag) end, function(value) SetSetting('moveTarget'..bag, value) end
	)

	LAM:AddHeader(panel, addonName..'HeaderGeneral', GetString(2539))
	LAM:AddCheckbox(panel, addonName..'ToggleMessages',
		GetString(19), 'Enable chat output when an item has been moved.',
		function() return GetSetting('showMessages') end, function(value) SetSetting('showMessages', value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleSlot',
		'Output Slot', 'Enable to add which slot was affected to movement messages.',
		function() return GetSetting('showSlot') end, function(value) SetSetting('showSlot', value) end)
	LAM:AddEditBox(panel, addonName..'Exclude',
		GetString(152), 'Add items that should not be touched when restacking, one itemID or itemLink per line',
		true,
		function() return GetSetting('exclude') end, function(value) SetSetting('exclude', value) end)
	LAM:AddDescription(panel, addonName..'ExcludeDesc', 'Add a new line with either the item\'s ID or the item\'s link by using "'..GetString(1796)..'"" and copying it into this text box.\nDon\'t know which item an id represents? Use "/stacked list" to get clickable links of all excluded items.', nil)
end

-- --------------------------------------------------------
--  Stack items together after trading/retrieving mail/...
-- --------------------------------------------------------
local function MoveItem(fromBag, fromSlot, toBag, toSlot, count, silent)
	count = count or GetSlotStackSize(fromBag, fromSlot)

	local success
	if CallSecureProtected('PickupInventoryItem', fromBag, fromSlot, count) then
		success = CallSecureProtected('PlaceInInventory', toBag, toSlot)
	end

	if addon.db.showMessages and not silent then
		local itemLink = GetItemLink(fromBag, fromSlot, LINK_STYLE_DEFAULT)
		--[[ local template = success and 'Moved %s x%d from %s to %s' or 'Failed to move %s x%d from %s to %s'
		if fromBag == toBag then
			template = success and 'Stacked %s x%d from %s to %s' or 'Failed to stack %s x%d from %s to %s'
		end
		Print(template, CleanText(itemLink), count, GetSlotText(fromBag, fromSlot), GetSlotText(toBag, toSlot)) --]]

		local template = success and 'Moved <<2*1>> from <<3>> to <<4>>' or 'Failed to move <<2*1>> from <<3>> to <<4>>'
		if fromBag == toBag then
			template = success and 'Stacked <<2*1>> from <<3>> to <<4>>' or 'Failed to stack <<2*1>> from <<3>> to <<4>>'
		end
		Print( LocalizeString(template, itemLink, count, GetSlotText(fromBag, fromSlot), GetSlotText(toBag, toSlot)) )
	end

	-- clear the cursor to avoid issues
	ClearCursor()
end

local positions = {}
local function StackContainer(bag, itemKey, silent)
	-- check if this bag may be stacked
	if not GetSetting('stackContainer'..bag) then return end

	local icon, numSlots = GetBagInfo(bag)
	for slot = 0, numSlots do
		local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
		local itemID, key
		if link then
			local _, _, _, itemID, _, level, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, uniqueID = ZO_LinkHandler_ParseLink(link)
			itemID = itemID and tonumber(itemID)
			key = GetKey(itemID, level, uniqueID)
		end

		-- don't touch if slot is empty or item is excluded
		if itemID and not addon.db.exclude[itemID] then
			local count, stackSize = GetSlotStackSize(bag, slot)
			local total = count
			if link and count < stackSize then
				local data = positions[key]

				if itemKey and key ~= itemKey then
					-- do nothing
				elseif data then
					total = total + data.count
					local success = MoveItem(bag, slot, data.bag, data.slot, count, silent)
					-- item was moved
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
end

local function CheckRestack(event)
	if (event == 'EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS' and not GetSetting('mail'))
		or (event == 'EVENT_TRADE_SUCCEEDED' and not GetSetting('trade'))
		or (event == 'EVENT_OPEN_BANK' and not GetSetting('bank')) then
		return
	end

	local firstBag, lastBag, direction = 1, GetMaxBags(), 1
	if GetSetting('moveTarget') == bagNames[BAG_BANK] then
		-- to put items into bank, we need different traversal
		firstBag = lastBag
		lastBag = 1
		direction = -1
	end

	wipe(positions)
	for bag = firstBag, lastBag, direction do
		StackContainer(bag)

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

-- --------------------------------------------------------
--  Stack items in guild bank
-- --------------------------------------------------------
local guildPositions, isStackingGB = {}, false
local currentItemLink, numItemsWithdrawn, numUsedStacks
local function DoGuildBankStacking() end -- forward declaration

local function DepositGuildBankItems(eventID)
	if not currentItemLink then return end

	if not eventID then
		Print('Deposit %s x%d back to guild bank...', CleanText(currentItemLink), numItemsWithdrawn)
	end

	local _, numSlots = GetBagInfo(BAG_BACKPACK)
	for slot = 0, numSlots do
		local itemLink = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
		local count = GetSlotStackSize(BAG_BACKPACK, slot)
		if itemLink == currentItemLink then
			if count < numItemsWithdrawn or GetSetting('moveTarget'..BAG_GUILDBANK) then
				TransferToGuildBank(BAG_BACKPACK, slot)
				numUsedStacks = numUsedStacks - 1
				numItemsWithdrawn = numItemsWithdrawn - count

				-- wait for event EVENT_GUILD_BANK_ITEM_ADDED
				return
			else
				-- TODO: split stack
				-- ZO_StackSplit, ZO_StackSplitSplit, ZO_StackSplitSpinnerDisplay
				Print('%s x%d was not deposited. Please split this off and deposit manually.')
			end
		end
	end

	Print('Freed %d slot(s).', numUsedStacks)
	currentItemLink = nil
	DoGuildBankStacking()
end
function DoGuildBankStacking(eventID)
	if not isStackingGB then return end

	-- choose an item to restack
	local slot, isNewItem
	for item, slots in pairs(guildPositions) do
		if eventID or not CheckInventorySpaceSilently(1) then
			-- find item that was handled before
			for i, gBankSlot in ipairs(slots) do
				if GetSlotStackSize(BAG_GUILDBANK, gBankSlot) == 0 then
					table.remove(guildPositions[item], i)
					if #guildPositions[item] < 1 then
						-- we're done with this item
						guildPositions[item] = nil

						-- restack in backpack
						StackContainer(BAG_BACKPACK, item, true)
						DepositGuildBankItems()

						-- wait for DepositGuildBankItems to call DoGuildBankStacking
						return
					else
						slot = slots[1]
					end
					break
				end
			end
		else
			-- first item wins
			slot = slots[1]
			isNewItem = true
			break
		end
	end

	if slot then
		local itemLink = GetItemLink(BAG_GUILDBANK, slot, LINK_STYLE_DEFAULT)
		local count, stackSize = GetSlotStackSize(BAG_GUILDBANK, slot)
		if isNewItem then
			Print('Stacking item %s...', CleanText(itemLink))
			currentItemLink = itemLink
			numItemsWithdrawn = 0
			numUsedStacks = 0
		end

		if itemLink ~= '' and count > 0 and count < stackSize then
			TransferFromGuildBank(slot)

			Print('Withdrew %s x%d', CleanText(itemLink), count)
			numItemsWithdrawn = numItemsWithdrawn + count
			numUsedStacks = numUsedStacks + 1

			-- wait for event EVENT_GUILD_BANK_ITEM_REMOVED
			return
		end
	elseif currentItemLink then
		Print('Stacking guild bank completed.')
		isStackingGB = false
		return
	end
end

local function StackGuildBank()
	local guildID = GetSelectedGuildBankId() -- internal id of selected guild
	if isStackingGB or not GetSetting('stackContainer'..BAG_GUILDBANK..guildID) then return end

	if not DoesPlayerHaveGuildPermission(guildID, 15) -- deposit
	  or not DoesPlayerHaveGuildPermission(guildID, 16) then -- withdraw
		Print('You need to have both withdrawal and deposit permissions to restack the guild bank')
		return
	elseif not CheckInventorySpaceSilently(2) then
		Print('You need at least 2 empty bag slots to restack the guild bank.')
		return
	end

	isStackingGB = true
	-- scan guild bank
	wipe(guildPositions)
	local slot = nil
	while true do
		slot = GetNextGuildBankSlotId(slot)
		if not slot then break end

		local itemLink = GetItemLink(BAG_GUILDBANK, slot, LINK_STYLE_DEFAULT)
		local itemID, key
		if itemLink ~= '' then
			local _, _, _, itemID, _, level, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, uniqueID = ZO_LinkHandler_ParseLink(itemLink)
			itemID = itemID and tonumber(itemID)
			key = GetKey(itemID, level, uniqueID)
		end

		-- don't touch if slot is empty or item is excluded
		if itemID and not addon.db.exclude[itemID] then
			local count, stackSize = GetSlotStackSize(BAG_GUILDBANK, slot)
			if count < stackSize then
				-- store location
				if not guildPositions[key] then
					guildPositions[key] = {}
				end
				table.insert(guildPositions[key], slot)
			end
		end
	end

	-- remove items with only one stack
	for key, slots in pairs(guildPositions) do
		if #slots < 2 then
			wipe(slots)
			guildPositions[key] = nil
		end
	end

	DoGuildBankStacking()
end

-- --------------------------------------------------------
--  Setup
-- --------------------------------------------------------
local function CreateSlashCommands()
	SLASH_COMMANDS['/stacked'] = function(arg)
		if arg == '' or arg == 'help' then
			Print('Stacked command help:'
				..'\n  "|cFFFFFF/stack|r" to start stacking manually'
				..'\n  "|cFFFFFF/stackgb|r" to start stacking the guild bank manually'
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
	SLASH_COMMANDS['/stackgb'] = StackGuildBank
end

local em = GetEventManager()
local function Initialize(eventCode, arg1, ...)
	if arg1 ~= addonName then return end

	addon.db = ZO_SavedVars:New(addonName..'DB', 2, nil, {
		-- default settings
		showMessages = true,
		showSlot = true,
		exclude = {
			[30357] = true, -- lockpicks, item links seem broken
		},
		-- containers
		['stackContainer'..BAG_BACKPACK] = true,
		['stackContainer'..BAG_BANK] = true,
		['stackContainer'..BAG_GUILDBANK..'1'] = true,
		['stackContainer'..BAG_GUILDBANK..'2'] = true,
		['stackContainer'..BAG_GUILDBANK..'3'] = true,
		['stackContainer'..BAG_GUILDBANK..'4'] = true,
		['stackContainer'..BAG_GUILDBANK..'5'] = true,
		-- move stacks
		['moveTarget'..BAG_BACKPACK] = false,
		['moveTarget'..BAG_BANK] = false,
		['moveTarget'..BAG_GUILDBANK] = false, -- applies to any GB with stacking allowed
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
	em:RegisterForEvent(addonName, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, function() CheckRestack('EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS') end)

	em:RegisterForEvent(addonName, EVENT_CLOSE_GUILD_BANK, function() isStackingGB = false end)
	em:RegisterForEvent(addonName, EVENT_GUILD_BANK_ITEMS_READY, StackGuildBank)
	em:RegisterForEvent(addonName, EVENT_GUILD_BANK_ITEM_ADDED, function(eventID) DepositGuildBankItems(eventID) end)
	em:RegisterForEvent(addonName, EVENT_GUILD_BANK_ITEM_REMOVED, function(eventID) DoGuildBankStacking(eventID) end)
end
em:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, Initialize)
