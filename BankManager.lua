--[[
-------------------------------------------------------------------------------
-- BankManager, by Ayantir
-------------------------------------------------------------------------------
This software is under : CreativeCommons CC BY-NC-SA 4.0
Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)

You are free to:

    Share — copy and redistribute the material in any medium or format
    Adapt — remix, transform, and build upon the material
    The licensor cannot revoke these freedoms as long as you follow the license terms.


Under the following terms:

    Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
    NonCommercial — You may not use the material for commercial purposes.
    ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.
    No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.


Please read full licence at :
http://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
]]

-- Global Vars
local LAM2 = LibAddonMenu2

local db = { }
local ADDON_NAME = "BankManagerRevived"
local displayName = "|c3366FFBank|r Manager |c990000Revived|r |cF4EE42(Jewelry Crafting fix)|r"
local ADDON_AUTHOR = "|cFF9B15Sharlikran|r, Lexynide, SnowmanDK, Ayantir, Eldrni, Todo"
local ADDON_VERSION = "1.70"
local ADDON_WEBSITE = "https://www.esoui.com/downloads/info2249-BankManagerRevivedJewelryCraftingfix.html"
local activeBankBag = 0
local isBanking = false
local actualProfile = 1
local inProgress = false
local panel
local guildList
local checkingGBank
local currentGBank
local currentGBankName
local restartFromAtGBank
local hasAnyPullToDo
local hasAnySpecialPullToDo
local qtyMovedToGBank = 0
local countMovedToGBank = 0
local dataSorted
local isESOPlusSubscriber

local ACTION_NOTSET = 1
local ACTION_PUSH = 2
local ACTION_PULL = 3
local ACTION_PUSH_GBANK = 4
local ACTION_PUSH_BOTH = 5

local function GetActionName(action)
  local actionTable = {
    [ACTION_NOTSET] = "ACTION_NOTSET",
    [ACTION_PUSH] = "ACTION_PUSH",
    [ACTION_PULL] = "ACTION_PULL",
    [ACTION_PUSH_GBANK] = "ACTION_PUSH_GBANK",
    [ACTION_PUSH_BOTH] = "ACTION_PUSH_BOTH",
  }
  return actionTable[action]
end

--[[TODO Optional Keyword, Returns true when keywordCondition.acceptedKeyword[arg1] is true ]]--
local BMR_RULEWRITER_VALUE_OPTIONAL_KEYWORD = 1
--[[TODO With Operator, Returns true when keywordCondition.acceptedKeyword[arg1] is true ]]--
--[[TODO Why is only "With Operator" used for GetRuleWriterCondition ]]--
local BMR_RULEWRITER_VALUE_WITH_OPERATOR = 2
--[[TODO Without Operator, second argument is converted to a number. Returns true if number is between 1 and 10000]]--
local BMR_RULEWRITER_VALUE_WITHOUT_OPERATOR = 3
--[[TODO Nothing, added because it wasn't defined. Requires 2 arguments and returns true if both false]]--
local BMR_RULEWRITER_VALUE_NOTHING = 4

local BMR_ITEMLINK = 1
local BMR_BAG_AND_SLOT = 2
local BMR_ITEMTYPE = 3
local BMR_ITEMTYPE_SPECIALIZED = 4
--local startTimeInMs			= 0

--[[
BAG_BACKPACK 	1
BAG_BANK 	2
BAG_GUILDBANK 3
BAG_SUBSCRIBER_BANK 	6
BAG_HOUSE_BANK_ONE 	7
BAG_HOUSE_BANK_TWO 	8
BAG_HOUSE_BANK_THREE 	9
BAG_HOUSE_BANK_FOUR 	10
BAG_HOUSE_BANK_FIVE 	11
BAG_HOUSE_BANK_SIX 	12
BAG_HOUSE_BANK_SEVEN 	13
BAG_HOUSE_BANK_EIGHT 	14
BAG_HOUSE_BANK_NINE 	15
BAG_HOUSE_BANK_TEN 	16

* IsBankOpen()
** _Returns:_ *bool* _isBankOpen_

* GetBankingBag()
** _Returns:_ *[Bag|#Bag]* _bankingBag_

* IsGuildBankOpen()
** _Returns:_ *bool* _isGuildBankOpen_
]]--
-- Array of queues for moving items to handle bag/bank capacity limits
BankManagerRevived = {}
BankManagerRevived.a_test = {} -- for testing and not spamming to chat
local pushQueue = {}
local pullQueue = {}
local movedItems = {
  [BAG_BACKPACK] = {},
  [BAG_BANK] = {},
  [BAG_GUILDBANK] = {},
  [BAG_SUBSCRIBER_BANK] = {},
  [BAG_HOUSE_BANK_ONE] = {},
  [BAG_HOUSE_BANK_TWO] = {},
  [BAG_HOUSE_BANK_THREE] = {},
  [BAG_HOUSE_BANK_FOUR] = {},
  [BAG_HOUSE_BANK_FIVE] = {},
  [BAG_HOUSE_BANK_SIX] = {},
  [BAG_HOUSE_BANK_SEVEN] = {},
  [BAG_HOUSE_BANK_EIGHT] = {},
  [BAG_HOUSE_BANK_NINE] = {},
  [BAG_HOUSE_BANK_TEN] = {},
}

-- Defaults structure for SV
-- memory is a bit wasted here, still need to try to find how to dynamically build defaults after the SV pull from file
local BMR_MAX_PROFILES = 9 -- Adjust as needed

local defaults = {
  worldname = GetWorldName(),
  actualProfile = {},
  globalAddonProfile = 1,
  gui_x = -600,
  gui_y = -400,
  profiles = {} -- Start with an empty table
}

-- Populate the profiles table with default values using a loop
do
  for i = 1, BMR_MAX_PROFILES do
    defaults.profiles[i] = {
      name = "",
      defined = (i == 1), -- First profile is defined, others are not
      autoTransfert = true,
      detailledDisplay = true,
      summary = true,
      protected = true,
      moved = true,
      detailledNotMoved = true,
      initialWaitInSecs = 2,
      overfill = 0,
      pauseInMs = 0,
      userRules = "",
      userRulesAfter = false,
    }
  end
end

-------------------------------------------------
----- Logger Function                       -----
-------------------------------------------------
BankManagerRevived.show_log = false
if LibDebugLogger then
  BankManagerRevived.logger = LibDebugLogger.Create(ADDON_NAME)
end

local logger
local viewer
if DebugLogViewer then viewer = true else viewer = false end
if LibDebugLogger then logger = true else logger = false end

local function create_log(log_type, log_content)
  if not viewer and log_type == "Info" then
    CHAT_ROUTER:AddSystemMessage(log_content)
    return
  end
  if not BankManagerRevived.show_log then return end
  if logger and log_type == "Debug" then
    BankManagerRevived.logger:Debug(log_content)
  end
  if logger and log_type == "Info" then
    BankManagerRevived.logger:Info(log_content)
  end
  if logger and log_type == "Verbose" then
    BankManagerRevived.logger:Verbose(log_content)
  end
  if logger and log_type == "Warn" then
    BankManagerRevived.logger:Warn(log_content)
  end
end

local function emit_message(log_type, text)
  if (text == "") then
    text = "[Empty String]"
  end
  create_log(log_type, text)
end

local function emit_table(log_type, t, indent, table_history)
  indent = indent or "."
  table_history = table_history or {}

  if not t then
    emit_message(log_type, indent .. "[Nil Table]")
    return
  end

  if next(t) == nil then
    emit_message(log_type, indent .. "[Empty Table]")
    return
  end

  for k, v in pairs(t) do
    local vType = type(v)

    emit_message(log_type, indent .. "(" .. vType .. "): " .. tostring(k) .. " = " .. tostring(v))

    if (vType == "table") then
      if (table_history[v]) then
        emit_message(log_type, indent .. "Avoiding cycle on table...")
      else
        table_history[v] = true
        emit_table(log_type, v, indent .. "  ", table_history)
      end
    end
  end
end

local function emit_userdata(log_type, udata)
  local function_limit = 5  -- Limit the number of functions displayed
  local total_limit = 10   -- Total number of entries to display (functions + non-functions)
  local function_count = 0  -- Counter for functions
  local entry_count = 0     -- Counter for total entries displayed

  emit_message(log_type, "Userdata: " .. tostring(udata))

  local meta = getmetatable(udata)
  if meta and meta.__index then
    for k, v in pairs(meta.__index) do
      -- Show function name for functions
      if type(v) == "function" then
        if function_count < function_limit then
          emit_message(log_type, "  Function: " .. tostring(k))  -- Function name
          function_count = function_count + 1
          entry_count = entry_count + 1
        end
      elseif type(v) ~= "function" then
        -- For non-function entries (like tables or variables), show them
        emit_message(log_type, "  " .. tostring(k) .. ": " .. tostring(v))
        entry_count = entry_count + 1
      end

      -- Stop when we've reached the total limit
      if entry_count >= total_limit then
        emit_message(log_type, "  ... (output truncated due to limit)")
        break
      end
    end
  else
    emit_message(log_type, "  (No detailed metadata available)")
  end
end

local function contains_placeholders(str)
  return type(str) == "string" and str:find("<<%d+>>")
end

function BankManagerRevived:dm(log_type, ...)
  local num_args = select("#", ...)
  local first_arg = select(1, ...)  -- The first argument is always the message string

  -- Check if the first argument is a string with placeholders
  if type(first_arg) == "string" and contains_placeholders(first_arg) then
    -- Extract any remaining arguments for zo_strformat (after the message string)
    local remaining_args = { select(2, ...) }

    -- Format the string with the remaining arguments
    local formatted_value = ZO_CachedStrFormat(first_arg, unpack(remaining_args))

    -- Emit the formatted message
    emit_message(log_type, formatted_value)
  else
    -- Process other argument types (userdata, tables, etc.)
    for i = 1, num_args do
      local value = select(i, ...)
      if type(value) == "userdata" then
        emit_userdata(log_type, value)
      elseif type(value) == "table" then
        emit_table(log_type, value)
      else
        emit_message(log_type, tostring(value))
      end
    end
  end
end

-- BMR code

-- Display a movement
local function PrintItemsToBag(itemLink, itemIcon, bagIdTo, qty, currentGBankName)
  CHAT_ROUTER:AddSystemMessage(zo_strformat(BMR_ACTION_ITEMS_MOVED, zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink), itemIcon, qty, GetString("BMR_ACTION_ITEMS_MOVED_TO", bagIdTo), currentGBankName))
end

local function PrintItemsNotMovedToBag(itemLink, itemIcon, bagIdTo, qty, currentGBankName)
  CHAT_ROUTER:AddSystemMessage(zo_strformat(BMR_ACTION_ITEMS_NOT_MOVED, zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink), itemIcon, qty, GetString("BMR_ACTION_ITEMS_MOVED_TO", bagIdTo), currentGBankName))
end

-- Display movement summary
local function PrintSummaryToBag(bagIdTo, countMoved, qtyMoved, currentGBankName)
  CHAT_ROUTER:AddSystemMessage(zo_strformat(BMR_ACTION_ITEMS_SUMMARY, countMoved, qtyMoved, GetString("BMR_ACTION_ITEMS_MOVED_TO", bagIdTo), currentGBankName))
end

-- Display currency movement
local function PrintCurrencyToBank(currencyType, qtyMoved)
  CHAT_ROUTER:AddSystemMessage(zo_strformat(BMR_ACTION_CURRENCY_SUMMARY, ZO_CurrencyControl_FormatCurrencyAndAppendIcon(qtyMoved, true, currencyType), GetString(BMR_ACTION_ITEMS_MOVED_TO2)))
end

-- Display currency movement
local function PrintCurrencyToBag(currencyType, qtyMoved)
  CHAT_ROUTER:AddSystemMessage(zo_strformat(BMR_ACTION_CURRENCY_SUMMARY, ZO_CurrencyControl_FormatCurrencyAndAppendIcon(qtyMoved, true, currencyType), GetString(BMR_ACTION_ITEMS_MOVED_TO1)))
end

local function Sanitize(value)
  return value:gsub("[-*+?^$().[%]%%]", "%%%0") -- escape meta characters
end

local function BuildWritsItems()

  local shouldBeWatched

  BankManagerRules.static.special.writsQuests = {}
  BankManagerRules.static.special.writsQuestsGlyphs = {}  -- Bit dirty, see how to improve - BankManagerRules.lua#271
  BankManagerRules.static.special.writsQuestsPots = {}

  for journalQuestIndex = 1, GetNumJournalQuests() do
    if GetJournalQuestType(journalQuestIndex) == QUEST_TYPE_CRAFTING then
      if GetJournalQuestNumSteps(journalQuestIndex) == QUEST_MAIN_STEP_INDEX then
        for numConditions = 1, GetJournalQuestNumConditions(journalQuestIndex, QUEST_MAIN_STEP_INDEX) do
          local conditionText, current, max, _, isComplete = GetJournalQuestConditionInfo(journalQuestIndex, QUEST_MAIN_STEP_INDEX, numConditions)
          if conditionText ~= "" and current < max then
            conditionText = string.gsub(conditionText, " ", " ") -- First is a NO-BREAK SPACE, 2nd a SPACE, found somes.
            conditionText = Sanitize(conditionText)
            table.insert(BankManagerRules.static.special.writsQuests, { text = conditionText, qtyToMove = max })
            table.insert(BankManagerRules.static.special.writsQuestsGlyphs, { text = conditionText, qtyToMove = max })
            table.insert(BankManagerRules.static.special.writsQuestsPots, { text = conditionText, qtyToMove = max })
            shouldBeWatched = true
          end
        end
      end
    end
  end

  if not shouldBeWatched then
    hasAnySpecialPullToDo = false
  end

end

-- Reset all vars when finishing a GBank move
local function OnCloseProcessAtGBank()

  restartFromAtGBank = nil
  qtyMovedToGBank = 0
  countMovedToGBank = 0
  inProgress = false
  pushQueue = {}

  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_TRANSFER_ERROR)
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_ITEM_ADDED)

end

-- Build the push/pull array
local function queueAction(ruleName, bagId, slotId)
  -- if activeBankBag ~= BAG_BACKPACK or activeBankBag ~= BAG_BANK or activeBankBag ~= BAG_GUILDBANK or activeBankBag ~= BAG_SUBSCRIBER_BANK then return end
  local whichAction = db.profiles[actualProfile].rules[ruleName].action
  if (whichAction == ACTION_PUSH or whichAction == ACTION_PUSH_GBANK or whichAction == ACTION_PUSH_BOTH) and bagId == BAG_BACKPACK then
    -- Push item to bank
    --BankManagerRevived:dm("Debug", string.format("BY ACTION: whichAction : %s ; ruleName: %s ; bagId: %s ; slotId: %s ; activeBankBag: %s", whichAction, ruleName, bagId, slotId, activeBankBag))
    --d("ACTION " .. whichAction .. " " .. ruleName .. " " .. bagId .. " " .. slotId)
    table.insert(pushQueue, { ruleName = ruleName, bagId = bagId, slotId = slotId, itemLink = GetItemLink(bagId, slotId), itemIcon = GetItemLinkInfo(GetItemLink(bagId, slotId)) })
  elseif whichAction == ACTION_PULL and (bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK) then
    -- Pull item to bank
    --BankManagerRevived:dm("Debug", string.format("ACTION_PULL: whichAction : %s ; ruleName: %s ; bagId: %s ; slotId: %s ; activeBankBag: %s", whichAction, ruleName, bagId, slotId, activeBankBag))
    --d("ACTION_PULL " .. ruleName .. " " .. bagId .. " " .. slotId)
    table.insert(pullQueue, { ruleName = ruleName, bagId = bagId, slotId = slotId, itemLink = GetItemLink(bagId, slotId), itemIcon = GetItemLinkInfo(GetItemLink(bagId, slotId)) })
  end

end

-- return true if item is protected
local function IsItemProtected(bagId, slotId)

  -- ESOUI
  if IsItemPlayerLocked(bagId, slotId) then
    return true
  end

  --Item Saver support
  if ItemSaver_IsItemSaved and ItemSaver_IsItemSaved(bagId, slotId) then
    return true
  end

  --FCO ItemSaver support
  if FCOIS and FCOIS.IsLocked then
    return FCOIS.IsLocked(bagId, slotId)
  end

  --FilterIt support
  if FilterIt and FilterIt.AccountSavedVariables and FilterIt.AccountSavedVariables.FilteredItems then
    local sUniqueId = Id64ToString(GetItemUniqueId(bagId, slotId))
    if FilterIt.AccountSavedVariables.FilteredItems[sUniqueId] then
      return FilterIt.AccountSavedVariables.FilteredItems[sUniqueId] ~= FILTERIT_VENDOR
    end
  end

  return false

end

-- To sort array
local function sortByKeyAndPosition(array)

  local arrayTemp = {}
  for key, data in pairs(array) do table.insert(arrayTemp, { key = key, data = data }) end

  local function sortByPosition(a, b)

    if not a.data.position and not b.data.position then return a.data.ruleName < b.data.ruleName end
    if not a.data.position and b.data.position then return true end
    if a.data.position and not b.data.position then return false end
    if a.data.position and b.data.position then
      return a.data.position < b.data.position
    end

  end

  table.sort(arrayTemp, sortByPosition)
  return arrayTemp

end

local function pairsByKeysAndPosition(array)

  local i = 0
  local iter = function()
    i = i + 1
    if array and array[i] then
      return array[i].key, array[i].data
    else
      return
    end
  end

  return iter

end

-- Check if slotId match a rule
local function prepareItem(bagId, slotId, checkingGBank)
  local itemLinkMoveRestricted = false
  local itemLink = GetItemLink(bagId, slotId)
  -- Inits
  if IsItemStolen(bagId, slotId) then itemLinkMoveRestricted = true end
  if db.profiles[actualProfile].protected and IsItemProtected(bagId, slotId) then itemLinkMoveRestricted = true end

  -- Cannot be moved to bank
  if bagId == BAG_BACKPACK and GetItemLinkBindType(itemLink) == BIND_TYPE_ON_PICKUP_BACKPACK then itemLinkMoveRestricted = true end

  -- Cannot be moved to GBank
  if checkingGBank and GetItemLinkBindType(itemLink) == BIND_TYPE_ON_PICKUP then itemLinkMoveRestricted = true end

  -- Might be BOE but item is Bound
  if checkingGBank and IsItemLinkBound(itemLink) then itemLinkMoveRestricted = true end

  -- Might be Unique and you can't store that in the Guild Bank
  if checkingGBank and IsItemLinkUnique(itemLink) then itemLinkMoveRestricted = true end

  if itemLinkMoveRestricted then return end

  local itemMatch = false
  local ruleMatch
  -- For each item in bag, look all rules
  for ruleName, ruleData in pairsByKeysAndPosition(dataSorted) do

    local action = db.profiles[actualProfile].rules[ruleName].action or ACTION_NOTSET
    local associatedGuild = db.profiles[actualProfile].rules[ruleName].associatedGuild
    local actionAssigned = action ~= ACTION_NOTSET
    local guildMatch = currentGBankName == associatedGuild
    -- table.insert(BankManagerRevived.a_test, string.format(tostring(ruleName) .. ":" .. GetItemLinkName(itemLink) .. " : currentGBankName: %s : associatedGuild: %s", tostring(currentGBankName), tostring(associatedGuild)))

    local actionPullValid = action == ACTION_PULL and (bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK)
    local actionPushValid = action == ACTION_PUSH and bagId == BAG_BACKPACK
    local actionPushGBankValid = guildMatch and action == ACTION_PUSH_GBANK and bagId == BAG_BACKPACK
    local actionPushBothValid = action == ACTION_PUSH_BOTH and ((guildMatch and IsGuildBankOpen()) or IsBankOpen()) and bagId == BAG_BACKPACK
    -- table.insert(BankManagerRevived.a_test, string.format(tostring(ruleName) .. ":" .. GetItemLinkName(itemLink) .. " : actionAssigned: %s : guildMatch: %s : actionPullValid: %s", tostring(actionAssigned), tostring(guildMatch), tostring(actionPullValid)))
    -- table.insert(BankManagerRevived.a_test, string.format(tostring(ruleName) .. ":" .. GetItemLinkName(itemLink) .. " : actionPushValid: %s : actionPushGBankValid: %s : actionPushBothValid: %s", tostring(actionPushValid), tostring(actionPushGBankValid), tostring(actionPushBothValid)))

    -- Check first if item didn't matched a previous rule
    if not itemMatch then

      local shouldMove = false
      if action == ACTION_PULL then
        if db.profiles[actualProfile].rules[ruleName].specialEnabled then
          hasAnySpecialPullToDo = true
        else
          hasAnyPullToDo = true
        end
      end
      if actionAssigned and (actionPullValid or actionPushValid or actionPushGBankValid or actionPushBothValid) then shouldMove = true end
      -- If rule is well writen and set to do something
      -- table.insert(BankManagerRevived.a_test, string.format(tostring(ruleName) .. ":" .. GetItemLinkName(itemLink) .. " : shouldMove: %s : action: %s", tostring(shouldMove), GetActionName(action)))
      if ruleData.params and shouldMove then

        for ruleParamIndex, ruleParamData in ipairs(ruleData.params) do

          local funcToUse = ruleParamData.func -- Our fonction stored
          local itemMatchValue

          if funcToUse then
            if ruleParamData.funcArgs == BMR_ITEMLINK then
              -- Is item matching values ?
              for funcChoices, funcMatches in ipairs(ruleParamData.values) do
                if funcToUse(itemLink) == funcMatches then
                  itemMatchValue = true
                end
              end

            elseif ruleParamData.funcArgs == BMR_ITEMTYPE then
              for funcChoices, funcMatches in ipairs(ruleParamData.values) do
                local itemType = funcToUse(itemLink)
                if itemType == funcMatches then
                  itemMatchValue = true
                end
              end

            elseif ruleParamData.funcArgs == BMR_ITEMTYPE_SPECIALIZED then
              for funcChoices, funcMatches in ipairs(ruleParamData.values) do
                local _, specializedItemType = funcToUse(itemLink)
                if specializedItemType == funcMatches then
                  itemMatchValue = true
                end
              end

            elseif ruleParamData.funcArgs == BMR_BAG_AND_SLOT then
              for funcChoices, funcMatches in ipairs(ruleParamData.values) do
                if funcToUse(bagId, slotId) == funcMatches then
                  itemMatchValue = true
                end
              end
            end

          end

          -- The item didn't match our filter, don't try other params, go to next rule
          if not itemMatchValue then
            itemMatch = false
            ruleMatch = nil
            break
          else
            -- The item match our filter .. for now
            itemMatch = true
            ruleMatch = ruleName
            --BankManagerRevived:dm("Debug", string.format("ITEM MATCH VALUE: itemLink : %s ; ( bagId: %s ; slotId: %s ) ; ruleMatch: %s ; ruleName / #: (%s , %s) activeBankBag: %s", itemLink, bagId, slotId, ruleMatch, ruleName, ruleParamIndex, activeBankBag))
            --d(itemLink .. " (" .. bagId .. " " .. slotId.. ") ruleMatch:" .. ruleName .. " #" .. ruleParamIndex)
          end

        end -- end params loop

      end
    else
      break
    end
  end

  if itemMatch and ruleMatch ~= nil then
    -- table.insert(BankManagerRevived.a_test, string.format(tostring(ruleMatch) .. ":" .. GetItemLinkName(itemLink) .. " itemMatch: %s", tostring(itemMatch)))
    queueAction(ruleMatch, bagId, slotId)
  end

end

-- Move all items defined in push/pull arrays
local function moveItems(errorReasonAtGBank)
  BankManagerRevived:dm("Debug", "moveItems")
  local atGuildBank = IsGuildBankOpen()
  local atBank = IsBankOpen()
  local bagIdOpen = GetBankingBag()

  -- Our bagcache, because game don't have it in realtime
  local tinyBagCache = {
    [BAG_BACKPACK] = {},
    [BAG_BANK] = {},
    [BAG_GUILDBANK] = {},
    [BAG_SUBSCRIBER_BANK] = {},
    [BAG_HOUSE_BANK_ONE] = {},
    [BAG_HOUSE_BANK_TWO] = {},
    [BAG_HOUSE_BANK_THREE] = {},
    [BAG_HOUSE_BANK_FOUR] = {},
    [BAG_HOUSE_BANK_FIVE] = {},
    [BAG_HOUSE_BANK_SIX] = {},
    [BAG_HOUSE_BANK_SEVEN] = {},
    [BAG_HOUSE_BANK_EIGHT] = {},
    [BAG_HOUSE_BANK_NINE] = {},
    [BAG_HOUSE_BANK_TEN] = {},
  }

  -- Our bagcache for qty, because game don't have it in realtime
  local qtyBagCache = {}

  -- Avoid checking first 230 slots if we already did it.
  local tinyBagCacheFirstSlot = {
    [BAG_BACKPACK] = 0,
    [BAG_BANK] = 0,
    [BAG_GUILDBANK] = 0,
    [BAG_SUBSCRIBER_BANK] = 0,
    [BAG_HOUSE_BANK_ONE] = 0,
    [BAG_HOUSE_BANK_TWO] = 0,
    [BAG_HOUSE_BANK_THREE] = 0,
    [BAG_HOUSE_BANK_FOUR] = 0,
    [BAG_HOUSE_BANK_FIVE] = 0,
    [BAG_HOUSE_BANK_SIX] = 0,
    [BAG_HOUSE_BANK_SEVEN] = 0,
    [BAG_HOUSE_BANK_EIGHT] = 0,
    [BAG_HOUSE_BANK_NINE] = 0,
    [BAG_HOUSE_BANK_TEN] = 0,
  }

  local freeSlots = {
    [BAG_BACKPACK] = 0,
    [BAG_BANK] = 0,
    [BAG_GUILDBANK] = 0,
    [BAG_SUBSCRIBER_BANK] = 0,
    [BAG_HOUSE_BANK_ONE] = 0,
    [BAG_HOUSE_BANK_TWO] = 0,
    [BAG_HOUSE_BANK_THREE] = 0,
    [BAG_HOUSE_BANK_FOUR] = 0,
    [BAG_HOUSE_BANK_FIVE] = 0,
    [BAG_HOUSE_BANK_SIX] = 0,
    [BAG_HOUSE_BANK_SEVEN] = 0,
    [BAG_HOUSE_BANK_EIGHT] = 0,
    [BAG_HOUSE_BANK_NINE] = 0,
    [BAG_HOUSE_BANK_TEN] = 0,
  }

  -- Items moved in psuh + pull actions
  local itemsMoved = 0
  local qtyMoved = 0
  local countMoved = 0
  local pushInProgress = true

  -- Thanks Merlight & circonian, FindFirstEmptySlotInBag don't refresh in realtime.
  local function FindEmptySlotInBag(bagId)
    BankManagerRevived:dm("Debug", "FindEmptySlotInBag")

    if isESOPlusSubscriber and bagId == BAG_BANK and freeSlots[bagId] == 0 then
      bagId = BAG_SUBSCRIBER_BANK
    end

    --d("FindEmptySlotInBag (" .. bagId .. ")" .. " ; isESOPlusSubscriber=" .. tostring(isESOPlusSubscriber))
    if atGuildBank or (bagId == BAG_BANK and not isESOPlusSubscriber and freeSlots[bagId] > db.profiles[actualProfile].overfill) or (isESOPlusSubscriber and (bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK) and freeSlots[BAG_SUBSCRIBER_BANK] > db.profiles[actualProfile].overfill) or (bagId == BAG_BACKPACK and freeSlots[bagId] > db.profiles[actualProfile].overfill) then
      for slotIndex = tinyBagCacheFirstSlot[bagId], (GetBagSize(bagId) - 1) do
        if not SHARED_INVENTORY.bagCache[bagId][slotIndex] and not tinyBagCache[bagId][slotIndex] then
          --d("tinyBagCache -> " .. bagId .. " " .. slotIndex)
          tinyBagCache[bagId][slotIndex] = true
          tinyBagCacheFirstSlot[bagId] = slotIndex + 1
          freeSlots[bagId] = freeSlots[bagId] - 1
          return bagId, slotIndex
        end
      end
    end
    return bagId
  end

  -- Return the slotIndex if the stack is not fulfilled or a newslot
  local function FindItemInBag(bagIdTo, bagIdFrom, slotIdFrom, maxStack)
    BankManagerRevived:dm("Debug", "FindItemInBag")
    --d("FindItemInBag")
    local itemInstanceId = SHARED_INVENTORY.bagCache[bagIdFrom][slotIdFrom].itemInstanceId
    for slotId, data in pairs(SHARED_INVENTORY.bagCache[bagIdTo]) do
      if data.itemInstanceId == itemInstanceId and data.stackCount < maxStack then
        return bagIdTo, data.slotIndex
      end
    end

    if bagIdTo == BAG_BANK then
      for slotId, data in pairs(SHARED_INVENTORY.bagCache[BAG_SUBSCRIBER_BANK]) do
        if data.itemInstanceId == itemInstanceId and data.stackCount < maxStack then
          return BAG_SUBSCRIBER_BANK, data.slotIndex
        end
      end
    end

    -- Not found or all stack are full
    return FindEmptySlotInBag(bagIdTo)

  end

  local function FindDestSlotInBag(stackCountTo, bagIdTo, bagIdFrom, slotIdFrom, maxStack)
    BankManagerRevived:dm("Debug", "FindDestSlotInBag")
    --d("FindDestSlotInBag " .. bagIdFrom .. " " .. slotIdFrom)
    if stackCountTo > 0 then
      return FindItemInBag(bagIdTo, bagIdFrom, slotIdFrom, maxStack)
    else
      return FindEmptySlotInBag(bagIdTo)
    end

  end

  local function moveItemInSlot(bagIdFrom, slotIdFrom, bagIdTo, slotIdTo, qtyToMove, itemLink)
    BankManagerRevived:dm("Debug", "moveItemInSlot")
    if IsProtectedFunction("RequestMoveItem") then
      CallSecureProtected("RequestMoveItem", bagIdFrom, slotIdFrom, bagIdTo, slotIdTo, qtyToMove)
    else
      RequestMoveItem(bagIdFrom, slotIdFrom, bagIdTo, slotIdTo, qtyToMove)
    end

    -- qtyBagCache[itemLink] is always set, because set just before.
    qtyBagCache[itemLink][bagIdTo] = qtyBagCache[itemLink][bagIdTo] + qtyToMove
    qtyBagCache[itemLink][bagIdFrom] = qtyBagCache[itemLink][bagIdFrom] - qtyToMove

    -- to check
    return true

  end

  -- Move a slot or a partial slot to GBank
  local function moveItemInGBank(bagIdFrom, slotIdFrom, qtyToMove, itemLink)
    BankManagerRevived:dm("Debug", "moveItemInGBank")

    --d("moveItemInGBank")
    if qtyToMove then
      --Partial slot, we need an empty slot
      local emptySlot = FindEmptySlotInBag(bagIdFrom)
      -- Local bag can be full
      if emptySlot then
        moveItemInSlot(bagIdFrom, slotIdFrom, bagIdFrom, emptySlot, qtyToMove, itemLink)
        TransferToGuildBank(bagIdFrom, emptySlot)
      end
    else
      TransferToGuildBank(bagIdFrom, slotIdFrom)
    end

    -- Temporary
    return true

  end

  local function StackInfoInBag(bagToCheck, slotIdFrom, bagIdFrom, itemLink)
    BankManagerRevived:dm("Debug", "StackInfoInBag")

    local stackCountBackpack, stackCountBank

    if not qtyBagCache[itemLink] then
      stackCountBackpack, stackCountBank = GetItemLinkStacks(itemLink) -- Not updated in realtime
      qtyBagCache[itemLink] = {}
      qtyBagCache[itemLink][BAG_BACKPACK] = stackCountBackpack
      qtyBagCache[itemLink][BAG_BANK] = stackCountBank
      qtyBagCache[itemLink][BAG_SUBSCRIBER_BANK] = stackCountBank
    else
      stackCountBackpack = qtyBagCache[itemLink][BAG_BACKPACK]
      stackCountBank = qtyBagCache[itemLink][BAG_BANK] + qtyBagCache[itemLink][BAG_SUBSCRIBER_BANK]
    end

    local stackSize, maxStack = GetSlotStackSize(bagIdFrom, slotIdFrom)
    if bagToCheck == BAG_BACKPACK then
      return stackCountBackpack >= maxStack, stackSize, maxStack, stackCountBackpack, stackCountBank
    elseif bagToCheck == BAG_BANK or bagToCheck == BAG_SUBSCRIBER_BANK then
      return stackCountBank >= maxStack, stackSize, maxStack, stackCountBackpack, stackCountBank
    end
  end

  local function RestackBags()
    BankManagerRevived:dm("Debug", "RestackBags")
    -- Sometimes needed (2 stacks, first 79, 2nd 200, but limit is 200 -> will push 79 , then 121, resulting 2 stacks), maybe need to optimize tinyBagCache
    StackBag(BAG_BANK)
    StackBag(BAG_SUBSCRIBER_BANK)
    StackBag(BAG_BACKPACK)
  end

  local function FinishBankMoves()
    BankManagerRevived:dm("Debug", "FinishBankMoves")

    hasAnyPullToDo = nil
    pushQueue = {}
    pullQueue = {}
    movedItems = {
      [BAG_BACKPACK] = {},
      [BAG_BANK] = {},
      [BAG_GUILDBANK] = {},
      [BAG_SUBSCRIBER_BANK] = {},
      [BAG_HOUSE_BANK_ONE] = {},
      [BAG_HOUSE_BANK_TWO] = {},
      [BAG_HOUSE_BANK_THREE] = {},
      [BAG_HOUSE_BANK_FOUR] = {},
      [BAG_HOUSE_BANK_FIVE] = {},
      [BAG_HOUSE_BANK_SIX] = {},
      [BAG_HOUSE_BANK_SEVEN] = {},
      [BAG_HOUSE_BANK_EIGHT] = {},
      [BAG_HOUSE_BANK_NINE] = {},
      [BAG_HOUSE_BANK_TEN] = {},
    }

    inProgress = false

  end

  local function tryMoveSlots(data, bagIdTo, restartAt)
    BankManagerRevived:dm("Debug", "tryMoveSlots")

    -- Need to push/pull?
    if not restartAt then restartAt = 1 end
    local moveData = data[restartAt]

    if moveData then

      -- Should not exceed 100 in a move or game will kick you
      if db.profiles[actualProfile].pauseInMs >= 100 or (itemsMoved < 98 and db.profiles[actualProfile].pauseInMs < 100) then
        --d(moveData.ruleName .. " will check qty and if, move " .. GetItemName(moveData.bagId, moveData.slotId))

        -- Is slot at max size in bank ?
        local isFullStack, stackSize, maxStack, stackCountBackpack, stackCountBank = StackInfoInBag(bagIdTo, moveData.slotId, moveData.bagId, moveData.itemLink)
        local itemMoved = false
        local qtyToMove, destSlot

        if BankManagerRules.data[moveData.ruleName].isSpecial then

          if bagIdTo == BAG_BACKPACK then
            qtyToMove = BankManagerRules.static.special[moveData.ruleName][moveData.itemLink]
            bagIdTo, destSlot = FindDestSlotInBag(stackCountBackpack, bagIdTo, moveData.bagId, moveData.slotId, maxStack)
          end

          --d("qtyToMove " .. qtyToMove .. " destSlot " .. tostring(destSlot))
          if destSlot then
            --d(moveData.ruleName .. " is moving " .. GetItemName(moveData.bagId, moveData.slotId) .. " (not full stack)")
            itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, qtyToMove, moveData.itemLink)
          elseif db.profiles[actualProfile].detailledNotMoved then
            PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
          end

        elseif not isFullStack and db.profiles[actualProfile].rules[moveData.ruleName].onlyIfNotFullStack then

          if bagIdTo == BAG_BACKPACK then
            qtyToMove = math.min(stackSize, (maxStack - stackCountBackpack))
            bagIdTo, destSlot = FindDestSlotInBag(stackCountBackpack, bagIdTo, moveData.bagId, moveData.slotId, maxStack)
          elseif bagIdTo == BAG_BANK or bagIdTo == BAG_SUBSCRIBER_BANK then
            qtyToMove = math.min(stackSize, (maxStack - stackCountBank))
            bagIdTo, destSlot = FindDestSlotInBag(stackCountBank, bagIdTo, moveData.bagId, moveData.slotId, maxStack) -- bagIdTo can change because of BAG_SUBSCRIBER_BANK
          end

          --d("qtyToMove " .. tostring(qtyToMove) .. " destSlot " .. tostring(bagIdTo) .. "/" .. tostring(destSlot))
          if destSlot then
            --d(moveData.ruleName .. " is moving " .. GetItemName(moveData.bagId, moveData.slotId) .. " (not full stack)")
            itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, qtyToMove, moveData.itemLink)
          elseif db.profiles[actualProfile].detailledNotMoved then
            PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
          end

        elseif not db.profiles[actualProfile].rules[moveData.ruleName].onlyIfNotFullStack then

          -- Still don't know why.
          if type(db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks) == "boolean" then
            db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks = 1
          end

          local stackCountInBag
          -- got 80 to push, bank got 350, stack is 200, 1st stack will receive 50, 2nd stack: 30 if maxStack = 3, or 50 and 0 because of maxStack = 2
          if bagIdTo == BAG_BACKPACK then
            stackCountInBag = stackCountBackpack
          elseif bagIdTo == BAG_BANK or bagIdTo == BAG_SUBSCRIBER_BANK then
            stackCountInBag = stackCountBank
          end

          local maxQtyAuthorized = db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks * maxStack
          qtyToMove = math.min(stackSize, maxStack - (stackCountInBag % maxStack))

          if qtyToMove + stackCountInBag <= maxQtyAuthorized then
            bagIdTo, destSlot = FindDestSlotInBag(stackCountInBag, bagIdTo, moveData.bagId, moveData.slotId, maxStack)
            --d("maxQtyAuthorized: " .. maxQtyAuthorized .. " stackCountInBag: " .. stackCountInBag)
            if qtyToMove == stackSize or (qtyToMove < stackSize and qtyToMove + stackCountInBag == maxQtyAuthorized) then

              -- 1 push to do
              --d("1 push to do")
              --d("qtyToMove " .. qtyToMove .. " destSlot " .. tostring(destSlot))
              if stackCountInBag + qtyToMove <= maxQtyAuthorized then
                if destSlot then
                  itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, qtyToMove, moveData.itemLink)
                elseif db.profiles[actualProfile].detailledNotMoved then
                  PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
                end
              end

            else

              --d("2 push to do?")
              --d("qtyToMove " .. qtyToMove .. " destSlot " .. tostring(destSlot))
              -- 2 push to do, first will fulfil, 2nd will take the modulo
              if stackCountInBag + qtyToMove <= maxQtyAuthorized then
                --Already too late!
                if destSlot then
                  --d("2 push to do -> destSlot1:" .. destSlot)
                  itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, qtyToMove, moveData.itemLink)
                elseif db.profiles[actualProfile].detailledNotMoved then
                  PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
                end

                -- Maybe move1 hit the limit?
                if stackCountInBag + qtyToMove < db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks * maxStack then
                  destSlot = FindEmptySlotInBag(bagIdTo)
                  if destSlot then
                    --d("2 push to do -> destSlot2:" .. destSlot)
                    itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, stackSize - qtyToMove, moveData.itemLink)
                    qtyToMove = stackSize -- to Display the correct value
                  elseif db.profiles[actualProfile].detailledNotMoved then
                    PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
                  end
                end
              end
            end

          end

        end

        if itemMoved then
          qtyMoved = qtyMoved + qtyToMove
          countMoved = countMoved + 1
          itemsMoved = itemsMoved + 1
          if db.profiles[actualProfile].detailledDisplay then
            PrintItemsToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
          end
        end

        zo_callLater(function() tryMoveSlots(data, bagIdTo, restartAt + 1) end, db.profiles[actualProfile].pauseInMs)

      else

        CHAT_ROUTER:AddSystemMessage(GetString(BMR_ZOS_LIMITATIONS))
        pushInProgress = false -- Don't do pull

        -- End of moves
        if qtyMoved > 0 then
          if db.profiles[actualProfile].summary then
            PrintSummaryToBag(bagIdTo, countMoved, qtyMoved)
          end
          RestackBags()
        end

        FinishBankMoves()
        return

      end
    elseif pushInProgress then

      -- End of push
      pushInProgress = false

      if qtyMoved > 0 then
        if db.profiles[actualProfile].summary then
          PrintSummaryToBag(bagIdTo, countMoved, qtyMoved)
        end
      end

      qtyMoved = 0
      countMoved = 0

      freeSlots[BAG_BACKPACK] = GetNumBagFreeSlots(BAG_BACKPACK)
      zo_callLater(function() tryMoveSlots(pullQueue, BAG_BACKPACK) end, db.profiles[actualProfile].pauseInMs)

    else

      -- End of pull
      if qtyMoved > 0 then
        if db.profiles[actualProfile].summary then
          PrintSummaryToBag(bagIdTo, countMoved, qtyMoved)
        end
        RestackBags()
      end

      FinishBankMoves()

    end

  end

  local function doSingleMove(moveData)
    BankManagerRevived:dm("Debug", "doSingleMove")
    local associatedGuild = db.profiles[actualProfile].rules[moveData.ruleName].associatedGuild
    local action = db.profiles[actualProfile].rules[moveData.ruleName].action
    local onlyIfNotFullStack = db.profiles[actualProfile].rules[moveData.ruleName].onlyIfNotFullStack
    local onlyStacksValue
    if type(db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks) == 'boolean' then onlyStacksValue = 1
    else onlyStacksValue = db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks end
    local validGuild = associatedGuild == currentGBankName

    local actionPushGBankValid = validGuild and action == ACTION_PUSH_GBANK and moveData.bagId == BAG_BACKPACK
    local actionPushBothValid = validGuild and (action == ACTION_PUSH_BOTH and IsGuildBankOpen()) and moveData.bagId == BAG_BACKPACK
    local shouldPushGuildBank = onlyIfNotFullStack and (actionPushGBankValid or actionPushBothValid)

    if validGuild then
      BankManagerRevived:dm("Debug", "validGuild")

      --d(moveData.ruleName .. " will check qty and if, move " .. GetItemName(moveData.bagId, moveData.slotId))

      -- Is slot at max size in bank ?
      local isFullStack, stackSize, maxStack, stackCountBackpack, stackCountBank = StackInfoInBag(BAG_BANK, moveData.slotId, moveData.bagId, moveData.itemLink)
      local stackSizeAndStackCountBank = stackSize + stackCountBank
      local stackSizeAndCountGreaterThanMaxStack = stackSizeAndStackCountBank > maxStack
      local stackSizeAndCountGreaterThanOnlyStacksValueTimesMaxStack = stackSizeAndStackCountBank > onlyStacksValue * maxStack
      local itemMoved = false
      local qtyToMove

      BankManagerRevived:dm("Debug", tostring(stackSizeAndCountGreaterThanMaxStack))
      BankManagerRevived:dm("Debug", tostring(stackSizeAndCountGreaterThanOnlyStacksValueTimesMaxStack))
      -- TODO verify shouldPushGuildBank will not interfere with the next two conditions
      if shouldPushGuildBank and (not stackSizeAndCountGreaterThanMaxStack or not stackSizeAndCountGreaterThanOnlyStacksValueTimesMaxStack) then
        BankManagerRevived:dm("Debug", "shouldPushGuildBank")

        --d(moveData.ruleName .. " is set to push everything to GBank (ACTION_PUSH_GBANK)")

        qtyToMove = stackSize
        if GetNumBagFreeSlots(BAG_GUILDBANK) > 0 then
          itemMoved = moveItemInGBank(moveData.bagId, moveData.slotId)
        elseif db.profiles[actualProfile].detailledNotMoved then
          PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, BAG_GUILDBANK, qtyToMove, currentGBankName)
        end

        --[[TODO the next two conditions are the same, revise because the previous condition changed]]--
      elseif onlyIfNotFullStack and stackSizeAndCountGreaterThanMaxStack then
        BankManagerRevived:dm("Debug", "onlyIfNotFullStack, stackSize and bank > maxStack")

        qtyToMove = math.min(stackSize, stackCountBank + stackSize - maxStack)

        --d("qtyToMove " .. qtyToMove)
        if GetNumBagFreeSlots(BAG_GUILDBANK) > 0 then
          if qtyToMove == stackSize then
            itemMoved = moveItemInGBank(moveData.bagId, moveData.slotId)
          else
            -- Qty is not available when transfering to GBank, it's a full slot
            itemMoved = moveItemInGBank(moveData.bagId, moveData.slotId, qtyToMove, moveData.itemLink)
          end
        elseif db.profiles[actualProfile].detailledNotMoved then
          PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, BAG_GUILDBANK, qtyToMove, currentGBankName)
        end

      elseif not onlyIfNotFullStack and stackSizeAndCountGreaterThanOnlyStacksValueTimesMaxStack then
        BankManagerRevived:dm("Debug", "not onlyIfNotFullStack, onlyStacks * maxStack")

        qtyToMove = math.min(stackSize, stackCountBank + stackSize - maxStack)

        --d("qtyToMove " .. qtyToMove)
        if GetNumBagFreeSlots(BAG_GUILDBANK) > 0 then
          if qtyToMove == stackSize then
            itemMoved = moveItemInGBank(moveData.bagId, moveData.slotId)
          else
            -- Qty is not available when transfering to GBank, it's a full slot
            itemMoved = moveItemInGBank(moveData.bagId, moveData.slotId, qtyToMove, moveData.itemLink)
          end
        elseif db.profiles[actualProfile].detailledNotMoved then
          PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, BAG_GUILDBANK, qtyToMove, currentGBankName)
        end

      end

      if itemMoved then
        if db.profiles[actualProfile].detailledDisplay then
          PrintItemsToBag(moveData.itemLink, moveData.itemIcon, BAG_GUILDBANK, qtyToMove, currentGBankName)
        end
      else
        --d("Nothing moved for " .. GetItemName(moveData.bagId, moveData.slotId))
      end

      return itemMoved, qtyToMove

    else
      --d("Incorrect GBank for rule " .. moveData.ruleName)
    end

    return false

  end

  local function tryMoveSlotsToGBank()
    BankManagerRevived:dm("Debug", "tryMoveSlotsToGBank")

    -- Need to push/pull?
    if #pushQueue > 0 then
      --d("#pushQueue " .. tostring(restartFromAtGBank) .. "/" .. tostring(#pushQueue))

      -- We can't loop for GBank, because we need to wait for server response, so use next()
      local moveIndex, moveData = next(pushQueue, restartFromAtGBank)
      --d("moveIndex = " .. tostring(moveIndex))

      if moveIndex then

        local itemMoved
        -- Even if itemMoved is true, it does not garantee that it has been really moved. It has just been Transfered to GBank
        local itemMoved, qtyMoved = doSingleMove(moveData)

        -- It will make the loop
        restartFromAtGBank = moveIndex

        -- If we didn't moved our item, EVENT_MANAGER won't send anything.
        if not itemMoved then
          tryMoveSlotsToGBank()
        else
          qtyMovedToGBank = qtyMovedToGBank + qtyMoved
          countMovedToGBank = countMovedToGBank + 1
        end

      else

        if qtyMovedToGBank > 0 then

          if db.profiles[actualProfile].summary then
            PrintSummaryToBag(BAG_GUILDBANK, countMovedToGBank, qtyMovedToGBank, currentGBankName)
          end

          -- Do a Roomba if the Addon is detected
          if Roomba and Roomba.BeginStackingProcess then Roomba.BeginStackingProcess() end

        end

        --d("End of loop")
        OnCloseProcessAtGBank()

      end

    end

  end

  if atGuildBank then

    freeSlots[BAG_BACKPACK] = GetNumBagFreeSlots(BAG_BACKPACK)

    BankManagerRevived:dm("Debug", string.format("errorReasonAtGBank: %s", tostring(errorReasonAtGBank)))
    if not errorReasonAtGBank then
      tryMoveSlotsToGBank(errorReasonAtGBank)
    elseif errorReasonAtGBank == GUILD_BANK_TRANSFER_PENDING then
      -- Bank is busy, retry
      restartFromAtGBank = restartFromAtGBank - 1
      tryMoveSlotsToGBank()
    elseif errorReasonAtGBank == GUILD_BANK_NO_SPACE_LEFT then
      -- While we are interacting, other move can be done simultaneously
      OnCloseProcessAtGBank()
    else
      tryMoveSlotsToGBank()
    end

  else

    freeSlots[BAG_BANK] = GetNumBagFreeSlots(BAG_BANK)
    freeSlots[BAG_SUBSCRIBER_BANK] = GetNumBagFreeSlots(BAG_SUBSCRIBER_BANK)
    tryMoveSlots(pushQueue, BAG_BANK)

  end

end

-- Move a currency
local function moveCurrency(ruleName, currencyType)

  -- Our currencies
  local currentCurrencyInInventory = GetCarriedCurrencyAmount(currencyType)
  local currentCurrencyInBank = GetBankedCurrencyAmount(currencyType)

  local inverted = db.profiles[actualProfile].rules[ruleName].keepInBank
  local currencyActionDone
  local currencyAmountMoved
  local actionDone

  -- Keep In Bank set to ON
  if inverted then
    -- Do I need to pull or push? If Inverted, addon push to inventory and pull from inventory
    local pushCurrency = currentCurrencyInBank > db.profiles[actualProfile].rules[ruleName].qtyToPush and (db.profiles[actualProfile].rules[ruleName].qtyToPush > 0 or (db.profiles[actualProfile].rules[ruleName].keepNothing and db.profiles[actualProfile].rules[ruleName].qtyToPush == 0))
    local pullCurrency = db.profiles[actualProfile].rules[ruleName].qtyToPull > 0 and currentCurrencyInBank < db.profiles[actualProfile].rules[ruleName].qtyToPull and currentCurrencyInInventory > 0

    if pullCurrency then
      currencyAmountMoved = db.profiles[actualProfile].rules[ruleName].qtyToPull - currentCurrencyInBank
      currencyAmountMoved = math.min(currencyAmountMoved, currentCurrencyInInventory)

      if currencyAmountMoved > 0 then
        DepositCurrencyIntoBank(currencyType, currencyAmountMoved)
        if db.profiles[actualProfile].detailledDisplay then
          PrintCurrencyToBank(currencyType, currencyAmountMoved)
        end
        actionDone = ACTION_PUSH
      end
    elseif pushCurrency then
      currencyAmountMoved = currentCurrencyInBank - db.profiles[actualProfile].rules[ruleName].qtyToPush
      if currencyAmountMoved > 0 then
        WithdrawCurrencyFromBank(currencyType, currencyAmountMoved)
        if db.profiles[actualProfile].detailledDisplay then
          PrintCurrencyToBag(currencyType, currencyAmountMoved)
        end
        actionDone = ACTION_PULL
      end
    end
    -- Keep In Bank set to OFF
  else
    -- Do I need to pull or push?
    local pushCurrency = currentCurrencyInInventory > db.profiles[actualProfile].rules[ruleName].qtyToPush and (db.profiles[actualProfile].rules[ruleName].qtyToPush > 0 or (db.profiles[actualProfile].rules[ruleName].keepNothing and db.profiles[actualProfile].rules[ruleName].qtyToPush == 0))
    local pullCurrency = db.profiles[actualProfile].rules[ruleName].qtyToPull > 0 and currentCurrencyInInventory < db.profiles[actualProfile].rules[ruleName].qtyToPull and currentCurrencyInBank > 0

    if pullCurrency then
      currencyAmountMoved = db.profiles[actualProfile].rules[ruleName].qtyToPull - currentCurrencyInInventory
      currencyAmountMoved = math.min(currencyAmountMoved, currentCurrencyInBank)
      if currencyAmountMoved > 0 then
        WithdrawCurrencyFromBank(currencyType, currencyAmountMoved)
        if db.profiles[actualProfile].detailledDisplay then
          PrintCurrencyToBag(currencyType, currencyAmountMoved)
        end
        actionDone = ACTION_PULL
      end
    elseif pushCurrency then
      currencyAmountMoved = currentCurrencyInInventory - db.profiles[actualProfile].rules[ruleName].qtyToPush
      if currencyAmountMoved > 0 then
        DepositCurrencyIntoBank(currencyType, currencyAmountMoved)
        if db.profiles[actualProfile].detailledDisplay then
          PrintCurrencyToBank(currencyType, currencyAmountMoved)
        end
        actionDone = ACTION_PUSH
      end
    end
  end

  return actionDone, currencyAmountMoved

end

-- Move currencies
local function moveCurrencies()

  local moves = {}
  local amounts = {}

  moves[CURT_MONEY], amounts[CURT_MONEY] = moveCurrency("currency" .. CURT_MONEY, CURT_MONEY)
  moves[CURT_TELVAR_STONES], amounts[CURT_TELVAR_STONES] = moveCurrency("currency" .. CURT_TELVAR_STONES, CURT_TELVAR_STONES)
  moves[CURT_ALLIANCE_POINTS], amounts[CURT_ALLIANCE_POINTS] = moveCurrency("currency" .. CURT_ALLIANCE_POINTS, CURT_ALLIANCE_POINTS)
  moves[CURT_WRIT_VOUCHERS], amounts[CURT_WRIT_VOUCHERS] = moveCurrency("currency" .. CURT_WRIT_VOUCHERS, CURT_WRIT_VOUCHERS)

  if db.profiles[actualProfile].summary and (NonContiguousCount(moves) > 1 or (not db.profiles[actualProfile].detailledDisplay and NonContiguousCount(moves) == 1)) then

    local message
    for currencyType, side in pairs(moves) do
      if not message then
        message = GetString(BMR_ACTION_HAS_MOVED) .. zo_strformat(BMR_ACTION_CURRENCY_GSUMMARY, ZO_CurrencyControl_FormatCurrencyAndAppendIcon(amounts[currencyType], true, currencyType), GetString("BMR_ACTION_CURRENCY_MOVED_TO", side))
      else
        message = table.concat({ message, zo_strformat(BMR_ACTION_CURRENCY_GSUMMARY, ZO_CurrencyControl_FormatCurrencyAndAppendIcon(amounts[currencyType], true, currencyType), GetString("BMR_ACTION_CURRENCY_MOVED_TO", side)) }, GetString(SI_LIST_COMMA_SEPARATOR))
      end
    end

    CHAT_ROUTER:AddSystemMessage(message)

  end

end

-- move currencies, prepare items, build push/pull queue and move items
local function interactWithBank()

  if not inProgress then
    inProgress = true

    moveCurrencies()
    dataSorted = sortByKeyAndPosition(BankManagerRules.data)

    -- Prepare items, check if they must be moved and queue them
    for slotIndex in pairs(SHARED_INVENTORY.bagCache[BAG_BACKPACK]) do
      if not movedItems[BAG_BACKPACK][slotIndex] then
        prepareItem(BAG_BACKPACK, slotIndex)
      end
    end
    --d(GetGameTimeMilliseconds() - startTimeInMs)

    if db.profiles[actualProfile].rules["writsQuests"].specialEnabled then
      BuildWritsItems()
    end

    -- Prepare items, check if they must be moved and queue them
    if hasAnyPullToDo or hasAnySpecialPullToDo then
      -- Has already been check in 1st loop
      for slotIndex in pairs(SHARED_INVENTORY.bagCache[BAG_BANK]) do
        if not movedItems[BAG_BANK][slotIndex] then
          prepareItem(BAG_BANK, slotIndex)
        end
      end
      for slotIndex in pairs(SHARED_INVENTORY.bagCache[BAG_SUBSCRIBER_BANK]) do
        if not movedItems[BAG_SUBSCRIBER_BANK][slotIndex] then
          prepareItem(BAG_SUBSCRIBER_BANK, slotIndex)
        end
      end
    end
    --d(GetGameTimeMilliseconds() - startTimeInMs)

    -- items have been queued
    if #pushQueue > 0 or #pullQueue > 0 then
      moveItems() -- zo_CallLater inside, nothing behind this line should be run, but inside it.
    end

    --d(GetGameTimeMilliseconds() - startTimeInMs)

  end

end

-- Display UI with arrows if needed
local function displayUI(multipleProfiles)

  local ruleName = db.profiles[actualProfile].name

  if ruleName == "" then
    ruleName = zo_strformat(BMR_PROFILE, actualProfile)
  end

  if multipleProfiles then
    BankManager:GetNamedChild("Before"):SetHidden(false)
    BankManager:GetNamedChild("After"):SetHidden(false)
  else
    BankManager:GetNamedChild("Before"):SetHidden(true)
    BankManager:GetNamedChild("After"):SetHidden(true)
  end

  BankManager:GetNamedChild("RuleName"):SetText(ruleName)
  BankManager:SetHidden(false)

end

-- Move to previous/next rule
local function nextRule(step)

  local changed
  for i = actualProfile + step, BMR_MAX_PROFILES, step do
    if db.profiles[i].defined then
      changed = true
      actualProfile = i
      break
    end
  end

  if not changed then
    actualProfile = 1
  end

  db.actualProfile = actualProfile

  -- Sync LAM
  CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)

  local ruleName = db.profiles[actualProfile].name

  if ruleName == "" then
    ruleName = zo_strformat(BMR_PROFILE, actualProfile)
  end

  BankManager:GetNamedChild("RuleName"):SetText(ruleName)

end

-- onSingleSlotUpdate (only between onOpenBank and onOpenBank+2s)
local function onSingleSlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange, triggeredByCharacterName, triggeredByDisplayName, isLastUpdateForMessage, bonusDropSource)

  -- if not, item has been moved elsewhere? We can't use SHARED_INVENTORY, it's still not updated.
  if GetItemType(bagId, slotIndex) ~= ITEMTYPE_NONE then
    if not movedItems[bagId] then movedItems[bagId] = {} end -- Handle other moves. BAG_WORN per exemple
    movedItems[bagId][slotIndex] = true
  end

end

-- onOpenBank
local function onOpenBank(eventCode, bankBag)
  BankManagerRevived:dm("Debug", "BankManagerRevived_executeRule")
  activeBankBag = bankBag or 0
  isBanking = true

  -- Trace all items moved by another addon while BMR waits
  if db.profiles[actualProfile].moved then
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onSingleSlotUpdate)
  end

  -- CallLater to let the bagCache be refreshed by core UI
  zo_callLater(function()

    -- Stop tracing
    if db.profiles[actualProfile].moved then
      EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end

    if isBanking then

      local multipleProfiles = false

      for i = 2, BMR_MAX_PROFILES do
        if db.profiles[i].defined == true then
          multipleProfiles = true
          break
        end
      end

      -- Display UI only if 2 profiles are defined or if actual is on manual mode
      if not db.profiles[actualProfile].autoTransfert or multipleProfiles then
        displayUI(multipleProfiles)
      end

      if db.profiles[actualProfile].autoTransfert then
        interactWithBank()
      end

    end
  end, (db.profiles[actualProfile].initialWaitInSecs * 1000))

end

-- onCloseBank, resets
local function onCloseBank()

  isBanking = false
  hasAnyPullToDo = nil
  pushQueue = {}
  pullQueue = {}
  movedItems = {
    [BAG_BACKPACK] = {},
    [BAG_BANK] = {},
    [BAG_GUILDBANK] = {},
    [BAG_SUBSCRIBER_BANK] = {},
    [BAG_HOUSE_BANK_ONE] = {},
    [BAG_HOUSE_BANK_TWO] = {},
    [BAG_HOUSE_BANK_THREE] = {},
    [BAG_HOUSE_BANK_FOUR] = {},
    [BAG_HOUSE_BANK_FIVE] = {},
    [BAG_HOUSE_BANK_SIX] = {},
    [BAG_HOUSE_BANK_SEVEN] = {},
    [BAG_HOUSE_BANK_EIGHT] = {},
    [BAG_HOUSE_BANK_NINE] = {},
    [BAG_HOUSE_BANK_TEN] = {},
  }

  inProgress = false
  BankManager:SetHidden(true)

end

local function doInteractionWithGBank()

  if not inProgress then
    inProgress = true

    dataSorted = sortByKeyAndPosition(BankManagerRules.data)

    -- Prepare items, check if they must be moved and queue them
    for slotIndex, slotdata in pairs(SHARED_INVENTORY.bagCache[BAG_BACKPACK]) do
      if not movedItems[BAG_BACKPACK][slotIndex] then
        prepareItem(BAG_BACKPACK, slotIndex, checkingGBank)
      end
    end

    -- items have been queued
    if #pushQueue > 0 then

      --d("Registering events")
      -- This will make the loop, because GBank cannot be looped
      EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_TRANSFER_ERROR, function(eventCode, reason) moveItems(reason) end)
      EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_ITEM_ADDED, function(eventCode, slotId, addedByLocalPlayer, itemSoundCategory, isLastUpdateForMessage) moveItems() end)

      moveItems()
    else
      inProgress = false
    end

  end

end

-- interactWithGBank
local function interactWithGBank()

  -- The permission is maybe not allowed
  if DoesPlayerHaveGuildPermission(currentGBank, GUILD_PERMISSION_BANK_DEPOSIT) then

    local multipleProfiles = false

    for i = 2, BMR_MAX_PROFILES do
      if db.profiles[i].defined == true then
        multipleProfiles = true
        break
      end
    end

    -- Display UI only if 2 profiles are defined or if actual is on manual mode
    if not db.profiles[actualProfile].autoTransfert or multipleProfiles then
      displayUI(multipleProfiles)
    end

    if db.profiles[actualProfile].autoTransfert then
      doInteractionWithGBank()
    end

  end

end

-- onGuildBankItemsReallyReady
local function onGuildBankItemsReallyReady()

  -- Because EVENT_GUILD_BANK_ITEMS_READY fires multiple times
  if not checkingGBank then
    checkingGBank = true
    interactWithGBank()
  end

end

-- onGuildBankItemsReady
local function onGuildBankItemsReady()
  -- Guild bank is evented to be ready, but wait a short while before processing. (multiple readys for big banks ~3/4)
  zo_callLater(onGuildBankItemsReallyReady, (db.profiles[actualProfile].initialWaitInSecs * 1000))
end

-- onGuildBankSelected
local function onGuildBankSelected(_, guildId)

  BankManager:SetHidden(true)
  checkingGBank = false
  currentGBank = guildId
  currentGBankName = GetGuildName(currentGBank)

  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_TRANSFER_ERROR)
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_ITEM_ADDED)

end

-- onCloseGuildBank
local function onCloseGuildBank()

  checkingGBank = false
  currentGBank = nil
  currentGBankName = nil
  OnCloseProcessAtGBank()
  BankManager:SetHidden(true)

end

-- Build 1 currency Panel for LAM
local function panelCurrencyPush(ruleName)

  local optionPanel = {
    type = "slider",
    name = GetString(BMR_CURRENCY_PUSH),
    tooltip = GetString(BMR_CURRENCY_PUSH_TOOLTIP),
    min = BankManagerRules.data[ruleName].min,
    max = BankManagerRules.data[ruleName].max,
    step = BankManagerRules.data[ruleName].step,
    getFunc = function() return db.profiles[actualProfile].rules[ruleName].qtyToPush end,
    setFunc = function(newValue) db.profiles[actualProfile].rules[ruleName].qtyToPush = newValue end,
    default = 0,
  }

  return optionPanel

end

-- Build 1 currency Panel for LAM
local function panelCurrencyPull(ruleName)

  local optionPanel = {
    type = "slider",
    name = GetString(BMR_CURRENCY_PULL),
    tooltip = GetString(BMR_CURRENCY_PULL_TOOLTIP),
    min = BankManagerRules.data[ruleName].min,
    max = BankManagerRules.data[ruleName].max,
    step = BankManagerRules.data[ruleName].step,
    getFunc = function() return db.profiles[actualProfile].rules[ruleName].qtyToPull end,
    setFunc = function(newValue) db.profiles[actualProfile].rules[ruleName].qtyToPull = newValue end,
    default = 0,
  }

  return optionPanel

end

-- Build 1 currency "Keep Nothing currency" for LAM
local function panelCurrencyNothing(ruleName, currencyType)

  local optionPanel = {
    type = "checkbox",
    name = zo_strformat(BMR_CURRENCY_NOTHING, GetCurrencyName(currencyType, false, false)),
    tooltip = zo_strformat(BMR_CURRENCY_NOTHING_TOOLTIP, GetCurrencyName(currencyType, false, false)),
    getFunc = function() return db.profiles[actualProfile].rules[ruleName].keepNothing end,
    setFunc = function(newValue) db.profiles[actualProfile].rules[ruleName].keepNothing = newValue end,
    default = false,
    disabled = function()
      -- db is not yet initialized
      if not db.profiles[actualProfile].rules[ruleName].qtyToPush then
        return false
      else
        return db.profiles[actualProfile].rules[ruleName].qtyToPush > 0
      end
    end,
  }

  return optionPanel

end

-- Build 1 currency "Keep in Bank Instead" for LAM
local function panelCurrencyKeepInBankInstead(ruleName, currencyType)

  local optionPanel = {
    type = "checkbox",
    name = zo_strformat(BMR_CURRENCY_KEEP_IN_BANK, GetString("SI_CURRENCYTYPE", currencyType)),
    tooltip = zo_strformat(BMR_CURRENCY_KEEP_IN_BANK_TOOLTIP, GetString("SI_CURRENCYTYPE", currencyType)),
    getFunc = function() return db.profiles[actualProfile].rules[ruleName].keepInBank end,
    setFunc = function(newValue) db.profiles[actualProfile].rules[ruleName].keepInBank = newValue end,
    default = false,
  }

  return optionPanel

end

-- Build 1 optionPanel for LAM
local function panelRule(ruleName)

  if BankManagerRules.data[ruleName] then
    local choices = {}
    choices[ACTION_NOTSET] = GetString(BMR_ACTION_NOTSET)
    choices[ACTION_PUSH] = GetString(BMR_ACTION_PUSH)
    choices[ACTION_PULL] = GetString(BMR_ACTION_PULL)
    choices[ACTION_PUSH_GBANK] = GetString(BMR_ACTION_PUSH_GBANK)
    choices[ACTION_PUSH_BOTH] = GetString(BMR_ACTION_PUSH_BOTH)

    local reverseChoices = {}
    reverseChoices[GetString(BMR_ACTION_NOTSET)] = ACTION_NOTSET
    reverseChoices[GetString(BMR_ACTION_PUSH)] = ACTION_PUSH
    reverseChoices[GetString(BMR_ACTION_PULL)] = ACTION_PULL
    reverseChoices[GetString(BMR_ACTION_PUSH_GBANK)] = ACTION_PUSH_GBANK
    reverseChoices[GetString(BMR_ACTION_PUSH_BOTH)] = ACTION_PUSH_BOTH

    local optionPanel = {
      type = "dropdown",
      name = BankManagerRules.data[ruleName].name,
      tooltip = BankManagerRules.data[ruleName].tooltip,
      choices = { GetString(BMR_ACTION_NOTSET), GetString(BMR_ACTION_PUSH), GetString(BMR_ACTION_PULL), GetString(BMR_ACTION_PUSH_GBANK), GetString(BMR_ACTION_PUSH_BOTH) },
      getFunc = function() return choices[db.profiles[actualProfile].rules[ruleName].action] end,
      setFunc = function(value)
        if reverseChoices[value] then
          db.profiles[actualProfile].rules[ruleName].action = reverseChoices[value]
        else
          db.profiles[actualProfile].rules[ruleName].action = ACTION_NOTSET
        end
      end,
      default = GetString(BMR_ACTION_NOTSET),
    }

    return optionPanel
  end

end

-- Build the "Only if not full stack" optionPanel
local function panelOnlyIfNotFullStack(ruleNamePatern, ruleNameToFollow)

  local optionPanel = {
    type = "checkbox",
    name = GetString(BMR_ONLY_IF_NOT_FULL_STACK),
    tooltip = GetString(BMR_ONLY_IF_NOT_FULL_STACK_TOOLTIP),
    getFunc = function() return db.profiles[actualProfile].rules[ruleNameToFollow].onlyIfNotFullStack end,
    setFunc = function(value)
      for optionName, optionData in pairs(db.profiles[actualProfile].rules) do
        if type(optionData) == "table" then
          if string.find(optionName, ruleNamePatern) then
            optionData.onlyIfNotFullStack = value
          end
        end
      end
      db.profiles[actualProfile].rules[ruleNameToFollow].onlyIfNotFullStack = value
    end,
    width = "half",
    default = true,
  }

  return optionPanel

end

-- Build the "Max Stacks" optionPanel
local function panelMaxStacks(ruleNamePatern, onlyIfNotFullStackToFollow, ruleNameToFollow)

  local optionPanel = {
    type = "slider",
    name = GetString(BMR_MAX_STACK),
    tooltip = GetString(BMR_MAX_STACK_TOOLTIP),
    min = 1,
    max = 10,
    getFunc = function() return db.profiles[actualProfile].rules[ruleNameToFollow].onlyStacks end,
    setFunc = function(value)
      for optionName, optionData in pairs(db.profiles[actualProfile].rules) do
        if type(optionData) == "table" then
          if string.find(optionName, ruleNamePatern) then
            --d("Changing " .. optionName)
            optionData.onlyStacks = value -- Don't know why sometimes this value is set to true and not value ?
          end
        end
      end
      db.profiles[actualProfile].rules[ruleNameToFollow].onlyStacks = value
    end,
    default = true,
    disabled = function()
      if not db.profiles[actualProfile].rules[onlyIfNotFullStackToFollow].onlyIfNotFullStack then
        return false
      else
        return db.profiles[actualProfile].rules[onlyIfNotFullStackToFollow].onlyIfNotFullStack
      end
    end,
  }

  return optionPanel

end

-- List all active guilds
local function listOfActiveGuilds()

  guildList = { GetString(BMR_ACTION_NOTSET) }
  if GetNumGuilds() > 0 then
    for guild = 1, GetNumGuilds() do
      local guildId = GetGuildId(guild)
      local guildName = GetGuildName(guildId)
      if (not guildName or (guildName):len() < 1) then
        guildName = "Guild " .. guildId
      end
      table.insert(guildList, guildName)
    end
  end

end

-- Will change the name of the associatedGuild for all rules who match ruleNamePatern
local function panelGuildBank(ruleNamePatern, ruleNameToFollow)

  local optionPanel = {
    type = "dropdown",
    name = GetString(BMR_GUILD_LIST),
    tooltip = GetString(BMR_GUILD_LIST_TOOLTIP),
    choices = guildList,
    getFunc = function() return db.profiles[actualProfile].rules[ruleNameToFollow].associatedGuild end,
    setFunc = function(value)
      for optionName, optionData in pairs(db.profiles[actualProfile].rules) do
        if type(optionData) == "table" then
          if string.find(optionName, ruleNamePatern) then
            optionData.associatedGuild = value
          end
        end
      end
      db.profiles[actualProfile].rules[ruleNameToFollow].associatedGuild = value
    end,
    width = "half",
    default = GetString(BMR_ACTION_NOTSET),
  }

  return optionPanel

end

-- Will change the name of the associatedGuild for all rules who match ruleNamePatern
local function panelGuildBankFull(ruleNamePatern, ruleNameToFollow)

  local optionPanel = {
    type = "dropdown",
    name = GetString(BMR_GUILD_LIST),
    tooltip = GetString(BMR_GUILD_LIST_TOOLTIP),
    choices = guildList,
    getFunc = function() return db.profiles[actualProfile].rules[ruleNameToFollow].associatedGuild end,
    setFunc = function(value)
      for optionName, optionData in pairs(db.profiles[actualProfile].rules) do
        if type(optionData) == "table" then
          if string.find(optionName, ruleNamePatern) then
            optionData.associatedGuild = value
          end
        end
      end
      db.profiles[actualProfile].rules[ruleNameToFollow].associatedGuild = value
    end,
    default = GetString(BMR_ACTION_NOTSET),
  }

  return optionPanel

end

local function panelSpecialFilter(ruleName)

  local specialConvert = {
    writsQuests = { writsQuests = true, writsQuestsGlyphs = true, writsQuestsPots = true }
  }

  local optionPanel = {
    type = "checkbox",
    name = BankManagerRules.data[ruleName].name,
    tooltip = BankManagerRules.data[ruleName].tooltip,
    getFunc = function() return db.profiles[actualProfile].rules[ruleName].specialEnabled end,
    setFunc = function(newValue)

      for ruleNameToFollow, rulesData in pairs(specialConvert) do
        if type(rulesData) == "table" and ruleNameToFollow == ruleName then
          for realRule in pairs(rulesData) do
            if newValue then
              db.profiles[actualProfile].rules[realRule].action = ACTION_PULL
              db.profiles[actualProfile].rules[realRule].specialEnabled = newValue
            else
              db.profiles[actualProfile].rules[realRule].action = ACTION_NOTSET
              db.profiles[actualProfile].rules[realRule].specialEnabled = newValue
            end
          end
        end
      end

    end,
    default = false,
  }

  return optionPanel

end

local function Explode(div, str)
  if div == "" then return false end
  local pos, arr = 0, {}
  for st, sp in function() return string.find(str, div, pos, true) end do
    table.insert(arr, string.sub(str, pos, st - 1))
    pos = sp + 1
  end
  table.insert(arr, string.sub(str, pos))
  return arr
end

local function GetValuesForCondition(keywordCondition, values, arg1, arg2)

  local acceptedValues = keywordCondition[values]

  if acceptedValues == BMR_RULEWRITER_VALUE_WITHOUT_OPERATOR then
    local numberConverted = tonumber(arg2)
    if type(numberConverted) == "number" and numberConverted >= 1 and numberConverted <= 10000 then
      return true, numberConverted
    end
  elseif acceptedValues == BMR_RULEWRITER_VALUE_NOTHING then
    if not arg1 and not arg2 then
      return true, "xxx"
    end
  elseif acceptedValues == BMR_RULEWRITER_VALUE_OPTIONAL_KEYWORD then
    if keywordCondition.acceptedKeyword[arg1] then
      return true, "xxx"
    end
  elseif acceptedValues == BMR_RULEWRITER_VALUE_WITH_OPERATOR then
    if keywordCondition.acceptedKeyword[arg1] then
      return true, "xxx"
    end
  end

end

local function IsValidRuleWriterOperator(rawOperator)
  if rawOperator == "<" or rawOperator == ">" or rawOperator == "<=" or rawOperator == ">=" or rawOperator == "==" or rawOperator == "~=" then
    return true
  end
end

local function GetRuleWriterFuncForMainKeyword(keywordCondition)
  return keywordCondition.func
end

local function GetRuleWriterArgsForMainKeyword(keywordCondition)
  return keywordCondition.args
end

local function GetRuleWriterCondition(conditionTable)

  local mainKeyword = string.lower(conditionTable[1])
  local keywordCondition = BankManagerRules.keywordConditionTable[mainKeyword]

  local conditionData

  if keywordCondition then

    if keywordCondition[BMR_RULEWRITER_VALUE_WITH_OPERATOR] then

      local rawOperator = conditionTable[2]
      local rawValues = conditionTable[3]

      if IsValidRuleWriterOperator(rawOperator) and rawValues then
        local isValidValuesForCondition, builtValues = GetValuesForCondition(keywordCondition, BMR_RULEWRITER_VALUE_WITH_OPERATOR, rawOperator, rawValues)
        if isValidValuesForCondition then
          conditionData = { func = GetRuleWriterFuncForMainKeyword(keywordCondition), funcArgs = GetRuleWriterArgsForMainKeyword(keywordCondition), operator = rawOperator, values = builtValues }
        end
      end
    end

  end

  return conditionData

end

local function EvaluateRuleWriterParams(paramString)

  local conditions = Explode("+", paramString)

  if #conditions >= 1 then

    local validParams = {}

    for conditionIndex, conditionData in ipairs(conditions) do
      local conditionText = string.gsub(conditionData, "^%s*(.-)%s*$", "%1")
      local conditionKeywords = Explode(" ", conditionText)
      local isValidCondition, params = GetRuleWriterCondition(conditionKeywords)
      if isValidCondition then
        table.insert(validParams, params)
      else
        return
      end

    end

    return validParams

  end

end

local function EvaluateRuleWriterAction(actionString)

end

local function AddRuleToUserList(params, action)

  local ruleName = GenerateRuleShortNameFromParams(params)

  BankManagerRules.data[ruleName] = {
    params = { params },
    action = { action },
    name = GenerateRuleLongNameFromParams(params),
  }

end

local function CheckAndAddRule(ruleString, fromLAM)

  local lines = Explode("\n", ruleString) -- Only line 1
  local newRule = lines[1]

  local line = Explode("=", newRule) -- Check presence of the result

  if line[1] and line[2] and not line[3] then

    local isParameterValid, params = EvaluateRuleWriterParams(line[1])
    local isActionValid, action = EvaluateRuleWriterAction(line[2])

    if isParameterValid and isActionValid then
      AddRuleToUserList(params, action)
    end

  else
    db.userRule = "" -- Strip the text
  end

  if lamCall then
    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
  end

end

-- Build the Rule Writer engine. it permit to the user to write its own rules
local function RuleWriterPanel()

  local optionPanel = {
    {
      type = "header",
      name = GetString(BMR_RULE_WRITER),
      width = "full",
    },
    {
      type = "description",
      text = GetString(BMR_RULE_WRITER_DESC),
      width = "full",
    }
  }

  local correctUserRules = {}
  for correctUserRuleIndex, correctUserRuleData in ipairs(correctUserRules) do
    table.insert(optionPanel, correctUserRuleData)
  end

  table.insert(optionPanel,
    {
      type = "editbox",
      name = GetString(BMR_RULE_WRITER_ADDNEWRULE),
      tooltip = GetString(BMR_RULE_WRITER_ADDNEWRULE_TOOLTIP),
      isMultiline = true,
      isExtraWide = true,
      getFunc = function() return db.userRule end,
      setFunc = function(newValue)
        CheckAndAddRule(newValue, true) -- Rebuild the control if data is invalid
      end,
      width = "full",
      default = "",
    })

  table.insert(optionPanel,
    {
      type = "checkbox",
      name = GetString(BMR_RULE_WRITER_RUNAFTER),
      tooltip = GetString(BMR_RULE_WRITER_RUNAFTER_TOOLTIP),
      getFunc = function() return db.profiles[actualProfile].userRulesAfter end,
      setFunc = function(value)
        db.profiles[actualProfile].userRulesAfter = value
      end,
      width = "full",
      default = false,
    })

  return optionPanel

end

-- Build a LAM SubMenu with a list of filters
local function LAMSubmenu(subMenu)

  local submenuControls = {}

  if subMenu == "currencies" then

    table.insert(submenuControls, { type = "description", text = zo_strformat("<<1>> :", GetCurrencyName(CURT_MONEY, false, false)) })
    table.insert(submenuControls, panelCurrencyPush("currency" .. CURT_MONEY))
    table.insert(submenuControls, panelCurrencyPull("currency" .. CURT_MONEY))
    table.insert(submenuControls, panelCurrencyNothing("currency" .. CURT_MONEY, CURT_MONEY))
    table.insert(submenuControls, panelCurrencyKeepInBankInstead("currency" .. CURT_MONEY, CURT_MONEY))
    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, { type = "description", text = zo_strformat("<<1>> :", GetCurrencyName(CURT_TELVAR_STONES, false, false)) })
    table.insert(submenuControls, panelCurrencyPush("currency" .. CURT_TELVAR_STONES))
    table.insert(submenuControls, panelCurrencyPull("currency" .. CURT_TELVAR_STONES))
    table.insert(submenuControls, panelCurrencyNothing("currency" .. CURT_TELVAR_STONES, CURT_TELVAR_STONES))
    table.insert(submenuControls, panelCurrencyKeepInBankInstead("currency" .. CURT_TELVAR_STONES, CURT_TELVAR_STONES))
    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, { type = "description", text = zo_strformat("<<1>> :", GetCurrencyName(CURT_ALLIANCE_POINTS, false, false)) })
    table.insert(submenuControls, panelCurrencyPush("currency" .. CURT_ALLIANCE_POINTS))
    table.insert(submenuControls, panelCurrencyPull("currency" .. CURT_ALLIANCE_POINTS))
    table.insert(submenuControls, panelCurrencyNothing("currency" .. CURT_ALLIANCE_POINTS, CURT_ALLIANCE_POINTS))
    table.insert(submenuControls, panelCurrencyKeepInBankInstead("currency" .. CURT_ALLIANCE_POINTS, CURT_ALLIANCE_POINTS))
    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, { type = "description", text = zo_strformat("<<1>> :", GetCurrencyName(CURT_WRIT_VOUCHERS, false, false)) })
    table.insert(submenuControls, panelCurrencyPush("currency" .. CURT_WRIT_VOUCHERS))
    table.insert(submenuControls, panelCurrencyPull("currency" .. CURT_WRIT_VOUCHERS))
    table.insert(submenuControls, panelCurrencyNothing("currency" .. CURT_WRIT_VOUCHERS, CURT_WRIT_VOUCHERS))
    table.insert(submenuControls, panelCurrencyKeepInBankInstead("currency" .. CURT_WRIT_VOUCHERS, CURT_WRIT_VOUCHERS))

    -- Traits
  elseif subMenu == "traits" then

    -- Adding our toplevel LAM controls
    table.insert(submenuControls, panelOnlyIfNotFullStack("trait", "traitAll"))
    table.insert(submenuControls, panelGuildBank("trait", "traitGBank"))

    table.insert(submenuControls, panelMaxStacks("trait", "traitAll", "traitStacks"))
    table.insert(submenuControls, panelRule("traitAll"))

    -- Horizontal Divider
    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    -- Courtesy of Dustman (Garkin)
    for traitItemIndex = 1, GetNumSmithingTraitItems() do
      local traitType, itemName = GetSmithingTraitItemInfo(traitItemIndex)
      local itemLink = GetSmithingTraitItemLink(traitItemIndex, LINK_STYLE_DEFAULT)
      local itemType = GetItemLinkItemType(itemLink)
      if itemType ~= ITEMTYPE_NONE and traitType ~= ITEM_TRAIT_TYPE_NONE then
        table.insert(submenuControls, panelRule("trait" .. traitType))
      end
    end

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })
    for traitId, data in pairs(BankManagerRules.static.jewelrycraftingRawTraits) do
      table.insert(submenuControls, panelRule("jewelTraitRaw" .. traitId))
    end

    -- Styles
  elseif subMenu == "styles" then

    table.insert(submenuControls, panelOnlyIfNotFullStack("style", "styleAll"))
    table.insert(submenuControls, panelGuildBank("style", "styleGBank"))

    table.insert(submenuControls, panelMaxStacks("style", "styleAll", "styleStacks"))
    table.insert(submenuControls, panelRule("styleAll"))

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })
    for styleId, data in pairs(BankManagerRules.static.rawStyles) do
      table.insert(submenuControls, panelRule("styleRaw" .. styleId))
    end

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })
    for stylesItemIndex = 1, GetNumSmithingStyleItems() do
      local _, _, _, meetsUsageRequirement, itemStyle = GetSmithingStyleItemInfo(stylesItemIndex)
      if meetsUsageRequirement and itemStyle ~= ITEMSTYLE_UNIVERSAL then
        table.insert(submenuControls, panelRule("style" .. itemStyle))
      end
    end

    -- Blacksmithing
  elseif subMenu == "blacksmithing" then

    -- Here there is no "All" ruleset to rule them all, so we have created in BankManagerRules a false rule which will handle this setting
    -- 1st value is the pattern of filters to control, 2nd arg is the Lua Var to store the global value
    table.insert(submenuControls, panelOnlyIfNotFullStack("improvement" .. CRAFTING_TYPE_BLACKSMITHING, "improvementAll" .. CRAFTING_TYPE_BLACKSMITHING))
    table.insert(submenuControls, panelGuildBank("improvement" .. CRAFTING_TYPE_BLACKSMITHING, "improvementGBank" .. CRAFTING_TYPE_BLACKSMITHING))
    table.insert(submenuControls, panelMaxStacks("improvement" .. CRAFTING_TYPE_BLACKSMITHING, "improvementAll" .. CRAFTING_TYPE_BLACKSMITHING, "improvementStacks" .. CRAFTING_TYPE_BLACKSMITHING))

    for improvementItemIndex = 1, GetNumSmithingImprovementItems() do
      table.insert(submenuControls, panelRule("improvement" .. CRAFTING_TYPE_BLACKSMITHING .. improvementItemIndex))
    end

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelRule("armorTypeWeight" .. ARMORTYPE_HEAVY))
    table.insert(submenuControls, panelRule("armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_HEAVY))
    table.insert(submenuControls, panelRule("armorTypeResearchableWeight" .. ARMORTYPE_HEAVY))
    table.insert(submenuControls, panelRule("weaponType" .. CRAFTING_TYPE_BLACKSMITHING))
    table.insert(submenuControls, panelRule("weaponType" .. CRAFTING_TYPE_BLACKSMITHING .. "Trait" .. ITEM_TRAIT_TYPE_WEAPON_INTRICATE))
    table.insert(submenuControls, panelRule("weaponTypeResearchable" .. CRAFTING_TYPE_BLACKSMITHING))

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })
    table.insert(submenuControls, panelOnlyIfNotFullStack("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_BLACKSMITHING, "MaterialAll" .. CRAFTING_TYPE_BLACKSMITHING))
    table.insert(submenuControls, panelGuildBank("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_BLACKSMITHING, "MaterialGBank" .. CRAFTING_TYPE_BLACKSMITHING))
    -- Adding a Max Stack Slider. It will follow "MaterialAll" .. CRAFTING_TYPE_BLACKSMITHING to know if the slider should be disabled or not.
    table.insert(submenuControls, panelMaxStacks("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_BLACKSMITHING, "MaterialAll" .. CRAFTING_TYPE_BLACKSMITHING, "MaterialStacks" .. CRAFTING_TYPE_BLACKSMITHING))
    table.insert(submenuControls, panelRule("MaterialAll" .. CRAFTING_TYPE_BLACKSMITHING))
    table.insert(submenuControls, panelRule("refinedMaterialAll" .. CRAFTING_TYPE_BLACKSMITHING))
    table.insert(submenuControls, panelRule("rawMaterialAll" .. CRAFTING_TYPE_BLACKSMITHING))

    for materialIndex = 1, #BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_BLACKSMITHING] do
      if BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_BLACKSMITHING][materialIndex] ~= "" then
        table.insert(submenuControls, panelRule("refinedMaterial" .. CRAFTING_TYPE_BLACKSMITHING .. materialIndex))
      end
      if BankManagerRules.static.rawMaterial[CRAFTING_TYPE_BLACKSMITHING][materialIndex] ~= "" then
        table.insert(submenuControls, panelRule("rawMaterial" .. CRAFTING_TYPE_BLACKSMITHING .. materialIndex))
      end
    end

    -- Clothier
  elseif subMenu == "clothier" then

    table.insert(submenuControls, panelOnlyIfNotFullStack("improvement" .. CRAFTING_TYPE_CLOTHIER, "improvementAll" .. CRAFTING_TYPE_CLOTHIER))
    table.insert(submenuControls, panelGuildBank("improvement" .. CRAFTING_TYPE_CLOTHIER, "improvementGBank" .. CRAFTING_TYPE_CLOTHIER))
    table.insert(submenuControls, panelMaxStacks("improvement" .. CRAFTING_TYPE_CLOTHIER, "improvementAll" .. CRAFTING_TYPE_CLOTHIER, "improvementStacks" .. CRAFTING_TYPE_CLOTHIER))
    for improvementItemIndex = 1, GetNumSmithingImprovementItems() do
      table.insert(submenuControls, panelRule("improvement" .. CRAFTING_TYPE_CLOTHIER .. improvementItemIndex))
    end

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })
    table.insert(submenuControls, panelRule("armorTypeWeight" .. ARMORTYPE_LIGHT))
    table.insert(submenuControls, panelRule("armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_LIGHT))
    table.insert(submenuControls, panelRule("armorTypeResearchableWeight" .. ARMORTYPE_LIGHT))
    table.insert(submenuControls, panelRule("armorTypeWeight" .. ARMORTYPE_MEDIUM))
    table.insert(submenuControls, panelRule("armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_MEDIUM))
    table.insert(submenuControls, panelRule("armorTypeResearchableWeight" .. ARMORTYPE_MEDIUM))
    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelOnlyIfNotFullStack("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_CLOTHIER, "MaterialAll" .. CRAFTING_TYPE_CLOTHIER))
    table.insert(submenuControls, panelGuildBank("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_CLOTHIER, "MaterialGBank" .. CRAFTING_TYPE_CLOTHIER))
    table.insert(submenuControls, panelMaxStacks("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_CLOTHIER, "MaterialAll" .. CRAFTING_TYPE_CLOTHIER, "MaterialStacks" .. CRAFTING_TYPE_CLOTHIER))
    table.insert(submenuControls, panelRule("MaterialAll" .. CRAFTING_TYPE_CLOTHIER))
    table.insert(submenuControls, panelRule("refinedMaterialAll" .. CRAFTING_TYPE_CLOTHIER))
    table.insert(submenuControls, panelRule("rawMaterialAll" .. CRAFTING_TYPE_CLOTHIER))

    for materialIndex = 1, #BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_CLOTHIER] do
      if BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_CLOTHIER][materialIndex] ~= "" then
        table.insert(submenuControls, panelRule("refinedMaterial" .. CRAFTING_TYPE_CLOTHIER .. materialIndex))
      end
      if BankManagerRules.static.rawMaterial[CRAFTING_TYPE_CLOTHIER][materialIndex] ~= "" then
        table.insert(submenuControls, panelRule("rawMaterial" .. CRAFTING_TYPE_CLOTHIER .. materialIndex))
      end
    end

    for materialIndex = 1, #BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_CLOTHIER * 100] do
      if BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_CLOTHIER * 100][materialIndex] ~= "" then
        table.insert(submenuControls, panelRule("refinedMaterial" .. (CRAFTING_TYPE_CLOTHIER * 100) .. materialIndex))
      end
      if BankManagerRules.static.rawMaterial[CRAFTING_TYPE_CLOTHIER * 100][materialIndex] ~= "" then
        table.insert(submenuControls, panelRule("rawMaterial" .. (CRAFTING_TYPE_CLOTHIER * 100) .. materialIndex))
      end
    end

    -- Woodworking
  elseif subMenu == "woodworking" then

    table.insert(submenuControls, panelOnlyIfNotFullStack("improvement" .. CRAFTING_TYPE_WOODWORKING, "improvementAll" .. CRAFTING_TYPE_WOODWORKING))
    table.insert(submenuControls, panelGuildBank("improvement" .. CRAFTING_TYPE_WOODWORKING, "improvementGBank" .. CRAFTING_TYPE_WOODWORKING))
    table.insert(submenuControls, panelMaxStacks("improvement" .. CRAFTING_TYPE_WOODWORKING, "improvementAll" .. CRAFTING_TYPE_WOODWORKING, "improvementStacks" .. CRAFTING_TYPE_WOODWORKING))
    for improvementItemIndex = 1, GetNumSmithingImprovementItems() do
      table.insert(submenuControls, panelRule("improvement" .. CRAFTING_TYPE_WOODWORKING .. improvementItemIndex))
    end

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelRule("weaponType" .. CRAFTING_TYPE_WOODWORKING))
    table.insert(submenuControls, panelRule("weaponType" .. CRAFTING_TYPE_WOODWORKING .. "Trait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE))
    table.insert(submenuControls, panelRule("weaponTypeResearchable" .. CRAFTING_TYPE_WOODWORKING))

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelOnlyIfNotFullStack("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_WOODWORKING, "MaterialAll" .. CRAFTING_TYPE_WOODWORKING))
    table.insert(submenuControls, panelGuildBank("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_WOODWORKING, "MaterialGBank" .. CRAFTING_TYPE_WOODWORKING))
    table.insert(submenuControls, panelMaxStacks("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_WOODWORKING, "MaterialAll" .. CRAFTING_TYPE_WOODWORKING, "MaterialStacks" .. CRAFTING_TYPE_WOODWORKING))
    table.insert(submenuControls, panelRule("MaterialAll" .. CRAFTING_TYPE_WOODWORKING))
    table.insert(submenuControls, panelRule("refinedMaterialAll" .. CRAFTING_TYPE_WOODWORKING))
    table.insert(submenuControls, panelRule("rawMaterialAll" .. CRAFTING_TYPE_WOODWORKING))

    for materialIndex = 1, #BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_WOODWORKING] do
      if BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_WOODWORKING][materialIndex] ~= "" then
        table.insert(submenuControls, panelRule("refinedMaterial" .. CRAFTING_TYPE_WOODWORKING .. materialIndex))
      end
      if BankManagerRules.static.rawMaterial[CRAFTING_TYPE_WOODWORKING][materialIndex] ~= "" then
        table.insert(submenuControls, panelRule("rawMaterial" .. CRAFTING_TYPE_WOODWORKING .. materialIndex))
      end
    end

    -- Jewelrycrafting
  elseif subMenu == "jewelrycrafting" then

    table.insert(submenuControls, panelOnlyIfNotFullStack("improvement" .. CRAFTING_TYPE_JEWELRYCRAFTING, "improvementAll" .. CRAFTING_TYPE_JEWELRYCRAFTING))
    table.insert(submenuControls, panelGuildBank("improvement" .. CRAFTING_TYPE_JEWELRYCRAFTING, "improvementGBank" .. CRAFTING_TYPE_JEWELRYCRAFTING))
    table.insert(submenuControls, panelMaxStacks("improvement" .. CRAFTING_TYPE_JEWELRYCRAFTING, "improvementAll" .. CRAFTING_TYPE_JEWELRYCRAFTING, "improvementStacks" .. CRAFTING_TYPE_JEWELRYCRAFTING))
    for improvementItemIndex = 1, GetNumSmithingImprovementItems() do
      table.insert(submenuControls, panelRule("improvement" .. CRAFTING_TYPE_JEWELRYCRAFTING .. improvementItemIndex))
    end

    table.insert(submenuControls, panelOnlyIfNotFullStack("improvement" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100), "improvementAll" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100)))
    table.insert(submenuControls, panelGuildBank("improvement" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100), "improvementGBank" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100)))
    table.insert(submenuControls, panelMaxStacks("improvement" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100), "improvementAll" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100), "improvementStacks" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100)))
    for improvementItemIndex = 1, GetNumSmithingImprovementItems() do
      table.insert(submenuControls, panelRule("improvement" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100) .. improvementItemIndex))
    end

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelOnlyIfNotFullStack("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_JEWELRYCRAFTING, "MaterialAll" .. CRAFTING_TYPE_JEWELRYCRAFTING))
    table.insert(submenuControls, panelGuildBank("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_JEWELRYCRAFTING, "MaterialGBank" .. CRAFTING_TYPE_JEWELRYCRAFTING))
    table.insert(submenuControls, panelMaxStacks("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_JEWELRYCRAFTING, "MaterialAll" .. CRAFTING_TYPE_JEWELRYCRAFTING, "MaterialStacks" .. CRAFTING_TYPE_JEWELRYCRAFTING))
    table.insert(submenuControls, panelRule("MaterialAll" .. CRAFTING_TYPE_JEWELRYCRAFTING))
    table.insert(submenuControls, panelRule("refinedMaterialAll" .. CRAFTING_TYPE_JEWELRYCRAFTING))
    table.insert(submenuControls, panelRule("rawMaterialAll" .. CRAFTING_TYPE_JEWELRYCRAFTING))

    for materialIndex = 1, #BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_JEWELRYCRAFTING] do
      if BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_JEWELRYCRAFTING][materialIndex] ~= "" then
        table.insert(submenuControls, panelRule("refinedMaterial" .. CRAFTING_TYPE_JEWELRYCRAFTING .. materialIndex))
      end
      if BankManagerRules.static.rawMaterial[CRAFTING_TYPE_JEWELRYCRAFTING][materialIndex] ~= "" then
        table.insert(submenuControls, panelRule("rawMaterial" .. CRAFTING_TYPE_JEWELRYCRAFTING .. materialIndex))
      end
    end

    -- Cooking
  elseif subMenu == "cooking" then
    table.insert(submenuControls, panelOnlyIfNotFullStack("cookingIngredients", "cookingIngredientsAll"))
    table.insert(submenuControls, panelGuildBank("cookingIngredients", "cookingIngredientsGBank"))
    table.insert(submenuControls, panelMaxStacks("cookingIngredients", "cookingIngredientsAll", "cookingIngredientsStacks"))

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelRule("cookingIngredientsFood"))
    table.insert(submenuControls, panelRule("cookingIngredientsDrink"))
    table.insert(submenuControls, panelRule("cookingIngredientsRare"))
    table.insert(submenuControls, panelRule("cookingAmbrosia"))

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelGuildBankFull("cookingRecipe", "cookingRecipeGBank"))
    table.insert(submenuControls, panelRule("cookingRecipeKnown"))
    table.insert(submenuControls, panelRule("cookingRecipeUnknown"))

    -- Alchemy
  elseif subMenu == "alchemy" then
    table.insert(submenuControls, panelOnlyIfNotFullStack("alchemy", "alchemyAll"))
    table.insert(submenuControls, panelGuildBank("alchemy", "alchemyGBank"))
    table.insert(submenuControls, panelMaxStacks("alchemy", "alchemyAll", "alchemyStacks"))

    table.insert(submenuControls, panelRule("alchemyAll"))
    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })
    table.insert(submenuControls, panelRule("alchemyReagent"))
    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })
    local MAX_ALCHEMY_SKILL = 9
    -- alchemySolvent
    for alchemySkill = 1, MAX_ALCHEMY_SKILL do
      table.insert(submenuControls, panelRule("alchemyPotionSolvent" .. alchemySkill))
    end
    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })
    for alchemySkill = 1, MAX_ALCHEMY_SKILL do
      table.insert(submenuControls, panelRule("alchemyPoisonSolvent" .. alchemySkill))
    end

    -- Companion
  elseif subMenu == "companion" then
    table.insert(submenuControls, panelOnlyIfNotFullStack("companion", "companionAll"))
    table.insert(submenuControls, panelGuildBank("companion", "companionGBank"))
    table.insert(submenuControls, panelMaxStacks("companion", "companionAll", "companionStacks"))

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelRule("companionItems"))

    -- Enchanting
  elseif subMenu == "enchanting" then
    table.insert(submenuControls, panelOnlyIfNotFullStack("enchanting", "enchantingAll"))
    table.insert(submenuControls, panelGuildBank("enchanting", "enchantingGBank"))
    table.insert(submenuControls, panelMaxStacks("enchanting", "enchantingAll", "enchantingStacks"))

    table.insert(submenuControls, panelRule("enchantingAll"))

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelRule("enchantingPotency"))
    table.insert(submenuControls, panelRule("enchantingEssence"))
    table.insert(submenuControls, panelRule("enchantingAspect"))
    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })
    table.insert(submenuControls, panelGuildBankFull("enchantingGlyphs", "enchantingGlyphsGBank"))
    table.insert(submenuControls, panelRule("enchantingGlyphs"))

    -- Trophies - Diverse
  elseif subMenu == "trophies" then
    table.insert(submenuControls, panelOnlyIfNotFullStack("trophy", "trophyAll"))
    table.insert(submenuControls, panelGuildBank("trophy", "trophyGBank"))
    table.insert(submenuControls, panelMaxStacks("trophy", "trophyAll", "trophyStacks"))

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelRule("trophyTreasureMaps"))
    table.insert(submenuControls, panelRule("trophySurveys"))
    table.insert(submenuControls, panelRule("trophyFragRecipe"))
    table.insert(submenuControls, panelRule("trophyICPVE"))
    table.insert(submenuControls, panelRule("trophyToy"))

    -- Misc - Diverse
  elseif subMenu == "misc" then
    table.insert(submenuControls, panelOnlyIfNotFullStack("Misc", "MiscAll"))
    table.insert(submenuControls, panelGuildBank("Misc", "MiscGBank"))
    table.insert(submenuControls, panelMaxStacks("Misc", "MiscAll", "MiscStacks"))

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelRule("MiscAvaRepair"))
    table.insert(submenuControls, panelRule("MiscAvaSiege"))
    table.insert(submenuControls, panelRule("MiscContainer"))
    table.insert(submenuControls, panelRule("MiscDisguises"))
    table.insert(submenuControls, panelRule("MiscLockpick"))
    table.insert(submenuControls, panelRule("MiscLure"))
    table.insert(submenuControls, panelRule("MiscFragMotifsKnown"))
    table.insert(submenuControls, panelRule("MiscFragMotifsUnknown"))
    table.insert(submenuControls, panelRule("MiscPoison"))
    table.insert(submenuControls, panelRule("MiscPotion"))
    table.insert(submenuControls, panelRule("MiscRepair"))
    table.insert(submenuControls, panelRule("MiscStylePagesKnown"))
    table.insert(submenuControls, panelRule("MiscStylePagesUnknown"))
    table.insert(submenuControls, panelRule("MiscSoulGemsEmpty"))
    table.insert(submenuControls, panelRule("MiscSoulGemsFulfilled"))
    table.insert(submenuControls, panelRule("MiscMasterWrit"))

    -- Housing
  elseif subMenu == "housing" then
    table.insert(submenuControls, panelOnlyIfNotFullStack("Housing", "HousingAll"))
    table.insert(submenuControls, panelGuildBank("Housing", "HousingGBank"))
    table.insert(submenuControls, panelMaxStacks("Housing", "HousingAll", "HousingStacks"))

    table.insert(submenuControls, { type = "texture", image = "EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth = 510, imageHeight = 4 })

    table.insert(submenuControls, panelRule("HousingRecipeKnown"))
    table.insert(submenuControls, panelRule("HousingRecipeUnknown"))
    table.insert(submenuControls, panelRule("HousingFurnitures"))
    table.insert(submenuControls, panelRule("HousingIngredients"))

    -- Special
  elseif subMenu == "special" then
    table.insert(submenuControls, panelSpecialFilter("writsQuests"))  -- Special
  elseif subMenu == "ruleWriter" then
    submenuControls = RuleWriterPanel() -- Rule Writer Panel
  end

  return submenuControls

end

local function NamesToIDSavedVars()

  if not db.namesToIDSavedVars then

    local displayName = GetDisplayName()
    local name = GetUnitName("player")

    if BMVars.Default[displayName][name] then
      db = BMVars.Default[displayName][name]
      db.namesToIDSavedVars = true -- should not be necessary because data don't exist anymore in BMVars.Default[displayName][name]
    end

  end

end

-- Build LAM panel
local function buildLAMPanel()

  local function GetIdFromName(choice)

    local charName, server = zo_strsplit("@", choice)
    local data = BMVars.Default[GetDisplayName()]
    for entryIndex, entryData in pairs(data) do
      local name = entryData["$LastCharacterName"]
      if charName == name and server == entryData.worldname then
        return entryIndex
      end
    end
  end

  --[[TODO Update panelData
  ]]--
  local panelData = {
    type = "panel",
    name = ADDON_NAME,
    displayName = displayName,
    author = ADDON_AUTHOR,
    version = ADDON_VERSION,
    website = ADDON_WEBSITE,
    registerForRefresh = true,
    --[[TODO Figure out a way to make this work
    ]]--
    registerForDefaults = false,
    slashCommand = "/bmr",
  }

  panel = LAM2:RegisterAddonPanel(ADDON_NAME .. "LAM2Options", panelData)

  -- Get the SV data
  db = ZO_SavedVars:NewCharacterIdSettings("BMVars", 4, nil, defaults, nil)

  NamesToIDSavedVars()

  -- Load profile
  actualProfile = tonumber(db.actualProfile)

  -- Creating LAM optionPanel following the rules
  local currenciesSubmenuControls = LAMSubmenu("currencies")
  local traitSubmenuControls = LAMSubmenu("traits")
  local styleSubmenuControls = LAMSubmenu("styles")
  local blacksmithingSubmenuControls = LAMSubmenu("blacksmithing")
  local clothierSubmenuControls = LAMSubmenu("clothier")
  local woodworkingSubmenuControls = LAMSubmenu("woodworking")
  local jewelrycraftingSubmenuControls = LAMSubmenu("jewelrycrafting")
  local cookingSubmenuControls = LAMSubmenu("cooking")
  local enchantmentSubmenuControls = LAMSubmenu("enchanting")
  local alchemySubmenuControls = LAMSubmenu("alchemy")
  local companionsSubmenuControls = LAMSubmenu("companion")
  local trophiesSubmenuControls = LAMSubmenu("trophies")
  local diverseSubmenuControls = LAMSubmenu("misc")
  local housingSubmenuControls = LAMSubmenu("housing")
  local specialFiltersControls = LAMSubmenu("special")
  local ruleWriterControls = LAMSubmenu("ruleWriter")

  local charactersKnown = {}
  if BMVars and BMVars.Default and BMVars.Default[GetDisplayName()] then
    for id, data in pairs(BMVars.Default[GetDisplayName()]) do
      if data.worldname then
        if not (data.worldname == GetWorldName() and data["$LastCharacterName"] == GetUnitName("player")) then
          table.insert(charactersKnown, data["$LastCharacterName"] .. "@" .. data.worldname)
        end
      end
    end
  end

  local listOfProfiles = {}
  for i = 1, BMR_MAX_PROFILES do
    listOfProfiles[i] = i
  end

  -- Build panel
  local optionsTable = {
    {  -- Profile list
      type = "submenu",
      name = zo_strformat(GetString(BMR_PROFILES)),
      controls = {
        {
          type = "dropdown",
          name = GetString(BMR_PROFILE_LIST),
          tooltip = GetString(BMR_PROFILE_LIST_TOOLTIP),
          choices = listOfProfiles,
          width = "full",
          getFunc = function() return db.actualProfile end,
          setFunc = function(choice)
            actualProfile = tonumber(choice)
            db.actualProfile = choice
            db.profiles[actualProfile].defined = true
          end,
        },
        {
          type = "editbox",
          name = GetString(BMR_PROFILE_NAME),
          tooltip = GetString(BMR_PROFILE_NAME_TOOLTIP),
          width = "full",
          getFunc = function() return db.profiles[actualProfile].name end,
          setFunc = function(choice) db.profiles[actualProfile].name = choice end,
        },
        {
          type = "button",
          name = GetString(BMR_PROFILE_RESET),
          tooltip = GetString(BMR_PROFILE_RESET_TOOLTIP),
          width = "full",
          func = function()
            local profileToDelete = actualProfile
            actualProfile = 1
            db.actualProfile = "1"
            db.profiles[profileToDelete] = defaults.profiles[profileToDelete]
          end,
        },
      },
    },
    {
      type = "submenu",
      name = GetString(SI_GAMEPAD_OPTIONS_MENU),
      controls = {
        {  -- Auto Transfer
          type = "checkbox",
          name = GetString(BMR_AUTO_TRANSFERT),
          tooltip = GetString(BMR_AUTO_TRANSFERT_TOOLTIP),
          getFunc = function() return db.profiles[actualProfile].autoTransfert end,
          setFunc = function(value) db.profiles[actualProfile].autoTransfert = value end,
          default = true,
        },
        {  -- Detailed move/stack
          type = "checkbox",
          name = GetString(BMR_STACK_DETAILLED),
          tooltip = GetString(BMR_STACK_DETAILLED_TOOLTIP),
          getFunc = function() return db.profiles[actualProfile].detailledDisplay end,
          setFunc = function(value) db.profiles[actualProfile].detailledDisplay = value end,
          default = true,
        },
        {  -- Detailed non moved
          type = "checkbox",
          name = GetString(BMR_STACK_DETAILLED_NOTMOVED),
          tooltip = GetString(BMR_STACK_DETAILLED_NOTMOVED_TOOLTIP),
          getFunc = function() return db.profiles[actualProfile].detailledNotMoved end,
          setFunc = function(value) db.profiles[actualProfile].detailledNotMoved = value end,
          default = true,
        },
        {  -- Display Summary
          type = "checkbox",
          name = GetString(BMR_DISPLAY_SUMMARY),
          tooltip = GetString(BMR_DISPLAY_SUMMARY_TOOLTIP),
          getFunc = function() return db.profiles[actualProfile].summary end,
          setFunc = function(value) db.profiles[actualProfile].summary = value end,
          default = true,
        },
        {  -- Display Summary
          type = "checkbox",
          name = GetString(BMR_DONT_MOVE_PROTECTED_ITEMS),
          tooltip = GetString(BMR_DONT_MOVE_PROTECTED_ITEMS_TOOLTIP),
          getFunc = function() return db.profiles[actualProfile].protected end,
          setFunc = function(value) db.profiles[actualProfile].protected = value end,
          default = true,
        },
        {  -- Protect 3rd party moves
          type = "checkbox",
          name = GetString(BMR_DONT_MOVE_MOVED_ITEMS),
          tooltip = GetString(BMR_DONT_MOVE_MOVED_ITEMS_TOOLTIP),
          getFunc = function() return db.profiles[actualProfile].moved end,
          setFunc = function(value) db.profiles[actualProfile].moved = value end,
          default = true,
        },
        {  -- Wait at startup
          type = "slider",
          name = GetString(BMR_WAIT_AT_STARTUP),
          tooltip = GetString(BMR_WAIT_AT_STARTUP_TOOLTIP),
          step = 0.5,
          min = 1,
          max = 4,
          getFunc = function() return db.profiles[actualProfile].initialWaitInSecs end,
          setFunc = function(value) db.profiles[actualProfile].initialWaitInSecs = value end,
          default = 2,
        },
        {  -- Don't overfill bags
          type = "slider",
          name = GetString(BMR_NO_OVERFILL),
          tooltip = GetString(BMR_NO_OVERFILL_TOOLTIP),
          step = 1,
          min = 0,
          max = 20,
          getFunc = function() return db.profiles[actualProfile].overfill end,
          setFunc = function(value) db.profiles[actualProfile].overfill = value end,
          default = 0,
        },
        {  -- Pause in Ms between moves
          type = "slider",
          name = GetString(BMR_DELAY_BETWEEN_MOVES),
          tooltip = GetString(BMR_DELAY_BETWEEN_MOVES_TOOLTIP),
          step = 10,
          min = 0,
          max = 110,
          getFunc = function() return db.profiles[actualProfile].pauseInMs end,
          setFunc = function(value) db.profiles[actualProfile].pauseInMs = value end,
          default = 0,
        },
      },
    },
    {
      type = "submenu",
      name = zo_strformat(GetString(SI_INVENTORY_CURRENCIES)),
      controls = currenciesSubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>> & <<2>> & <<3>>", GetString("SI_ITEMTYPE", ITEMTYPE_ARMOR_TRAIT),
        GetString("SI_ITEMTYPE", ITEMTYPE_WEAPON_TRAIT), GetString("SI_ITEMTYPE", ITEMTYPE_JEWELRY_TRAIT)),
      controls = traitSubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>>", GetString(SI_ITEMTYPE44)),
      controls = styleSubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>>", GetString(SI_TRADESKILLTYPE1)),
      controls = blacksmithingSubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>>", GetString(SI_TRADESKILLTYPE2)),
      controls = clothierSubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>>", GetString(SI_TRADESKILLTYPE6)),
      controls = woodworkingSubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>>", GetString(SI_TRADESKILLTYPE7)),
      controls = jewelrycraftingSubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>>", GetString(SI_TRADESKILLTYPE5)),
      controls = cookingSubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>>", GetString(SI_TRADESKILLTYPE3)),
      controls = enchantmentSubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>>", GetString(SI_TRADESKILLTYPE4)),
      controls = alchemySubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>>", GetString(SI_ITEMFILTERTYPE27)),
      controls = companionsSubmenuControls,
    },
    {
      type = "submenu",
      name = GetString(SI_ITEMTYPE5),
      controls = trophiesSubmenuControls,
    },
    {
      type = "submenu",
      name = GetString(SI_HOUSING_BOOK_TITLE),
      controls = housingSubmenuControls,
    },
    {
      type = "submenu",
      name = GetString(SI_PLAYER_MENU_MISC),
      controls = diverseSubmenuControls,
    },
    {
      type = "submenu",
      name = zo_strformat("<<1>> : <<2>>", GetString(SI_JOURNAL_MENU_QUESTS), GetString("SI_QUESTTYPE", QUEST_TYPE_CRAFTING)),
      controls = specialFiltersControls,
    },

    --[[
  {
    type = "submenu",
    name = GetString(BMR_PROFILES),
    controls = ruleWriterControls,
  },

    ]]

    {
      type = "dropdown",
      name = GetString(BMR_IMPORT),
      tooltip = GetString(BMR_IMPORT_DESC),
      choices = charactersKnown,
      width = "full",
      getFunc = function() return GetUnitName('player') end,
      warning = "ReloadUI",
      setFunc = function(choice)

        local playerId = GetCurrentCharacterId()
        local referenceId = GetIdFromName(choice)

        if referenceId then

          for entryIndex, entryData in pairs(BMVars.Default[GetDisplayName()][referenceId]) do
            if entryIndex ~= "$LastCharacterName" then
              db[entryIndex] = entryData
              BMVars.Default[GetDisplayName()][playerId][entryIndex] = entryData
            end
          end

          SCENE_MANAGER:ShowBaseScene()
          CHAT_ROUTER:AddSystemMessage(zo_strformat(BMR_IMPORTED, choice))

          zo_callLater(function() ReloadUI() end, 2000)

        end
      end
    },
  }

  LAM2:RegisterOptionControls(ADDON_NAME .. "LAM2Options", optionsTable)

end

-- Move UI to its place
local function RebuildAnchorsGUI()
  BankManager:ClearAnchors()
  BankManager:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, db.gui_x, db.gui_y)
end

--Load Addon
local function onAddonLoaded(_, addon)

  if addon == ADDON_NAME then
    if BankManagerRules then

      -- Load rules
      BankManagerRules.addFilters()
      BankManagerRules.addFiltersTaggedAll()

      -- Adding defaults values to all our rules
      BankManagerRules.defaults = BankManagerRules.addDefaultFilters(BankManagerRules.data, BankManagerRules.defaults)

      -- Load profiles defaults, Huge memory waste :'(
      for i = 1, BMR_MAX_PROFILES do
        defaults.profiles[i].rules = BankManagerRules.defaults
      end

      -- Build it a single time to avoid unneeded loops
      listOfActiveGuilds()

      -- Build LAM
      buildLAMPanel()

      -- Move GUI to its saved position
      RebuildAnchorsGUI()

      isESOPlusSubscriber = IsESOPlusSubscriber()

      -- Register / Unregister
      EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_OPEN_BANK, onOpenBank)
      EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CLOSE_BANK, onCloseBank)

      EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_SELECTED, onGuildBankSelected)
      EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_ITEMS_READY, onGuildBankItemsReady)
      EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CLOSE_GUILD_BANK, onCloseGuildBank)

      EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    end
  end

end

-- Called by UI
function BankManagerRevived_nextRule(_, step)
  nextRule(step)
end

-- Called by UI
function BankManagerRevived_executeRule()
  BankManagerRevived:dm("Debug", "BankManagerRevived_executeRule")
  --startTimeInMs = GetGameTimeMilliseconds()
  if checkingGBank then
    doInteractionWithGBank()
  else
    interactWithBank()
  end

end

-- Called by UI
function BankManagerRevived_saveGuiPosition()

  local _, _, rightScreen, bottomScreen = GuiRoot:GetScreenRect()
  local _, _, right, bottom = BankManager:GetScreenRect()

  db.gui_x = zo_floor(right - rightScreen)
  db.gui_y = zo_floor(bottom - bottomScreen)

end

-- Called by Bindings
function BankManagerRevived_runProfile(profile)

  if db.profiles[profile].defined then

    actualProfile = profile
    db.actualProfile = profile

    -- Sync LAM
    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)

    if isBanking then

      local multipleProfiles = false

      for i = 2, BMR_MAX_PROFILES do
        if db.profiles[i].defined == true then
          multipleProfiles = true
          break
        end
      end

      -- Display UI only if 2 profiles are defined or if actual is on manual mode
      if not db.profiles[actualProfile].autoTransfert or multipleProfiles then
        displayUI(multipleProfiles)
      end

      if checkingGBank then
        doInteractionWithGBank()
      else
        interactWithBank()
      end

    end

  end

end

-- For API
function BankManagerRevived_inProgress()
  return inProgress
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddonLoaded)