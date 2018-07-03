local GladiusEx = _G.GladiusEx
local L = LibStub("AceLocale-3.0"):GetLocale("GladiusEx")
local fn = LibStub("LibFunctional-1.0")

-- V: heavily inspired by Jaxington's Gladius-With-Interrupts
-- (and then heavily improved by Konjunktur.)

local function GetDefaultInterruptData()
    return {
        ["Pummel"] = {duration = 4, priority = 7},   -- [Warrior] Pummel
        ["Rebuke"] = {duration = 4, priority = 7},  -- [Paladin] Rebuke
        ["Avenger's Shield"] = {duration = 3, priority = 7}, -- [Paladin] Avengers Shield
        ["Kick"] = {duration = 5, priority = 7},   -- [Rogue] Kick
        ["Mind Freeze"] = {duration = 3, priority = 7},  -- [DK] Mind Freeze
        ["Wind Shear"] = {duration = 3, priority = 7},  -- [Shaman] Wind Shear
        ["Spell Lock"] = {duration = 6, priority = 7},  -- [Warlock] Spell Lock
        ["Counterspell"] = {duration = 6, priority = 7},   -- [Mage] Counterspell
        ["Skull Bash(Cat Form)"] = {duration = 4, priority = 7}, -- [Feral] Skull Bash
        ["Skull Bash(Bear Form)"] = {duration = 4, priority = 7},  -- [Feral] Skull Bash
        ["Solar Beam"] = {duration = 5, priority = 7},  -- [Moonkin] Solar Beam
    }
end

local defaults = {
	classIconInterrupts = GetDefaultInterruptData()
}

local Interrupt = GladiusEx:NewGladiusExModule("Interrupt", defaults, defaults)


function Interrupt:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    if not self.frame then
		self.frame = {}
	end
end

function Interrupt:OnDisable()
	self:UnregisterAllEvents()
	for unit in pairs(self.frame) do
		self.frame[unit]:SetAlpha(0)
	end
end

function Interrupt:PLAYER_ENTERING_WORLD()
    local arena = select(2, IsInInstance())
    
    if arena then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end

end

function Interrupt:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
	local subEvent = select(2, ...)
	local destGUID = select(8, ...)
	local name = select(13, ...)
    local spellid = select(12, ...)

	if subEvent ~= "SPELL_CAST_SUCCESS" and subEvent ~= "SPELL_INTERRUPT" then
        return
	end
    
    local unit = GladiusEx:GetUnitIdByGUID(destGUID)
	if not unit then return end
    
	-- it is necessary to check ~= false, as if the unit isn't casting a channeled spell, it will be nil
	if subEvent == "SPELL_CAST_SUCCESS" and select(8, UnitChannelInfo(unit)) ~= false then
		-- not interruptible
		return
	end

    local data = self.db[unit].ClassIconInterrupts[name]
    if data then
        local duration = data[1]
        if not duration then return end
        local priority = data[2]
        if not priority then return end
        local button = GladiusEx.buttons[unit]
        if not button then return end
        
        local _,_,icon = GetSpellInfo(spellid)
     
        self:InterruptUpdate(unit, name, icon, duration, GetTime()+duration, priority)
        GladiusEx:ScheduleTimer(self.InterruptUpdate, duration+0.1, self, unit)

    end
end

function Interrupt:InterruptUpdate(unit, name, icon, duration, expires, priority)
    Interrupt:SendMessage("GLADIUSEX_INTERRUPT_UPDATE", unit, name, icon, duration, expires, priority)
end

local function HasInterruptEditBox()
	return not not LibStub("AceGUI-3.0").WidgetVersions["Interrupt_EditBox"]
end

function Interrupt:GetOptions(unit)
	-- TODO: Add system for changing priorities of the interrupts
	local options
	options = {
		interruptList = {
			type = "group",
			name = "Important interrupts",
			childGroups = "tree",
			order = 3,
			args = {
				newInterrupt = {
					type = "group",
					name = "New interrupt",
					desc = "New interrupt",
					inline = true,
					order = 1,
					args = {
						name = {
							type = "input",
							dialogControl = HasInterruptEditBox() and "Interrupt_EditBox" or nil,
							name = L["Name"],
							desc = "Name of the interrupt",
							get = function() return self.newInterruptName or "" end,
							set = function(info, value) self.newInterruptName = GetSpellInfo(value) or value end,
							disabled = function() return not self:IsUnitEnabled(unit) end,
							order = 1,
						},
						priority = {
							type= "range",
							name = L["Priority"],
							desc = "Select what priority the interrupt should have - higher equals more priority",
							get = function() return self.newInterruptPriority or "" end,
							set = function(info, value) self.newInterruptPriority = value end,
							disabled = function() return not self:IsUnitEnabled(unit) end,
							min = 0,
							max = 10,
							step = 1,
							order = 2,
						},
                        duration = {
							type= "range",
							name = "Duration",
							desc = "Enter the duration of the interrupt",
							get = function() return self.newInterruptDuration or "" end,
							set = function(info, value) self.newInterruptDuration = value end,
							disabled = function() return not self:IsUnitEnabled(unit) end,
							min = 0,
							max = 10,
							step = 1,
							order = 3,
						},
						add = {
							type = "execute",
							name = "Add new interrupt",
							func = function(info)
								self.db[unit].classIconInterrupts[self.newInterruptName] = {duration = self.newInterruptDuration or 1000, priority = self.newInterruptPriority or 0}
								options.interruptList.args[self.newInterruptName] = self:SetupInterruptOptions(options, unit, self.newInterruptName)
								self.newInterruptName = nil
								GladiusEx:UpdateFrames()
							end,
							disabled = function() return not self:IsUnitEnabled(unit) or not (self.newInterruptName and self.newInterruptPriority) end,
							order = 4,
						},
					},
				},
			},
		},
	}

	-- set some initial value for the interrupts priority
	self.newInterruptPriority = 5
    
    -- set some initial value for the interrupts duration
	self.newInterruptDuration = 4

	-- setup interrupts
	for interrupt, data in pairs(self.db[unit].classIconInterrupts) do
        print(interrupt)
		options.interruptList.args[interrupt] = self:SetupInterruptOptions(options, unit, interrupt)
	end

	return options
end

function Interrupt:SetupInterruptOptions(options, unit, interrupt)
	return {
		type = "group",
		name = interrupt,
		desc = interrupt,
		get = getInterrupt,
		set = setInterrupt,
		disabled = function() return not self:IsUnitEnabled(unit) end,
		args = {
			name = {
				type = "input",
				dialogControl = HasInterruptEditBox() and "Interrupt_EditBox" or nil,
				name = L["Name"],
				desc = "Name of the interrupt",
				disabled = function() return not self:IsUnitEnabled(unit) end,
                set = function(info, value)
                    local old = self.db[unit].classIconInterrupts[info[#(info) - 1]]
                    self.db[unit].classIconInterrupts[info[#(info) - 1]] = nil 
                    self.db[unit].classIconInterrupts[value] = {old.priority, old.duration} 
                
                end,
                get = function(info, value) return info[#(info) - 1] end,
				order = 1,
			},
			priority = {
				type= "range",
				name = L["Priority"],
				desc = "Select what priority the interrupt should have - higher equals more priority",
                set = function(info, value) self.db[unit].classIconInterrupts[info[#(info) - 1]].priority = value end,
                get = function(info, value) return self.db[unit].classIconInterrupts[info[#(info) - 1]].priority end,
				min = 0, softMax = 10, step = 1,
				order = 2,
			},
            duration = {
				type= "range",
				name = "Duration",
				desc = "Select what duration the interrupt should have",
                set = function(info, value) self.db[unit].classIconInterrupts[info[#(info) - 1]].duration = value end,
                get = function(info, value) return self.db[unit].classIconInterrupts[info[#(info) - 1]].duration end,
				min = 0, softMax = 10, step = 1,
				order = 3,
			},
			delete = {
				type = "execute",
				name = L["Delete"],
				func = function(info)
					local interrupt = info[#(info) - 1]
					self.db[unit].classIconInterrupts[interrupt] = nil
					options.interruptList.args[interrupt] = nil
					GladiusEx:UpdateFrames()
				end,
				disabled = function() return not self:IsUnitEnabled(unit) end,
				order = 4,
			},
		},
	}
end
