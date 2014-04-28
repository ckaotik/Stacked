local addonName, _ = 'Stacked'
local addon = _G[addonName]
local L = addon.L

-- GLOBALS: LINK_STYLE_DEFAULT, BAG_BANK
-- GLOBALS: GetSlotStackSize, ClearCursor, LocalizeString, CallSecureProtected, GetBagInfo, GetItemLink, GetMaxBags, IsItemConsumable, ZO_LinkHandler_ParseLink
-- GLOBALS: string, pairs, tonumber

local function GetSlotText(bag, slot)
	local result = addon.bagNames[bag]
	if slot and addon.db.showSlot then
		result = string.format('%s (Slot %d)', result, slot)
	end
	return result
end

local function MoveItem(fromBag, fromSlot, toBag, toSlot, count, silent)
	count = count or GetSlotStackSize(fromBag, fromSlot)

	local success
	if CallSecureProtected('PickupInventoryItem', fromBag, fromSlot, count) then
		success = CallSecureProtected('PlaceInInventory', toBag, toSlot)
	end

	if addon.db.showMessages and not silent then
		local itemLink = GetItemLink(fromBag, fromSlot, LINK_STYLE_DEFAULT)
		local template = success and 'Moved <<C:2*1>> from <<3>> to <<4>>' or 'Failed to move <<2*1>> from <<3>> to <<4>>'
		if fromBag == toBag then
			if addon.db.showSlot then
				template = success and 'Stacked <<C:2*1>> from <<3>> to <<4>>' or 'Failed to stack <<2*1>> from <<3>> to <<4>>'
			else
				template = success and 'Stacked <<C:2*1>> in <<4>>' or 'Failed to stack <<2*1>> in <<4>>'
			end
		end
		addon.Print( LocalizeString(template, itemLink, count, GetSlotText(fromBag, fromSlot), GetSlotText(toBag, toSlot)) )
	end

	-- clear the cursor to avoid issues
	ClearCursor()
end

local positions = {}
function addon.StackContainer(bag, itemKey, silent)
	-- check if this bag may be stacked
	if not addon.GetSetting('stackContainer'..bag) then return end

	local icon, numSlots = GetBagInfo(bag)
	for slot = 0, numSlots do
		local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
		local itemID, key
		if link then
			local level, uniqueID
			_, _, _, itemID, _, level, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, uniqueID = ZO_LinkHandler_ParseLink(link)
			itemID = itemID and tonumber(itemID)
			key = addon.GetKey(itemID, level, uniqueID, IsItemConsumable(bag, slot))
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
	if (event == 'EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS' and not addon.GetSetting('mail'))
		or (event == 'EVENT_TRADE_SUCCEEDED' and not addon.GetSetting('trade'))
		or (event == 'EVENT_OPEN_BANK' and not addon.GetSetting('bank')) then
		return
	end

	local firstBag, lastBag, direction = 1, GetMaxBags(), 1
	if addon.GetSetting('moveTarget'..BAG_BANK) then
		-- to put items into bank, we need different traversal
		firstBag = lastBag
		lastBag = 1
		direction = -1
	end

	addon.wipe(positions)
	for bag = firstBag, lastBag, direction do
		addon.StackContainer(bag)

		if not addon.GetSetting('moveTarget'..bag) then
			-- don't stack from other containers into this one
			for key, position in pairs(positions) do
				if position.bag == bag then
					addon.wipe(positions[key])
					positions[key] = nil
				end
			end
		end
	end
end

local em = GetEventManager()
em:RegisterForEvent(addonName, EVENT_TRADE_SUCCEEDED, function() CheckRestack('EVENT_TRADE_SUCCEEDED') end)
em:RegisterForEvent(addonName, EVENT_OPEN_BANK, function() CheckRestack('EVENT_OPEN_BANK') end)
em:RegisterForEvent(addonName, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, function() CheckRestack('EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS') end)

addon.slashCommandHelp = (addon.slashCommandHelp or '') .. '\n  "|cFFFFFF/stack|r" to start stacking manually'
SLASH_COMMANDS['/stack'] = addon.CheckRestack
