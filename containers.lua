local addonName, _ = 'Stacked'
local addon = _G[addonName]
local L = addon.L

-- GLOBALS: LINK_STYLE_DEFAULT, BAG_BANK, KEYBIND_STRIP, ZO_GuildBank
-- GLOBALS: GetSlotStackSize, ClearCursor, LocalizeString, CallSecureProtected, GetBagInfo, GetItemLink, GetMaxBags, IsItemConsumable, ZO_LinkHandler_ParseLink, GetItemInstanceId
-- GLOBALS: string, pairs, tonumber

local function GetSlotText(bag, slot)
	local result = (bag == BAG_BACKPACK and L'backpack')
		or (bag == BAG_BANK and L'bank')
		or 'unknown'
	if slot and addon.db.showSlot then
		result = L('bag slot number', result, slot)
	end
	return result
end
addon.GetSlotText = GetSlotText

local function MoveItem(fromBag, fromSlot, toBag, toSlot, count, silent)
	count = count or GetSlotStackSize(fromBag, fromSlot)

	local success
	if CallSecureProtected('PickupInventoryItem', fromBag, fromSlot, count) then
		success = CallSecureProtected('PlaceInInventory', toBag, toSlot)
	end

	if addon.db.showMessages and not silent then
		local itemLink = GetItemLink(fromBag, fromSlot, LINK_STYLE_DEFAULT)
		local template = success and 'moved item' or 'failed moving item'
		if fromBag == toBag then
			if addon.db.showSlot then
				template = success and 'stacked item' or 'failed stacking item'
			else
				template = success and 'stacked item in container' or 'failed stacking item in container'
				count = count + (GetSlotStackSize(toBag, toSlot))
			end
		end
		addon.Print( L(template, itemLink, count, GetSlotText(fromBag, fromSlot), GetSlotText(toBag, toSlot)) )
	end

	-- clear the cursor to avoid issues
	ClearCursor()
end

local positions = {}
function addon.StackContainer(bag, itemKey, silent)
	local _, numSlots = GetBagInfo(bag)
	for slot = 0, numSlots do
		local itemLink = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
		local itemID, key
		if itemLink then
			_, _, _, itemID = ZO_LinkHandler_ParseLink(itemLink)
			itemID = itemID and tonumber(itemID)
			key = GetItemInstanceId(bag, slot)
		end

		-- don't touch if slot is empty or item is excluded
		if itemID and not addon.db.exclude[itemID] then
			local count, stackSize = GetSlotStackSize(bag, slot)
			local total = count
			if itemLink and count < stackSize then
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
	local moveTarget = addon.GetSetting('moveTarget')
	if moveTarget == L'bank' then
		-- to put items into bank, we need different traversal
		firstBag = lastBag
		lastBag = 1
		direction = -1
	end

	addon.wipe(positions)
	for bag = firstBag, lastBag, direction do
		-- check if this bag may be stacked but still allow manual stacking (/stack or keybind)
		if addon.GetSetting('stackContainer'..bag) or not event then
			addon.StackContainer(bag)
		end

		if (bag == BAG_BACKPACK and moveTarget ~= L'backpack')
			or (bag == BAG_BANK and moveTarget ~= L'bank') then
			for key, position in pairs(positions) do
				if position.bag == bag then
					addon.wipe(positions[key])
					positions[key] = nil
				end
			end
		end
	end
end

addon.slashCommandHelp = (addon.slashCommandHelp or '') .. '\n' .. L'/stack'
SLASH_COMMANDS['/stack'] = CheckRestack
table.insert(addon.bindings, {
	name = L'Stack',
	keybind = 'STACKED_STACK',
	callback = CheckRestack
})

local em = GetEventManager()
em:RegisterForEvent(addonName, EVENT_TRADE_SUCCEEDED, function() CheckRestack('EVENT_TRADE_SUCCEEDED') end)
em:RegisterForEvent(addonName, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, function() CheckRestack('EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS') end)
em:RegisterForEvent(addonName, EVENT_OPEN_BANK, function() CheckRestack('EVENT_OPEN_BANK') end)

local function UpdateKeybindButtons(self, hidden)
	if hidden then
		KEYBIND_STRIP:RemoveKeybindButtonGroup(addon.bindings)
	else
		KEYBIND_STRIP:AddKeybindButtonGroup(addon.bindings)
	end
end
ZO_PreHook(ZO_PlayerInventory, 'SetHidden', UpdateKeybindButtons)
ZO_PreHook(ZO_PlayerBank, 'SetHidden', UpdateKeybindButtons)
