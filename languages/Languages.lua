

--langage var
language = {}

-----------------------------------------------------------------------
-- ** Function which will return the corresponding string translated **
-- getTranslated(text)
-- @text : String, The text ID in the localization array
-----------------------------------------------------------------------
function getTranslated(text)
    return language[BankManager.Saved["language"]][text]
end

------------------------------------------------------------
-- ** Function that will detect the langage of the user **
-- getBaseLanguage()
-- Thanks to FTC for the discovery of this creative technic!
------------------------------------------------------------
function getBaseLanguage()
	local errorString = GetErrorString(16)
	if (errorString == "Ziel aus dem Gleichgewicht") then
		return "Deutsch"
	elseif (errorString == "Cible \195\169tourdie") then
		return "Francais"
	else
		return "English"
	end
end 