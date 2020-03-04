-----------------------
-- TEXTURE LIST
----------------------- 
TEXTURE_PROFILE_BUTTON_1		  = "BankManager/img/Profile_1.dds"
TEXTURE_PROFILE_BUTTON_PRESSED_1  = "BankManager/img/ProfilePressed_1.dds"

TEXTURE_PROFILE_BUTTON_2		  = "BankManager/img/Profile_2.dds"
TEXTURE_PROFILE_BUTTON_PRESSED_2  = "BankManager/img/ProfilePressed_2.dds"

TEXTURE_PROFILE_BUTTON_3		  = "BankManager/img/Profile_3.dds"
TEXTURE_PROFILE_BUTTON_PRESSED_3  = "BankManager/img/ProfilePressed_3.dds"

GOLD_BUTTON						  = "BankManager/img/Gold.dds"
GOLD_BUTTON_PRESSED				  = "BankManager/img/GoldPressed.dds"

FONT_TEXTURE 		  			  = "BankManager/img/font.dds"


-----------------------
-- BUTTON CODE
-----------------------
local GOLD   = {
	id      		= "_GOLD",
	tooltip 		= "goldHeader",
	texture 		= GOLD_BUTTON,
	texturePressed  = GOLD_BUTTON_PRESSED,
	func    		= function ()
			            moveGold()
			        end
}

-----------------------
-- TOOLBAR BUTTON LIST
-----------------------
local toolBarOptions ={

}


-----------------------
-- UI VARS ONLY
-----------------------
local startingOffsetXPosition = 5
local iconSize = 60

--------------------------------------------------------------------
-- ** Function which will dynamically create the profiles buttons **
-- createProfilesButtons()
--------------------------------------------------------------------
local function createProfilesButtons()
	for i=1,BankManager.Saved["profilesNb"] do
		local profile   = {
			id      		= "_PROFILE_"..i,
			tooltip 		= getProfileName(i),
			texture 		= _G["TEXTURE_PROFILE_BUTTON_"..i],
			texturePressed  = _G["TEXTURE_PROFILE_BUTTON_PRESSED_"..i],
			func    		= function ()
					            local status,err = pcall(moveItems,true,true,i)
					            if not status then
					                cleanAll(err)
					            end
					            subMenuBlackSmithingRulesBM1:SetHidden(true)
					        end
		}
		table.insert(toolBarOptions,profile)
	end
end


------------------------------------------------------------------------------------------------------
-- ** Function which create one button in the toolbar **
-- AddButton(parentWindow,id,func,texturePath,offsetY)
-- @parentWindow  : WINDOW_CONTROL, The main window the button has to be put on, here it's the toolbar
-- @id      	  : String,  		Id of the graphic element, has to be unique
-- @texturePath   : String,  		Texture path of the button
-- @offsetY       : Int,     		X offset of the button
------------------------------------------------------------------------------------------------------
local function AddButton(parentWindow,id,text,func,texturePath,texturePressed,offsetY)
    local button = WINDOW_MANAGER:CreateControl(id, parentWindow, CT_BUTTON)
    button:SetDimensions(iconSize,iconSize)
    button:SetAnchor(TOP, parentWindow, TOP, 0,offsetY)
    button:SetHandler("OnClicked", func)
    button:SetMouseEnabled(true)
    button:SetPressedTexture(texturePressed)
    button:SetNormalTexture(texturePath)

		--	TOOLTIP CONTROL
	local tooltipControl
	tooltipControl = WINDOW_MANAGER:CreateControl(id .. "_TOOLTIP",button,CT_TOOLTIP)
	tooltipControl:SetOwner(button,TOPLEFT,-string.len(text)*6,10,TOPLEFT)
	tooltipControl:AddLine(text,"ZoFontBoss",255,255,255,CENTER,MODIFY_TEXT_TYPE_NONE,CENTER, true)
	tooltipControl:SetHidden(true)
    
    -- Show the action tooltip on mouseover:
	button:SetHandler("onMouseEnter", function() tooltipControl:SetHidden(false) end)
	button:SetHandler("onMouseExit", function() tooltipControl:SetHidden(true) end)
	
end

--------------------------------------------------------------------------
-- ** Function called at the initialization of the addon to prep the UI **
-- InitializeGUI()
--------------------------------------------------------------------------
function InitializeGUI()
	BankManagerUI:SetAnchor( CENTER, GuiRoot, CENTER, 185 , -10 )
	BankManagerUI:SetWidth ( 70 )
	BankManagerUI:SetHeight( 300 )
	BankManagerUI:SetHidden(true)

	BankManagerUIBG:SetAnchor(TOPLEFT, BankManagerUI, TOPLEFT, 0, 0)
	BankManagerUIBG:SetAnchorFill(BankManagerUI)
	BankManagerUIBG:SetCenterColor( 0,0,0,.4 )
	BankManagerUIBG:SetEdgeColor( 0,0,0,100 )
	BankManagerUIBG:SetEdgeTexture("",8,8,4)
	BankManagerUIBG:SetHidden(false)
	--BankManagerUIBG:SetAlpha(0.3)

	local texture = WINDOW_MANAGER:CreateControl(BankManagerUI:GetName() .. "_TEXTURE", BankManagerUIBG, CT_TEXTURE)
	--texture:SetDimensions(512,1024)
    texture:SetAnchorFill()
    texture:SetTexture(FONT_TEXTURE)

    if BankManager.Saved["goldButtonToolbar"] then
    	GOLD.tooltip = getTranslated(GOLD.tooltip)
    	table.insert(toolBarOptions,GOLD)
    end
    createProfilesButtons()

    for k,toolBarItem in pairs(toolBarOptions) do
    	local offset = k*startingOffsetXPosition + (k-1)*iconSize
    	AddButton(BankManagerUIBG,BankManagerUIBG:GetName() .. toolBarItem.id,toolBarItem.tooltip, toolBarItem.func,toolBarItem.texture,toolBarItem.texturePressed,offset,BankManager.Saved)
    end
end

-------------------------------------------
-- ** Function which show the UI/toolbar **
-- showUI()
-------------------------------------------
function showUI()
	BankManagerUI:SetHidden(false)
end

-------------------------------------------
-- ** Function which hide the UI/toolbar **
-- hideUI()
-------------------------------------------
function hideUI()
	BankManagerUI:SetHidden(true)
end

