local addonName, addon, _ = 'Stacked', {}

-- GLOBALS: ZO_SavedVars, SLASH_COMMANDS, LINK_STYLE_DEFAULT, BAG_WORN, BAG_BACKPACK, BAG_BANK, BAG_GUILDBANK, BAG_BUYBACK, BAG_TRANSFER
-- GLOBALS: GetSlotStackSize, GetItemLink, CallSecureProtected, ClearCursor, GetMaxBags, GetBagInfo
-- GLOBALS: string, math, pairs, d, select, tostring

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
		-- "|HFFFFFF:item:45847:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|hTaderi^N|h"
		local itemLink = GetItemLink(fromBag, fromSlot, LINK_STYLE_DEFAULT)
		local template = success and 'Moved %s from %s to %s' or 'Failed to move %s from %s to %s'
		local text = string.format(template,
			CleanText(itemLink), GetSlotText(fromBag, fromSlot), GetSlotText(toBag, toSlot))
		d(text)
	end

	-- clear the cursor to avoid issues
	ClearCursor()
end
local positions = {}
local function CheckRestack()
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
				itemID, value, level = link:match('item:([^:]+):([^:]+):([^:]+)')
			end

			if itemID and not addon.db.exclude[itemID] then
				-- don't touch excluded items
				local count, stackSize = GetSlotStackSize(bag, slot)
				local total = count
				if link and count < stackSize then
					local key = level and itemID..':'..level or itemID
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

	addon.db = ZO_SavedVars:NewAccountWide(addonName..'DB', 1, nil, {
		-- default settings
		stackToBank = true,
		showMessages = true,
		exclude = {},
	})

	_G[addonName] = addon

	SLASH_COMMANDS['/stacked'] = function(arg)
		if arg == '' or arg == 'help' then
			d('Stacked command help:'
				..'\n  "|cFFFFFF/stack|r" to start the stacking algorithm'
				..'\n  "|cFFFFFF/stacked stackToBank|r |cFF8040true|r" to stack to bank, |cFF8040false|r to stack to bags'
				..'\n  "|cFFFFFF/stacked showMessages|r |cFF8040true|r" to show, |cFF8040false|r to hide movement notices'
				..'\n  "|cFFFFFF/stacked exclude|r |cFF80401234|r" to exclude the item with id 1234'
				..'\n  "|cFFFFFF/stacked include|r |cFF80401234|r" to re-include the item with id 1234')
			return
		end

		local option, value = string.match(arg, '([%d%a]+)%s*(.*)')
		local optionType = type(addon.db[option])
		if type(addon.db[option]) == 'boolean' then
			addon.db[option] = (value and value ~= 'false') and true or false
		elseif option == 'exclude' then
			local itemID, _, level = value:match('item:([^:]+):([^:]+):([^:]+)')
			if itemID then value = itemID end
			addon.db.exclude[value] = true
			d('Stacked now ignores item #'..value)
		elseif option == 'include' then
			local itemID, _, level = value:match('item:([^:]+):([^:]+):([^:]+)')
			if itemID then value = itemID end
			addon.db.exclude[value] = nil
			d('Stacked no longer ignores #'..value)
		end
	end
	SLASH_COMMANDS['/stack'] = CheckRestack

	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_TRADE_SUCCEEDED, CheckRestack)
	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_OPEN_BANK, CheckRestack)
	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, CheckRestack)
end
EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, Initialize)
