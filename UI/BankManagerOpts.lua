

function setReloadMessage()
    reloadUITextbox.desc:SetText("|cFF0000"..getTranslated("reloadWarning").."|r")
end

local function setlanguage(val)
    BankManager.Saved["language"] = val
    dirty = true
    setReloadMessage()
end

--Browse the language to find the key back
local function changeTranslateTable(val,key,profileNum)
    for keyTrad,tradValue in pairs(language[BankManager.Saved["language"]]) do
        if tradValue == val then
            if profileNum ~= nil then
                BankManager.Saved[key][profileNum] = keyTrad
            else    
                BankManager.Saved[key] = keyTrad
            end
            return
        end
    end
end


local function getTranslateTable(arraySendingType)
    local result = {}
    for i,v in ipairs(arraySendingType) do
        table.insert(result,getTranslated(v))
    end
    return result
end

local function getGuildList()
    local guildList = {}
    local nbGuild = GetNumGuilds()

    for i=1,nbGuild do
        table.insert(guildList,GetGuildName(GetGuildId(i)))
    end
    return guildList
end

local function setGuild(val)
    local nbGuild = GetNumGuilds()

    for i=1,nbGuild do
        guildId = GetGuildId(i)
        if val == GetGuildName(guildId) then
            BankManager.Saved["guildChoice"] = guildId
            return
        end
    end
end

local function getMaxProfilesNb()
    local profileNbList = {}
    for i=1,maxProfilesNb do
        table.insert(profileNbList,i)
    end
    return profileNbList
end

local function setProfilesNb(val)
    BankManager.Saved["profilesNb"] = val
    dirty = true
    setReloadMessage()
end


function getProfileName(numProfile)
    if BankManager.Saved["profilesNames"][numProfile] ~= nil then
        return BankManager.Saved["profilesNames"][numProfile]
    else
        return getTranslated("profile") .. "_"..numProfile
    end
end

local function getProfilesNames()
    local profilesNames = {}
    for i=1,BankManager.Saved["profilesNb"] do
        table.insert(profilesNames,getProfileName(i))
    end
    return profilesNames
end

local function setDefaultProfile(val)
    for k,v in pairs(getProfilesNames()) do
        if v == val then
            BankManager.Saved["defaultProfile"] = k
            return
        end
    end
end

local function setAllOptions(val,numProfile,arrayElements)
    for key,element in pairs(arrayElements) do
        dropmenu = ZO_ComboBox_ObjectFromContainer(GetControl(element.."#"..numProfile, "Dropdown"))
        dropmenu:SetSelectedItem(val)
        changeTranslateTable(val,element,numProfile)
    end
end

local function createSubMenuGoldRules(lam,panelID)
    lam:AddDropdown(panelID, "directionGoldTransfer", getTranslated("directionGoldTransfer"), "", getTranslateTable(directionGoldTransfer),
        function() return getTranslated(BankManager.Saved["directionGoldTransfer"]) end,
        function(val) changeTranslateTable(val,"directionGoldTransfer") end)
    
    lam:AddDropdown(panelID, "typeOfGoldTransferBM", getTranslated("typeOfGoldTransfer"), "", getTranslateTable(typeOfGoldTransfer),
        function() return getTranslated(BankManager.Saved["typeOfGoldTransfer"]) end,
        function(val)
            changeTranslateTable(val,"typeOfGoldTransfer")
            -- Check global vars
            -- [1] : goldAmount
            -- [2] : goldPercentage
            if val == getTranslated(typeOfGoldTransfer[1]) then
                amountInt:SetHidden(false)
                amountPerc:SetHidden(true)
            else
                amountInt:SetHidden(true)
                amountPerc:SetHidden(false)
            end
        end)

    amountInt = lam:AddEditBox(panelID, "amountGoldTransferIntBM", getTranslated("amountGoldTransferInt"), getTranslated("amountGoldTransferIntTooltip"), false,
        function() return BankManager.Saved["amountGoldTransferInt"] end,
        function(val) BankManager.Saved["amountGoldTransferInt"] = val end)

    amountPerc = lam:AddSlider(panelID, "amountGoldTransferPercBM", getTranslated("amountGoldTransferPerc"), getTranslated("amountGoldTransferPercTooltip"), 1, 100, 1,
        function() return BankManager.Saved["amountGoldTransferPerc"] end,
        function(val) BankManager.Saved["amountGoldTransferPerc"] = val end)

    lam:AddEditBox(panelID, "minGoldKeepBM", getTranslated("minGoldKeep"), getTranslated("minGoldKeepTooltip"), false,
        function() return BankManager.Saved["minGoldKeep"] end,
        function(val) BankManager.Saved["minGoldKeep"] = val end)

    lam:AddSlider(panelID, "timeBetweenGoldTransferBM", getTranslated("timeBetweenGoldTransfer"), getTranslated("timeBetweenGoldTransferTooltip"), 5, 300, 5,
        --because it's minute related!
        function() return BankManager.Saved["timeBetweenGoldTransfer"]/60 end,
        function(val) BankManager.Saved["timeBetweenGoldTransfer"] = val*60 end)
end

local function createSubMenuStacksRules(lam,panelID,numProfile)
    lam:AddDropdown(panelID, "fillStacks#"..numProfile, getTranslated("fillStacks"), getTranslated("fillStacksTooltip"), getTranslateTable(sendingType),
        function() return getTranslated(BankManager.Saved["fillStacks"][numProfile]) end,
        function(val) changeTranslateTable(val,"fillStacks",numProfile) end)

    lam:AddCheckbox(panelID, "transferBasedStackSize#"..numProfile,getTranslated("stackSizeCheckBox"),getTranslated("stackSizeCheckBoxTooltip"),
        function() return BankManager.Saved["stackSizeCheckBox"][numProfile] end,
        function(val) BankManager.Saved["stackSizeCheckBox"][numProfile] = val end)

    lam:AddSlider(panelID, "sliderStackSizeBM#"..numProfile, getTranslated("stackSizeSlider"), getTranslated("stackSizeSliderTooltip"), 1, 100, 1,
        function() return BankManager.Saved["stackSizeSlider"][numProfile] end,
        function(val) BankManager.Saved["stackSizeSlider"][numProfile] = val end)
end


local function createSubMenuBlackSmithingRules(lam,panelID,numProfile)
    lam:AddHeader(panelID, "blackSmithingHeaderBM#"..numProfile,  "|c3366FF" .. getTranslated("CRAFTING_TYPE_BLACKSMITHING").."|r")
    lam:AddDropdown(panelID, "setAllOptionsBlackSmithing#"..numProfile, "|cFFA200" .. getTranslated("setAllOptions") .."|r", getTranslated("setAllOptionsTooltip"), getTranslateTable(sendingType),
            function() return "-" end,
            function(val) setAllOptions(val,numProfile,blackSmithingRules) end)

    for k,craftKey in pairs(blackSmithingRules) do
        lam:AddDropdown(panelID, craftKey.."#"..numProfile, getTranslated(craftKey), "", getTranslateTable(sendingType),
        function() return getTranslated(BankManager.Saved[craftKey][numProfile]) end,
        function(val) changeTranslateTable(val,craftKey,numProfile) end)
    end
end

local function createSubMenuClothierRules(lam,panelID,numProfile)
    lam:AddHeader(panelID, "clothierHeaderBM#"..numProfile,  "|c3366FF" .. getTranslated("CRAFTING_TYPE_CLOTHIER").."|r")
    lam:AddDropdown(panelID, "setAllOptionsClothier#"..numProfile, "|cFFA200" .. getTranslated("setAllOptions") .."|r", getTranslated("setAllOptionsTooltip"), getTranslateTable(sendingType),
            function() return "-" end,
            function(val) setAllOptions(val,numProfile,clothierRules) end)

    for k,craftKey in pairs(clothierRules) do
        lam:AddDropdown(panelID, craftKey.."#"..numProfile, getTranslated(craftKey), "", getTranslateTable(sendingType),
        function() return getTranslated(BankManager.Saved[craftKey][numProfile]) end,
        function(val) changeTranslateTable(val,craftKey,numProfile) end)
    end
end

local function createSubMenuWoodWorkingRules(lam,panelID,numProfile)
    lam:AddHeader(panelID, "woodworkingHeaderBM#"..numProfile,  "|c3366FF" .. getTranslated("CRAFTING_TYPE_WOODWORKING").."|r")
    lam:AddDropdown(panelID, "setAllOptionsWoodWorking#"..numProfile, "|cFFA200" .. getTranslated("setAllOptions") .."|r", getTranslated("setAllOptionsTooltip"), getTranslateTable(sendingType),
            function() return "-" end,
            function(val) setAllOptions(val,numProfile,woodWorkingRules) end)

    for k,craftKey in pairs(woodWorkingRules) do
        lam:AddDropdown(panelID, craftKey.."#"..numProfile, getTranslated(craftKey), "", getTranslateTable(sendingType),
        function() return getTranslated(BankManager.Saved[craftKey][numProfile]) end,
        function(val) changeTranslateTable(val,craftKey,numProfile) end)
    end
end

local function createSubMenuProvisioningRules(lam,panelID,numProfile)
    lam:AddHeader(panelID, "provisioningHeaderBM#"..numProfile,  "|c3366FF" .. getTranslated("CRAFTING_TYPE_PROVISIONING").."|r")
    lam:AddDropdown(panelID, "setAllOptionsProvisioning#"..numProfile, "|cFFA200" .. getTranslated("setAllOptions") .."|r", getTranslated("setAllOptionsTooltip"), getTranslateTable(sendingType),
            function() return "-" end,
            function(val) setAllOptions(val,numProfile,provisioningRules) end)

    for k,craftKey in pairs(provisioningRules) do
        lam:AddDropdown(panelID, craftKey.."#"..numProfile, getTranslated(craftKey), "", getTranslateTable(sendingType),
        function() return getTranslated(BankManager.Saved[craftKey][numProfile]) end,
        function(val) changeTranslateTable(val,craftKey,numProfile) end)
    end
end

local function createSubMenuEnchantingRules(lam,panelID,numProfile)
    lam:AddHeader(panelID, "enchantingHeaderBM#"..numProfile,  "|c3366FF" .. getTranslated("CRAFTING_TYPE_ENCHANTING").."|r")
    lam:AddDropdown(panelID, "setAllOptionsEnchanting#"..numProfile, "|cFFA200" .. getTranslated("setAllOptions") .."|r", getTranslated("setAllOptionsTooltip"), getTranslateTable(sendingType),
            function() return "-" end,
            function(val) setAllOptions(val,numProfile,enchantingRules) end)

    for k,craftKey in pairs(enchantingRules) do
        lam:AddDropdown(panelID, craftKey.."#"..numProfile, getTranslated(craftKey), "", getTranslateTable(sendingType),
        function() return getTranslated(BankManager.Saved[craftKey][numProfile]) end,
        function(val) changeTranslateTable(val,craftKey,numProfile) end)
    end
end

local function createSubMenuAlchemyRules(lam,panelID,numProfile)
    lam:AddHeader(panelID, "alchemyHeaderBM#"..numProfile,  "|c3366FF" .. getTranslated("CRAFTING_TYPE_ALCHEMY").."|r")
    lam:AddDropdown(panelID, "setAllOptionsAlchemy#"..numProfile, "|cFFA200" .. getTranslated("setAllOptions") .."|r", getTranslated("setAllOptionsTooltip"), getTranslateTable(sendingType),
            function() return "-" end,
            function(val) setAllOptions(val,numProfile,alchemyRules) end)

    for k,craftKey in pairs(alchemyRules) do
        lam:AddDropdown(panelID, craftKey.."#"..numProfile, getTranslated(craftKey), "", getTranslateTable(sendingType),
        function() return getTranslated(BankManager.Saved[craftKey][numProfile]) end,
        function(val) changeTranslateTable(val,craftKey,numProfile) end)
    end
end


local function createSubMenuOthersItemsRules(lam,panelID,numProfile)
    --CRAFT MODE
    lam:AddHeader(panelID, "othersHeaderBM#"..numProfile,  "|c3366FF" .. getTranslated("othersHeader").."|r")
    lam:AddDropdown(panelID, "setAllOptionsOthers#"..numProfile, "|cFFA200" .. getTranslated("setAllOptions") .."|r", getTranslated("setAllOptionsTooltip"), getTranslateTable(sendingType),
            function() return "-" end,
            function(val) setAllOptions(val,numProfile,othersElementsRules) end)

    for k,othersKey in pairs(othersElementsRules) do
        lam:AddDropdown(panelID, othersKey.."#"..numProfile, getTranslated(othersKey), "", getTranslateTable(sendingType),
        function() return getTranslated(BankManager.Saved[othersKey][numProfile]) end,
        function(val) changeTranslateTable(val,othersKey,numProfile) end)
    end
end

function options()
    local textCheckBox = ""
    local craftName, textCheckBox, othersKey
    local LAM = LibStub("LibAddonMenu-1.0")
    optionsPanel = LAM:CreateControlPanel("Bank Manager", "|c3366FFBank|r Manager")
    LAM:AddHeader(optionsPanel, "versionBM", "|c3366FF" .. getTranslated("version").."|r:" .. currentVersion)
    LAM:AddHeader(optionsPanel, "headerBM", "|c3366FF" .. getTranslated("title").."|r" )

    reloadUITextbox = LAM:AddDescription(optionsPanel, "ReloadRequiredBM", "")

    LAM:AddDropdown(optionsPanel, "languageBM", getTranslated("dropDownLanguageText"), getTranslated("dropDownLanguageTooltip"), languages,
            function() return BankManager.Saved["language"] end,
            setlanguage,
            true , getTranslated("reloadWarning"))
    
    LAM:AddCheckbox(optionsPanel, "toolBarDisplayedBM", getTranslated("toolBarDisplayed"), getTranslated("toolBarDisplayedTooltip"),
            function() return BankManager.Saved["toolBarDisplayed"] end,
            function(val) BankManager.Saved["toolBarDisplayed"] = val end)
    
    LAM:AddDropdown(optionsPanel, "bankChoice", "|cFF0000" .. getTranslated("bankChoice").."|r", getTranslated("bankChoiceTooltip"), getTranslateTable(banks),
            function() return getTranslated(BankManager.Saved["bankChoice"]) end,
            function(val) changeTranslateTable(val,"bankChoice") end,
            true,"NOT WORKING")

    LAM:AddDropdown(optionsPanel, "guildChoice", getTranslated("guildChoice"), getTranslated("guildChoice"), getGuildList(),
            function() return GetGuildName(BankManager.Saved["guildChoice"]) end,
            setGuild)

    LAM:AddCheckbox(optionsPanel, "autoTransfertBM", getTranslated("autoTransfert"), getTranslated("autoTransfertTooltip"),
            function() return BankManager.Saved["autoTransfert"] end,
            function(val) BankManager.Saved["autoTransfert"] = val end)


    LAM:AddCheckbox(optionsPanel, "spamChatBM", getTranslated("spamChatText"), getTranslated("spamChatTooltip"),
            function() return BankManager.Saved["spamChat"] end,
            function(val) BankManager.Saved["spamChat"] = val end)
    
    LAM:AddCheckbox(optionsPanel, "spamChatAllBM", getTranslated("spamChatAllText"), getTranslated("spamChatAllTextTooltip"),
            function() return BankManager.Saved["spamChatAll"] end,
            function(val) BankManager.Saved["spamChatAll"] = val end)

    LAM:AddSlider(optionsPanel, "delayTransferBM", getTranslated("delayTransfer"), getTranslated("delayTransferTooltip"), 0, 500, 25,
        function() return BankManager.Saved["delayTransfer"] end,
        function(val) BankManager.Saved["delayTransfer"] = val end)

    LAM:AddDropdown(optionsPanel, "profilesNbBM", getTranslated("profilesNb"), getTranslated("profilesNbTooltip"), getMaxProfilesNb(),
            function() return BankManager.Saved["profilesNb"] end,
            setProfilesNb,
            true , getTranslated("reloadWarning"))

    --Small note : if we decrease the number of avalaible profils we must check that the default profil name is not one of the unaccessible profils
    LAM:AddDropdown(optionsPanel, "defaultProfileBM", getTranslated("defaultProfile"), getTranslated("defaultProfileTooltip"), getProfilesNames(),
            function() return getProfileName(tonumber(BankManager.Saved["defaultProfile"]) <= tonumber(BankManager.Saved["profilesNb"]) and BankManager.Saved["defaultProfile"] or 1) end,
            setDefaultProfile)

    -- GOLD MODE
    LAM:AddHeader(optionsPanel, "headerGoldBM", "|c3366FF" .. getTranslated("goldHeader").."|r" )
    LAM:AddCheckbox(optionsPanel, "autoGoldTransferBM", getTranslated("autoGoldTransfer"), getTranslated("autoGoldTransferTooltip"),
            function() return BankManager.Saved["autoGoldTransfer"] end,
            function(val) BankManager.Saved["autoGoldTransfer"] = val end)

    LAM:AddCheckbox(optionsPanel, "goldButtonToolbarBM", getTranslated("goldButtonToolbar"), "",
            function() return BankManager.Saved["goldButtonToolbar"] end,
            function(val) 
                BankManager.Saved["goldButtonToolbar"] = val
                dirty = true
                setReloadMessage()
            end,
            true , getTranslated("reloadWarning"))

    local subMenuGoldRules = LAM:AddSubMenu(optionsPanel, "subMenuGoldRulesBM", getTranslated("subMenuGoldRules"), "")
    createSubMenuGoldRules(LAM, subMenuGoldRules)


    --Profile Mode !
    for i=1,BankManager.Saved["profilesNb"] do
        LAM:AddHeader(optionsPanel, "headerProfilesBM#"..i, "|c3366FF"..getProfileName(i).."|r")
        LAM:AddEditBox(optionsPanel, "editBoxProfilesBM#"..i, getTranslated("profileName"), getTranslated("profileNameTooltip"), false,
            function() return getProfileName(i) end,
            function(val)
                if val ~= BankManager.Saved["profilesNames"][i] then
                    BankManager.Saved["profilesNames"][i] = val
                    dirty = true
                    setReloadMessage()
                end
            end,
            true , getTranslated("reloadWarning"))

        LAM:AddDropdown(optionsPanel, "AllBM#"..i, getTranslated("AllBM"), "", getTranslateTable(sendingType),
            function() return getTranslated(BankManager.Saved["AllBM"][i]) end,
            function(val) changeTranslateTable(val,"AllBM",i) end)

        ----------------------------------------------------------
        ---------------------- STACK BUTTON ----------------------
        ----------------------------------------------------------
        local subMenuStacksRules = LAM:AddSubMenu(optionsPanel, "subMenuStacksRulesBM#"..i, getTranslated("subMenuStacksRules"), getTranslated("subMenuStacksRulesTooltip"))
        createSubMenuStacksRules(LAM, subMenuStacksRules,i)

        ----------------------------------------------------------
        ---------------------- SMITHING BUTTON -------------------
        ----------------------------------------------------------
        subMenuBlackSmithingRules = LAM:AddSubMenu(optionsPanel, "subMenuBlackSmithingRulesBM"..i, getTranslated("CRAFTING_TYPE_BLACKSMITHING"), "")
        createSubMenuBlackSmithingRules(LAM, subMenuBlackSmithingRules,i)

        ----------------------------------------------------------
        ---------------------- CLOTHIER BUTTON -------------------
        ----------------------------------------------------------
        local subMenuClothierRules = LAM:AddSubMenu(optionsPanel, "subMenuClothierRulesBM#"..i, getTranslated("CRAFTING_TYPE_CLOTHIER"), "")
        createSubMenuClothierRules(LAM, subMenuClothierRules,i)

        ----------------------------------------------------------
        -------------------- WOODWORKING BUTTON ------------------
        ----------------------------------------------------------
        local subMenuWoodWorkingRules = LAM:AddSubMenu(optionsPanel, "subMenuWoodWorkingRulesBM#"..i, getTranslated("CRAFTING_TYPE_WOODWORKING"), "")
        createSubMenuWoodWorkingRules(LAM, subMenuWoodWorkingRules,i)

        ----------------------------------------------------------
        -------------------- PROVISIONING BUTTON -----------------
        ----------------------------------------------------------
        local subMenuProvisioningRules = LAM:AddSubMenu(optionsPanel, "subMenuProvisioningRulesBM#"..i, getTranslated("CRAFTING_TYPE_PROVISIONING"), "")
        createSubMenuProvisioningRules(LAM, subMenuProvisioningRules,i)

        ----------------------------------------------------------
        ---------------------- ENCHANTING BUTTON -----------------
        ----------------------------------------------------------
        local subMenuEnchantingRules = LAM:AddSubMenu(optionsPanel, "subMenuEnchantingRulesBM#"..i, getTranslated("CRAFTING_TYPE_ENCHANTING"), "")
        createSubMenuEnchantingRules(LAM, subMenuEnchantingRules,i)

        ----------------------------------------------------------
        ---------------------- ALCHEMY BUTTON --------------------
        ----------------------------------------------------------
        local subMenuAlchemyRules = LAM:AddSubMenu(optionsPanel, "subMenuAlchemyRulesBM#"..i, getTranslated("CRAFTING_TYPE_ALCHEMY"), "")
        createSubMenuAlchemyRules(LAM, subMenuAlchemyRules,i)

        ----------------------------------------------------------
        ---------------------- ALCHEMY BUTTON --------------------
        ----------------------------------------------------------
        local subMenuOthersItemsRules = LAM:AddSubMenu(optionsPanel, "subMenuOthersItemsRulesBM#"..i, getTranslated("othersHeader"), "")
        createSubMenuOthersItemsRules(LAM, subMenuOthersItemsRules,i)

    end
end