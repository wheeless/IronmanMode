local addonName, Ironman = ...

-- Initialize defaults
local function InitMinimapDB()
  if not IronmanModeDB.minimap then
    IronmanModeDB.minimap = {
      hide = false,
    }
  end
end

local icon = LibStub("LibDBIcon-1.0")  -- Move this declaration UP before LDB

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
  type = "data source",
  text = addonName,
  icon = "Interface\\AddOns\\IronmanMode\\Ironman_Mode_logo.png",
  OnClick = function(self, button)
    if button == "LeftButton" then
      if Ironman and Ironman.OpenUI then
      if Ironman.UI and Ironman.UI:IsShown() then
        Ironman.UI:Hide()
      else
        Ironman:OpenUI()
      end
    end
    elseif button == "RightButton" then
      -- Toggle minimap icon visibility
      IronmanModeDB.minimap.hide = not IronmanModeDB.minimap.hide
      if IronmanModeDB.minimap.hide then
        icon:Hide(addonName)
        print("|cffff0000[Ironman]|r Minimap icon hidden. Use /ironman or addon settings to show it again.")
      else
        icon:Show(addonName)
        print("|cffff0000[Ironman]|r Minimap icon shown.")
      end
    end
  end,
  OnTooltipShow = function(tooltip)
    tooltip:AddLine(addonName)
    tooltip:AddLine("|cffffff00Left-Click|r to open addon")
    tooltip:AddLine("|cffffff00Right-Click|r to toggle visibility")
  end,
})

-- Wait for DB to be ready
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
  if loadedAddon == "IronmanMode" then
    InitMinimapDB()

    -- Register the icon with saved position
    if icon and LDB then
      icon:Register(addonName, LDB, IronmanModeDB.minimap)

      -- Show or hide based on saved preference
      if IronmanModeDB.minimap.hide then
        icon:Hide(addonName)
      else
        icon:Show(addonName)
      end
    end

    self:UnregisterEvent("ADDON_LOADED")
  end
end)

-- Settings panel
local panel = CreateFrame("Frame")
panel.name = "Ironman Mode"

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Ironman Mode")

local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
desc:SetText("Customize your Ironman addon settings here!")

-- Minimap toggle checkbox
local minimapCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
minimapCheckbox:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
minimapCheckbox.text = minimapCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
minimapCheckbox.text:SetPoint("LEFT", minimapCheckbox, "RIGHT", 5, 0)
minimapCheckbox.text:SetText("Show Minimap Icon")
minimapCheckbox:SetScript("OnShow", function(self)
  self:SetChecked(not IronmanModeDB.minimap.hide)
end)
minimapCheckbox:SetScript("OnClick", function(self)
  IronmanModeDB.minimap.hide = not self:GetChecked()
  if icon then
    if IronmanModeDB.minimap.hide then
      icon:Hide(addonName)
      print("|cffff0000[Ironman]|r Minimap icon hidden.")
    else
      icon:Show(addonName)
      print("|cffff0000[Ironman]|r Minimap icon shown.")
    end
  end
end)

local logo = panel:CreateTexture(nil, "ARTWORK")
logo:SetSize(64, 64)
logo:SetPoint("TOPRIGHT", -16, -16)
logo:SetTexture("Interface\\AddOns\\IronmanMode\\Ironman_Mode_logo.png")

-- Note: InterfaceOptions_AddCategory was removed in newer WoW versions
-- Settings can be accessed via /ironman command instead

-- Slash command to show minimap icon (must be at the very end)
SLASH_IRONMANICON1 = "/ironmanicon"
SlashCmdList["IRONMANICON"] = function()
  if IronmanModeDB and IronmanModeDB.minimap then
    if IronmanModeDB.minimap.hide then
      IronmanModeDB.minimap.hide = false
      icon:Show(addonName)
      print("|cffff0000[Ironman]|r Minimap icon shown.")
    else
      print("|cffff0000[Ironman]|r Minimap icon is already visible.")
    end
  else
    print("|cffff0000[Ironman]|r Error: Database not initialized.")
  end
end