

---------------------------------------------------------------------------------------
-- ** Function that place one item in another bag/slot **
-- placeItems(fromBag, fromSlot, destBag, destSlot, quantity)
-- @fromBag   : Int, Bag where the item has to come from
-- @fromSlot  : Int, Slot where the item has to come from
-- @destBag   : Int, Bag where the item will go
-- @destSlot  : Int, Slot where the item will go
-- @quantity  : int, Quantity moved
---------------------------------------------------------------------------------------
function placeItems(fromBag, fromSlot, destBag, destSlot, quantity)
    --local fromName = GetItemName(fromBag, fromSlot)
    --local destName = GetItemName(destBag, destSlot)
    --if destName ~= nil then
    --    d("(" .. fromName .. ")[" .. fromBag .. "," .. fromSlot .."] => (" .. destName .. ") [" .. destBag .. "," .. destSlot .."] (" .. quantity .. ")")
    --else
    --    d("(" .. fromName .. ")[" .. fromBag .. "," .. fromSlot .."] => (nil) [" .. destBag .. "," .. destSlot .."] (" .. quantity .. ")")
    --end
    zo_callLater(function() 
        ClearCursor()
        if CallSecureProtected("PickupInventoryItem", fromBag, fromSlot, quantity) then
            CallSecureProtected("PlaceInInventory", destBag, destSlot)
        end
        ClearCursor()
    end, delayTransfer)
    delayTransfer = delayTransfer + BankManager.Saved["delayTransfer"]
end

---------------------------------------------------------------------------------------
-- ** Function return the state of an item regarding of the option sets **
-- getItemState(craftingType,itemType)
-- @itemType      : Int,  Type of item,  describe in the API of ESO
-- @stackSize     : Int,  Size of the item stack
-- @return        : The state of the item, NOTHING, INVENTORY_TO_BANK,BANK_TO_INVENTORY
---------------------------------------------------------------------------------------
local function getItemState(itemType,stackSize)
    --Test if their is a limit on the stack size
    if BankManager.Saved["stackSizeCheckBox"][currentProfile] and BankManager.Saved["stackSizeSlider"][currentProfile] ~= stackSize then
        return NOTHING
    end

    --Test of the global setting for the profil
    if BankManager.Saved.AllBM[currentProfile] == INVENTORY_TO_BANK or BankManager.Saved.AllBM[currentProfile] == BANK_TO_INVENTORY then
        return BankManager.Saved.AllBM[currentProfile]
    end

    if itemType ~= ITEMTYPE_NONE and ITEMTYPE_TRANSLATION[itemType] then
        return BankManager.Saved[ITEMTYPE_TRANSLATION[itemType]][currentProfile]
    end
    return NOTHING

--    if (itemType == ITEMTYPE_BLACKSMITHING_RAW_MATERIAL or 
--           itemType == ITEMTYPE_CLOTHIER_RAW_MATERIAL or
--           itemType == ITEMTYPE_WOODWORKING_RAW_MATERIAL) then
--        itemType = ITEMTYPE_RAW_MATERIAL
--    end
--
--    --If the craft of itemtype is known and we got a entry for it (we treat it)
--    if craftingType ~= CRAFTING_TYPE_INVALID and CRAFTING_TYPE_TRANSLATION[craftingType] then
--        if itemType == ITEMTYPE_RAW_MATERIAL and BankManager.Saved[ITEMTYPE_TRANSLATION[itemType]][currentProfile] ~= MATCH_CRAFT then
--            return BankManager.Saved[ITEMTYPE_TRANSLATION[itemType]][currentProfile]
--        else
--            return BankManager.Saved[CRAFTING_TYPE_TRANSLATION[craftingType]][currentProfile]
--        end
--    end
end



--------------------------------------------------------------------------------------------------------------------
-- ** Function that parse one bag then register information about free space, stackable items and push/pull items **
-- getBagDescription(bag,pushItems,pullItems)
-- @bag          : Int,   The ID of the bag (BackPack,Bank,GuildBank)
-- @pushItems    : Table, The table contains all items that have to be pushed
-- @pullItems    : Table, The table contains all items that have to be pulled
-- @return       :        The items stack table and the free slot avalaible of the corresponding bag
--------------------------------------------------------------------------------------------------------------------
local function getBagDescription(bag,pushItems,pullItems)
    --get the number of slot in the destination
    local bagIcon, bagSlots = GetBagInfo(bag)
    --return tables of stackable items in the bag and free slots
    local itemsStackTable, slotAvalaibleDest = {},{}
    --iteration to get all the slots
    for slotDest = 0, bagSlots-1 do
        local item                              = {}
        local idItem                            = GetItemInstanceId(bag, slotDest)
        local _, _, _, _, _, _, _, itemQuality  = GetItemInfo(bag, slotDest)
        --if the item exist, we create it
        if idItem ~= nil then
            item.id                    = idItem
            item.bag                   = bag
            item.slot                  = slotDest
            item.name                  = GetItemName(bag, slotDest)
            item.stack,item.maxStack   = GetSlotStackSize(bag, slotDest)
            item.itemType              = GetItemType(bag, slotDest)
            item.state                 = getItemState(item.itemType,item.stack)
            item.quality               = itemQuality
        end
        --if the item is not from the junk, and if the items got room for more
        if (idItem ~= nil and not IsItemJunk(bag, slotDest)) then
            --if the all option is disabled
            if (item.state == INVENTORY_TO_BANK and bag ~= BANKS_TRANSLATION[BankManager.Saved.bankChoice]) then
                item.idPushPull = #pushItems+1
                table.insert(pushItems,item)
            elseif (item.state == BANK_TO_INVENTORY and bag ~= BAG_BACKPACK) then
                item.idPushPull = #pullItems+1
                table.insert(pullItems,item)
            end

            if  item.stack < item.maxStack then
                itemsStackTable[idItem] = item
            end
        elseif idItem == nil then
            table.insert(slotAvalaibleDest,slotDest)
        end
    end
    return itemsStackTable,slotAvalaibleDest
end

------------------------------------------------------------------------------------------------------------
-- ** Function that analyze the stack of the item and the stack of the destination then stack items  **
-- stackItems(idItem, fromTable,destTable,fromFreeSpaceTable)
-- @idItem              : String, the ID of the element, ID are ingame value made of an object (8-9 numbers)
-- @fromTable           : Table,  The stacking table which contains items by there ID
-- @destTable           : Table,  The destination stacking table which contains items by there ID
-- @fromFreeSpaceTable  : Table,  The table contains all free space from one bag
-- @return              :         If the item has been entirely moved to his destination stack
------------------------------------------------------------------------------------------------------------
local function stackItems(idItem, fromTable,destTable,fromFreeSpaceTable)
    local fromItem     = fromTable[idItem]
    local destItem     = destTable[idItem]
    --If we gotta do something
    --2 case : enough place, not enough place :)
    local maxDestQuantity = destItem.maxStack - destItem.stack
    --enough place
    if(maxDestQuantity >= fromItem.stack) then
        placeItems(fromItem.bag, fromItem.slot, destItem.bag, destItem.slot, fromItem.stack)
        destItem.stack = destItem.stack + fromItem.stack
        --from item is no more so we have a new free place and we can remove that element
        table.insert(fromFreeSpaceTable,fromItem.slot)
        fromTable[idItem] = nil
        if destItem.stack == destItem.maxStack then
            destTable[idItem] = nil
        end

        local argb = GetItemQualityColor(fromItem.quality)
        displayChat(fromItem.name, fromItem.stack, false, {argb.r,argb.g,argb.b})
        return true
    --no enough place
    else
        fromItem.stack = fromItem.stack - maxDestQuantity
        placeItems(fromItem.bag, fromItem.slot, destItem.bag, destItem.slot, maxDestQuantity)
        destTable[idItem] = nil
        local argb = GetItemQualityColor(fromItem.quality)
        displayChat(fromItem.name, maxDestQuantity, false,{argb.r,argb.g,argb.b})
        return false
    end
end

---------------------------------------------------------
-- ** First Function in the moving part of the object **
-- moveItems(isPushSet,isPullSet,numProfile)
-- @isPushSet  : Boolean, define if we have to do the push
-- @isPullSet  : Boolean, define if we have to do the pull
-- @numProfile : Int,     the profile which rules here
---------------------------------------------------------
function moveItems(isPushSet,isPullSet,numProfile)
    -- check if the program is already performing
    assert(not flagAlreadyPerforming, getTranslated("alreadyPerforming"))
    --now it's performing :)
    flagAlreadyPerforming  = true
    currentProfile         = numProfile
    delayTransfer          = 0
    local nbItemsMoveToBank,nbItemsMoveToInv,nbItemsStack = 0,0,0
    local pushItems,pullItems                             = {},{}
    local bankBag                                         = BANKS_TRANSLATION[BankManager.Saved.bankChoice]
    local backpackBag                                     = BAG_BACKPACK
    local bankItemsStackTable, bankFreeSlots              = {},{}
    local inventoryItemsStackTable, inventoryFreeSlots    = {},{}
    local securityCounter                                 = 0

    --BANK ANALYZE
    bankItemsStackTable,bankFreeSlots = getBagDescription(bankBag,pushItems,pullItems)
    --INVENTORY ANALYZE
    inventoryItemsStackTable, inventoryFreeSlots = getBagDescription(backpackBag,pushItems,pullItems)

    --If it's the GUILDBANK, we got a special treatment cause of the shitty system of waiting event:)
    --if BankManager.Saved.bankChoice == "BAG_GUILDBANK" then
    --    initGuildBankManager(backpackBag,bankBag,bankItemsStackTable,inventoryItemsStackTable, inventoryFreeSlots,pushItems,pullItems)
    --    return
    --end


    --Stacking time, we run the inventory because statistically there is more chance that the inventory contains less items that the bank
    for idItem,itemInventory in pairs(inventoryItemsStackTable) do
        --If the items is present in the dest
        if bankItemsStackTable[idItem] then
            local itemState   = itemInventory.state
            local idPush      = inventoryItemsStackTable[idItem].idPushPull
            local idPull      = bankItemsStackTable[idItem].idPushPull

            --PUSH STACKING
            if (isPushSet and (itemState == INVENTORY_TO_BANK or BankManager.Saved["fillStacks"][currentProfile] == INVENTORY_TO_BANK)) then
                -- The item has been completely stack ! We gotta remove it from the push table
                if stackItems(idItem,inventoryItemsStackTable,bankItemsStackTable,inventoryFreeSlots) and itemState == INVENTORY_TO_BANK then
                    pushItems[idPush] = nil
                end
                nbItemsStack = nbItemsStack + 1
            --Same rule but for TO_INVENTORY
            elseif (isPullSet and (itemState == BANK_TO_INVENTORY or BankManager.Saved["fillStacks"][currentProfile] == BANK_TO_INVENTORY)) then
                if stackItems(idItem,bankItemsStackTable,inventoryItemsStackTable,bankFreeSlots) and itemState == BANK_TO_INVENTORY then
                    pullItems[idPull] = nil
                end
                nbItemsStack = nbItemsStack + 1
            end
        end
    end


    -- if there is place in both bags AND there is something to move

    while ((next(bankFreeSlots) ~= nil and next(pushItems) ~= nil and isPushSet) or (next(inventoryFreeSlots) ~= nil and next(pullItems) ~= nil and isPullSet) and securityCounter < 300) do
        securityCounter = securityCounter +1
        --We begin by pushing items from inventory
        if isPushSet then
            for k,item in pairs(pushItems) do
                --if the items was already stack (secure for maxStack items that are not registered at all)
                --if not inventoryItemsStackTable[item.id] and item.stack < item.maxStack then
                --    table.remove(pushItems,k)
                -- if there is a place in the bank at least
                if next(bankFreeSlots) ~= nil then
                    placeItems(item.bag, item.slot, BANKS_TRANSLATION[BankManager.Saved.bankChoice], table.remove(bankFreeSlots), item.stack)
                    --new place in bank
                    table.insert(inventoryFreeSlots,item.slot)
                    pushItems[k] = nil
                    nbItemsMoveToBank  = nbItemsMoveToBank + 1
                    local argb = GetItemQualityColor(item.quality)
                    displayChat(item.name, item.stack, true,{argb.r,argb.g,argb.b})
                --if not there is no point to continue
                else
                    break
                end
            end
        end
        --pull time
        if isPullSet then
            for k,item in pairs(pullItems) do
                --if not bankItemsStackTable[item.id] and item.stack < item.maxStack then
                --    table.remove(pullItems,k)
                if next(inventoryFreeSlots) ~= nil then
                    placeItems(item.bag, item.slot, BAG_BACKPACK, table.remove(inventoryFreeSlots), item.stack)
                    --new place in bank
                    table.insert(bankFreeSlots,item.slot)
                    pullItems[k] = nil
                    nbItemsMoveToInv  = nbItemsMoveToInv + 1
                    local argb = GetItemQualityColor(item.quality)
                    displayChat(item.name, item.stack, true,{argb.r,argb.g,argb.b})
                else
                    break
                end
            end
        end

    end
    if(securityCounter > 299) then
        d("Something went wrong : plz send me a message on the forum of esoui, pseudo : Todo")
    end

    if BankManager.Saved["spamChat"] and counterMessageChat > limitMessageChat then
        d((counterMessageChat - limitMessageChat) .. " " .. getTranslated("noDisplayed"))
    end

    if BankManager.Saved["spamChatAll"] then
        d(nbItemsStack .. " " .. getTranslated("itemsStacked"))
        d((nbItemsMoveToInv + nbItemsMoveToBank) .. " " .. getTranslated("itemsMoved"))
        if next(pushItems) ~= nil then
            d(sizeArray(pushItems) .. " " .. getTranslated("itemsNotMovedInv"))
        end
        if next(pullItems) ~= nil then
            d(sizeArray(pullItems) .. " " .. getTranslated("itemsNotMovedBank"))
        end

    end
    --Data reset for new action
    counterMessageChat    = 0
    flagAlreadyPerforming = false
end

function sizeArray(arrayVar)
    local i = 0
    for k,v in pairs(arrayVar) do
        i = i +1
    end
    return i
end

function moveGold()
    --If the time between 2 gold transaction is not reach
    local timeStampDiff = GetDiffBetweenTimeStamps(GetTimeStamp(), BankManager.Saved["timeLastDeposit"])
    if timeStampDiff < tonumber(BankManager.Saved["timeBetweenGoldTransfer"]) then
        if BankManager.Saved["spamChatAll"] then
            timeStampDiff = (tonumber(BankManager.Saved["timeBetweenGoldTransfer"]) - timeStampDiff)/60
            d(math.floor(timeStampDiff + 0.5) .. " " .. getTranslated("goldTimeNotReach"))
        end
        return
    end

    local currentGold = 0
    local sendGold    = nil
    local goldValue   = 0
    
    --Set up the direction of the transaction and all the related functions
    if BankManager.Saved["directionGoldTransfer"] == INVENTORY_TO_BANK then
        currentGold = GetCurrentMoney()
        sendGold  = DepositMoneyIntoBank
    else
        currentGold = GetBankedMoney()
        sendGold  = WithdrawMoneyFromBank
    end

    --Check if the currentGold owned is not under the gold limit
    if currentGold <= tonumber(BankManager.Saved["minGoldKeep"]) then
        d(getTranslated("notEnoughGold"))
        return
    end

    --get the amount of gold that will be transfered - typeOfGoldTransfer[1] = "goldAmount"
    if BankManager.Saved["typeOfGoldTransfer"] == typeOfGoldTransfer[1] then
        goldValue = tonumber(BankManager.Saved["amountGoldTransferInt"])
        if goldValue == nil then
            return
        end
    else
        goldValue = math.floor(tonumber(tonumber(BankManager.Saved["amountGoldTransferPerc"]))*currentGold/100 + 0.5)
    end

    --if there isn't enough gold above the min amount
    if currentGold - goldValue < tonumber(BankManager.Saved["minGoldKeep"]) then
        goldValue = currentGold - tonumber(BankManager.Saved["minGoldKeep"])
    end

    BankManager.Saved["timeLastDeposit"] = GetTimeStamp()
    sendGold(goldValue)

    if BankManager.Saved["spamChatAll"] then
        d(goldValue .. " " .. getTranslated("goldMoved"))
    end
end