local addonName, _ = 'Stacked'
local addon = _G[addonName]
local L = addon.L

-- GLOBALS: LINK_STYLE_DEFAULT, BAG_GUILDBANK, BAG_BACKPACK, SI_TOOLTIP_ITEM_NAME
-- GLOBALS: GetItemLink, GetNextGuildBankSlotId, GetSlotStackSize, CheckInventorySpaceSilently, GetBagInfo, ZO_LinkHandler_ParseLink, DoesPlayerHaveGuildPermission, TransferToGuildBank, TransferFromGuildBank, GetSelectedGuildBankId, IsItemConsumable
-- GLOBALS: tonumber, table, pairs, ipairs, wipe, zo_strformat

local guildPositions, isStackingGB = {}, false
local currentItemLink, numItemsWithdrawn, numUsedStacks

local function CleanText(text)
	-- return string.gsub(text or '', '(\^[^ :\124]+)', '')
	-- return LocalizeString('<<1>>', text)
	return zo_strformat(SI_TOOLTIP_ITEM_NAME, text)
end

local function DoGuildBankStacking() end -- forward declaration

local function DepositGuildBankItems(eventID)
	if not currentItemLink then return end

	if not eventID then
		addon.Print('Deposit %s x%d back to guild bank...', CleanText(currentItemLink), numItemsWithdrawn)
	end

	local _, numSlots = GetBagInfo(BAG_BACKPACK)
	for slot = 0, numSlots do
		local itemLink = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
		local count = GetSlotStackSize(BAG_BACKPACK, slot)
		if itemLink == currentItemLink then
			if count < numItemsWithdrawn or addon.GetSetting('moveTarget'..BAG_GUILDBANK) then
				TransferToGuildBank(BAG_BACKPACK, slot)
				numUsedStacks = numUsedStacks - 1
				numItemsWithdrawn = numItemsWithdrawn - count

				-- wait for event EVENT_GUILD_BANK_ITEM_ADDED
				return
			else
				-- TODO: split stack
				-- ZO_StackSplit, ZO_StackSplitSplit, ZO_StackSplitSpinnerDisplay
				addon.Print('%s x%d was not deposited. Please split this off and deposit manually.')
			end
		end
	end

	addon.Print('Freed %d slot(s).', numUsedStacks)
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
						addon.StackContainer(BAG_BACKPACK, item, true)
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
			addon.Print('Stacking item %s...', CleanText(itemLink))
			currentItemLink = itemLink
			numItemsWithdrawn = 0
			numUsedStacks = 0
		end

		if itemLink ~= '' and count > 0 and count < stackSize then
			TransferFromGuildBank(slot)

			addon.Print('Withdrew %s x%d', CleanText(itemLink), count)
			numItemsWithdrawn = numItemsWithdrawn + count
			numUsedStacks = numUsedStacks + 1

			-- wait for event EVENT_GUILD_BANK_ITEM_REMOVED
			return
		end
	elseif currentItemLink then
		addon.Print('Stacking guild bank completed.')
		isStackingGB = false
		return
	end
end

local function StackGuildBank()
	local guildID = GetSelectedGuildBankId() -- internal id of selected guild
	if isStackingGB or not addon.GetSetting('stackContainer'..BAG_GUILDBANK..guildID) then return end

	if not DoesPlayerHaveGuildPermission(guildID, 15) -- deposit
	  or not DoesPlayerHaveGuildPermission(guildID, 16) then -- withdraw
		addon.Print('You need to have both withdrawal and deposit permissions to restack the guild bank')
		return
	elseif not CheckInventorySpaceSilently(2) then
		addon.Print('You need at least 2 empty bag slots to restack the guild bank.')
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
			local level, uniqueID
			_, _, _, itemID, _, level, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, uniqueID = ZO_LinkHandler_ParseLink(itemLink)
			itemID = itemID and tonumber(itemID)
			key = addon.GetKey(itemID, level, uniqueID, IsItemConsumable(BAG_GUILDBANK, slot))
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

local em = GetEventManager()
em:RegisterForEvent(addonName, EVENT_GUILD_BANK_ITEMS_READY, StackGuildBank)
em:RegisterForEvent(addonName, EVENT_GUILD_BANK_ITEM_ADDED, function(eventID) DepositGuildBankItems(eventID) end)
em:RegisterForEvent(addonName, EVENT_GUILD_BANK_ITEM_REMOVED, function(eventID) DoGuildBankStacking(eventID) end)
em:RegisterForEvent(addonName, EVENT_CLOSE_GUILD_BANK, function() isStackingGB = false end)

addon.slashCommandHelp = (addon.slashCommandHelp or '') .. '\n  "|cFFFFFF/stackgb|r" to start stacking the guild bank manually'
SLASH_COMMANDS['/stackgb'] = StackGuildBank
