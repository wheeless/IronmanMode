local addonName, Ironman = ...
-- Config.lua
SLASH_IRONMAN1 = "/ironman"
SlashCmdList["IRONMAN"] = function(msg)
  if msg == "rules" then
    print("|cff00ff00Ironman Rules:|r")
    for rule, active in pairs(IronmanModeDB.rules) do
      print(" - " .. rule .. ": " .. (active and "ON" or "OFF"))
    end
  elseif msg:match("^toggle%s+") then
    local rule = msg:match("^toggle%s+(%S+)")
    if IronmanModeDB.rules[rule] ~= nil then
      IronmanModeDB.rules[rule] = not IronmanModeDB.rules[rule]
      print(rule .. " toggled to " .. tostring(IronmanModeDB.rules[rule]))
    else
      print("Unknown rule: " .. rule)
    end
  else
    print("|cff00ff00Ironman Commands:|r")
    print("/ironman rules - list current rule states")
    print("/ironman toggle <rule> - toggle a rule")
  end
end
