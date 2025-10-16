-- Core.lua
local addonName, Ironman = ...
Ironman.frame = CreateFrame("Frame")
local f = Ironman.frame

-- Default settings
Ironman.defaults = {
  enabled = false,
  firstLogin = true,
  hasBeenTurnedOff = false,
  hasBeenCleared = false,
  normalScore = 0,
  hardcoreScore = 0,
  achievements = {},
  doHardcore = false,
  rules = {
    noTrade = true,
    noGuild = true,
    noParty = true,
    noMail = true,
    noAH = true,
	-- Future rules:
	-- noDungeons = false,
    -- noHeirlooms = true,
    -- noOutsideBuffs = false,
	-- noMounts = false,
	-- noPets = false,
	-- noProfessions = false,
	-- noCrafting = false,
	-- noConsumables = false,
	-- noResurrection = false,
	-- ironWill = false,
  },
}

-- In Core.lua - Add integrity checks
Ironman.lastKnownHash = nil

function Ironman:GenerateHash()
  local LibSHA1 = LibStub:GetLibrary("LibSHA1-1.0", true)
  
  if not LibSHA1 then
    return Ironman:GenerateSimpleHash()
  end
  
  local str = string.format("%d|%d|%d|%s|%s|%d|%s|%s|%d",
    IronmanModeDB.normalScore or 0,
    IronmanModeDB.hardcoreScore or 0,
    #(IronmanModeDB.violations or {}),
    tostring(IronmanModeDB.hasBeenCleared),
    tostring(IronmanModeDB.hasBeenTurnedOff),
    UnitLevel("player"),
    UnitName("player"),
    GetRealmName(),
    IronmanModeDB.sessionID or 0
  )
  
  -- Add salt for extra security
  local salt = "IronmanMode_Super_SecretSalt"
  
  return LibSHA1:SHA256(str .. salt)
end

function Ironman:GenerateSimpleHash()
  local str = string.format("%d|%d|%d|%s|%s",
    IronmanModeDB.normalScore or 0,
    IronmanModeDB.hardcoreScore or 0,
    #(IronmanModeDB.violations or {}),
    tostring(IronmanModeDB.hasBeenCleared),
    tostring(IronmanModeDB.hasBeenTurnedOff)
  )
  
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + string.byte(str, i)) % 2147483647
  end
  return hash
end


-- Initialize DB
function Ironman:InitDB()
  if not IronmanModeDB then
    IronmanModeDB = CopyTable(self.defaults)
  else
    -- ensure top-level keys
    for k, v in pairs(self.defaults) do
      if IronmanModeDB[k] == nil then
        IronmanModeDB[k] = CopyTable(v)
      end
    end
    -- deep-merge rules
    if not IronmanModeDB.rules then
      IronmanModeDB.rules = CopyTable(self.defaults.rules)
    else
      for rule, value in pairs(self.defaults.rules) do
        if IronmanModeDB.rules[rule] == nil then
          IronmanModeDB.rules[rule] = value
        end
      end
    end
  end
  -- always ensure violations table exists
  if not IronmanModeDB.violations then
    IronmanModeDB.violations = {}
  end
end

function Ironman:ShowSetupPrompt()
  local playerLevel = UnitLevel("player")
  if playerLevel and playerLevel > 1 and IronmanModeDB.firstLogin == true then
    print("|cffff0000[Ironman]|r Player level is greater than 1, cannot enable Ironman Mode!")
    IronmanModeDB.firstLogin = false
    IronmanModeDB.enabled = false
    IronmanModeDB.hasBeenTurnedOff = true
    IronmanModeDB.hasBeenCleared = true
    IronmanModeDB.violations = {}
    IronmanModeDB.disabledDueToEligibility = true
    return
  end

  local popup = CreateFrame("Frame", "IronmanSetupPopup", UIParent, "BackdropTemplate")
  popup:SetSize(320, 140)
  popup:SetPoint("CENTER")
  popup:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })

  local text = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOP", 0, -25)
  text:SetText("Enable Ironman Mode for this character?")

  local enableBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
  enableBtn:SetSize(100, 24)
  enableBtn:SetPoint("BOTTOMLEFT", 40, 20)
  enableBtn:SetText("Enable")
  enableBtn:SetScript("OnClick", function()
    IronmanModeDB.enabled = true
    IronmanModeDB.firstLogin = false
    popup:Hide()

    -- 🧭 Second confirmation for Hardcore mode
    StaticPopupDialogs["IRONMAN_HARDCORE_CONFIRM"] = {
      text = "Would you also like to enable Hardcore Mode?",
      button1 = "Yes",
      button2 = "No",
      OnAccept = function()
        Ironman:EnableHardcoreMode(true)
        Ironman:OpenUI()
        print("|cffff0000[Ironman]|r Ironman + Hardcore Mode enabled.")
        C_Timer.After(0.1, function()
          if Ironman.AddAchievement then
            Ironman:AddAchievement("Ironman Mode", "Enabled Ironman + Hardcore Mode", 1)
          end
        end)
      end,
      OnCancel = function()
        Ironman:EnableHardcoreMode(false)
        Ironman:OpenUI()
        print("|cffff0000[Ironman]|r Ironman Mode enabled (without Hardcore).")
        C_Timer.After(0.1, function()
          if Ironman.AddAchievement then
            Ironman:AddAchievement("Ironman Mode", "Enabled Ironman Mode", 1)
          end
        end)
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }

    StaticPopup_Show("IRONMAN_HARDCORE_CONFIRM")
  end)

  local disableBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
  disableBtn:SetSize(100, 24)
  disableBtn:SetPoint("BOTTOMRIGHT", -40, 20)
  disableBtn:SetText("Disable")
  disableBtn:SetScript("OnClick", function()
    IronmanModeDB.enabled = false
    IronmanModeDB.firstLogin = false
    popup:Hide()
    print("|cffff0000[Ironman]|r Mode disabled for this character.")
  end)
end


function Ironman:EnableHardcoreMode(enable)
  -- Only toggle, no UI
  if enable then
    if not IronmanModeDB.doHardcore then
      IronmanModeDB.doHardcore = true
      print("|cffff0000[Ironman]|r Hardcore mode enabled. Death will disable Ironman Mode!")
      return true
    end
  else
    if IronmanModeDB.doHardcore then
      IronmanModeDB.doHardcore = false
      print("|cffff0000[Ironman]|r Hardcore mode disabled.")
      return false
    end
  end
end
