-- Achievements.lua
local addonName, Ironman = ...

local achievementFrame = CreateFrame("Frame")

-- Utility print function
local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Ironman]|r " .. msg)
end

-- Track an achievement
function Ironman:AddAchievement(category, description, points)
  IronmanModeDB.achievements = IronmanModeDB.achievements or {}
  IronmanModeDB.normalScore = IronmanModeDB.normalScore or 0
  IronmanModeDB.hardcoreScore = IronmanModeDB.hardcoreScore or
  
  table.insert(IronmanModeDB.achievements, {
    time = date("%Y-%m-%d %H:%M:%S"),
    category = category,
    description = description,
    points = points or 0
  })
  IronmanModeDB.normalScore = IronmanModeDB.normalScore + (points or 0)
  -- For hardcore mode, double the points
  if IronmanModeDB.doHardcore then
	IronmanModeDB.hardcoreScore = IronmanModeDB.hardcoreScore + (points or 0)
  end
  
  Print(string.format("|cff00ff00Achievement!|r %s (+%d points)", description, points or 0))
end

-- Item quality thresholds
local RARE_QUALITY = 3  -- Blue (Rare)
local EPIC_QUALITY = 4  -- Purple (Epic)
local LEGENDARY_QUALITY = 5  -- Orange (Legendary)

-- Rare mob classification
local function IsRareMob(unitID)
  local classification = UnitClassification(unitID)
  return classification == "rare" or classification == "rareelite"
end

local function IsBoss(unitID)
  local classification = UnitClassification(unitID)
  return classification == "worldboss" or classification == "elite" or UnitLevel(unitID) == -1
end

-- Event handlers
achievementFrame:SetScript("OnEvent", function(self, event, ...)
  if not IronmanModeDB or not IronmanModeDB.enabled then return end
  
  if event == "CHAT_MSG_LOOT" then
    local message = ...
    -- Parse loot message for item links
    local itemLink = message:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    
    if itemLink then
      local _, _, itemQuality, itemLevel, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(itemLink)
      local itemName = GetItemInfo(itemLink)
      
      if itemQuality then
        -- Epic or Legendary items
        if itemQuality >= EPIC_QUALITY then
          local points = itemQuality == LEGENDARY_QUALITY and 100 or 50
          Ironman:AddAchievement("Loot", string.format("Looted %s", itemLink), points)
        -- High item level rares
        elseif itemQuality == RARE_QUALITY and itemLevel and itemLevel >= 100 then
          Ironman:AddAchievement("Loot", string.format("Looted rare item %s", itemLink), 25)
        end
      end
    end
    
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()
    
    -- Check if player killed something
    if subevent == "PARTY_KILL" and sourceGUID == UnitGUID("player") then
      local unitID = "target"
      
      -- Rare mob kill
      if IsRareMob(unitID) then
        Ironman:AddAchievement("Combat", string.format("Defeated rare mob: %s", destName or "Unknown"), 50)
      -- Boss kill
      elseif IsBoss(unitID) then
        Ironman:AddAchievement("Combat", string.format("Defeated boss: %s", destName or "Unknown"), 75)
      end
    end
    
  elseif event == "QUEST_TURNED_IN" then
    local questID, xpReward, moneyReward = ...
    local questTitle = C_QuestLog.GetTitleForQuestID(questID)
    
    -- Check if it's a difficult quest (high level, dungeon, raid, or group quest)
    local questInfo = C_QuestLog.GetQuestTagInfo(questID)
    
    if questInfo then
      local isGroup = questInfo.isGroup
      local isDungeon = questInfo.isDungeon
      local isRaid = questInfo.isRaid
      
      if isRaid then
        Ironman:AddAchievement("Quest", string.format("Completed raid quest: %s", questTitle or "Unknown"), 100)
      elseif isDungeon then
        Ironman:AddAchievement("Quest", string.format("Completed dungeon quest: %s", questTitle or "Unknown"), 75)
      elseif isGroup then
        Ironman:AddAchievement("Quest", string.format("Completed group quest: %s", questTitle or "Unknown"), 50)
      end
    end
    
    -- High XP reward quests (indicates difficulty)
    if xpReward and xpReward >= 10000 then
      Ironman:AddAchievement("Quest", string.format("Completed high-reward quest: %s", questTitle or "Unknown"), 30)
    end
    
  elseif event == "ACHIEVEMENT_EARNED" then
    local achievementID = ...
    local _, name, points, completed, month, day, year = GetAchievementInfo(achievementID)
    
    if completed then
      Ironman:AddAchievement("Achievement", string.format("Earned achievement: %s", name), points * 10)
    end
    
  elseif event == "PLAYER_LEVEL_UP" then
    local level = ...
    local points = level * 10
    Ironman:AddAchievement("Level", string.format("Reached level %d", level), points)
  end
end)

-- Register events
achievementFrame:RegisterEvent("CHAT_MSG_LOOT")
achievementFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
achievementFrame:RegisterEvent("QUEST_TURNED_IN")
achievementFrame:RegisterEvent("ACHIEVEMENT_EARNED")
achievementFrame:RegisterEvent("PLAYER_LEVEL_UP")

print("|cffff0000[Ironman]|r Achievements system loaded.")