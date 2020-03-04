--------------------------------------------------------------------------------------
-- ** Function that transfor RGB table into HEX - Thanks to marceloCodget on Github **
-- rgbToHex(rgb)
-- @rgb     : Table,  table like {0.255, 0.100, 0.020}
-- @return  : String, String of the Hex value
----------------------------------------------------------------------------------
function rgbToHex(rgb)
    local hexadecimal = ''
    for key, value in pairs(rgb) do
        value = value * 255
        local hex = ''
        while(value > 0)do
            local index = math.fmod(value, 16) + 1
            value = math.floor(value / 16)
            hex = string.sub('0123456789ABCDEF', index, index) .. hex           
        end
        if(string.len(hex) == 0)then
            hex = '00'
        elseif(string.len(hex) == 1)then
            hex = '0' .. hex
        end
        hexadecimal = hexadecimal .. hex
    end
    return hexadecimal
end

----------------------------------------------------------------------------------
-- ** Function that display information in the chat about moving/stacking items **
-- displayChat(itemName, quantity, moved)
-- @itemName    : String,  Name of the item
-- @quantity    : Int,     Quantity of the item
-- @moved       : Boolean, If the item had been moved or stacked
-- @rgb         : Table,   Table of RGB colors
----------------------------------------------------------------------------------
function displayChat(itemName, quantity, moved, rgb)
    if(counterMessageChat <= limitMessageChat) then
        local startString,endString = string.find(itemName,"%^")
        local ending                = ""
        if startString ~= nil then
            itemName = string.sub(itemName,0,startString-1)
        end
        if BankManager.Saved["spamChat"] then
            if moved then
                ending = getTranslated("itemsMoved")
            else
                ending = getTranslated("itemsStacked")
            end
            d("|c".. rgbToHex(rgb) .. "[".. itemName .. "]|r " .. "(x" .. quantity .. ") " .. ending)
        end
    end
    counterMessageChat = counterMessageChat +1
end