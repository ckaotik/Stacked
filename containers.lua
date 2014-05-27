local addonName, _ = 'Stacked'
local addon = _G[addonName]
local L = addon.L

-- GLOBALS: LINK_STYLE_DEFAULT, BAG_BANK, KEYBIND_STRIP, ZO_GuildBank
-- GLOBALS: GetSlotStackSize, ClearCursor, LocalizeString, CallSecureProtected, GetBagInfo, GetItemLink, GetMaxBags, IsItemConsumable, ZO_LinkHandler_ParseLink, GetItemInstanceId
-- GLOBALS: string, pairs, tonumber

local function GetSlotText(bag, slot)
	local result = (bag == BAG_BACKPACK and L'backpack')
		or (bag == BAG_BANK and L'bank')
		or (bag == BAG_GUILDBANK and L'guildbank')
		or 'unknown'
	if slot and addon.db.showSlot then
		result = L('bag slot number', result, slot)
	end
	return result
end
addon.GetSlotText = GetSlotText

local function MoveItem(fromBag, fromSlot, toBag, toSlot, count, destCount, silent)
	local sourceCount = count or GetSlotStackSize(fromBag, fromSlot)
	local destCount   = destCount or GetSlotStackSize(toBag, toSlot)

	local success
	if CallSecureProtected('PickupInventoryItem', fromBag, fromSlot, sourceCount) then
		success = CallSecureProtected('PlaceInInventory', toBag, toSlot)
	end

	if addon.db.showMessages and not silent then
		local itemLink = GetItemLink(fromBag, fromSlot, LINK_STYLE_DEFAULT)
		local output
		if fromBag == toBag and not addon.db.showSlot then
			output = L(success and 'stacked item' or 'failed stacking item',
				itemLink, (sourceCount + destCount), GetSlotText(toBag, toSlot), sourceCount, destCount)
		else
			output = L(success and 'moved item' or 'failed moving item',
				itemLink, sourceCount, GetSlotText(fromBag, fromSlot), GetSlotText(toBag, toSlot))
		end
		addon.Print(output)
	end

	-- clear the cursor to avoid issues
	ClearCursor()

	return success
end

local positions = {}
function addon.StackContainer(bag, itemKey, silent, excludeSlots)
	local _, numSlots = GetBagInfo(bag)
	for slot = 0, numSlots do
		local itemLink = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
		local itemID, key
		if itemLink then
			_, _, _, itemID = ZO_LinkHandler_ParseLink(itemLink)
			itemID = itemID and tonumber(itemID)
			key = GetItemInstanceId(bag, slot)
		end

		-- don't touch if slot is empty or item or slot is excluded
		if itemID and not addon.db.exclude[itemID]
			and not (type(excludeSlots) == 'table' and addon.Find(excludeSlots, slot)) then
			local count, stackSize = GetSlotStackSize(bag, slot)
			local total = count
			if itemLink and count < stackSize then
				local data = positions[key]

				if itemKey and key ~= itemKey then
					-- do nothing
				elseif data then
					total = total + data.count
					local success = MoveItem(bag, slot, data.bag, data.slot, count, data.count, silent)
					if not success then
						-- oops, moving failed
					elseif total > stackSize then
						-- dest stack was full, remove, instead use updated source
						data.bag = bag
						data.slot = slot
						data.count = total - stackSize
					else
						-- items fit, update count
						data.count = total
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

	addon.Print(L'stacking completed')
end

-- Events
-----------------------------------------------------------
local em = GetEventManager()
em:RegisterForEvent(addonName, EVENT_TRADE_SUCCEEDED, function() CheckRestack('EVENT_TRADE_SUCCEEDED') end)
em:RegisterForEvent(addonName, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, function() CheckRestack('EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS') end)
em:RegisterForEvent(addonName, EVENT_OPEN_BANK, function() CheckRestack('EVENT_OPEN_BANK') end)

-- Keybindings
-----------------------------------------------------------
addon.slashCommandHelp = (addon.slashCommandHelp or '') .. '\n' .. L'/stack'
SLASH_COMMANDS['/stack'] = CheckRestack
table.insert(addon.bindings, {
	name = L'Stack',
	keybind = 'STACKED_STACK',
	callback = CheckRestack,
	visible = function()
		return not ZO_PlayerBank:IsHidden() or not ZO_PlayerInventory:IsHidden()
	end,
})
-- add keybinds always since inventory does not trigger an event
KEYBIND_STRIP:AddKeybindButtonGroup(addon.bindings)

local inventory_SetHidden = ZO_PlayerInventory.SetHidden
ZO_PlayerInventory.SetHidden = function(...)
	inventory_SetHidden(...)
	KEYBIND_STRIP:UpdateKeybindButtonGroup(addon.bindings)
end
local bank_SetHidden = ZO_PlayerBank.SetHidden
ZO_PlayerBank.SetHidden = function(...)
	bank_SetHidden(...)
	KEYBIND_STRIP:UpdateKeybindButtonGroup(addon.bindings)
end
