-- UI.lua
local addonName, Ironman = ...

function Ironman:OpenUI()
  if Ironman.UI then
    Ironman.UI:Show()
    if Ironman.ShowTab then
      Ironman:ShowTab("status")
    end
    return
  end

  -------------------------------------------------
  -- Check if ineligible
  -------------------------------------------------
  if IronmanModeDB and IronmanModeDB.disabledDueToEligibility then
	print("|cffff0000[Ironman]|r You are ineligible to use Ironman Mode on this character.")
	print("|cffff0000[Ironman]|r Ironman Mode has been disabled for this character.")
	print("|cffff0000[Ironman]|r You may create a new character to use Ironman Mode.")
	return
  end
  -------------------------------------------------
  -- Main Frame
  -------------------------------------------------

  local frame = CreateFrame("Frame", "IronmanUIFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(400, 440)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("FULLSCREEN_DIALOG")  -- Highest non-tooltip layer
  frame:SetFrameLevel(1000)  -- Very high within that strata
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Make ESC key close the frame
  frame:SetScript("OnHide", function(self)
    if self.isClosing then return end
  end)
  
  -- Register for ESC key
  table.insert(UISpecialFrames, "IronmanUIFrame")

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("TOP", 0, -8)
  frame.title:SetText("Ironman Mode")

  -- Logo
  local logo = frame:CreateTexture(nil, "ARTWORK")
  logo:SetSize(64, 64)
  logo:SetPoint("TOP", 0, -35)
  logo:SetTexture("Interface\\AddOns\\IronmanMode\\Ironman_Mode_logo.png")

  -------------------------------------------------
  -- Tabs
  -------------------------------------------------
  local tabs = {}
  local function CreateTab(id, text, tabKey)
    local tab = CreateFrame("Button", "IronmanTab"..id, frame, "UIPanelButtonTemplate")
    tab:SetID(id)
    tab:SetText(text)
    tab:SetSize(100, 24)
    tab.tabKey = tabKey
    tab:SetScript("OnClick", function(self)
      Ironman:ShowTab(self.tabKey)
    end)
    return tab
  end

  tabs[1] = CreateTab(1, "Status", "status")
  tabs[2] = CreateTab(2, "Rules", "rules")
  tabs[3] = CreateTab(3, "Violations", "violations")
  tabs[4] = CreateTab(4, "Settings", "settings")

  tabs[1]:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 5, 7)
  tabs[2]:SetPoint("LEFT", tabs[1], "RIGHT", -15, 0)
  tabs[3]:SetPoint("LEFT", tabs[2], "RIGHT", -15, 0)
  tabs[4]:SetPoint("LEFT", tabs[3], "RIGHT", -15, 0)

  -------------------------------------------------
  -- Status Tab
  -------------------------------------------------
  local statusPanel = CreateFrame("Frame", nil, frame)
  statusPanel:SetSize(360, 360)
  statusPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
  statusPanel:SetFrameLevel(frame:GetFrameLevel() + 1)

  -- Status display elements
  local statusY = -110
  local statusSpacing = -30

  local turnedOffLabel = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  turnedOffLabel:SetPoint("TOPLEFT", 20, statusY)
  turnedOffLabel:SetText("Has Been Turned Off:")
  
  local turnedOffValue = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  turnedOffValue:SetPoint("LEFT", turnedOffLabel, "RIGHT", 10, 0)
  
  statusY = statusY + statusSpacing
  
  local clearedLabel = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  clearedLabel:SetPoint("TOPLEFT", 20, statusY)
  clearedLabel:SetText("Has Been Cleared:")
  
  local clearedValue = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  clearedValue:SetPoint("LEFT", clearedLabel, "RIGHT", 10, 0)
  
  statusY = statusY + statusSpacing
  
  local violationCountLabel = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  violationCountLabel:SetPoint("TOPLEFT", 20, statusY)
  violationCountLabel:SetText("Total Violations:")
  
  local violationCountValue = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  violationCountValue:SetPoint("LEFT", violationCountLabel, "RIGHT", 10, 0)
  
  statusY = statusY + statusSpacing
  
  local validityLabel = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  validityLabel:SetPoint("TOPLEFT", 20, statusY)
  validityLabel:SetText("Iron Man Validity:")
  
  local validityValue = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  validityValue:SetPoint("LEFT", validityLabel, "RIGHT", 10, 0)

  statusY = statusY + statusSpacing

  local ironmanScoreLabel = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ironmanScoreLabel:SetPoint("TOPLEFT", 20, statusY)
  ironmanScoreLabel:SetText("Iron Man Score:")
  
  local ironmanScoreValue = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  ironmanScoreValue:SetPoint("LEFT", ironmanScoreLabel, "RIGHT", 10, 0)

  statusY = statusY + statusSpacing

  local hardcoreScoreLabel = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  hardcoreScoreLabel:SetPoint("TOPLEFT", 20, statusY)
  hardcoreScoreLabel:SetText("Hardcore Score:")

  local hardcoreScoreValue = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  hardcoreScoreValue:SetPoint("LEFT", hardcoreScoreLabel, "RIGHT", 10, 0)
  -------------------------------------------------

  local function RefreshStatus()
    -- Get data from DB
    local hasBeenTurnedOff = IronmanModeDB.hasBeenTurnedOff or false
    local hasBeenCleared = IronmanModeDB.hasBeenCleared or false
    local violations = IronmanModeDB.violations or {}
    local violationCount = #violations
    
    -- Calculate rule statistics (needed for both validity and score)
    local rules = IronmanModeDB.rules or {}
    local totalRules = 0
    local enabledRules = 0
    
    for ruleKey, enabled in pairs(rules) do
      totalRules = totalRules + 1
      if enabled then
        enabledRules = enabledRules + 1
      end
    end
    
    -- Calculate validity
    local validity = 0
    local validityColor = {1, 0, 0}
    local validityText = "Invalid"
    
    if hasBeenCleared or hasBeenTurnedOff then
      validity = 0
      validityText = "Invalid (Flagged)"
    else
      validity = 100
      validity = validity - ((totalRules - enabledRules) * 10)
      
      if violationCount > 0 and validity > 0 then
        local penaltyPerViolation = 100 / 120
        local totalPenalty = penaltyPerViolation * violationCount
        validity = math.max(0, validity - totalPenalty)
      end
      
      validity = math.floor(validity * 100 + 0.5) / 100
      
      if validity >= 90 then
        validityText = string.format("Excellent (%.2f)", validity)
        validityColor = {0, 1, 0}
      elseif validity >= 70 then
        validityText = string.format("Good (%.2f)", validity)
        validityColor = {0.5, 1, 0}
      elseif validity >= 50 then
        validityText = string.format("Fair (%.2f)", validity)
        validityColor = {1, 1, 0}
      elseif validity >= 25 then
        validityText = string.format("Poor (%.2f)", validity)
        validityColor = {1, 0.5, 0}
      elseif validity > 0 then
        validityText = string.format("Very Poor (%.2f)", validity)
        validityColor = {1, 0, 0}
      else
        validityText = "Invalid (0.00)"
        validityColor = {1, 0, 0}
      end
    end
    
    turnedOffValue:SetText(hasBeenTurnedOff and "Yes" or "No")
    turnedOffValue:SetTextColor(hasBeenTurnedOff and 1 or 0, hasBeenTurnedOff and 0 or 1, 0)
    
    clearedValue:SetText(hasBeenCleared and "Yes" or "No")
    clearedValue:SetTextColor(hasBeenCleared and 1 or 0, hasBeenCleared and 0 or 1, 0)
    
    violationCountValue:SetText(tostring(violationCount))
    violationCountValue:SetTextColor(violationCount > 0 and 1 or 0, violationCount == 0 and 1 or 0, 0)
    
    validityValue:SetText(validityText)
    validityValue:SetTextColor(validityColor[1], validityColor[2], validityColor[3])

    -- Iron Man Score
    local ironmanScore = IronmanModeDB.normalScore or 0
    local hardcoreScore = IronmanModeDB.hardcoreScore or 0
    
    if IronmanModeDB.doHardcoreTurnedOffOnStart == true then
	  ironmanScoreValue:SetText(string.format("%d", ironmanScore))
	  ironmanScoreValue:SetTextColor(1, 1, 1)
	elseif IronmanModeDB.doHardcoreTurnedOff == true then
      -- Show both scores if hardcore was turned off, but hardcore score is frozen
      ironmanScoreValue:SetText(string.format("%d", ironmanScore))
      ironmanScoreValue:SetTextColor(1, 1, 1) -- Orange tint
	  hardcoreScoreValue:SetText(string.format("%d (Frozen)", hardcoreScore))
	  hardcoreScoreValue:SetTextColor(1, 1, 0.5)
    else
	  -- Show only hardcore score if in hardcore mode
      ironmanScoreValue:SetText(tostring(ironmanScore))
      ironmanScoreValue:SetTextColor(1, 1, 1)
	  hardcoreScoreValue:SetText(string.format("%d", hardcoreScore))
	  hardcoreScoreValue:SetTextColor(1, 1, 1)
    end
  end

  -------------------------------------------------
  -- Rules Tab
  -------------------------------------------------
  local rulesPanel = CreateFrame("Frame", nil, frame)
  rulesPanel:SetSize(360, 360)
  rulesPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
  rulesPanel:SetFrameLevel(frame:GetFrameLevel() + 1)

  -- Temporary storage for rule changes
  local tempRules = {}

  local function CreateCheckbox(parent, label, ruleKey, offsetY)
    if not IronmanModeDB.rules[ruleKey] then
      return nil
    end
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, offsetY)
    
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cb.text:SetText(label)
    
    cb.ruleKey = ruleKey
    
    if IronmanModeDB and IronmanModeDB.rules then
      cb:SetChecked(IronmanModeDB.rules[ruleKey])
      tempRules[ruleKey] = IronmanModeDB.rules[ruleKey]
    else
      cb:SetChecked(false)
      tempRules[ruleKey] = false
    end
    
    cb:SetScript("OnClick", function(self)
      tempRules[ruleKey] = self:GetChecked()
    end)
    
    return cb
  end

  local y = -110
  local spacing = -35

  rulesPanel.checks = {}
  rulesPanel.checks.noTrade = CreateCheckbox(rulesPanel, "No Trading", "noTrade", y)
  if IronmanModeDB.rules["noTrade"] then
    y = y + spacing
  end
  rulesPanel.checks.noGuild = CreateCheckbox(rulesPanel, "No Guilds", "noGuild", y)
  if IronmanModeDB.rules["noGuild"] then
    y = y + spacing
  end
  rulesPanel.checks.noParty = CreateCheckbox(rulesPanel, "No Parties", "noParty", y)
  if IronmanModeDB.rules["noParty"] then
    y = y + spacing
  end
  rulesPanel.checks.noMail = CreateCheckbox(rulesPanel, "No Mail", "noMail", y)
  if IronmanModeDB.rules["noMail"] then
    y = y + spacing
  end
  rulesPanel.checks.noAH = CreateCheckbox(rulesPanel, "No Auction House", "noAH", y)

  -- OK Button
  local okBtn = CreateFrame("Button", nil, rulesPanel, "UIPanelButtonTemplate")
  okBtn:SetSize(100, 24)
  okBtn:SetPoint("BOTTOM", 0, 15)
  okBtn:SetText("OK")
  okBtn:SetScript("OnClick", function()
    for ruleKey, value in pairs(tempRules) do
      IronmanModeDB.rules[ruleKey] = value
    end
    print("|cffff0000[Ironman]|r Rules saved.")
    if Ironman.RefreshStatus then
      Ironman:RefreshStatus()
    end
  end)

  local function RefreshRules()
    for _, cb in pairs(rulesPanel.checks) do
      if cb and IronmanModeDB and IronmanModeDB.rules and cb.ruleKey then
        cb:SetChecked(IronmanModeDB.rules[cb.ruleKey])
        tempRules[cb.ruleKey] = IronmanModeDB.rules[cb.ruleKey]
      end
    end
  end

  -------------------------------------------------
  -- Violations Tab
  -------------------------------------------------
  local violationsPanel = CreateFrame("Frame", nil, frame)
  violationsPanel:SetSize(360, 360)
  violationsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
  violationsPanel:SetFrameLevel(frame:GetFrameLevel() + 1)

  local scrollFrame = CreateFrame("ScrollFrame", "IronmanViolationsScroll", violationsPanel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetSize(360, 250)
  scrollFrame:SetPoint("TOPLEFT", 20, -110)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(340, 1)
  scrollFrame:SetScrollChild(content)

  local fontStrings = {}
  
  local function RefreshViolations()
    for _, fs in ipairs(fontStrings) do
      fs:Hide()
    end

    local data = IronmanModeDB.violations or {}
    local yOff = -5

    if #data == 0 then
      if not fontStrings[1] then
        fontStrings[1] = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      end
      fontStrings[1]:SetPoint("TOPLEFT", 0, yOff)
      fontStrings[1]:SetText("No violations recorded for this character.")
      fontStrings[1]:Show()
      content:SetHeight(20)
      return
    end

    for i, entry in ipairs(data) do
      if not fontStrings[i] then
        fontStrings[i] = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      end
      local fs = fontStrings[i]
      fs:ClearAllPoints()
      fs:SetPoint("TOPLEFT", 0, yOff)
      fs:SetText(string.format("[%s] %s - %s", entry.time, entry.rule, entry.detail))
      fs:SetJustifyH("LEFT")
      fs:SetWidth(340)
      fs:Show()
      yOff = yOff - 18
    end

    content:SetHeight(math.max(1, math.abs(yOff)))
  end

  local clearBtn = CreateFrame("Button", nil, violationsPanel, "UIPanelButtonTemplate")
  clearBtn:SetSize(100, 22)
  clearBtn:SetPoint("BOTTOM", 0, 15)
  clearBtn:SetText("Clear Log")
  clearBtn:SetScript("OnClick", function()
    IronmanModeDB.violations = {}
    IronmanModeDB.hasBeenCleared = true
    RefreshViolations()
    if Ironman.RefreshStatus then
      Ironman:RefreshStatus()
    end
  end)

-------------------------------------------------
-- Settings Tab
-------------------------------------------------
local settingsPanel = CreateFrame("Frame", nil, frame)
settingsPanel:SetSize(360, 360)
settingsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
settingsPanel:SetFrameLevel(frame:GetFrameLevel() + 1)

-- Version display (bottom left, opposite of close button)
local versionText = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
versionText:SetPoint("BOTTOMLEFT", 20, 15)
local addonVersion = GetAddOnMetadata("IronmanMode", "Version") or "Unknown"
local addonAuthor = GetAddOnMetadata("IronmanMode", "Author") or "Unknown"
versionText:SetText(string.format("v%s by %s", addonVersion, addonAuthor))
versionText:SetTextColor(0.7, 0.7, 0.7, 1) -- Gray color

local settingsY = -110
local settingsSpacing = -35

-- Minimap Icon checkbox
local minimapCheckbox = CreateFrame("CheckButton", nil, settingsPanel, "UICheckButtonTemplate")
minimapCheckbox:SetPoint("TOPLEFT", 20, settingsY)
minimapCheckbox.text = minimapCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
minimapCheckbox.text:SetPoint("LEFT", minimapCheckbox, "RIGHT", 5, 0)
minimapCheckbox.text:SetText("Show Minimap Icon")

settingsY = settingsY + settingsSpacing

-- Hardcore Mode checkbox
local hardcoreCheckbox = CreateFrame("CheckButton", nil, settingsPanel, "UICheckButtonTemplate")
hardcoreCheckbox:SetPoint("TOPLEFT", 20, settingsY)
hardcoreCheckbox.text = hardcoreCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hardcoreCheckbox.text:SetPoint("LEFT", hardcoreCheckbox, "RIGHT", 5, 0)
hardcoreCheckbox.text:SetText("Hardcore Mode (Death = Disabled)")

local function RefreshSettings()
  if IronmanModeDB and IronmanModeDB.minimap then
    minimapCheckbox:SetChecked(not IronmanModeDB.minimap.hide)
  end
  
  -- Initialize doHardcore if it doesn't exist
  if IronmanModeDB.doHardcore == nil then
    IronmanModeDB.doHardcore = false
  end
  if IronmanModeDB.doHardcoreTurnedOff == nil then
    IronmanModeDB.doHardcoreTurnedOff = false
  end
  
  -- Hide hardcore checkbox if it was previously turned off
  if IronmanModeDB.doHardcoreTurnedOff or IronmanModeDB.doHardcoreTurnedOffOnStart then
    hardcoreCheckbox:Hide()
    hardcoreCheckbox.text:Hide()
  else
    hardcoreCheckbox:Show()
    hardcoreCheckbox.text:Show()
    hardcoreCheckbox:SetChecked(IronmanModeDB.doHardcore)
  end
end

minimapCheckbox:SetScript("OnClick", function(self)
  if IronmanModeDB and IronmanModeDB.minimap then
    IronmanModeDB.minimap.hide = not self:GetChecked()
    local icon = LibStub("LibDBIcon-1.0")
    if IronmanModeDB.minimap.hide then
      icon:Hide("IronmanMode")
      print("|cffff0000[Ironman]|r Minimap icon hidden.")
    else
      icon:Show("IronmanMode")
      print("|cffff0000[Ironman]|r Minimap icon shown.")
    end
  end
end)

hardcoreCheckbox:SetScript("OnClick", function(self)
  local isChecked = self:GetChecked()
  
  if isChecked then
    -- Turning hardcore ON
    IronmanModeDB.doHardcore = true
  else
    -- Turning hardcore OFF - show confirmation
    if IronmanModeDB.doHardcore then
      -- Revert the checkbox state temporarily
      self:SetChecked(true)
      
      -- Show confirmation dialog
      StaticPopupDialogs["IRONMAN_HARDCORE_DISABLE"] = {
        text = "If you opt out of hardcore mode, your Hardcore Score will be frozen and you will not be able to opt in again. Are you sure?",
        button1 = "OK",
        button2 = "Cancel",
        OnAccept = function()
          -- User confirmed - disable hardcore
          IronmanModeDB.doHardcore = false
          IronmanModeDB.doHardcoreTurnedOff = true
          hardcoreCheckbox:SetChecked(false)
          print("|cffff0000[Ironman]|r Hardcore mode disabled and locked.")
          
          -- Hide the checkbox
          hardcoreCheckbox:Hide()
          hardcoreCheckbox.text:Hide()
        end,
        OnCancel = function()
          -- User cancelled - keep it checked
          hardcoreCheckbox:SetChecked(true)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
      }
      StaticPopup_Show("IRONMAN_HARDCORE_DISABLE")
    end
  end
end)

  -------------------------------------------------
  -- Tab Switch Logic
  -------------------------------------------------
  function Ironman:ShowTab(tab)
    statusPanel:Hide()
    rulesPanel:Hide()
    violationsPanel:Hide()
    settingsPanel:Hide()
    
    if tab == "status" then
      statusPanel:Show()
      RefreshStatus()
    elseif tab == "rules" then
      rulesPanel:Show()
      RefreshRules()
    elseif tab == "violations" then
      violationsPanel:Show()
      RefreshViolations()
    elseif tab == "settings" then
      settingsPanel:Show()
      RefreshSettings()
    else
      statusPanel:Show()
      RefreshStatus()
    end
  end

  function Ironman:RefreshStatus()
    RefreshStatus()
  end

  statusPanel:Show()
  rulesPanel:Hide()
  violationsPanel:Hide()
  settingsPanel:Hide()
  RefreshStatus()

  -------------------------------------------------
  -- Close Button
  -------------------------------------------------
  local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  close:SetSize(80, 24)
  close:SetPoint("BOTTOMRIGHT", -10, 15)
  close:SetText("Close")
  close:SetScript("OnClick", function() frame:Hide() end)

  Ironman.UI = frame
end

SLASH_IRONMANUI1 = "/ironman"
SlashCmdList["IRONMANUI"] = function()
  Ironman:OpenUI()
end