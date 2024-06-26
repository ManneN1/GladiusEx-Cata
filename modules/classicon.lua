local GladiusEx = _G.GladiusEx
local L = LibStub("AceLocale-3.0"):GetLocale("GladiusEx")
local fn = LibStub("LibFunctional-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- upvalues
local strfind = string.find
local pairs, select, unpack = pairs, select, unpack
local GetTime, SetPortraitTexture, GetSpellInfo = GetTime, SetPortraitTexture, GetSpellInfo

local Spectate = GladiusEx:GetModule("Spectate", true)

local UnitClass = Spectate and Spectate.UnitClass or UnitClass
local UnitExists = Spectate and Spectate.UnitExists or UnitExists
local UnitGUID = Spectate and Spectate.UnitGUID or UnitGUID
local UnitAura = Spectate and Spectate.UnitAura or UnitAura
local UnitIsVisible = Spectate and Spectate.UnitIsVisible or UnitIsVisible
local UnitIsConnected = Spectate and Spectate.UnitIsConnected or UnitIsConnected



-- NOTE: this list can be modified from the ClassIcon module options, no need to edit it here
-- Nonetheless, if you think that we missed an important aura, please post it on the addon site at curse or wowace
local defaults = {
    classIconMode = "SPEC",
    classIconGloss = false,
    classIconGlossColor = { r = 1, g = 1, b = 1, a = 0.4 },
    classIconImportantAuras = true,
    classIconCrop = true,
    classIconCooldown = true,
    classIconCooldownReverse = true,
    classIconAuras = GladiusEx.GetDefaultImportantAuras()
}

ClassIcon = GladiusEx:NewGladiusExModule("ClassIcon",
    fn.merge(defaults, {
        classIconPosition = "LEFT",
    }),
    fn.merge(defaults, {
        classIconPosition = "RIGHT",
    }))

function ClassIcon:OnEnable()
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("UNIT_PORTRAIT_UPDATE", "UNIT_AURA")
    self:RegisterEvent("UNIT_MODEL_CHANGED")
    self:RegisterMessage("GLADIUSEX_SPEC_UPDATE", "UNIT_AURA")
    self:RegisterMessage("GLADIUSEX_INTERRUPT", "UNIT_AURA")

    if not self.frame then
        self.frame = {}
    end
end

function ClassIcon:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()

    for unit in pairs(self.frame) do
        self.frame[unit].priority = nil
        self.frame[unit].expires = nil
        self.frame[unit]:Hide()
    end

end

function ClassIcon:GetAttachType(unit)
    return "InFrame"
end

function ClassIcon:GetAttachPoint(unit)
    return self.db[unit].classIconPosition
end

function ClassIcon:GetAttachSize(unit)
    return GladiusEx:GetBarsHeight(unit)
end

function ClassIcon:GetModuleAttachPoints()
    return {
        ["ClassIcon"] = L["ClassIcon"],
    }
end

function ClassIcon:GetModuleAttachFrame(unit)
    if not self.frame[unit] then
        self:CreateFrame(unit)
    end

    return self.frame[unit]
end

function ClassIcon:UNIT_AURA(event, unit)
    if not self.frame[unit] or not self.frame[unit]:IsShown() then  return end
    -- important auras
    self:UpdateAura(unit)

end

function ClassIcon:UNIT_MODEL_CHANGED(event,unit)
    if not self.frame[unit] then return end

    -- force model update
    if self.frame[unit].portrait3d then
        self.frame[unit].portrait3d.guid = false
    end

    self:UpdateAura(unit)
end

function ClassIcon:handle_aura(unit, name, best_priority)
    local prio = self:GetImportantAura(unit, name)
        
    if prio and prio >= best_priority then
        return true, prio
    else
        return false, nil
    end
end

function ClassIcon:ScanAuras(unit)
    local best_priority = 0
    local best_name, best_icon, best_duration, best_expires
    local t = GetTime()

    -- debuffs
    for index = 1, 40 do
        local name,_, icon, _, _, duration, expires, _, _, _, spellid = UnitAura(unit, index, "HARMFUL")
        if not name then break end
        local prio = self:GetImportantAura(unit, name) or self:GetImportantAura(unit, spellid)
        if prio and prio > best_priority or (prio == best_priority and best_expires and expires > best_expires) then
            best_name, best_icon, best_duration, best_expires, best_priority = name, icon, duration, expires, prio
        end
    end

    -- buffs
    for index = 1, 40 do
        local name,_, icon, _, _, duration, expires, _, _, _, spellid = UnitAura(unit, index, "HELPFUL")
        if not name then break end
        local prio = self:GetImportantAura(unit, name) or self:GetImportantAura(unit, spellid)
        -- V: make sure we have a best_expires before comparing it
        if prio and prio > best_priority or (prio == best_priority and best_expires and expires > best_expires) then
            best_name, best_icon, best_duration, best_expires, best_priority = name, icon, duration, expires, prio
        end
    end
    
    -- interrupts
    local interrupt = GladiusEx:GetModule("InterruptsEx", true)
    if interrupt then
        local name, icon, duration, expires, prio = interrupt:GetInterruptFor(unit)
        if name then
            if prio and prio > best_priority or (prio == best_priority and best_expires and expires > best_expires) then
                best_name, best_icon, best_duration, best_expires, best_priority = name, icon, duration, expires, prio
            end
        end
    end
    
    return best_name, best_icon, best_duration, best_expires
end

function ClassIcon:UpdateAura(unit)
    if not self.frame[unit] or not self.db[unit].classIconImportantAuras then return end

    local name, icon, duration, expires = self:ScanAuras(unit)
    
    if name then
        self:SetAura(unit, name, icon, duration, expires)
    else
        self:SetClassIcon(nil, unit)
    end
end

function ClassIcon:SetAura(unit, name, icon, duration, expires)
    -- don't display the aura if we're already showing the same icon / expiration / duration (this causes a brief "glitch" to appear)
    if self.frame[unit].icon and self.frame[unit].icon == icon and
        ((not self.frame[unit].duration and not duration) or (self.frame[unit].duration and duration and self.frame[unit].duration == duration)) and
        ((not self.frame[unit].expires and not expires) or (self.frame[unit].expires and expires and self.frame[unit].expires == expires)) then
       return 
    end
    
    self.frame[unit].icon = icon
    self.frame[unit].duration = duration
    self.frame[unit].expires = expires
    
    self:SetTexture(unit, icon, true, 0, 1, 0, 1)

    -- display aura
    if self.db[unit].classIconCooldown and duration ~= 0 then
        self.frame[unit].cooldown:SetCooldown(expires - duration, duration)
        self.frame[unit].cooldown:Show()
    else
        self.frame[unit].cooldown:Hide()
    end
end

function ClassIcon:SetTexture(unit, texture, needs_crop, left, right, top, bottom)
    -- so the user wants a border, but the borders in the blizzard icons are
    -- messed up in random ways (some are missing the alpha at the corners, some contain
    -- random blocks of colored pixels there)
    -- so instead of using the border already present in the icons, we crop them and add
    -- our own (this would have been a lot easier if wow allowed alpha mask textures)
    local needs_border = needs_crop and not self.db[unit].classIconCrop
    local size = self:GetAttachSize(unit)
    if needs_border then
        self.frame[unit].texture:ClearAllPoints()
        self.frame[unit].texture:SetPoint("CENTER")
        self.frame[unit].texture:SetWidth(size * (1 - 6 / 64))
        self.frame[unit].texture:SetHeight(size * (1 - 6 / 64))
        self.frame[unit].texture_border:Show()
    else
        self.frame[unit].texture:ClearAllPoints()
        self.frame[unit].texture:SetPoint("CENTER")
        self.frame[unit].texture:SetWidth(size)
        self.frame[unit].texture:SetHeight(size)
        self.frame[unit].texture_border:Hide()
    end


    if needs_crop then
        local n
        if self.db[unit].classIconCrop then n = 5 else n = 3 end
        left = left + (right - left) * (n / 64)
        right = right - (right - left) * (n / 64)
        top = top + (bottom - top) * (n / 64)
        bottom = bottom - (bottom - top) * (n / 64)
    end

    -- set texture
    self.frame[unit].texture:SetTexture(texture)
    self.frame[unit].texture:SetTexCoord(left, right, top, bottom)

    -- hide portrait
    if self.frame[unit].portrait3d then
        self.frame[unit].portrait3d:Hide()
    end
    if self.frame[unit].portrait2d then
        self.frame[unit].portrait2d:Hide()
    end
end

function ClassIcon:SetClassIcon(_, unit)
    if not self.frame[unit] then return end

    -- hide cooldown frame
    self.frame[unit].cooldown:Hide()

    if self.db[unit].classIconMode == "PORTRAIT2D" and (GladiusEx:IsArenaUnit(unit) or not self:IsSpectating()) then
        -- portrait2d
        if not self.frame[unit].portrait2d then
            self.frame[unit].portrait2d = self.frame[unit]:CreateTexture(nil, "OVERLAY")
            self.frame[unit].portrait2d:SetAllPoints()
            local n = 9 / 64
            self.frame[unit].portrait2d:SetTexCoord(n, 1 - n, n, 1 - n)
        end
        if not UnitIsVisible(unit) or not UnitIsConnected(unit) then
            self.frame[unit].portrait2d:Hide()
        else
            SetPortraitTexture(self.frame[unit].portrait2d, unit)
            self.frame[unit].portrait2d:Show()
            if self.frame[unit].portrait3d then
                self.frame[unit].portrait3d:Hide()
            end
            self.frame[unit].texture:SetTexture(0, 0, 0, 1)
            return
        end
    elseif self.db[unit].classIconMode == "PORTRAIT3D" and (GladiusEx:IsArenaUnit(unit) or not self:IsSpectating()) then
        -- portrait3d
        local zoom = 1.0
        if not self.frame[unit].portrait3d then
            self.frame[unit].portrait3d = CreateFrame("PlayerModel", nil, self.frame[unit])
            self.frame[unit].portrait3d:SetAllPoints()
            self.frame[unit].portrait3d:SetScript("OnShow", function(f) f:SetPortraitZoom(zoom) end)
            self.frame[unit].portrait3d:SetScript("OnHide", function(f) f.guid = nil end)
        end
        if not UnitIsVisible(unit) or not UnitIsConnected(unit) then
            self.frame[unit].portrait3d:Hide()
        else
            local guid = UnitGUID(unit)
            if self.frame[unit].portrait3d.guid ~= guid then
                self.frame[unit].portrait3d.guid = guid
                self.frame[unit].portrait3d:SetUnit(unit)
                self.frame[unit].portrait3d:SetPortraitZoom(zoom)
                self.frame[unit].portrait3d:SetPosition(0, 0, 0)
            end
            self.frame[unit].portrait3d:Show()
            self.frame[unit].texture:SetTexture(0, 0, 0, 1)
            if self.frame[unit].portrait2d then
                self.frame[unit].portrait2d:Hide()
            end
            return
        end
    end

    -- get unit class
    local class, specID

    if not GladiusEx:IsTesting(unit) or GladiusEx:IsSpectating() then
        class = UnitExists(unit) and select(2, UnitClass(unit)) or nil
        
        -- check for arena prep info
        if not class then
            class = GladiusEx.buttons[unit].class
        end
        specID = GladiusEx.buttons[unit].specID
    else
        class = GladiusEx.testing[unit].unitClass
        specID = GladiusEx.testing[unit].specID
    end

    local texture
    local left, right, top, bottom
    local needs_crop

    if not class then
        texture = [[Interface\Icons\INV_Misc_QuestionMark]]
        left, right, top, bottom = 0, 1, 0, 1
        needs_crop = true
    elseif self.db[unit].classIconMode == "SPEC" and specID then
        texture = GladiusEx.SPECIALIZATION_ICONS[specID]
        left, right, top, bottom = 0, 1, 0, 1
        needs_crop = true
    else
        texture = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
        left, right, top, bottom = unpack(CLASS_BUTTONS[class])
        needs_crop = true
    end

    self:SetTexture(unit, texture, needs_crop, left, right, top, bottom)
end

function ClassIcon:CreateFrame(unit)
    local button = GladiusEx.buttons[unit]
    if (not button) then return end

    -- create frame
    self.frame[unit] = CreateFrame("CheckButton", "GladiusEx" .. self:GetName() .. "Frame" .. unit, button, "ActionButtonTemplate")
    self.frame[unit]:EnableMouse(false)
    self.frame[unit].texture = _G[self.frame[unit]:GetName().."Icon"]
    self.frame[unit].normalTexture = _G[self.frame[unit]:GetName().."NormalTexture"]
    self.frame[unit].cooldown = _G[self.frame[unit]:GetName().."Cooldown"]
    self.frame[unit].texture_border = self.frame[unit]:CreateTexture(nil, "BACKGROUND", nil, -1)
    self.frame[unit].texture_border:SetTexture([[Interface\AddOns\GladiusEx\media\icon_border]])
    self.frame[unit].texture_border:SetAllPoints()
end

function ClassIcon:Update(unit)
    -- create frame
    if not self.frame[unit] then
        self:CreateFrame(unit)
    end

    -- style action button
    self.frame[unit].normalTexture:SetHeight(self.frame[unit]:GetHeight() + self.frame[unit]:GetHeight() * 0.4)
    self.frame[unit].normalTexture:SetWidth(self.frame[unit]:GetWidth() + self.frame[unit]:GetWidth() * 0.4)

    self.frame[unit].normalTexture:ClearAllPoints()
    self.frame[unit].normalTexture:SetPoint("CENTER")
    self.frame[unit]:SetNormalTexture([[Interface\AddOns\GladiusEx\media\gloss]])

    self.frame[unit].texture:ClearAllPoints()
    self.frame[unit].texture:SetPoint("TOPLEFT", self.frame[unit], "TOPLEFT")
    self.frame[unit].texture:SetPoint("BOTTOMRIGHT", self.frame[unit], "BOTTOMRIGHT")

    self.frame[unit].normalTexture:SetVertexColor(self.db[unit].classIconGlossColor.r, self.db[unit].classIconGlossColor.g,
        self.db[unit].classIconGlossColor.b, self.db[unit].classIconGloss and self.db[unit].classIconGlossColor.a or 0)

    self.frame[unit].cooldown:SetReverse(self.db[unit].classIconCooldownReverse)

    -- hide
    self.frame[unit]:Hide()
end

function ClassIcon:Refresh(unit)
    self:UpdateAura(unit)
end

function ClassIcon:Show(unit)
    -- show frame
    self.frame[unit]:Show()

    -- set class icon
    self:UpdateAura(unit)
end

function ClassIcon:Reset(unit)
    if not self.frame[unit] then return end

    -- hide
    self.frame[unit].priority = nil
    self.frame[unit].expires = nil
    self.frame[unit]:Hide() 
end

function ClassIcon:Test(unit)
end

function ClassIcon:GetImportantAura(unit, name)
    return self.db[unit].classIconAuras[name]
end

local function HasAuraEditBox()
    return not not LibStub("AceGUI-3.0").WidgetVersions["Aura_EditBox"]
end

function ClassIcon:GetOptions(unit)
    local options
    options = {
        general = {
            type = "group",
            name = L["General"],
            order = 1,
            args = {
                widget = {
                    type = "group",
                    name = L["Widget"],
                    desc = L["Widget settings"],
                    inline = true,
                    order = 1,
                    args = {
                        classIconMode = {
                            type = "select",
                            name = L["Show"],
                            values = {
                                ["CLASS"] = L["Class"],
                                ["SPEC"] = L["Spec"],
                                ["PORTRAIT2D"] = L["Portrait 2D"],
                                ["PORTRAIT3D"] = L["Portrait 3D"],
                            },
                            desc = L["When available, show specialization instead of class icons"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 3,
                        },
                        sep = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 4,
                        },
                        classIconImportantAuras = {
                            type = "toggle",
                            name = L["Important auras"],
                            desc = L["Show important auras instead of the class icon"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 5,
                        },
                        classIconCrop = {
                            type = "toggle",
                            name = L["Crop borders"],
                            desc = L["Toggle if the icon borders should be cropped or not"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 6,
                        },
                        sep2 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 7,
                        },
                        classIconCooldown = {
                            type = "toggle",
                            name = L["Cooldown spiral"],
                            desc = L["Display the cooldown spiral for the important auras"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 10,
                        },
                        classIconCooldownReverse = {
                            type = "toggle",
                            name = L["Cooldown reverse"],
                            desc = L["Invert the dark/bright part of the cooldown spiral"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 15,
                        },
                        sep3 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 17,
                        },
                        classIconGloss = {
                            type = "toggle",
                            name = L["Gloss"],
                            desc = L["Toggle gloss on the icon"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 20,
                        },
                        classIconGlossColor = {
                            type = "color",
                            name = L["Gloss color"],
                            desc = L["Color of the gloss"],
                            get = function(info) return GladiusEx:GetColorOption(self.db[unit], info) end,
                            set = function(info, r, g, b, a) return GladiusEx:SetColorOption(self.db[unit], info, r, g, b, a) end,
                            hasAlpha = true,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 25,
                        },
                    },
                },
                position = {
                    type = "group",
                    name = L["Position"],
                    desc = L["Position settings"],
                    inline = true,
                    order = 3,
                    args = {
                        classIconPosition = {
                            type = "select",
                            name = L["Position"],
                            desc = L["Position of the frame"],
                            values = { ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"] },
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 1,
                        },
                    },
                },
            },
        },
        auraList = {
            type = "group",
            name = L["Important auras"],
            childGroups = "tree",
            order = 3,
            args = {
                newAura = {
                    type = "group",
                    name = L["New aura"],
                    desc = L["New aura"],
                    inline = true,
                    order = 1,
                    args = {
                        name = {
                            type = "input",
                            dialogControl = HasAuraEditBox() and "Aura_EditBox" or nil,
                            name = L["Name"],
                            desc = L["Name of the aura"],
                            get = function() return self.newAuraName or "" end,
                            set = function(info, value) self.newAuraName = GetSpellInfo(value) or value end,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 1,
                        },
                        priority = {
                            type= "range",
                            name = L["Priority"],
                            desc = L["Select what priority the aura should have - higher equals more priority"],
                            get = function() return self.newAuraPriority or "" end,
                            set = function(info, value) self.newAuraPriority = value end,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            min = 0,
                            max = 10,
                            step = 0.1,
                            order = 2,
                        },
                        add = {
                            type = "execute",
                            name = L["Add new aura"],
                            func = function(info)
                                self.db[unit].classIconAuras[self.newAuraName] = self.newAuraPriority
                                options.auraList.args[self.newAuraName] = self:SetupAuraOptions(options, unit, self.newAuraName)
                                self.newAuraName = nil
                                GladiusEx:UpdateFrames()
                            end,
                            disabled = function() return not self:IsUnitEnabled(unit) or not (self.newAuraName and self.newAuraPriority) end,
                            order = 3,
                        },
                    },
                },
            },
        },
    }

    -- set some initial value for the auras priority
    self.newAuraPriority = 5

    -- setup auras
    for aura, priority in pairs(self.db[unit].classIconAuras) do
        options.auraList.args[aura] = self:SetupAuraOptions(options, unit, aura)
    end

    return options
end

function ClassIcon:SetupAuraOptions(options, unit, aura)
    local function setAura(info, value)
        if (info[#(info)] == "name") then
            local old_name = info[#(info) - 1]

            -- create new aura
            self.db[unit].classIconAuras[value] = self.db[unit].classIconAuras[old_name]
            options.auraList.args[value] = self:SetupAuraOptions(options, unit, value)

            -- delete old aura
            self.db[unit].classIconAuras[old_name] = nil
            options.auraList.args[old_name] = nil
        else
            self.db[unit].classIconAuras[info[#(info) - 1]] = value
        end

        GladiusEx:UpdateFrames()
    end

    local function getAura(info)
        if (info[#(info)] == "name") then
            return info[#(info) - 1]
        else
            return self.db[unit].classIconAuras[info[#(info) - 1]]
        end
    end

    return {
        type = "group",
        name = aura,
        desc = aura,
        get = getAura,
        set = setAura,
        disabled = function() return not self:IsUnitEnabled(unit) end,
        args = {
            name = {
                type = "input",
                dialogControl = HasAuraEditBox() and "Aura_EditBox" or nil,
                name = L["Name"],
                desc = L["Name of the aura"],
                disabled = function() return not self:IsUnitEnabled(unit) end,
                order = 1,
            },
            priority = {
                type= "range",
                name = L["Priority"],
                desc = L["Select what priority the aura should have - higher equals more priority"],
                min = 0, softMax = 10, step = 0.1,
                order = 2,
            },
            delete = {
                type = "execute",
                name = L["Delete"],
                func = function(info)
                    local aura = info[#(info) - 1]
                    self.db[unit].classIconAuras[aura] = nil
                    options.auraList.args[aura] = nil
                    GladiusEx:UpdateFrames()
                end,
                disabled = function() return not self:IsUnitEnabled(unit) end,
                order = 3,
            },
        },
    }
end
