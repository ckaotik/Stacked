local L = _G['Stacked'].L

L['Stack'] = 'Stapeln' -- keybind

-- --------------------------------------------------------
-- settings
L['General Options'] = 'Allgemeine Einstellungen'
L['merge target'] = 'Stapel kombinieren'
L['merge target description'] = 'Wenn ein Gegenstand in mehreren Taschen unvollständige Stapel hat, können diese in eine Tasche kombiniert werden.'
L['none'] = 'Keine'
L['backpack'] = GetString(2258)
L['bank'] = GetString(790)
L['guildbank'] = 'Gildenbank'

L['tradeSucceeded'] = GetString(2073):gsub('%.$', '')
L['attachmentsRetrieved'] = 'Briefanhänge entnommen'
L['bank opened'] = 'Bank geöffnet'
L['guildbank opened'] = 'Gildenbank geöffnet'

L['ignore items'] = 'Gegenstände ignorieren'
L['ignore items description'] = 'Gegenstände auf deiner Ignorieren-Liste werden nicht von Stacked betrachtet.'
L['ignore items info'] = 'Nutze "|cFFFFFF/stacked list|r" um eine klickbare Liste aller ignorierten Gegenstände auszugeben. So kannst du leicht deren Namen herausfinden!'
L['ignore items help'] = 'Eine Zeile pro Gegenstand mit entweder der Gegenstands-ID oder dem Link (nutze die Option "|cFFFFFF'..GetString(1796)..'|r|cFFFFB0" und kopiere den Chat-Link in dieses Textfeld).'

L['Messages'] = 'Nachrichten'
L['item moved'] = 'Gegenstand wurde bewegt'
L['item moved description'] = 'Zeige eine Chat-Nachricht wenn ein Gegenstand bewegt wurde.'
L['slots'] = 'Nummer des Taschenplatzes'
L['slots description'] = 'Zeige die Nummer des Taschenplatzes in allen Nachrichten.'
L['guild bank details'] = 'Details für Gildenbank-Aktionen'
L['guild bank details description'] = 'Zeige alle einzelnen Aktionen beim Gildenbank-Stapeln, insbesondere getätigte Entnahmen und Einzahlungen.'

L['Automatic Stacking'] = 'Automatisch Stapeln'
L['automatic events'] = 'Bei diesen Ereignissen automatisch stapeln:'
L['automatic containers'] = 'Nur diese Taschen automatisch bearbeiten:'

-- --------------------------------------------------------
-- slash commands
L['/help'] = '<<1>> Befehlshilfe: <<2>>'
L['/stack'] = '"|cFFFFFF/stack|r" um das Stapeln auszulösen'
L['/stackgb'] = '"|cFFFFFF/stackgb|r" um die Gildenbank zu stapeln'
L['/stacked list'] = '"|cFFFFFF/stacked list|r" um ignorierte Gegenstände aufzulisten'
L['/stacked exclude'] = '"|cFFFFFF/stacked exclude|r |cFF80401234|r" um den Gegenstand mit ID 1234 zu ignorieren'
	.. '\n"|cFFFFFF/stacked exclude|r |cFF8040[Item Link]|r" um den verlinkten Gegenstand zu ignorieren'
L['/stacked include'] = '"|cFFFFFF/stacked include|r |cFF80401234|r" um den Gegenstand mit ID 1234 nicht mehr zu ignorieren'
	.. '\n"|cFFFFFF/stacked include|r |cFF8040[Item Link]|r" um den verlinkten Gegenstand nicht mehr zu ignorieren'

-- --------------------------------------------------------
-- container stacking
L['bag slot number'] = '<<1>> (Platz <<2>>)'
L['stacked item'] = '<<2*1>> wurde von <<3>> nach <<4>> gestapelt'
L['failed stacking item'] = 'Stapeln von <<2*1>> in <<3>> nach <<4>> ist fehlgeschlagen'
L['stacked item in container'] = '<<2*1>> wurde in <<4>> gestapelt'
L['failed stacking item in container'] = 'Stapeln von <<2*1>> in <<4>> ist fehlgeschlagen'
L['moved item'] = '<<2*1>> wurde von <<3>> nach <<4>> bewegt'
L['failed moving item'] = 'Bewegen von <<2*1>> in <<3>> nach <<4>> ist fehlgeschlagen'

-- --------------------------------------------------------
-- guild bank stacking
L['stacking item'] = 'Stapeln von <<1>>...'
L['stacking item failed'] = 'Stapeln von <<1>> ist fehlgeschlagen.'
L['withdrew item'] = '<<2*1>> abgehoben'
L['deposit item'] = 'Einzahlen von <<2*1>> in die Gildenbank...'
L['deposit item manually'] = '<<2*1>> wurden nicht eingezahlt. Bitte tu dies manuell.'
L['guild bank stacking completed'] = 'Gildenbank-Stapeln abgeschlossen. <<1>> Plätze gewonnen.'

-- error messages
L['not enough members'] = 'Diese Gilde hat nicht genügend Mitglieder um die Gildenbank zu nutzen.'
L['insufficient permissions'] = 'Du benötigst sowohl Einzahlungs- als auch Entnahme-Berechtigungen um die Gildenbank zu stapeln.'
L['inventory full'] = 'Es werden mindestens 2 freie Tascenplätze zum Stapeln der Gildenbank benötigt.'
L['not available'] = 'Gildenbank-Daten sind noch nicht verfügbar.'

