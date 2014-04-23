local addonName, addon, _ = 'Stacked', {}

-- GLOBALS: _G, ZO_SavedVars, SLASH_COMMANDS, EVENT_MANAGER, EVENT_TRADE_SUCCEEDED, EVENT_OPEN_BANK, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, LINK_STYLE_DEFAULT, ITEM_LINK_TYPE, BAG_WORN, BAG_BACKPACK, BAG_BANK, BAG_GUILDBANK, BAG_BUYBACK, BAG_TRANSFER
-- GLOBALS: GetSlotStackSize, GetItemLink, CallSecureProtected, ClearCursor, GetMaxBags, GetBagInfo, ZO_LinkHandler_CreateLink, ZO_LinkHandler_ParseLink
-- GLOBALS: string, math, pairs, d, select, tostring, type

local function CleanText(text)
	return string.gsub(text or '', '(\^[^ :\124]+)', '')
end

local bagNames = {
	[BAG_WORN] = 'Equipped',
	[BAG_BACKPACK] = 'Backpack',
	[BAG_BANK] = 'Bank',
	[BAG_GUILDBANK] = 'Guild Bank',
	[BAG_BUYBACK] = 'Buy Back',
	[BAG_TRANSFER] = 'Transfer',
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

-- --------------------------------------------------------
--  Stack items together after trading
-- --------------------------------------------------------
local function MoveItem(fromBag, fromSlot, toBag, toSlot, count)
	count = count or GetSlotStackSize(fromBag, fromSlot)

	local success
	if CallSecureProtected('PickupInventoryItem', fromBag, fromSlot, count) then
		success = CallSecureProtected('PlaceInInventory', toBag, toSlot)
	end

	if addon.db.showMessages then
		local itemLink = GetItemLink(fromBag, fromSlot, LINK_STYLE_DEFAULT)
		local template = success and 'Moved %s x%d from %s to %s' or 'Failed to move %s from %s to %s'
		local text = string.format(template,
			CleanText(itemLink), count, GetSlotText(fromBag, fromSlot), GetSlotText(toBag, toSlot))
		d(text)
	end

	-- clear the cursor to avoid issues
	ClearCursor()
end
local positions = {}
local function CheckRestack(...)
	for link, data in pairs(positions) do
		for k, v in pairs(data) do
			data[k] = nil
		end
		positions[link] = nil
	end

	local direction, firstBag, lastBag
	local maxBags = math.min(BAG_BANK, GetMaxBags())
	if addon.db.stackToBank then
		direction, firstBag, lastBag = -1, maxBags, 1
	else
		direction, firstBag, lastBag = 1, 1, maxBags
	end

	for bag = firstBag, lastBag, direction do
		local icon, numSlots = GetBagInfo(bag)
		for slot = 0, numSlots do
			local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
			local itemID, level
			if link then
				-- linkName, color, linkType, linkID
				_, _, _, itemID, _, level = ZO_LinkHandler_ParseLink(link)
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
	end
end

-- --------------------------------------------------------
--  UI / Saved Vars management
-- --------------------------------------------------------
local function Initialize(eventCode, arg1, ...)
	if arg1 ~= addonName then return end

	-- addon.db = ZO_SavedVars:NewAccountWide(addonName..'DB', 1, nil, {
	addon.db = ZO_SavedVars:New(addonName..'DB', 1, nil, {
		-- default settings
		stackToBank = true,
		showMessages = true,
		exclude = {},

		trade = true,
		mail = true,
		bank = true,
	})

	_G[addonName] = addon

	SLASH_COMMANDS['/stacked'] = function(arg)
		if arg == '' or arg == 'help' then
			d('Stacked command help:'
				..'\n  "|cFFFFFF/stack|r" to start stacking manually'
				..'\n  "|cFFFFFF/stacked stackToBank|r |cFF8040true|r" to stack to bank, |cFF8040false|r to stack to bags'
				..'\n  "|cFFFFFF/stacked showMessages|r |cFF8040true|r" to show, |cFF8040false|r to hide movement notices'
				..'\n  "|cFFFFFF/stacked exclude|r" or "|cFFFFFF/stacked list|r" to list all items excluded from stacking'
				..'\n  "|cFFFFFF/stacked exclude|r |cFF80401234|r" to exclude the item with id 1234'
				..'\n  "|cFFFFFF/stacked include|r |cFF80401234|r" to re-include the item with id 1234')
			return
		end

		local option, value = string.match(arg, '([%d%a]+)%s*(.*)')
		local optionType = type(addon.db[option])
		if type(addon.db[option]) == 'boolean' then
			addon.db[option] = (value and value ~= 'false') and true or false
			d('Stacked option "'..option..'" is now set to '..tostring(value))
		elseif option == 'list' or (option == 'exclude' and not value) then
			local list = ''
			for itemID, _ in pairs(addon.db.exclude) do
				list = (list ~= '' and list..', ' or '') .. GetLinkFromID(itemID)
			end
			d('Stacked excludes '..(list ~= '' and list or 'no items'))
		elseif option == 'exclude' then
			local _, _, _, itemID = ZO_LinkHandler_ParseLink(value)
			if itemID then value = itemID end

			if not value or value == '' then return end
			addon.db.exclude[value] = true
			d('Stacked now excludes item '..GetLinkFromID(value))
		elseif option == 'include' then
			local _, _, _, itemID = ZO_LinkHandler_ParseLink(value)
			if itemID then value = itemID end

			if not value or value == '' then return end
			addon.db.exclude[value] = nil
			d('Stacked no longer excludes '..GetLinkFromID(value))
		end
	end
	SLASH_COMMANDS['/stack'] = CheckRestack

	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_TRADE_SUCCEEDED, CheckRestack)
	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_OPEN_BANK, CheckRestack)
	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, CheckRestack)
end
EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, Initialize)
