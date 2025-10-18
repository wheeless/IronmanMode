local addonName, Ironman = ...
-- Config.lua
SLASH_IRONMAN1 = "/ironman"
SLASH_IRONMAN2 = "/im"
SlashCmdList["IRONMAN"] = function(msg)
  msg = msg or ""
  local cmd = string.lower(msg)

  if cmd == "rules" then
    print("|cff00ff00Ironman Rules:|r")
    for ruleKey, rule in pairs(IronmanModeDB.rules) do
      if type(rule) == "table" then
        print(" - " .. (rule.name or ruleKey) .. ": " .. (rule.enabled and "ON" or "OFF") .. " (weight: " .. (rule.weight or 10) .. ")")
      else
        print(" - " .. ruleKey .. ": " .. (rule and "ON" or "OFF") .. " (BOOLEAN - NEEDS CONVERSION)")
      end
    end

  elseif cmd == "convert" then
    print("|cffff0000[Ironman]|r Manually triggering rule conversion...")
    if IronmanModeDB and IronmanModeDB.rules then
      Ironman:ConvertRulesToObjects()
      print("|cffff0000[Ironman]|r Conversion attempt complete. Check above for details.")
    else
      print("|cffff0000[Ironman]|r No rules to convert!")
    end

  elseif cmd == "debug" then
    print("|cffff0000[Ironman]|r === Debug Info ===")
    print("Enabled: " .. tostring(IronmanModeDB.enabled))
    print("Validity: " .. tostring(IronmanModeDB.validity))
    print("Hardcore: " .. tostring(IronmanModeDB.doHardcore))
    print("Normal Score: " .. tostring(IronmanModeDB.normalScore))
    print("Hardcore Score: " .. tostring(IronmanModeDB.hardcoreScore))
    print("Violations: " .. tostring(#(IronmanModeDB.violations or {})))
    print("Rules:")
    for ruleKey, rule in pairs(IronmanModeDB.rules or {}) do
      if type(rule) == "table" then
        print("  " .. ruleKey .. ": enabled=" .. tostring(rule.enabled) .. ", weight=" .. tostring(rule.weight) .. ", name=" .. tostring(rule.name))
      else
        print("  " .. ruleKey .. ": " .. tostring(rule) .. " (BOOLEAN - NEEDS CONVERSION)")
      end
    end

  elseif msg:match("^toggle%s+") then
    local ruleKey = msg:match("^toggle%s+(%S+)")
    if IronmanModeDB.rules[ruleKey] ~= nil then
      local rule = IronmanModeDB.rules[ruleKey]
      if type(rule) == "table" then
        IronmanModeDB.rules[ruleKey].enabled = not rule.enabled
        print(ruleKey .. " toggled to " .. tostring(IronmanModeDB.rules[ruleKey].enabled))
      else
        IronmanModeDB.rules[ruleKey] = not rule
        print(ruleKey .. " toggled to " .. tostring(IronmanModeDB.rules[ruleKey]) .. " (still boolean - use /ironman convert)")
      end
      -- Recalculate validity after toggle
      IronmanModeDB.validity = Ironman:CalculateValidity()
    else
      print("Unknown rule: " .. ruleKey)
    end

  else
    print("|cff00ff00Ironman Commands:|r")
    print("/ironman or /im - open UI")
    print("/ironman rules - list current rule states")
    print("/ironman toggle <rule> - toggle a rule")
    print("/ironman debug - show detailed debug info")
    print("/ironman convert - manually convert rules to object format")
  end
end
