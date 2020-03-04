
	---------------------------------------------------------
	-- 		This file is design to answer the problem
	--		of guild bank drawing/withdrawing items.
	--		Items can't be put by using the cursor system,
	--		We have to use the function TransferToGuildBank
	--		which can't stored multiple items, so we have
	--		to do it once at a time waiting for the event
	--		ITEM_ADDED to be sent.
	---------------------------------------------------------

------------------------------------
-- This function is design to be the main entry point for managing the add of items in the guild bank
-- initGuildBankManager(backpackBag,bankBag,bankItemsTable,inventoryItemsTable, inventoryFreeSlots,pushItems,pullItems)
-- backpackBag			: The backbag ID (default BAG_BACKBACK)
-- bankBag				: The bank ID (default here BAG_GUILDBANK)
-- bankItemsTable		: The items in the bank without the fulls stacks (ordered by idItems)
-- inventoryItemsTable	: Items in inventory without the fulls stacks (ordered by idItems)
-- inventoryFreeSlots   : Free places in the inventory (no ID)
-- pushItems			: Items we gotta push (no ID)
-- pullItems			: Items we gotta pull (no ID)
------------------------------------

nbItemsStackGB 			= 0
nbItemsMovedGB 			= 0
backpackBagGB			= nil			
bankBagGB				= nil			
bankItemsTableGB		= {}			
inventoryItemsTableGB	= {}			
inventoryFreeSlotsGB	= {}			 
pushItemsGB				= {}		
pullItemsGB				= {}
itemFrom				= nil
itemDest				= nil
stackQuantity			= 0

--Global States : 
--	READY
--	TOBANK
--	 * READY
--	 * ADDING
--	 * REMOVING
--	TOINVENTORY
--	 * READY
--	 * ADDING
--	 * REMOVING


TOBANK 		 = 1
TOINVENTORY  = 2

READY		 = 10
ADDING		 = 20
REMOVING	 = 30



stackingState			= {}
stackingState.global	= READY
stackingState.detailed	= READY

function initGuildBankManager(backpackBag,bankBag,bankItemsTable,inventoryItemsTable, inventoryFreeSlots,pushItems,pullItems)
	nbItemsStackGB 			= 0
	nbItemsMovedGB 			= 0
	backpackBagGB			= backpackBag			
	bankBagGB				= bankBag
	bankItemsTableGB		= bankItemsTable
	inventoryItemsTableGB	= inventoryItemsTable
	inventoryFreeSlotsGB	= inventoryFreeSlots
	pushItemsGB				= pushItems
	pullItemsGB				= pullItems
	itemFrom				= nil
	itemDest				= nil
	stackQuantity			= 0


	if next(inventoryFreeSlots) == nil then
		d(getTranslated("freeSpaceRequired"))
		return
	end
	--Registered the event for stacking time
	EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_GUILD_BANK_ITEM_ADDED  , stackingGuildBank)
    EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_GUILD_BANK_ITEM_REMOVED, stackingGuildBank)


	stackingGuildBank()
end


function findItemSlot(item, bagId)
    local icon, maxSlots = GetBagInfo(bagId)
	
    d("global vars")
	d(itemFrom.slot)
	d(item.id)
	d("begin for")
    for slot=0,maxSlots do
    	stack, maxStack = GetSlotStackSize(bagId, slot)
    	local itemName = GetItemName(bagId, slot)
    	--If it's not the item already present, id must be equal :), and if it's not a full stack
		d("--------")
		d(itemName)
		d(slot)
		d(GetItemInstanceId(bagId, slot))
		d(stack .. "/" .. maxStack)
		d("--------")
        if slot ~= d(itemFrom.slot) and item.id == GetItemInstanceId(bagId, slot) and stack~=maxStack then
            return slot
        end
    end

    return nil
end

----------------------------
-- Stack to bank mean we gotta do 3 steps :
--  * Draw the item in the inventory
--	* Stack the item in the inventory
--	* Send it back to the bank
----------------------------
local function stackToGuildBank()

	--We draw to the inventory
	if stackingState.detailed == READY then
		stackingState.detailed = REMOVING
		--Itemdest because we can't stack in the bank
		d("trasnfert to from GB : " .. itemDest.slot)
		TransferFromGuildBank(itemDest.slot)
	-- next step, we have to stack the items together
	elseif stackingState.detailed == REMOVING then
		--first found where the system put our item
		itemDest.slot = findItemSlot(itemDest,backpackBagGB)
		d("item found on slot " .. itemDest.slot)
		local maxDestQuantity = itemFrom.maxStack - itemFrom.stack

	    --enough place
	    if(maxDestQuantity >= itemDest.stack) then
	    	d("enough place")
	        placeItems(backpackBagGB, itemDest.slot, backpackBagGB, itemFrom.slot, itemDest.stack)
	        stackQuantity  = itemFrom.stack
	        itemFrom.stack = itemFrom.stack + itemDest.stack

	    --no enough place
	    else
	        itemDest.stack = itemDest.stack - maxDestQuantity
	        placeItems(backpackBagGB, itemDest.slot, backpackBagGB, itemFrom.slot, maxDestQuantity)
	        stackQuantity  = maxDestQuantity

	        --we add in the push list
	        table.insert(pushItemsGB,itemDest)
	    end

        --we add the items back to the bank
		stackingState.detailed = ADDING
		d("item move to GB " .. backpackBagGB .. " " .. itemFrom.slot)
        TransferToGuildBank(backpackBagGB,itemFrom.slot)
	   --Adding finish, we display and continue the algo
	elseif stackingState.detailed == ADDING then
		d("ready again")
		stackingState.global   = READY
		stackingState.detailed = ADDING
		displayChat(itemDest.name, stackQuantity, false)

		stackingGuildBank()
	end
end


-- Stacking method :)
function stackingGuildBank(eventCode,slotAdded)

	--state checking
	if stackingState.global == TOBANK then
		stackToGuildBank()
		return
	end


	--test if stacking finished
	if next(inventoryItemsTableGB) == nil then
		--We unregistered the event ADD/REMOVE
		EVENT_MANAGER:UnregisterForEvent(BankManagerAppName, EVENT_GUILD_BANK_ITEM_ADDED  , stackingGuildBank)

		--We register the Event for moving the items
		--EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_GUILD_BANK_ITEM_ADDED  , moveItemsGuildBank)
	    --EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_GUILD_BANK_ITEM_REMOVED, bankOpening)
		return
	end
	--Stacking time by inv for performance talking
	for idItem,itemInv in pairs(inventoryItemsTableGB) do
		--If the items is present in the bank
        if bankItemsTableGB[idItem] then
        	--3 possibilites : NOTHING, Stack in Bank, Stack in Inventory
        	d("Found " .. bankItemsTableGB[idItem].name)

            if (itemInv.state == INVENTORY_TO_BANK or BankManager.Saved.AllBM == INVENTORY_TO_BANK) then
            	stackingState.global   = TOBANK
            	stackingState.detailed = READY

                itemFrom = inventoryItemsTableGB[idItem]
                itemDest = bankItemsTableGB[idItem]
                stackToGuildBank()


--            elseif (itemInv.state == BANK_TO_INVENTORY or BankManager.Saved.AllBM == BANK_TO_INVENTORY) then
--                stackItems(idItem,bankItemsTableGB,inventoryItemsTableGB)
--
--
--
--            --We consider here that the item  has no specific place to go
--            elseif (BankManager.Saved["fillStacks"] == INVENTORY_TO_BANK) then
--                stackItems(idItem,inventoryItemsTableGB,bankItemsTableGB,inventoryFreeSlotsGB)
--
--
--            elseif (BankManager.Saved["fillStacks"] == BANK_TO_INVENTORY) then
--                stackItems(idItem,bankItemsTableGB,inventoryItemsTableGB)
            end
            nbItemsStackGB = nbItemsStackGB + 1
        --If the item is not present we remove it from the table to not go throught it again
        end
       	inventoryItemsTableGB[idItem] = nil
	end
end

-- Moving method :)
function moveItemsGuildBank(eventCode,slotRemoved)
	EVENT_MANAGER:UnregisterForEvent(BankManagerAppName, EVENT_GUILD_BANK_ITEM_ADDED  , moveItemsGuildBank)
	--EVENT_MANAGER:RegisterForEvent(BankManagerAppName, EVENT_GUILD_BANK_ITEM_REMOVED, bankOpening)

end