local L = _G['Stacked'].L

-- L['Stack'] = 'Stack' -- keybind

-- --------------------------------------------------------
-- settings
-- L['General Options'] = 'General Options'
L['merge target'] = 'Merge stacks'
L['merge target description'] = 'When multiple locations contain the same item in incomplete stacks, those stacks may be merged together into one location.'
L['none'] = 'None'
L['backpack'] = GetString(2258)
L['bank'] = GetString(790)
L['guildbank'] = 'Guild Bank'

L['tradeSucceeded'] = GetString(2073):gsub('%.$', '')
L['attachmentsRetrieved'] = 'Mail attachments retrieved'
L['bank opened'] = 'Bank opened'
L['guildbank opened'] = 'Guild Bank opened'

L['ignore items'] = 'Ignore items'
L['ignore items description'] = 'Items that are on your ignore list will never be touched by Stacked.'
L['ignore items info'] = 'Don\'t know which item an id represents? Use "/stacked list" to get clickable links of all excluded items.'
L['ignore items help'] = 'Add a new line with either the item ID or link (via menu option "|cFFFFFF'..GetString(1796)..'|r|cFFFFB0" and copy the link into this text box).'

-- L['Messages'] = 'Messages'
L['item moved'] = 'Item was moved'
L['item moved description'] = 'Enable chat output when an item has been moved.'
L['slots'] = 'Slot numbers'
L['slots description'] = 'Enable to add which slot was affected to movement messages.'
L['guild bank details'] = 'Guild Bank stacking details'
L['guild bank details description'] = 'Enable to show messages when items are moved for guild bank stacking.'

-- L['Automatic Stacking'] = 'Automatic Stacking'
L['automatic events'] = 'Automatically stack when any of these events happen:'
L['automatic containers'] = 'Allow automatic stacking only for these containers:'

-- --------------------------------------------------------
-- slash commands
L['/help'] = '<<1>> command help: <<2>>'
L['/stack'] = '"|cFFFFFF/stack|r" to start stacking manually'
L['/stackgb'] = '"|cFFFFFF/stackgb|r" to start stacking the guild bank manually'
L['/stacked list'] = '"|cFFFFFF/stacked list|r" to list all ignored items'
L['/stacked exclude'] = '"|cFFFFFF/stacked exclude|r |cFF80401234|r" to ignore the item with id 1234'
	.. '\n"|cFFFFFF/stacked exclude|r |cFF8040[Item Link]|r" to ignore the linked item'
L['/stacked include'] = '"|cFFFFFF/stacked include|r |cFF80401234|r" to un-ignore the item with id 1234'
	.. '\n"|cFFFFFF/stacked include|r |cFF8040[Item Link]|r" to un-ignore the linked item'

-- --------------------------------------------------------
-- container stacking
L['bag slot number'] = '<<1>> (Slot <<2>>)'
L['stacked item'] = 'Stacked <<2*1>> from <<3>> to <<4>>'
L['failed stacking item'] = 'Failed to stack <<2*1>> from <<3>> to <<4>>'
L['stacked item in container'] = 'Stacked <<2*1>> in <<4>>'
L['failed stacking item in container'] = 'Failed to stack <<2*1>> in <<4>>'
L['moved item'] = 'Moved <<2*1>> from <<3>> to <<4>>'
L['failed moving item'] = 'Failed to move <<2*1>> from <<3>> to <<4>>'

-- --------------------------------------------------------
-- guild bank stacking
L['stacking item'] = 'Stacking <<1>>...'
L['stacking item failed'] = 'Stacking <<1>> failed.'
L['withdrew item'] = 'Withdrew <<2*1>>'
L['deposit item'] = 'Deposit <<2*1>> back to guild bank...'
L['deposit item manually'] = '<<2*1>> was not deposited. Please do so manually.'
L['guild bank stacking completed'] = 'Stacking guild bank completed. Freed <<1>> slot(s).'

-- error messages
L['not enough members'] = 'This guild does not have enough members to use the guild bank.'
L['insufficient permissions'] = 'You need to have both withdrawal and deposit permissions to restack the guild bank'
L['inventory full'] = 'You need at least 2 empty bag slots to restack the guild bank.'
L['not available'] = 'Guild bank data is not yet available.'
