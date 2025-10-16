-- Achievements.lua
local addonName, Ironman = ...

local achievementFrame = CreateFrame("Frame")

-- Track recent damage targets
local recentTargets = {}

-- Utility print function
local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Ironman]|r " .. msg)
end

-- Track an achievement
function Ironman:AddAchievement(category, description, points)
  IronmanModeDB.achievements = IronmanModeDB.achievements or {}
  table.insert(IronmanModeDB.achievements, {
    time = time(), -- Unix timestamp
    date = date("%Y-%m-%d %H:%M:%S"),
    category = category,
    description = description,
    points = points or 0,
    level = UnitLevel("player"),
    zone = GetZoneText(),
    session = IronmanModeDB.sessionID
  })

  Ironman:AddScore(points or 0)

  Print(string.format("|cff00ff00Achievement!|r %s (+%d points)", description, points or 0))
end

-- Add score with integrity checking
function Ironman:AddScore(amount)
  -- Sanity check: no single achievement worth more than 1000 points
  if amount > 1000 then
    Print("Invalid score amount detected!")
    return
  end
  
  -- Initialize scores if needed
  IronmanModeDB.normalScore = IronmanModeDB.normalScore or 0
  IronmanModeDB.hardcoreScore = IronmanModeDB.hardcoreScore or 0
  
  -- Add to appropriate score
  if IronmanModeDB.doHardcore then
    IronmanModeDB.hardcoreScore = IronmanModeDB.hardcoreScore + amount
	IronmanModeDB.normalScore = IronmanModeDB.hardcoreScore
  else
    IronmanModeDB.normalScore = IronmanModeDB.normalScore + amount
  end
  
  -- Update integrity hash
  if Ironman.GenerateHash then
    IronmanModeDB.integrityHash = Ironman:GenerateHash()
  end
end

-- Item quality thresholds
local RARE_QUALITY = 3  -- Blue (Rare)
local EPIC_QUALITY = 4  -- Purple (Epic)
local LEGENDARY_QUALITY = 5  -- Orange (Legendary)


-- Generate point scaling by percent for level difference from player
-- Positive levelDiff means the target is higher level than the player
local function GetLevelScaling(playerLevel, targetLevel)

  local levelDiff = targetLevel - playerLevel

  if levelDiff >= 5 then
	return 2.0  -- 200% for 5 or more levels higher
  elseif levelDiff == 4 then
	return 1.8
  elseif levelDiff == 3 then
	return 1.6
  elseif levelDiff == 2 then
	return 1.4
  elseif levelDiff == 1 then
	return 1.2
  elseif levelDiff == 0 then
	return 1.0
  elseif levelDiff == -1 then
	return 0.8
  elseif levelDiff == -2 then
	return 0.6
  elseif levelDiff == -3 then
	return 0.4
  elseif levelDiff == -4 then
	return 0.2
  else
	return 0.0  -- 0% for 5 or more levels lower
  end
end


-- Event handlers
achievementFrame:SetScript("OnEvent", function(self, event, ...)
  if not IronmanModeDB or not IronmanModeDB.enabled then return end
  
  if event == "CHAT_MSG_LOOT" then
    local message = ...
    -- Parse loot message for item links
    local itemLink = message:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    
    if itemLink then
      local itemName, _, itemQuality, itemLevel = GetItemInfo(itemLink)
      
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
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()
    
    -- Track when player damages something
    if sourceGUID == UnitGUID("player") and (subevent == "SWING_DAMAGE" or string.find(subevent, "_DAMAGE")) then
      recentTargets[destGUID] = {
        name = destName,
        flags = destFlags,
        time = GetTime()
      }
    end
    
    -- Check if something died that we recently damaged
    if subevent == "UNIT_DIED" and recentTargets[destGUID] then
      local target = recentTargets[destGUID]
      
      -- Only award if damaged within last 10 seconds
      if GetTime() - target.time <= 10 then
        local destFlags = target.flags
        local isElite = bit.band(destFlags, COMBATLOG_OBJECT_ELITE) ~= 0
        local isRareElite = bit.band(destFlags, COMBATLOG_OBJECT_RAREELITE) ~= 0
        local isRare = bit.band(destFlags, COMBATLOG_OBJECT_RARE) ~= 0
        local isWorldBoss = bit.band(destFlags, COMBATLOG_OBJECT_WORLDBOSS) ~= 0
        local isNotPlayer = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0

        if isNotPlayer then
          if isWorldBoss then
            Ironman:AddAchievement("Combat", string.format("Defeated World Boss: %s", target.name), 100 * GetLevelScaling(UnitLevel("player"), UnitLevel(target.name)))
          elseif isRareElite then
            Ironman:AddAchievement("Combat", string.format("Defeated Rare Elite: %s", target.name), 75  * GetLevelScaling(UnitLevel("player"), UnitLevel(target.name)))
          elseif isRare then
            Ironman:AddAchievement("Combat", string.format("Defeated Rare: %s", target.name), 50 * GetLevelScaling(UnitLevel("player"), UnitLevel(target.name)))
          elseif isElite then
            Ironman:AddAchievement("Combat", string.format("Defeated Elite: %s", target.name), 25 * GetLevelScaling(UnitLevel("player"), UnitLevel(target.name)))
		  else
			Ironman:AddAchievement("Combat", string.format("Defeated: %s", target.name), 1 * GetLevelScaling(UnitLevel("player"), UnitLevel(target.name)))
          end
        end
      end
      
      -- Clean up
      recentTargets[destGUID] = nil
    end
    
  elseif event == "QUEST_TURNED_IN" then
    local questID, xpReward, moneyReward = ...
    local questTitle = C_QuestLog.GetTitleForQuestID(questID)
    
    -- Check if it's a difficult quest
    local questInfo = C_QuestLog.GetQuestTagInfo(questID)
    
    if questInfo then
      local isGroup = questInfo.tagID == 1
      local isDungeon = questInfo.tagID == 81
      local isRaid = questInfo.tagID == 62
      
      if isRaid then
        Ironman:AddAchievement("Quest", string.format("Completed raid quest: %s", questTitle or "Unknown"), 100)
      elseif isDungeon then
        Ironman:AddAchievement("Quest", string.format("Completed dungeon quest: %s", questTitle or "Unknown"), 75)
      elseif isGroup then
        Ironman:AddAchievement("Quest", string.format("Completed group quest: %s", questTitle or "Unknown"), 50)
      end
    end
    
    -- High XP reward quests
    if xpReward and xpReward >= 10000 then
      Ironman:AddAchievement("Quest", string.format("Completed high-reward quest: %s", questTitle or "Unknown"), 30)
    end
    
  elseif event == "ACHIEVEMENT_EARNED" then
    local achievementID = ...
    local _, name, points, completed = GetAchievementInfo(achievementID)
    
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