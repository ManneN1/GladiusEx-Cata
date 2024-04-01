local major = "DRData-1.0"
local minor = 1049
assert(LibStub, string.format("%s requires LibStub.", major))

local Data = LibStub:NewLibrary(major, minor)
if( not Data ) then return end

local L = {
	["Banish"] = "Banish",
	["Controlled stuns"] = "Controlled stuns",
	["Cyclone"] = "Cyclone",
	["Disarms"] = "Disarms",
	["Disorients"] = "Disorients",
	["Entrapment"] = "Entrapment",
	["Fears"] = "Fears",
	["Horrors"] = "Horrors",
	["Mind Control"] = "Mind Control",
	["Random roots"] = "Random roots",
	["Random stuns"] = "Random stuns",
	["Controlled roots"] = "Controlled roots",
	["Scatter Shot"] = "Scatter Shot",
	["Dragon's Breath"] = "Dragon's Breath",
	["Silences"] = "Silences",
	["Taunts"] = "Taunts",
}

if GetLocale() == "frFR" then
	L["Banish"] = "Bannissement"
	L["Controlled stuns"] = "Etourdissements contrôlés"
	L["Cyclone"] = "Cyclone"
	L["Disarms"] = "Désarmements"
	L["Disorients"] = "Désorientations"
	L["Entrapment"] = "Piège"
	L["Fears"] = "Peurs"
	L["Horrors"] = "Horreurs"
	L["Mind Control"] = "Contrôle mental"
	L["Random roots"] = "Immobilisations aléatoires"
	L["Random stuns"] = "Etourdissemensts aléatoires"
	L["Controlled roots"] = "Immobilisations contrôlées"
	L["Scatter Shot"] = "Flèche de dispersion"
	L["Dragon's Breath"] = "Souffle du dragon"
	L["Silences"] = "Silences"
	L["Taunts"] = "Provocations"
end

-- How long before DR resets ?
Data.resetTimes = {
	default   = 20,
}
Data.RESET_TIME = Data.resetTimes.default

-- Successives diminished durations
Data.diminishedDurations = {
	-- Decreases by 50%, immune at the 4th application
	default   = { 0.50, 0.25 },
}

-- Spells and providers by categories
--[[ Generic format:
	category = {
		-- When the debuff and the spell that applies it are the same:
		debuffId = true
		-- When the debuff and the spell that applies it differs:
		debuffId = spellId
		-- When several spells apply the debuff:
		debuffId = {spellId1, spellId2, ...}
	}
--]]

-- See http://eu.battle.net/wow/en/forum/topic/11267997531
-- or http://blue.mmo-champion.com/topic/326364-diminishing-returns-in-warlords-of-draenor/
local spellsAndProvidersByCategory = {

    --[[ TAUNT ]]--
	taunt = {
        [  355] = true, -- Taunt (Warrior)
        [53477] = true, -- Taunt (Hunter tenacity pet)
        [ 6795] = true, -- Growl (Druid)
        [56222] = true, -- Dark Command
        [62124] = true, -- Hand of Reckoning
        [31790] = true, -- Righteous Defense
        [20736] = true, -- Distracting Shot
        [ 1161] = true, -- Challenging Shout
        [ 5209] = true, -- Challenging Roar
        [57603] = true, -- Death Grip
        [36213] = true, -- Angered Earth -- FIXME: NPC ability ?
        [17735] = true, -- Suffering (Voidwalker)
        [58857] = true, -- Twin Howl (Spirit wolves)
    },

	--[[ DISORIENTS ]]--
    disorient = {
        [49203] = true, -- Hungering Cold
        [ 6770] = true, -- Sap
        [ 1776] = true, -- Gouge
        [51514] = true, -- Hex
        [ 9484] = true, -- Shackle Undead
        [  118] = true, -- Polymorph
        [28272] = true, -- Polymorph (pig)
        [28271] = true, -- Polymorph (turtle)
        [61305] = true, -- Polymorph (black cat)
        [61025] = true, -- Polymorph (serpent) -- FIXME: gone ?
        [61721] = true, -- Polymorph (rabbit)
        [61780] = true, -- Polymorph (turkey)
        [ 3355] = true, -- Freezing Trap
        [19386] = true, -- Wyvern Sting
        [20066] = true, -- Repentance
        [ 2637] = true, -- Hibernate
        [82676] = true, -- Ring of Frost
    },
    
	--[[ SILENCES ]]--
    silence = {
        [50479] = true, -- Nether Shock (Nether ray)
        [ 1330] = true, -- Garrote
        [25046] = true, -- Arcane Torrent (Energy version)
        [28730] = true, -- Arcane Torrent (Mana version)
        [50613] = true, -- Arcane Torrent (Runic power version)
        [69179] = true, -- Arcane Torrent (Rage version)
        [80483] = true, -- Arcane Torrent (Focus version)
        [15487] = true, -- Silence
        [34490] = true, -- Silencing Shot
        [18425] = true, -- Improved Kick (rank 1)
        [86759] = true, -- Improved Kick (rank 2)
        [18469] = true, -- Improved Counterspell (rank 1)
        [55021] = true, -- Improved Counterspell (rank 2)
        [24259] = true, -- Spell Lock (Felhunter)
        [47476] = true, -- Strangulate
        [18498] = true, -- Gag Order (Warrior talent)
        [81261] = true, -- Solar Beam
        [31935] = true, -- Avenger's Shield
    },

	--[[ DISARMS ]]--
    disarm = {
	    [91644] = true, -- Snatch (Bird of Prey)
	    [51722] = true, -- Dismantle
	    [  676] = true, -- Disarm
	    [64058] = true, -- Psychic Horror (Disarm effect)
	    [50541] = true, -- Clench (Scorpid)
    },
    
	--[[ FEARS ]]--
    fear = {
        [ 2094] = true, -- Blind
        [ 5782] = true, -- Fear (Warlock)
        [ 6358] = true, -- Seduction (Succubus)
        [ 5484] = true, -- Howl of Terror
        [ 8122] = true, -- Psychic Scream
        [65545] = true, -- Psychic Horror
        [ 1513] = true, -- Scare Beast
        [10326] = true, -- Turn Evil
        [ 5246] = true, -- Intimidating Shout (main target)
        [20511] = true, -- Intimidating Shout (secondary targets)
    },

	--[[ CONTROL STUNS ]]--
    ctrlstun = {
        [89766] = true, -- Axe Toss (Felguard)
        [50519] = true, -- Sonic Blast (Bat)
        [12809] = true, -- Concussion Blow
        [46968] = true, -- Shockwave
        [  853] = true, -- Hammer of Justice
        [ 5211] = true, -- Bash
        [24394] = true, -- Intimidation
        [22570] = true, -- Maim
        [  408] = true, -- Kidney Shot
        [20549] = true, -- War Stomp
        [20252] = true, -- Intercept
        [20253] = true, -- Intercept
        [44572] = true, -- Deep Freeze
        [30283] = true, -- Shadowfury
        [ 2812] = true, -- Holy Wrath
        [22703] = true, -- Inferno Effect
        [54785] = true, -- Demon Leap (Warlock)
        [47481] = true, -- Gnaw (Ghoul)
        [93433] = true, -- Burrow Attack (Worm)
        [56626] = true, -- Sting (Wasp)
        [85388] = true, -- Throwdown
        [ 1833] = true, -- Cheap Shot
        [ 9005] = true, -- Pounce
        [88625] = true, -- Holy Word: Chastise
        [ 7922] = true, -- Charge
        [90337] = true, -- Bad Manner (Monkey) -- FIXME: to check
    },

	--[[ RANDOM STUNS ]]--
    rndstun = {
        [64343] = true, -- Impact
        [39796] = true, -- Stoneclaw Stun
        [11210] = true, -- Improved Polymorph (rank 1)
        [12592] = true, -- Improved Polymorph (rank 2)
    },

	--[[ CYCLONE ]]--
    cyclone = {
        [33786] = true, -- Cyclone
    },

	--[[ ROOTS ]]--
    ctrlroot = {
        [33395] = true, -- Freeze (Water Elemental)
        [50245] = true, -- Pin (Crab)
        [  122] = true, -- Frost Nova
        [  339] = true, -- Entangling Roots
        [19975] = true, -- Nature's Grasp (Uses different spellIDs than Entangling Roots for the same spell)
        [64695] = true, -- Earthgrab (Storm, Earth and Fire talent)
        [ 4167] = true, -- Web (Spider)
        [54706] = true,	-- Venom Web Spray (Silithid)
        [19306] = true, -- Counterattack
        [90327] = true, -- Lock Jaw (Dog)
        [11190] = true, -- Improved Cone of Cold (rank 1)
        [12489] = true, -- Improved Cone of Cold (rank 2)
    },

	--[[ RANDOM ROOTS ]]--
	rndroot = {
        [23694] = true, -- Improved Hamstring -- FIXME: to check
        [44745] = true, -- Shattered Barrier (rank 1)
        [54787] = true, -- Shattered Barrier (rank 2)
    },

	--[[ HORROR ]]--
    horror = {
        [ 6789] = true, -- Death Coil
        [64044] = true, -- Psychic Horror
        [87099] = true, -- Sin and Punishment (rank 1)
        [87100] = true, -- Sin and Punishment (rank 2)
    },

	--[[ MISC ]]--
    scatter = {
        [19503] = true, -- Scatter Shot
    },
    dragons = {
        [31661] = true, -- Dragon's Breath
    },
    mc = {
        [  605] = true, -- Mind Control
    },
    banish = {
        [  710] = true, -- Banish
    },
    entrapment = {
        [19185] = true, -- Entrapment
    },
}

-- DR Category names
Data.categoryNames = {
	["banish"] = L["Banish"],
	["ctrlstun"] = L["Controlled stuns"],
	["cyclone"] = L["Cyclone"],
	["disarm"] = L["Disarms"],
	["disorient"] = L["Disorients"],
	["entrapment"] = L["Entrapment"],
	["fear"] = L["Fears"],
	["horror"] = L["Horrors"],
	["mc"] = L["Mind Control"],
	["rndroot"] = L["Random roots"],
	["rndstun"] = L["Random stuns"],
	["ctrlroot"] = L["Controlled roots"],
	["scatters"] = L["Scatter Shot"],
	["dragons"] = L["Dragon's Breath"],
	["silence"] = L["Silences"],
	["taunt"] = L["Taunts"],
}

-- Categories that have DR in PvE as well as PvP
Data.pveDR = {
	["ctrlstun"] = true,
	["rndstun"] = true,
	["taunt"] = true,
	["cyclone"] = true,
} 

Data.pveDR = {
	ctrlstun	= true,
	rndstun  	= true,
	taunt    	= true,
	cyclone		= true,
}

--- List of spellID -> DR category
Data.spells = {}

--- List of spellID => ProviderID
Data.providers = {}

-- Dispatch the spells in the final tables
for category, spells in pairs(spellsAndProvidersByCategory) do

	local i = 1
	for spell, provider in pairs(spells) do
		Data.spells[spell] = category
		if provider == true then -- "== true" is really needed
			Data.providers[spell] = spell
			spells[spell] = spell
		else
			Data.providers[spell] = provider
		end
		i = i + 1
	end
end

-- Get the number of spells in a given category
-- Pass "nil" to iterate through all spells.
function Data:GetNumSpellsInCategory(category)
	if category and spellsAndProvidersByCategory[category] then
        local r = 0
        for k,v in pairs(spellsAndProvidersByCategory[category]) do
            r = r + 1
        end
        return r
	end
    return nil
end

-- Public APIs
-- Category name in something usable
function Data:GetCategoryName(cat)
	return cat and Data.categoryNames[cat] or nil
end

-- Spell list
function Data:GetSpells()
	return Data.spells
end

-- Provider list
function Data:GetProviders()
	return Data.providers
end

-- Seconds before DR resets
function Data:GetResetTime(category)
	return Data.resetTimes[category or "default"] or Data.resetTimes.default
end

-- Get the category of the spellID
function Data:GetSpellCategory(spellID)
	return spellID and Data.spells[spellID] or nil
end

-- Does this category DR in PvE?
function Data:IsPVE(cat)
	return cat and Data.pveDR[cat] or nil
end

-- List of categories
function Data:GetCategories()
	return Data.categoryNames
end

-- Next DR
function Data:NextDR(diminished, category)
	local durations = Data.diminishedDurations[category or "default"] or Data.diminishedDurations.default
	for i = 1, #durations do
		if diminished > durations[i] then
			return durations[i]
		end
	end
	return 0
end

-- Iterate through the spells of a given category.
-- Pass "nil" to iterate through all spells.
do
	local function categoryIterator(id, category)
		local newCat
		repeat
			id, newCat = next(Data.spells, id)
			if id and newCat == category then
				return id, category
			end
		until not id
	end

	function Data:IterateSpells(category)
		if category then
			return categoryIterator, category
		else
			return next, Data.spells
		end
	end
end

-- Iterate through the spells and providers of a given category.
-- Pass "nil" to iterate through all spells.
function Data:IterateProviders(category)
	if category then
		return next, spellsAndProvidersByCategory[category] or {}
	else
		return next, Data.providers
	end
end

--[[ EXAMPLES ]]--
-- This is how you would track DR easily, you're welcome to do whatever you want with the below functions

--[[
local trackedPlayers = {}
local function debuffGained(spellID, destName, destGUID, isEnemy, isPlayer)
	-- Not a player, and this category isn't diminished in PVE, as well as make sure we want to track NPCs
	local drCat = DRData:GetSpellCategory(spellID)
	if( not isPlayer and not DRData:IsPVE(drCat) ) then
		return
	end

	if( not trackedPlayers[destGUID] ) then
		trackedPlayers[destGUID] = {}
	end

	-- See if we should reset it back to undiminished
	local tracked = trackedPlayers[destGUID][drCat]
	if( tracked and tracked.reset <= GetTime() ) then
		tracked.diminished = 1.0
	end
end

local function debuffFaded(spellID, destName, destGUID, isEnemy, isPlayer)
	local drCat = DRData:GetSpellCategory(spellID)
	if( not isPlayer and not DRData:IsPVE(drCat) ) then
		return
	end

	if( not trackedPlayers[destGUID] ) then
		trackedPlayers[destGUID] = {}
	end

	if( not trackedPlayers[destGUID][drCat] ) then
		trackedPlayers[destGUID][drCat] = { reset = 0, diminished = 1.0 }
	end

	local time = GetTime()
	local tracked = trackedPlayers[destGUID][drCat]

	tracked.reset = time + DRData:GetResetTime(drCat)
	tracked.diminished = DRData:NextDR(tracked.diminished, drCat)

	-- Diminishing returns changed, now you can do an update
end

local function resetDR(destGUID)
	-- Reset the tracked DRs for this person
	if( trackedPlayers[destGUID] ) then
		for cat in pairs(trackedPlayers[destGUID]) do
			trackedPlayers[destGUID][cat].reset = 0
			trackedPlayers[destGUID][cat].diminished = 1.0
		end
	end
end

local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local COMBATLOG_OBJECT_REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local COMBATLOG_OBJECT_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER

local eventRegistered = {["SPELL_AURA_APPLIED"] = true, ["SPELL_AURA_REFRESH"] = true, ["SPELL_AURA_REMOVED"] = true, ["PARTY_KILL"] = true, ["UNIT_DIED"] = true}
local function COMBAT_LOG_EVENT_UNFILTERED(self, event, timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName, spellSchool, auraType)
	if( not eventRegistered[eventType] ) then
		return
	end

	-- Enemy gained a debuff
	if( eventType == "SPELL_AURA_APPLIED" ) then
		if( auraType == "DEBUFF" and DRData:GetSpellCategory(spellID) ) then
			local isPlayer = ( bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER or bit.band(destFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) == COMBATLOG_OBJECT_CONTROL_PLAYER )
			debuffGained(spellID, destName, destGUID, (bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE), isPlayer)
		end

	-- Enemy had a debuff refreshed before it faded, so fade + gain it quickly
	elseif( eventType == "SPELL_AURA_REFRESH" ) then
		if( auraType == "DEBUFF" and DRData:GetSpellCategory(spellID) ) then
			local isPlayer = ( bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER or bit.band(destFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) == COMBATLOG_OBJECT_CONTROL_PLAYER )
			local isHostile = (bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE)
			debuffFaded(spellID, destName, destGUID, isHostile, isPlayer)
			debuffGained(spellID, destName, destGUID, isHostile, isPlayer)
		end

	-- Buff or debuff faded from an enemy
	elseif( eventType == "SPELL_AURA_REMOVED" ) then
		if( auraType == "DEBUFF" and DRData:GetSpellCategory(spellID) ) then
			local isPlayer = ( bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER or bit.band(destFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) == COMBATLOG_OBJECT_CONTROL_PLAYER )
			debuffFaded(spellID, destName, destGUID, (bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE), isPlayer)
		end

	-- Don't use UNIT_DIED inside arenas due to accuracy issues, outside of arenas we don't care too much
	elseif( ( eventType == "UNIT_DIED" and select(2, IsInInstance()) ~= "arena" ) or eventType == "PARTY_KILL" ) then
		resetDR(destGUID)
	end
end]]