local addonName, _ = 'Stacked'
local addon = _G[addonName]
local L = addon.L

-- GLOBALS: LINK_STYLE_DEFAULT, BAG_GUILDBANK, BAG_BACKPACK, SI_TOOLTIP_ITEM_NAME, GUILD_PRIVILEGE_BANK_DEPOSIT, KEYBIND_STRIP, ZO_GuildBank
-- GLOBALS: GetItemLink, GetNextGuildBankSlotId, GetSlotStackSize, CheckInventorySpaceSilently, GetBagInfo, ZO_LinkHandler_ParseLink, DoesPlayerHaveGuildPermission, DoesGuildHavePrivilege, TransferToGuildBank, TransferFromGuildBank, GetSelectedGuildBankId, IsItemConsumable, LocalizeString, GetItemInstanceId
-- GLOBALS: tonumber, table, pairs, ipairs, zo_strformat, type, next

local STATE_IDLE, STATE_PREPARE, STATE_MOVING, STATE_STACKING = 0, 1, 2, 3
local state = STATE_IDLE

local guildPositions, bagPositions = {}, {}
local logs = {
	deposit = {},
	withdraw = {},
}

local numFreedSlots = 0
local currentItemLink, numItemsWithdrawn, numUsedStacks

local dataGuildID
local function CanStackGuildBank(guildID)
	local errorMsg
	if not DoesGuildHavePrivilege(guildID, GUILD_PRIVILEGE_BANK_DEPOSIT) then
		errorMsg = L'not enough members'
	elseif not DoesPlayerHaveGuildPermission(guildID, 15) -- deposit
	  or not DoesPlayerHaveGuildPermission(guildID, 16) then -- withdraw
		errorMsg = L'insufficient permissions'
	elseif not CheckInventorySpaceSilently(2) then
		errorMsg = L'inventory full'
	elseif not dataGuildID or dataGuildID ~= guildID then
		errorMsg = L'not available'
	end
	return not errorMsg, errorMsg
end

local function DoGuildBankStacking() end -- forward declaration

local function DepositGuildBankItems(eventID)
	if not currentItemLink then return end
	local moveTarget = addon.GetSetting('moveTargetGB')

	if not eventID and addon.GetSetting('showGBStackDetail') then
		addon.Print(L('deposit item', currentItemLink, numItemsWithdrawn))
	end

	local _, numSlots = GetBagInfo(BAG_BACKPACK)
	for slot = 0, numSlots do
		local itemLink = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
		local count = GetSlotStackSize(BAG_BACKPACK, slot)
		if itemLink == currentItemLink then
			if count <= numItemsWithdrawn or moveTarget == L'guildbank' then
				TransferToGuildBank(BAG_BACKPACK, slot)
				numUsedStacks = numUsedStacks - 1
				numItemsWithdrawn = numItemsWithdrawn - count

				-- wait for event EVENT_GUILD_BANK_ITEM_ADDED
				return
			else
				-- TODO: split stack
				-- ZO_StackSplit, ZO_StackSplitSplit, ZO_StackSplitSpinnerDisplay, ZO_Menu, ZO_Menu_ClickItem
				addon.Print(L('deposit item manually', itemLink, numItemsWithdrawn))
			end
		end
	end

	-- print info about our own moved items
	if numItemsWithdrawn < 0 then
		addon.Print( L('moved item', currentItemLink, -1*numItemsWithdrawn,
			addon.GetSlotText(BAG_BACKPACK), addon.GetSlotText(BAG_GUILDBANK)) )
	end

	numFreedSlots = numFreedSlots + numUsedStacks
	currentItemLink = nil
	DoGuildBankStacking()
end
function DoGuildBankStacking(eventID)
	if state == STATE_IDLE then return end

	-- choose an item to restack
	local slot, newItem
	for item, slots in pairs(guildPositions) do
		if eventID or not CheckInventorySpaceSilently(1) then
			-- find item that was handled before
			for i, gBankSlot in ipairs(slots) do
				if GetSlotStackSize(BAG_GUILDBANK, gBankSlot) == 0 then
					table.remove(guildPositions[item], i)
					if #guildPositions[item] < 1 then
						-- we've taken all stacks of item
						guildPositions[item] = nil

						-- restack in backpack
						addon.StackContainer(BAG_BACKPACK, item, true)

						DepositGuildBankItems()
						-- wait for it to call DoGuildBankStacking again
						return
					else
						slot = slots[1]
						break
					end
				end
			end
			-- found next stack for this item
			if slot then break end
		else
			-- first item wins
			slot = slots[1]
			newItem = item
			break
		end
	end

	if slot then
		local itemLink = GetItemLink(BAG_GUILDBANK, slot, LINK_STYLE_DEFAULT)
		local count, stackSize = GetSlotStackSize(BAG_GUILDBANK, slot)
		if newItem then
			local numStacks, totalCount = #guildPositions[newItem], 0
			for i, slotID in ipairs(guildPositions[newItem]) do
				totalCount = totalCount + GetSlotStackSize(BAG_GUILDBANK, slot)
			end

			addon.Print(L('stacking guildbank item', itemLink, numStacks, totalCount))
			currentItemLink = itemLink
			numItemsWithdrawn = 0
			numUsedStacks = 0
		end

		if itemLink ~= '' and count > 0 and count < stackSize then
			TransferFromGuildBank(slot)
			logs.withdraw[slot] = {itemLink, count}

			-- wait for event EVENT_GUILD_BANK_ITEM_REMOVED
			return
		end
	elseif not currentItemLink then
		addon.Print(L('guild bank stacking completed', numFreedSlots))
		state = STATE_IDLE
		return
	end
end

local lastGuildID
local function StackGuildBank(guildID)
	local guildID = type(guildID) == 'number' and guildID or GetSelectedGuildBankId() -- internal id of selected guild
	if lastGuildID == guildID or state ~= STATE_IDLE then return end

	local canStackGuildBank, errorMsg = CanStackGuildBank(guildID)
	if errorMsg then
		addon.Print(errorMsg)
		return
	end

	lastGuildID = guildID
	state = STATE_PREPARE
	numFreedSlots = 0

	-- scan guild bank
	addon.wipe(guildPositions)
	local slot = nil
	while true do
		slot = GetNextGuildBankSlotId(slot)
		if not slot then break end

		local itemLink = GetItemLink(BAG_GUILDBANK, slot, LINK_STYLE_DEFAULT)
		local itemID, key
		if itemLink ~= '' then
			_, _, _, itemID = ZO_LinkHandler_ParseLink(itemLink)
			itemID = itemID and tonumber(itemID)
			key = GetItemInstanceId(BAG_GUILDBANK, slot)
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

	-- scan inventory
	addon.wipe(bagPositions)
	local moveTarget = addon.GetSetting('moveTargetGB')
	if moveTarget ~= L'none' then
		local _, numSlots = GetBagInfo(BAG_BACKPACK)
		for slot = 0, numSlots do
			local itemLink = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
			local itemID
			if itemLink ~= '' then
				_, _, _, itemID = ZO_LinkHandler_ParseLink(itemLink)
				itemID = itemID and tonumber(itemID)
			end

			-- don't touch if slot is empty or item is excluded
			if itemID and not addon.db.exclude[itemID] then
				local count, stackSize = GetSlotStackSize(BAG_BACKPACK, slot)
				if count < stackSize then
					local key = GetItemInstanceId(BAG_BACKPACK, slot)
					if not bagPositions[key] then
						bagPositions[key] = {}
					end
					table.insert(bagPositions[key], slot)
				end
			end
		end
	end

	addon.wipe(logs.withdraw)
	addon.wipe(logs.deposit)
	for key, slots in pairs(guildPositions) do
		local keepSingleStacks = false
		if bagPositions[key] then
			-- handle merging into backpack/guild bank
			local itemLink = GetItemLink(BAG_GUILDBANK, slots[1])

			if moveTarget == L'backpack' then
				-- have item in bags, pull from guild bank
				local capacity = 0
				for _, slot in pairs(bagPositions[key]) do
					-- TODO: this will use up to the same numer of stacks if backpack is untidy
					local count, stackSize = GetSlotStackSize(BAG_BACKPACK, slot)
					capacity = capacity + (stackSize - count)
				end

				for index, slot in pairs(slots) do
					local count = GetSlotStackSize(BAG_GUILDBANK, slot)
					-- TODO: this is a rather dumb FCFS logic
					if count <= capacity then
						TransferFromGuildBank(slot)
						logs.withdraw[slot] = {itemLink, count}
						capacity = capacity - count

						-- we take this item, no need to stack it
						guildPositions[key][index] = nil
					end
				end
			elseif moveTarget == L'guildbank' then
				-- deposit (fitting) bag items to guild bank. they'll be stacked later
				local capacity = 0
				for _, slot in pairs(slots) do
					-- TODO: this will use up to the same number of stacks if guild bank is untidy
					local count, stackSize = GetSlotStackSize(BAG_GUILDBANK, slot)
					capacity = capacity + (stackSize - count)
				end

				for index, slot in pairs(bagPositions[key]) do
					local count = GetSlotStackSize(BAG_BACKPACK, slot)
					-- TODO: this is a rather dumb FCFS logic
					if count <= capacity then
						TransferToGuildBank(BAG_BACKPACK, slot)
						logs.deposit[slot] = key
						capacity = capacity - count

						-- needs to be stacked, even if there's only 1 stack in guild bank now
						keepSingleStacks = true
					end
				end
			end
		end

		if #guildPositions[key] < 2 and not keepSingleStacks then
			-- this item no longer needs to be stacked
			addon.wipe(guildPositions[key])
			guildPositions[key] = nil
		end
	end

	if next(logs.withdraw) or next(logs.deposit) then
		state = STATE_MOVING
		-- wait for EVENT_GUILD_BANK_ITEM_ADDED & EVENT_GUILD_BANK_ITEM_REMOVED events
	else
		-- stack right now!
		state = STATE_STACKING
		DoGuildBankStacking()
	end
end

addon.slashCommandHelp = (addon.slashCommandHelp or '') .. '\n' .. L'/stackgb'
SLASH_COMMANDS['/stackgb'] = StackGuildBank

-- adjust keybinds since we use one binding for both, container and guld bank stacking
if not addon.bindings[1] then
	table.insert(addon.bindings, {
		name = L'Stack',
		keybind = 'STACKED_STACK',
	})
end
local orig = addon.bindings[1].callback
addon.bindings[1].callback = function()
	if not ZO_GuildBank:IsHidden() then
		StackGuildBank()
	elseif orig then
		orig()
	end
end
addon.bindings[1].visible = function() return ZO_GuildBank:IsHidden() or CanStackGuildBank(GetSelectedGuildBankId()) end

local em = GetEventManager()
em:RegisterForEvent(addonName, EVENT_GUILD_BANK_ITEMS_READY, function()
	local guildID = GetSelectedGuildBankId() -- internal id of selected guild
	dataGuildID = guildID
	KEYBIND_STRIP:UpdateKeybindButtonGroup(addon.bindings)
	if addon.GetSetting('guildbank') and addon.GetSetting('stackContainer'..BAG_GUILDBANK..guildID) then StackGuildBank() end
end)
em:RegisterForEvent(addonName, EVENT_GUILD_BANK_ITEM_ADDED, function(eventID, slot)
	if state == STATE_STACKING then
		DepositGuildBankItems(eventID)
	elseif state == STATE_MOVING then
		-- item was deposited, compare to logs
		local count = GetSlotStackSize(BAG_GUILDBANK, slot)
		local itemLink = GetItemLink(BAG_GUILDBANK, slot)
		local key = GetItemInstanceId(itemLink)

		for bagSlot, itemKey in pairs(logs.deposit) do
			if itemKey == key and GetItemLink(BAG_BACKPACK, bagSlot) == '' then
				addon.Print( L('moved item', itemLink, count,
					addon.GetSlotText(BAG_BACKPACK, bagSlot), addon.GetSlotText(BAG_GUILDBANK, slot)) )
				-- add it to guildPositions so we stack it properly
				table.insert(guildPositions[key], slot)
				-- remove from logs
				logs.deposit[bagSlot] = nil
				break
			end
		end

		if not next(logs.withdraw) and not next(logs.deposit) then
			addon.StackContainer(BAG_BACKPACK, nil, true)
			-- stack right now!
			state = STATE_STACKING
			DoGuildBankStacking()
		end
	end
end)
em:RegisterForEvent(addonName, EVENT_GUILD_BANK_ITEM_REMOVED, function(eventID, slot)
	-- TODO: Oh, this is sooo not DRY
	if state == STATE_STACKING then
		local data = logs.withdraw[slot]
		if data then
			if addon.GetSetting('showGBStackDetail') then
				addon.Print(L('withdrew item', data[1], data[2] or 1))
			end
			numItemsWithdrawn = numItemsWithdrawn + (data[2] or 1)
			numUsedStacks = numUsedStacks + 1

			-- remove from logs
			data[1], data[2] = nil, nil
			logs.withdraw[slot] = nil
		else
			-- let's check if this is an item we had plans for
			local matchedKey = nil
			for key, slots in pairs(guildPositions) do
				for index, gbSlot in pairs(slots) do
					if slot == gbSlot then
						-- nooooo! someone took our item
						matchedKey = key
						guildPositions[key][index] = nil
						break
					end
				end
				if matchedKey then break end
			end
			if matchedKey and #guildPositions[matchedKey] < 2 then
				addon.wipe(guildPositions[matchedKey])
				guildPositions[matchedKey] = nil
			end
		end

		DoGuildBankStacking(eventID)
	elseif state == STATE_MOVING then
		-- item was withdrawn, compare to logs
		local data = logs.withdraw[slot]
		if data then
			addon.Print( L('moved item', data[1], data[2] or 1,
				addon.GetSlotText(BAG_GUILDBANK, slot), addon.GetSlotText(BAG_BACKPACK)) )

			-- remove from logs
			data[1], data[2] = nil, nil
			logs.withdraw[slot] = nil
		end

		if not next(logs.withdraw) and not next(logs.deposit) then
			addon.StackContainer(BAG_BACKPACK, nil, true)
			-- stack right now!
			state = STATE_STACKING
			DoGuildBankStacking()
		end
	end
end)
em:RegisterForEvent(addonName, EVENT_GUILD_BANK_TRANSFER_ERROR, function()
	if state == STATE_STACKING then
		addon.Print(L('failed stacking guildbank item', currentItemLink))
		currentItemLink = nil
		DoGuildBankStacking()
	elseif state == STATE_MOVING then
		addon.Print(L'failed moving guildbank item')
		-- TODO: how to continue?
	end
end)
em:RegisterForEvent(addonName, EVENT_OPEN_GUILD_BANK, function()
	KEYBIND_STRIP:AddKeybindButtonGroup(addon.bindings)
end)
em:RegisterForEvent(addonName, EVENT_CLOSE_GUILD_BANK, function()
	state = STATE_IDLE
	lastGuildID = nil
	dataGuildID = nil
	KEYBIND_STRIP:RemoveKeybindButtonGroup(addon.bindings)
end)
em:RegisterForEvent(addonName, EVENT_GUILD_BANK_SELECTED, function(self, guildID)
	KEYBIND_STRIP:UpdateKeybindButtonGroup(addon.bindings)
end)

local function UpdateKeybindButtons(self, hidden)
	if hidden then
		KEYBIND_STRIP:RemoveKeybindButtonGroup(addon.bindings)
	else
		KEYBIND_STRIP:AddKeybindButtonGroup(addon.bindings)
	end
end
ZO_PreHook(ZO_GuildBank, 'SetHidden', UpdateKeybindButtons)
