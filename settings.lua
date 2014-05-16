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
			k = tonumber(k)

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

	LAM:AddHeader(panel, addonName..'HeaderGeneral', L'General Options')
	LAM:AddDropdown(panel, addonName..'MoveTarget',
		L'merge target', L'merge target description',
		{L'none', L'backpack', L'bank'},
		function() return GetSetting('moveTarget') end, function(value) SetSetting('moveTarget', value) end)
	-- LAM:AddDropdown(panel, addonName..'MoveTargetGB',
	-- 	L'merge guildbank target', L'merge guildbank target description',
	-- 	{L'none', L'backpack', L'guildbank'},
	-- 	function() return GetSetting('moveTargetGB') end, function(value) SetSetting('moveTargetGB', value) end)
	LAM:AddEditBox(panel, addonName..'Exclude',
		L'ignore items', L'ignore items description', true,
		function() return GetSetting('exclude') end, function(value) SetSetting('exclude', value) end,
		true, L'ignore items info')
	LAM:AddDescription(panel, addonName..'ExcludeDesc', '|cFFFFB0'..L'ignore items help'..'|r')

	LAM:AddHeader(panel, addonName..'HeaderMessages', L'Messages')
	LAM:AddCheckbox(panel, addonName..'ToggleMessages',
		L'item moved', L'item moved description',
		function() return GetSetting('showMessages') end, function(value) SetSetting('showMessages', value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleSlot',
		L'slots', L'slots description',
		function() return GetSetting('showSlot') end, function(value) SetSetting('showSlot', value) end)
	-- LAM:AddCheckbox(panel, addonName..'ToggleGBStack',
	-- 	L'guild bank details', L'guild bank details description',
	-- 	function() return GetSetting('showGBStackDetail') end, function(value) SetSetting('showGBStackDetail', value) end)

	LAM:AddHeader(panel, addonName..'HeaderStacking', L'Automatic Stacking')
	LAM:AddDescription(panel, addonName..'EventsDesc', '|cFFFFB0'..L'automatic events'..'|r')
	LAM:AddCheckbox(panel, addonName..'ToggleTrade',
		L'tradeSucceeded', nil,
		function() return GetSetting('trade') end, function(value) SetSetting('trade', value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleMail',
		L'attachmentsRetrieved', nil,
		function() return GetSetting('mail') end, function(value) SetSetting('mail', value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleBank',
		L'bank opened', nil,
		function() return GetSetting('bank') end, function(value) SetSetting('bank', value) end)
	-- LAM:AddCheckbox(panel, addonName..'ToggleGuildBank',
	-- 	L'guildbank opened', nil,
	-- 	function() return GetSetting('guildbank') end, function(value) SetSetting('guildbank', value) end)

	LAM:AddDescription(panel, addonName..'ContainersDesc', '|cFFFFB0'..L'automatic containers'..'|r')
	LAM:AddCheckbox(panel, addonName..'ToggleContainer'..BAG_BACKPACK,
		L'backpack', nil,
		function() return GetSetting('stackContainer'..BAG_BACKPACK) end,
		function(value) SetSetting('stackContainer'..BAG_BACKPACK, value) end)
	LAM:AddCheckbox(panel, addonName..'ToggleContainer'..BAG_BANK,
		L'bank', nil,
		function() return GetSetting('stackContainer'..BAG_BANK) end,
		function(value) SetSetting('stackContainer'..BAG_BANK, value) end)
	-- local bag = BAG_GUILDBANK
	-- for i = 1, 5 do
	-- 	LAM:AddCheckbox(panel, addonName..'ToggleContainer'..BAG_GUILDBANK..i,
	-- 		L'guildbank'..' '..i, nil,
	-- 		function() return GetSetting('stackContainer'..BAG_GUILDBANK..i) end,
	-- 		function(value) SetSetting('stackContainer'..BAG_GUILDBANK..i, value) end)
	-- end
end

addon.slashCommandHelp = (addon.slashCommandHelp or '')
	..'\n'..L'/stacked list'
	..'\n'..L'/stacked exclude'
	..'\n'..L'/stacked include'

function addon.CreateSlashCommands()
	SLASH_COMMANDS['/stacked'] = function(arg)
		if arg == '' or arg == 'help' then
			addon.Print(L('/help', addonName, addon.slashCommandHelp))
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
			addon.Print('Stacked ignores %s', list ~= '' and list or 'no items')
		elseif option == 'exclude' then
			local _, _, _, itemID = ZO_LinkHandler_ParseLink(value)
			if itemID then value = itemID end

			if not value or value == '' then return end
			addon.db.exclude[value] = true
			addon.Print('Stacked now ignores item %s', GetLinkFromID(value))
		elseif option == 'include' then
			local _, _, _, itemID = ZO_LinkHandler_ParseLink(value)
			if itemID then value = itemID end

			if not value or value == '' then return end
			addon.db.exclude[value] = nil
			addon.Print('Stacked no longer ignores %s', GetLinkFromID(value))
		end
	end
end
