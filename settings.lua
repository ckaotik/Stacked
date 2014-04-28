local addonName, _ = 'Stacked'
local addon = _G[addonName]
local L = addon.L

-- GLOBALS: LibStub, SLASH_COMMANDS, BAG_BANK, BAG_BACKPACK, BAG_GUILDBANK, ITEM_LINK_TYPE
-- GLOBALS: ZO_LinkHandler_CreateLink, ZO_LinkHandler_ParseLink, GetString
-- GLOBALS: string, type, pairs, tostring, tonumber, zo_strtrim

local function isNumber(text) return text:match("^(-?%d-%.*%d-)$") end

local function GetLinkFromID(linkID, linkType)
	local stub = string.rep(':0', 19)
	return ZO_LinkHandler_CreateLink(linkID, nil, linkType or ITEM_LINK_TYPE, linkID .. stub)
end

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
addon.GetSetting = GetSetting

local function SetSetting(setting, value)
	local old = addon.db and addon.db[setting]
	if old == nil then return end

	if type(old) == 'table' then
		-- remove all entries (will be re-added if needed)
		addon.wipe(old)

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
addon.SetSetting = SetSetting

function addon.CreateSettings()
	local LAM = LibStub('LibAddonMenu-1.0')
	local panel = LAM:CreateControlPanel(addonName..'Settings', addonName)

	LAM:AddHeader(panel, addonName..'HeaderEvents', addon.L['events'])
	LAM:AddCheckbox(panel, addonName..'ToggleTrade',
		addon.L['tradeSucceeded'], 'Enable stacking after a trade was completed.',
		function() return GetSetting('trade') end, function(value) SetSetting('trade', value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleMail',
		addon.L['attachmentsRetrieved'], 'Enable stacking after retrieving mail attachments.',
		function() return GetSetting('mail') end, function(value) SetSetting('mail', value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleBank',
		addon.L['bank'], 'Enable stacking when opening your bank.',
		function() return GetSetting('bank') end, function(value) SetSetting('bank', value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleGuildBank',
		addon.L['guildbank'], 'Enable stacking when opening your guild bank.',
		function() return GetSetting('guildbank') end, function(value) SetSetting('guildbank', value) end)

	local descFormat = 'Enable stacking of items in your %s'
	LAM:AddHeader(panel, addonName..'HeaderContainers', addon.L['containers'])
	local bag = BAG_BACKPACK
	LAM:AddCheckbox(panel, addonName..'ToggleContainer'..bag,
		addon.bagNames[bag], descFormat:format(addon.bagNames[bag]),
		function() return GetSetting('stackContainer'..bag) end, function(value) SetSetting('stackContainer'..bag, value) end
	)
	local bag = BAG_BANK
	LAM:AddCheckbox(panel, addonName..'ToggleContainer'..bag,
		addon.bagNames[bag], descFormat:format(addon.bagNames[bag]),
		function() return GetSetting('stackContainer'..bag) end, function(value) SetSetting('stackContainer'..bag, value) end
	)
	local bag = BAG_GUILDBANK
	for i = 1, 5 do
		LAM:AddCheckbox(panel, addonName..'ToggleContainer'..bag..i,
			addon.bagNames[bag]..' '..i, descFormat:format(addon.bagNames[bag]..' '..i),
			function() return GetSetting('stackContainer'..bag..i) end, function(value) SetSetting('stackContainer'..bag..i, value) end
		)
	end

	LAM:AddHeader(panel, addonName..'HeaderMoveTarget', 'Move to other bag')
	LAM:AddDescription(panel, addonName..'MoveTargetDesc', 'When multiple locations contain the same item in incomplete stacks, those stacks may be merged together into one location.', nil)

	local descFormat = 'Enable moving partial stacks into your %s.'
	local bag = BAG_BACKPACK
	LAM:AddCheckbox(panel, addonName..'ToggleMoveTarget'..BAG_BACKPACK,
		addon.bagNames[BAG_BACKPACK], descFormat:format(addon.bagNames[BAG_BACKPACK]),
		function() return GetSetting('moveTarget'..BAG_BACKPACK) end, function(value) SetSetting('moveTarget'..BAG_BACKPACK, value) end,
		true, ('If enabled make sure to disable %s and %s!'):format(addon.bagNames[BAG_BANK], addon.bagNames[BAG_GUILDBANK])
	)
	local bag = BAG_BANK
	LAM:AddCheckbox(panel, addonName..'ToggleMoveTarget'..bag,
		addon.bagNames[bag], descFormat:format(addon.bagNames[bag]),
		function() return GetSetting('moveTarget'..bag) end, function(value) SetSetting('moveTarget'..bag, value) end
	)
	local bag = BAG_GUILDBANK
	LAM:AddCheckbox(panel, addonName..'ToggleMoveTarget'..bag,
		addon.bagNames[bag], descFormat:format(addon.bagNames[bag]),
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

addon.slashCommandHelp = (addon.slashCommandHelp or '')
	..'\n  "|cFFFFFF/stacked showMessages|r |cFF8040true|r" to show, |cFF8040false|r to hide movement notices'
	..'\n  "|cFFFFFF/stacked showSlot|r |cFF8040true|r" to show, |cFF8040false|r to hide slot numbers in movement notices'
	..'\n  "|cFFFFFF/stacked list|r" to list all items excluded from stacking'
	..'\n  "|cFFFFFF/stacked exclude|r |cFF80401234|r" to exclude the item with id 1234'
	..'\n  "|cFFFFFF/stacked exclude|r |cFF8040[Item Link]|r" to exclude the linked item'
	..'\n  "|cFFFFFF/stacked include|r |cFF80401234|r" to re-include the item with id 1234'
	..'\n  "|cFFFFFF/stacked include|r |cFF8040[Item Link]|r" to re-include the linked item'

function addon.CreateSlashCommands()
	SLASH_COMMANDS['/stacked'] = function(arg)
		if arg == '' or arg == 'help' then
			addon.Print(addonName..' command help:'..addon.slashCommandHelp)
			return
		end

		local option, value = string.match(arg, '([%d%a]+)%s*(.*)')
		local optionType = type(addon.db[option])
		if type(addon.db[option]) == 'boolean' then
			addon.db[option] = (value and value ~= 'false') and true or false
			addon.Print('Stacked option "%s" is now set to %s', option, value)
		elseif option == 'list' or (option == 'exclude' and not value) then
			local list = ''
			for itemID, _ in pairs(addon.db.exclude) do
				list = (list ~= '' and list..', ' or '') .. GetLinkFromID(itemID)
			end
			addon.Print('Stacked excludes %s', list ~= '' and list or 'no items')
		elseif option == 'exclude' then
			local _, _, _, itemID = ZO_LinkHandler_ParseLink(value)
			if itemID then value = itemID end

			if not value or value == '' then return end
			addon.db.exclude[value] = true
			addon.Print('Stacked now excludes item %s', GetLinkFromID(value))
		elseif option == 'include' then
			local _, _, _, itemID = ZO_LinkHandler_ParseLink(value)
			if itemID then value = itemID end

			if not value or value == '' then return end
			addon.db.exclude[value] = nil
			addon.Print('Stacked no longer excludes %s', GetLinkFromID(value))
		end
	end
end
