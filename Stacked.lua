local addonName, addon, _ = 'Stacked', {}

-- GLOBALS: ZO_SavedVars, SLASH_COMMANDS, LINK_STYLE_DEFAULT, BAG_WORN, BAG_BACKPACK, BAG_BANK, BAG_GUILDBANK, BAG_BUYBACK, BAG_TRANSFER
-- GLOBALS: GetSlotStackSize, GetItemLink, CallSecureProtected, ClearCursor, GetMaxBags, GetBagInfo
-- GLOBALS: string, math, pairs, d, select, tostring

local function print(...)
	local result
	for i = 1, select('#', ...) do
		local value = select(i, ...)
		result = (result and result..' ' or '') .. tostring(value)
	end
	d(result or '')
end

local function CleanText(text)
	return string.gsub(text or '', '(\^[^ |:]+)', '')
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

	if addon.db.showMessages then
		-- "|HFFFFFF:item:45847:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|hTaderi^N|h"
		local itemLink = GetItemLink(fromBag, fromSlot, LINK_STYLE_DEFAULT)
		print('Moved', CleanText(itemLink), 'from', GetSlotText(fromBag, fromSlot), 'to', GetSlotText(toBag, toSlot))
	end

	local success
	if CallSecureProtected('PickupInventoryItem', fromBag, fromSlot, count) then
		success = CallSecureProtected('PlaceInInventory', toBag, toSlot)
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
			local itemID = link and link:match('item:(%d+)')

			local count, stackSize = GetSlotStackSize(bag, slot)
			local total = count
			if link and count < stackSize then
				if positions[itemID] then
					total = total + positions[itemID].count
					local success = MoveItem(bag, slot, positions[itemID].bag, positions[itemID].slot, count)
					if success and total > stackSize then
						positions[itemID].bag = bag
						positions[itemID].slot = slot
						positions[itemID].count = total - stackSize
					end
				else
					-- first time encountering this item
					positions[itemID] = {
						bag = bag,
						slot = slot,
						count = count,
					}
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

	addon.db = ZO_SavedVars:New(addonName..'DB', 1, nil, {
		-- default settings
		stackToBank = true,
		showMessages = true,
	})

	_G[addonName] = addon

	SLASH_COMMANDS['/stacked'] = function(arg)
		if arg == '' or arg == 'help' then
			d('Stacked help:'
				..'\n  "/stack" to start the stacking algorithm'
				..'\n  "/stacked stackToBank true" to stack to bank, false to stack to bags'
				..'\n  "/stacked showMessages true" to show, false to hide movement notices')
			return
		end

		local option, value = string.match(arg, '([%d%a]+)%s*(.*)')
		if addon.db[option] ~= nil then
			-- TODO: only supports boolean for now
			addon.db[option] = (value and value ~= 'false') and true or false
		end
	end
	SLASH_COMMANDS['/stack'] = CheckRestack

	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_TRADE_SUCCEEDED, CheckRestack)
	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_OPEN_BANK, CheckRestack)
	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, CheckRestack)

	CheckRestack()
end
EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, Initialize)
