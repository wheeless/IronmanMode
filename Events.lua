-- Events.lua
local addonName, Ironman = ...
local f = CreateFrame("Frame")
Ironman.events = f

-- Track party members using the addon
local partyIronmanUsers = {}

-- Utility print function
local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Ironman]|r " .. msg)
end

-- Track a violation
local function AddViolation(rule, detail)
  IronmanModeDB.violations = IronmanModeDB.violations or {}
  table.insert(IronmanModeDB.violations, {
    time = date("%Y-%m-%d %H:%M:%S"),
    rule = rule,
    detail = detail
  })
  Print("Rule violated: " .. rule)
end

-- Disable a rule, with optional message
local function DisableRule(rule, message)
  if IronmanModeDB.rules[rule] then
    IronmanModeDB.rules[rule] = false
    if message then
      Print(message)
    end
  end
end

-- Send ping to party members
local function PingParty()
  if GetNumGroupMembers() > 0 then
    C_ChatInfo.SendAddonMessage("IronmanMode", "PING", "PARTY")
  end
end

-- Check if all party members are Ironman users
local function IsIronmanParty()
  local numMembers = GetNumGroupMembers()
  if numMembers == 0 then
    return false
  end
  
  -- Count how many party members (excluding self) responded
  local otherMembers = numMembers - 1
  local ironmanMembers = 0
  
  for name, _ in pairs(partyIronmanUsers) do
    ironmanMembers = ironmanMembers + 1
  end
  
  -- All other party members must be using Ironman addon
  return ironmanMembers == otherMembers and otherMembers > 0
end

-- Event handler
f:SetScript("OnEvent", function(self, event, ...)
  -- Handle PLAYER_LOGIN first (before checking if enabled)
  if event == "PLAYER_LOGIN" then
    Ironman:InitDB()
    if IronmanModeDB.firstLogin then
      Ironman:ShowSetupPrompt()
    elseif IronmanModeDB.enabled then
      Print("Welcome back, fearless ironman!")
    end
    return
  end
  
  -- Handle addon messages
  if event == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = ...
    if prefix == "IronmanMode" then
      if message == "PING" then
        -- Someone is checking if we're using Ironman
        C_ChatInfo.SendAddonMessage("IronmanMode", "PONG", "PARTY")
      elseif message == "PONG" then
        -- Someone confirmed they're using Ironman
        partyIronmanUsers[sender] = true
      end
    end
    return
  end
  
  -- Handle party roster changes
  if event == "GROUP_ROSTER_UPDATE" then
    -- Clear the list
    partyIronmanUsers = {}
    
    -- If in a party, ping everyone
    if GetNumGroupMembers() > 0 then
      PingParty()
      -- Give 1 second for responses
      C_Timer.After(1, function()
        if IronmanModeDB and IronmanModeDB.enabled and IronmanModeDB.rules.noParty then
          if not IsIronmanParty() then
            -- Not all party members are Ironman users
            StaticPopupDialogs["IRONMAN_PARTY_CONFIRM"] = {
              text = "Joining a party with non-Ironman players will violate Iron Man rules. Leave party?",
              button1 = "Yes",
              button2 = "No",
              OnAccept = function()
                LeaveParty()
                Print("Left party to maintain Iron Man status.")
              end,
              OnCancel = function()
                DisableRule("noParty", "You joined a party with non-Ironman players. You have lost 10% validity.")
              end,
              timeout = 0,
              whileDead = true,
              hideOnEscape = true,
            }
            StaticPopup_Show("IRONMAN_PARTY_CONFIRM")
          else
            -- All party members are Ironman users!
            Print("Party allowed - all members are Ironman players!")
          end
        end
      end)
    end
    return
  end
  
  -- For all other events, check if addon is enabled
  if not IronmanModeDB or not IronmanModeDB.enabled then return end
  local rules = IronmanModeDB.rules
  
  if event == "TRADE_SHOW" and rules.noTrade then
    CancelTrade()
    StaticPopupDialogs["IRONMAN_TRADE_CONFIRM"] = {
      text = "Trading will violate Iron Man rules. Proceed anyway?",
      button1 = "Yes",
      button2 = "No",
      OnAccept = function()
        DisableRule("noTrade", "Attempted to trade with another player. You have lost 10% validity.")
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
    }
    StaticPopup_Show("IRONMAN_TRADE_CONFIRM")
    
  elseif event == "GUILD_ROSTER_UPDATE" and rules.noGuild then
    if IsInGuild() then
      StaticPopupDialogs["IRONMAN_GUILD_CONFIRM"] = {
        text = "Being in a guild violates Iron Man rules. Leave guild?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
          GuildLeave()
          Print("Left guild to maintain Iron Man status.")
        end,
        OnCancel = function()
          DisableRule("noGuild", "You joined a guild and lost 10% validity.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
      }
      StaticPopup_Show("IRONMAN_GUILD_CONFIRM")
    end
    
  elseif event == "MAIL_SHOW" and rules.noMail then 
    CloseMail()
    StaticPopupDialogs["OPEN_MAIL_CONFIRM"] = {
      text = "You will lose 30 percent validity for opening your mailbox. Are you sure?",
      button1 = "Yes",
      button2 = "No",
      OnAccept = function()
        DisableRule("noMail", "You have lost 10% validity.")
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
    }
    StaticPopup_Show("OPEN_MAIL_CONFIRM")
    
	elseif event == "PLAYER_DEAD" and IronmanModeDB.doHardcore then
  	IronmanModeDB.doHardcore = false
  	IronmanModeDB.doHardcoreTurnedOff = true
  	Print("You have died. You have lost your Hardcore Ironman status.")
    
  elseif event == "AUCTION_HOUSE_SHOW" and rules.noAH then
    CloseAuctionHouse()
    StaticPopupDialogs["IRONMAN_AH_CONFIRM"] = {
      text = "Using the Auction House will violate Iron Man rules. Proceed anyway?",
      button1 = "Yes",
      button2 = "No",
      OnAccept = function()
        DisableRule("noAH", "Opened the Auction House and lost 10% validity.")
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
    }
    StaticPopup_Show("IRONMAN_AH_CONFIRM")
  end
end)

-- Register addon message prefix
C_ChatInfo.RegisterAddonMessagePrefix("IronmanMode")

-- Register all relevant events
f:RegisterEvent("TRADE_SHOW")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:RegisterEvent("MAIL_SHOW")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")