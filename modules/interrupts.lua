local GladiusEx = _G.GladiusEx
local L = LibStub("AceLocale-3.0"):GetLocale("GladiusEx")
local fn = LibStub("LibFunctional-1.0")

-- V: heavily inspired by Jaxington's Gladius-With-Interrupts
-- (and then heavily improved by Konjunktur.)

local function GetDefaultInterruptData()
    return {
        ["Pummel"] = {4, 7},   -- [Warrior] Pummel
        ["Rebuke"] = {4, 7},  -- [Paladin] Rebuke
        ["Avenger's Shield"] = {3, 7}, -- [Paladin] Avengers Shield
--        [147362] = {3, 7}, -- [Hunter] Countershot
        ["Kick"] = {5, 7},   -- [Rogue] Kick
        ["Mind Freeze"] = {3, 7},  -- [DK] Mind Freeze
        ["Wind Shear"] = {3, 7},  -- [Shaman] Wind Shear
        --[115781] = {6, 7}, -- [Warlock] Optical Blast
        ["Spell Lock"] = {6, 7},  -- [Warlock] Spell Lock
        --[212619] = {6, 7}, -- [Warlock] Call Felhunter
        --[132409] = {6, 7}, -- [Warlock] Spell Lock
        --[171138] = {6, 7}, -- [Warlock] Shadow Lock
        ["Counterspell"] = {6, 7},   -- [Mage] Counterspell
        ["Skull Bash(Cat Form)"] = {4, 7}, -- [Feral] Skull Bash
        ["Skull Bash(Bear Form)"] = {4, 7},  -- [Feral] Skull Bash
        ["Solar Beam"] = {5, 7},  -- [Moonkin] Solar Beam
    }
end

local defaults = {
	interruptdata = GetDefaultInterruptData()
}

local Interrupt = GladiusEx:NewGladiusExModule("Interrupt", defaults, defaults)


function Interrupt:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function Interrupt:OnDisable()
	self:UnregisterAllEvents()
	for unit in pairs(self.frame) do
		self.frame[unit]:SetAlpha(0)
	end
end

function Interrupt:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
	local subEvent = select(2, ...)
	local destGUID = select(8, ...)
	local spellID = select(12, ...)

	local unit = GladiusEx:GetUnitIdByGUID(destGUID)
	if not unit then return end

	if subEvent ~= "SPELL_CAST_SUCCESS" and subEvent ~= "SPELL_INTERRUPT" then
		return
	end
	-- it is necessary to check ~= false, as if the unit isn't casting a channeled spell, it will be nil
	if subEvent == "SPELL_CAST_SUCCESS" and select(8, UnitChannelInfo(unit)) ~= false then
		-- not interruptible
		return
	end

   	local duration = INTERRUPTS[spellID]
   	if not duration then return end
   	local button = GladiusEx.buttons[unit]
   	if not button then return end
    
    self:SendMessage("INTERRUPT_UPDATE", unit, name, icon, duration, priority)
end

function Interrupt:GetOptions(unit)
	-- TODO: Add system for changing priorities of the interrupts
	return {
		general = {
			type = "group",
			name = L["General"],
			order = 1,
			args = {
                sep2 = {
                    type = "description",
                    name = "This module shows interrupt durations over the Arena Enemy Class Icons when they are interrupted.",
                    width = "full",
                    order = 17,
                }},
        },
    }
end
