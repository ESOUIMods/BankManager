


--------------------------------------------------------------------------------
--  ***** Bank Manager *****
--
--  * Benjamin Creusot - Todo
--  * Creation : 17/04/2014 
--  * v2.9.1
--      Manage easily your bank. Automatically places items in your bank/inventory
--
--  * LICENSE MIT
--
--------------------------------------------------------------------------------


---------------------------------------------------------------------------
-- ** Function called when the events are raised **
-- bankOpening(eventCode, addOnName, isManual)
-- @eventCode : Int,     Code of the event
-- @addOnName : String,  Name of the addon
-- @isManual  : Boolean, If the function was not launch by us... I guess :)
---------------------------------------------------------------------------
function bankOpening(eventCode, addOnName, isManual)
    if isManual then
        return
    end

    --Display the toolbar
    if BankManager.Saved["toolBarDisplayed"] then
        showUI()
    end

    --GOLD
    if BankManager.Saved["autoGoldTransfer"] then
        moveGold()
    end

    -- if the automatique push/pull is disable
    if not BankManager.Saved["autoTransfert"] then
        return
    end

    if BankManager.Saved.bankChoice == "BAG_BANK" and eventCode == EVENT_OPEN_BANK then
        ClearCursor()
        local status,err = pcall(moveItems,true,true,BankManager.Saved["defaultProfile"])
        if not status then
            cleanAll(err)
        end
    elseif BankManager.Saved.bankChoice == "BAG_GUILDBANK" and eventCode == EVENT_GUILD_BANK_ITEMS_READY  and BankManager.Saved["guildChoice"] then
        --We set the guild bank to work with
        --we check the permission
        if DoesPlayerHaveGuildPermission(BankManager.Saved["guildChoice"], GUILD_PERMISSION_BANK_DEPOSIT) and DoesPlayerHaveGuildPermission(BankManager.Saved["guildChoice"], GUILD_PERMISSION_BANK_WITHDRAW) then 
            SelectGuildBank(BankManager.Saved["guildChoice"])
            ClearCursor()
            local status,err = pcall(moveItems,true,true,BankManager.Saved["defaultProfile"])
            if not status then
                cleanAll(err)
            end
        else
            d(getTranslated("noPermission"))
        end
    end

end

------------------------------------------------
-- ** Function called when the bank is closed **
-- bankClose()
------------------------------------------------
function bankClose()
    hideUI()
end
---------------------------------------------------------------------------
-- ** Function called when an error is catch on the main loop, moveItems **
-- cleanAll(err)
-- @err the error catch
---------------------------------------------------------------------------
function cleanAll(err)
    counterMessageChat    = 0
    flagAlreadyPerforming = false
    --I have to print the error with the INGame system for a better communication between users and me
    assert(false,err)
end

------------------------------------------------------------------------------------
-- ** Function called when the options panel is close (EVENT_ACTION_LAYER_POPPED) **
-- dirtyAndReloadUI(eventCode, layerIndex, activeLayerIndex)
-- @eventCode        : Int, Code of the event
-- @layerIndex       : Int, Int of the last last layer pushed
-- @activeLayerIndex : Int, Current layer I guess
------------------------------------------
function dirtyAndReloadUI(eventCode, layerIndex, activeLayerIndex)
    --15 are the options panel and 2 don't remember :D
    if layerIndex == 15 and activeLayerIndex == 2 and dirty then
        dirty = false
        ReloadUI()
    end
end

------------------------------------------
-- ** Init Function **
-- init(eventCode, addOnName)
-- @eventCode : Int,     Code of the event
-- @addOnName : String,  Name of the addon
------------------------------------------
function init(eventCode, addOnName)
    if addOnName ~= BankManagerAppName then
        return
    end

    local initVarFalse              = NOTHING
    local defaults = {
        ["language"]                = getBaseLanguage(),
        ["toolBarDisplayed"]        = true,
        ["bankChoice"]              = "BAG_BANK",
        ["guildChoice"]             = GetGuildId(1),
        ["autoTransfert"]           = true,
        ["spamChat"]                = true,
        ["spamChatAll"]             = true,
        ["delayTransfer"]           = 0,
        ["profilesNb"]              = 1,
        ["profilesNames"]           = {},
        ["defaultProfile"]          = 1,
        ["AllBM"]                   = {},
        ["fillStacks"]              = {},
        ["stackSizeCheckBox"]       = {},
        ["stackSizeSlider"]         = {},
        ["autoGoldTransfer"]        = false,
        ["goldButtonToolbar"]       = true,
        ["directionGoldTransfer"]   = INVENTORY_TO_BANK,
        ["typeOfGoldTransfer"]      = typeOfGoldTransfer[1], 
        ["amountGoldTransferInt"]   = 1000,
        ["amountGoldTransferPerc"]  = 10,
        ["minGoldKeep"]             = 1000,
        ["timeBetweenGoldTransfer"] = 10*60,
        ["timeLastDeposit"]         = 0
    }
    
    for i=1,maxProfilesNb do
        defaults["AllBM"][i]      = NOTHING
        defaults["fillStacks"][i] = NOTHING
        defaults["stackSizeCheckBox"][i] = false
        defaults["stackSizeSlider"][i] = 100
        for key,arrayRules in ipairs(allRules) do
            for keyRule,rule in ipairs(arrayRules) do
                if defaults[rule] == nil then
                     defaults[rule] = {}
                end
                defaults[rule][i] = initVarFalse
            end
        end
    end
    BankManager.Saved = ZO_SavedVars:New(BankManagerVars, 3, nil, defaults, nil)

    --mistake by me when I have pre-set the vars
    if BankManager.Saved["typeOfGoldTransfer"] == nil or type(BankManager.Saved["typeOfGoldTransfer"]) == type({}) then
        BankManager.Saved["typeOfGoldTransfer"] = typeOfGoldTransfer[1]
    end
    if BankManager.Saved["directionGoldTransfer"] == nil then
        BankManager.Saved["directionGoldTransfer"] = INVENTORY_TO_BANK
    end
    if BankManager.Saved["goldButtonToolbar"] == nil then
        BankManager.Saved["goldButtonToolbar"] = true
    end
    if BankManager.Saved["timeLastDeposit"] == nil then
        BankManager.Saved["timeLastDeposit"] = 0
    end
    if BankManager.Saved["delayTransfer"] == nil then
        BankManager.Saved["delayTransfer"] = 0
    end
    if BankManager.Saved["ITEMTYPE_ENCHANTING_RUNE_ASPECT"] == nil then
        BankManager.Saved["ITEMTYPE_ENCHANTING_RUNE_ASPECT"] = initVarFalse
    end
    if BankManager.Saved["ITEMTYPE_ENCHANTING_RUNE_ESSENCE"] == nil then
        BankManager.Saved["ITEMTYPE_ENCHANTING_RUNE_ESSENCE"] = initVarFalse
    end
    if BankManager.Saved["ITEMTYPE_ENCHANTING_RUNE_POTENCY"] == nil then
        BankManager.Saved["ITEMTYPE_ENCHANTING_RUNE_POTENCY"] = initVarFalse
    end
    if BankManager.Saved["ITEMTYPE_RACIAL_STYLE_MOTIF"] == nil then
        BankManager.Saved["ITEMTYPE_RACIAL_STYLE_MOTIF"] = initVarFalse
    end


    --Later call of the option function to remove the anchor issue
    zo_callLater(function() options() end, 500)
    InitializeGUI()


    EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_ACTION_LAYER_POPPED     , dirtyAndReloadUI)

    --ZO_PreHook("ZO_OptionsWindow_ChangePanels", function(panel) end)

    EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_OPEN_BANK              , bankOpening)
    EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_CLOSE_BANK             , bankClose)
    --EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_GUILD_BANK_ITEMS_READY, bankOpening)
    
    --EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_PLAYER_ACTIVATED       , playerReady)

end


EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_ADD_ON_LOADED, init)