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
  validity = 100,
  rules = {
    noTrade = {enabled = true, weight = 10, name = "No Trading"},
    noGuild = {enabled = true, weight = 10, name = "No Guilds"},
    noParty = {enabled = true, weight = 10, name = "No Parties"},
    noMail = {enabled = true, weight = 10, name = "No Mail"},
    noAH = {enabled = true, weight = 10, name = "No Auction House"},
	-- Future rules:
	-- noDungeons = {enabled = false, weight = 10, name = "No Dungeons"},
    -- noHeirlooms = {enabled = true, weight = 10, name = "No Heirlooms"},
    -- noOutsideBuffs = {enabled = false, weight = 5, name = "No Outside Buffs"},
	-- noMounts = {enabled = false, weight = 5, name = "No Mounts"},
	-- noPets = {enabled = false, weight = 5, name = "No Pets"},
	-- noProfessions = {enabled = false, weight = 10, name = "No Professions"},
	-- noCrafting = {enabled = false, weight = 10, name = "No Crafting"},
	-- noConsumables = {enabled = false, weight = 5, name = "No Consumables"},
	-- noResurrection = {enabled = false, weight = 15, name = "No Resurrection"},
	-- ironWill = {enabled = false, weight = 20, name = "Iron Will"},
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

-- Helper to count table entries
function Ironman:TableSize(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end


-- Convert old boolean rules to new object format
function Ironman:ConvertRulesToObjects()
  if not IronmanModeDB.rules then
    return
  end

  local needsConversion = false
  for ruleKey, value in pairs(IronmanModeDB.rules) do
    if type(value) == "boolean" then
      needsConversion = true
      break
    end
  end

  if needsConversion then
    local newRules = {}
    for ruleKey, value in pairs(IronmanModeDB.rules) do
      if type(value) == "boolean" then
        -- Get default rule object from defaults
        local defaultRule = self.defaults.rules[ruleKey]
        if defaultRule then
          newRules[ruleKey] = {
            enabled = value,
            weight = defaultRule.weight,
            name = defaultRule.name
          }
        else
          -- Unknown rule, create with default weight
          newRules[ruleKey] = {
            enabled = value,
            weight = 10,
            name = ruleKey
          }
        end
      else
        -- Already an object, keep it
        newRules[ruleKey] = value
      end
    end
    IronmanModeDB.rules = newRules
    print("|cffff0000[Ironman]|r Rules converted to new format!")
  end
end

-- Calculate validity score
function Ironman:CalculateValidity()
  if not IronmanModeDB then
    return 0
  end

  local hasBeenTurnedOff = IronmanModeDB.hasBeenTurnedOff or false
  local hasBeenCleared = IronmanModeDB.hasBeenCleared or false
  local violations = IronmanModeDB.violations or {}
  local violationCount = #violations

  -- If flagged, validity is 0
  if hasBeenCleared or hasBeenTurnedOff then
    return 0
  end

  -- Start at 100
  local validity = 100

  -- Count total rule weight and enabled weight
  local rules = IronmanModeDB.rules or {}
  local totalWeight = 0
  local enabledWeight = 0

  for ruleKey, rule in pairs(rules) do
    if type(rule) == "table" then
      totalWeight = totalWeight + (rule.weight or 10)
      if rule.enabled then
        enabledWeight = enabledWeight + (rule.weight or 10)
      end
    end
  end

  -- Calculate validity based on enabled weight percentage
  if totalWeight > 0 then
    validity = (enabledWeight / totalWeight) * 100
  end

  -- Deduct for violations (each violation = 0.83% penalty, 120 violations = invalid)
  if violationCount > 0 and validity > 0 then
    local penaltyPerViolation = 100 / 120
    local totalPenalty = penaltyPerViolation * violationCount
    validity = math.max(0, validity - totalPenalty)
  end

  -- Round to 2 decimal places
  validity = math.floor(validity * 100 + 0.5) / 100

  return validity
end

-- Initialize DB
function Ironman:InitDB()
  if not IronmanModeDB then
    -- New character - initialize with defaults
    IronmanModeDB = CopyTable(self.defaults)
  else
    -- Existing character - ensure top-level keys exist
    for k, v in pairs(self.defaults) do
      if IronmanModeDB[k] == nil then
        if type(v) == "table" then
          IronmanModeDB[k] = CopyTable(v)
        else
          IronmanModeDB[k] = v
        end
      end
    end

    -- Ensure rules table exists
    if not IronmanModeDB.rules then
      IronmanModeDB.rules = CopyTable(self.defaults.rules)
    else
      -- Add any new rules from defaults that don't exist yet
      for ruleKey, defaultRule in pairs(self.defaults.rules) do
        if IronmanModeDB.rules[ruleKey] == nil then
          IronmanModeDB.rules[ruleKey] = CopyTable(defaultRule)
        end
      end
    end
  end

  -- Always ensure violations table exists
  if not IronmanModeDB.violations then
    IronmanModeDB.violations = {}
  end

  -- Calculate and save initial validity
  IronmanModeDB.validity = self:CalculateValidity()
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
        print("|cffff0000[Ironman]|r Hardcore mode enabled. Death will disable Ironman Mode!")
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
