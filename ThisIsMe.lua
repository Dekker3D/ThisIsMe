-----------------------------------------------------------------------------------------------
-- Client Lua Script for ThisIsMe
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Unit"
require "ICComm"
require "ICCommLib"
require "GameLib"
require "HousingLib"
require "CombatFloater"
 
-----------------------------------------------------------------------------------------------
-- ThisIsMe Module Definition
-----------------------------------------------------------------------------------------------
local ThisIsMe = {}
local LibCommExt = nil
local ProfileWindow = {}
local ThisIsMeInst = nil

local Major, Minor, Patch, Suffix = 0, 3, 7, 2 -- 10 is j
local YOURADDON_CURRENT_VERSION = string.format("%d.%d.%d", Major, Minor, Patch)

local Locale = nil
local GeminiLocale = nil
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressed")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")
local redErrorText = ApolloColor.new("AddonError")
local defaultText = ApolloColor.new("UI_WindowTextDefault")
local listDefault = "CRB_Basekit:kitInnerFrame_MetalGold_FrameBright2"
local listBright = "CRB_Basekit:kitInnerFrame_MetalGold_FrameBright"
local listDull = "CRB_Basekit:kitInnerFrame_MetalGold_FrameDull"
local portraitDominion = ApolloColor.new(2, 0.8, 0.7, 1)
local portraitExile = ApolloColor.new(1.0, 0.8, 1.3, 1)
local portraitNeutral = ApolloColor.new(1.2, 0.9, 1, 1)
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function ThisIsMe:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.profileListEntries = {} -- keep track of all the list items
	o.characterProfiles = {}
	o.sortedCharacterProfiles = {}
	
	o.seenEveryone = false
	
	o.sortMode = 1
	o.sortInvert = false
	o.sortByOnline = true
	
	o.portraits = {
		["3"]={"charactercreate:sprCharC_Finalize_RaceAurinM", "charactercreate:sprCharC_Finalize_RaceAurinF"},
		["5"]={"charactercreate:sprCharC_Finalize_RaceDrakenM", "charactercreate:sprCharC_Finalize_RaceDrakenF"},
		["6"]={"charactercreate:sprCharC_Finalize_RaceGranokM", "charactercreate:sprCharC_Finalize_RaceGranokF"},
		["7"]={"charactercreate:sprCharC_Finalize_RaceExileM", "charactercreate:sprCharC_Finalize_RaceExileF"},
		["8"]={"charactercreate:sprCharC_Finalize_RaceMechariM", "charactercreate:sprCharC_Finalize_RaceMechariF"},
		["9"]={"charactercreate:sprCharC_Finalize_RaceMordeshM", "charactercreate:sprCharC_Finalize_RaceMordeshF"},
		["10"]={"charactercreate:sprCharC_Finalize_RaceDomM", "charactercreate:sprCharC_Finalize_RaceDomF"},
		["11"]={"charactercreate:sprCharC_Finalize_RaceDomM", "charactercreate:sprCharC_Finalize_RaceDomF"}
	}
	o.portraitUnknown = "charactercreate:sprCharC_Finalize_SkillLevel1"
	o.portraitChua = "charactercreate:sprCharC_Finalize_RaceChua"
	
	o.Comm = nil
	o.channel = "__TIM__"
	
	o.sendTimer = nil
	
	o.errorMessages = {}
	o.errorBuffer = true
	
	o.profileEdit = false
	o.profileCharacter = nil
	o.editedProfile = {}
	
	o.fullyLoaded = false
	
	o.enableUpdateButton = true
	
	o.messageCharacterLimit = 80
	o.messagesPerSecond = 5
	
	o.protocolVersionMin = 4
	o.protocolVersionMax = 5
	
	o.profileRequestBuffer = {}
	
	o.defaultProtocolVersion = 4
	
	o.options = {}
	o.options.logLevel = 0
	o.options.debugMode = false
	o.options.protocolVersion = o.defaultProtocolVersion
	o.options.useDefaultProtocolVersion = true
	
	o.dropdownTextMap = {
		"Name",
		"Age",
		"Race",
		"Gender",
		"EyeColour",
		"BodyType",
		"Length",
		"HairColour",
		"HairStreaks",
		"HairStyle",
		"HairLength",
		"HairQuality",
		"TailSize",
		"TailState",
		"TailDecoration",
		"Tattoos",
		"Scars",
		"Talents",
		"Disabilities",
		"FacialHair"
	}
	
	for k, v in pairs(o.dropdownTextMap) do
		o.dropdownTextMap[v] = k
	end
	
	o.TargetFrame = nil
	
    return o
end

-----------------------------------------------------------------------------------------------
-- Initialization Functions
-----------------------------------------------------------------------------------------------

function ThisIsMe:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"Gemini:Timer-1.0",
		"LibCommExt-1.0"
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function ThisIsMe:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("ThisIsMe.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	GeminiTimer = Apollo.GetPackage("Gemini:Timer-1.0").tPackage
	GeminiTimer:Embed(self)
	LibCommExt = Apollo.GetPackage("LibCommExt-1.0").tPackage
	GeminiLocale = Apollo.GetPackage("Gemini:Locale-1.0").tPackage
	Locale = GeminiLocale:GetLocale("ThisIsMe", true)
	self:LoadEntries()
end

function ThisIsMe:OnDocLoaded()
	self.errorBuffer = false
	if self.errorMessages ~= nil then
		for k, v in pairs(self.errorMessages) do
			self:Print(0, v)
		end
	end
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "ProfileList", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window.")
			return
		end
		-- item list
		self.wndProfileList = self.wndMain:FindChild("ItemList")
	    self.wndMain:Show(false, true)

		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("tim", "OnThisIsMeOn", self)
		Apollo.RegisterSlashCommand("timvi", "OnTestCommand", self)
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
		self:OnInterfaceMenuListHasLoaded()
		Apollo.RegisterEventHandler("ToggleMyAddon", "OnThisIsMeOn", self)
		Apollo.RegisterEventHandler("TargetUnitChanged", "OnTargetUnitChanged", self)

		self.wndProfile = Apollo.LoadForm(self.xmlDoc, "Profile", nil, self)
		if self.wndProfile == nil then
			Apollo.AddAddonErrorText(self, "Could not load the profile window.")
			return
		end
	    self.wndProfile:Show(false, true)
		self.wndProfileContainer = self.wndProfile:FindChild("ListContainer")

		self.wndOptions = Apollo.LoadForm(self.xmlDoc, "OptionsWindow", nil, self)
		if self.wndOptions == nil then
			Apollo.AddAddonErrorText(self, "Could not load the options window.")
			return
		end
		GeminiLocale:TranslateWindow(Locale, self.wndOptions)
		self.wndOptions:Show(false, true)
	end
	self.startupTimer = ApolloTimer.Create(5, false, "CheckComms", self)
	self.dataCheckTimer = ApolloTimer.Create(1, true, "CheckData", self)
	self.MyHeartbeatTimer = ApolloTimer.Create(60, true, "sendHeartbeatMessage", self)
end

function ThisIsMe:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "This Is Me", {"ToggleMyAddon", "", "CRB_HUDAlerts:sprAlert_CallBase"})
	Event_FireGenericEvent("OneVersion_ReportAddonInfo", "This Is Me", Major, Minor, Patch, Suffix)
end

function ThisIsMe:ConnectToTargetFrame()
	if self.TargetFrameAddon == nil then
		self.VanillaFrame = Apollo.GetAddon("TargetFrame")
		self.TargetFrameAddon = self.VanillaFrame
	end
	if self.TargetFrameAddon == nil then
		self.KuronaFrames = Apollo.GetAddon("KuronaFrames")
		self.TargetFrameAddon = self.KuronaFrames
	end
	if self.TargetFrameAddon == nil then
		self.ForgeFrames = Apollo.GetAddon("ForgeUI_UnitFrames")
		self.TargetFrameAddon = self.ForgeFrames
	end
	if self.TargetFrameButton then
		self.TargetFrameButton:Destroy()
		self.TargetFrameButton = nil
	end
	if self.CurrentTarget ~= nil and self.CurrentTarget:IsACharacter() and self.characterProfiles[self.CurrentTarget:GetName()] ~= nil then
		if self.VanillaFrame then
			local targetFrame = self.VanillaFrame.luaTargetFrame
			if targetFrame then
				targetFrame = targetFrame.wndLargeFrame
				if targetFrame then
					self.TargetFrame = targetFrame
					self.TargetFrameButton = Apollo.LoadForm(self.xmlDoc, "TIMProfileButton", targetFrame, self)
				end
			end
		elseif self.KuronaFrames then
			local targetFrame = self.KuronaFrames.targetFrame
			if targetFrame then
				self.TargetFrameButton = Apollo.LoadForm(self.xmlDoc, "TIMKuronaButton", targetFrame, self)
			end
		elseif self.ForgeFrames then
			local targetFrame = self.ForgeFrames.wndTargetFrame
			if targetFrame then
				self:Print(1, "Forge!")
				self.TargetFrameButton = Apollo.LoadForm(self.xmlDoc, "TIMForgeButton", targetFrame, self)
			end
		end
	end
end

function ThisIsMe:OnTargetUnitChanged(targetID)
	self.CurrentTarget = targetID
	self:ConnectToTargetFrame()
end

function ThisIsMe:OpenProfileViaTargetFrame()
	if self.CurrentTarget ~= nil then
		self.profileEdit = false
		self.profileCharacter = self.CurrentTarget:GetName()
		self:OpenProfileView()
	end
end

function ThisIsMe:LoadEntries()
	self.hairStyle = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Plain"],
		Locale["Pig-tails"],
		Locale["Pony-tail"],
		Locale["Mohawk"],
		Locale["Dreadlocks"],
		Locale["Pompadour"],
		Locale["Mullet"],
		Locale["Comb-over"]
	}
	
	self.hairLength = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Bald"],
		Locale["Short/Small"],
		Locale["Shoulder-Length/Medium"],
		Locale["Waist-Length/Large"],
		Locale["Hip-Length/Huge"]
	}
	
	self.hairQuality = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Lustrous"],
		Locale["Glossy"],
		Locale["Dull"],
		Locale["Gelled"],
		Locale["Styled"],
		Locale["Well Kept"],
		Locale["Neatly Combed"],
		Locale["Plain"],
		Locale["Messy"],
		Locale["Untamed"],
		Locale["Leafy"],
		Locale["Unclean"],
		Locale["Ragged"],
		Locale["Very Curly"],
		Locale["Curly"],
		Locale["Spikey"],
		Locale["Braided"],
		Locale["Crystalline"],
		Locale["Full"],
		Locale["Thinning"]
	}
	
	self.hairColour = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Gray"]
	}
	
	self.tailSize = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Long"],
		Locale["Short"],
		Locale["Cut Off"],
		Locale["Cut Short"],
		Locale["Thick"],
		Locale["Muscular"],
		Locale["Thin"],
		Locale["Ratty"]
	}
	
	self.tailState = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Fluffy"],
		Locale["Gloriously Fluffy"],
		Locale["Bald"],
		Locale["Patchy"],
		Locale["Scaled"],
		Locale["Leathery"],
		Locale["Cracked"],
		Locale["Dirty"]
	}
	
	self.tailDecoration = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Circlet/Band"],
		Locale["Pierced - Loops"],
		Locale["Pierced - Studs"]
	}
		
	self.genders = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Male"],
		Locale["Female"],
		Locale["Transmale"],
		Locale["Transfemale"],
		Locale["Genderless"]
	}
	
	self.races = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Aurin"],
		Locale["Chua"],
		Locale["Draken"],
		Locale["Granok"],
		Locale["Human"],
		Locale["Mechari"],
		Locale["Mordesh"],
		Locale["Cassian Highborn"],
		Locale["Cassian Lowborn"],
		Locale["Luminai"]
	}
	
	self.ages = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Baby"],
		Locale["Child"],
		Locale["Teen"],
		Locale["Young Adult"],
		Locale["Adult"],
		Locale["Middle-Aged"],
		Locale["Old"],
		Locale["Ancient"],
		Locale["Ageless"]
	}
	
	self.bodyTypes = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Skin And Bones"],
		Locale["Slim"],
		Locale["Average"],
		Locale["Thick"],
		Locale["Chunky"],
		Locale["Wirey"],
		Locale["Toned"],
		Locale["Athletic"],
		Locale["Muscular"],
		Locale["Top-Heavy"],
		Locale["Pear-Shaped"],
		Locale["Perfect Hourglass"],
		Locale["Barrel-Chested"]
	}
	
	self.heights = {
		Locale["N/A"],
		Locale["Other"],
		Locale["Tiny"],
		Locale["Short"],
		Locale["Below Average"],
		Locale["Average"],
		Locale["Above Average"],
		Locale["Tall"],
		Locale["Gargantuan"]
	}
	
	self.sortModes = {
		Locale["Newest First"],
		Locale["By Character Name"],
		Locale["By Customized Name"]
	}
end

---------------------------------------------------------------------------------------------------
-- Utility Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:Print(logLevel, strToPrint)
	if strToPrint ~= nil and type(logLevel) == "number" and logLevel <= self.options.logLevel and self.options.debugMode == true then
		if self.errorBuffer then
			table.insert(self.errorMessages, strToPrint)
		else
		 	Print("TIM: " .. strToPrint)
		end
	end
end

function ThisIsMe:PrintTable(logLevel, table)
	for k, v in pairs(table) do
		if type(v) == "table" then self:Print(logLevel, k .. ": table")
		elseif type(v) == "userdata" then self:Print(logLevel, k .. ": userdata")
		elseif type(v) == "boolean" then self:Print(logLevel, k .. ": boolean")
		else self:Print(logLevel, k .. ": " .. v) end
	end
end

function ThisIsMe:NilCheckString(name, value)
	if value ~= nil then
		return name .. " is not nil"
	end
	return name .. " is nil"
end

function ThisIsMe:getCharAt(input, num)
	if input == nil or num == nil or num < 0 then
		return nil
	end
	if input:len() <= num then
		return nil
	end
	return input:sub(num, num)
end

function ThisIsMe:GetRaceEnum(unit)
	if unit ~= nil then
		local unitRace = unit:GetRaceId()
		local race = nil
		if unitRace == GameLib.CodeEnumRace.Aurin then race = 3; self.currentFaction = "E"
		elseif unitRace == GameLib.CodeEnumRace.Chua then race = 4; self.currentFaction = "D"
		elseif unitRace == GameLib.CodeEnumRace.Draken then race = 5; self.currentFaction = "D"
		elseif unitRace == GameLib.CodeEnumRace.Granok then race = 6; self.currentFaction = "E"
		elseif unitRace == GameLib.CodeEnumRace.Human then race = 7
		elseif unitRace == GameLib.CodeEnumRace.Mechari then race = 8; self.currentFaction = "D"
		elseif unitRace == GameLib.CodeEnumRace.Mordesh then race = 9; self.currentFaction = "E"
		end
		return race
	end
end

function ThisIsMe:GetGenderEnum(unit)
	if unit ~= nil then
		local unitGender = unit:GetGender()
		local gender = nil
		if unit:GetRaceId() == GameLib.CodeEnumRace.Chua then gender = 7
		elseif unitGender == Unit.CodeEnumGender.Male then gender = 3
		elseif unitGender == Unit.CodeEnumGender.Female then gender = 4
		else gender = 1 end
		return gender
	end
end

function ThisIsMe:Clamp(num, min, max)
	if num < min then return min end
	if num > max then return max end
	return num
end

function ThisIsMe:GetWindowAbsolutePosition(window)
	local position = window:GetClientRect() -- might want to change this to GetRect too. Otherwise I'm just gonna get rect.
	local x = position.nLeft
	local y = position.nTop
	local newWindow = window:GetParent()
	local left, top, right, bottom
	while newWindow ~= nil do
		left, top, right, bottom = newWindow:GetRect()
		x = x + left
		y = y + top
		newWindow = newWindow:GetParent()
	end
	return {nLeft = x, nTop = y, nRight = x + position.nWidth, nBottom = y + position.nHeight, nWidth = position.nWidth, nHeight = position.nHeight}
end

function ThisIsMe:TableIterator(myTable)
	local orderedIndex = {}
	for key in pairs(myTable) do
		table.insert(orderedIndex, key)
	end
	table.sort(orderedIndex)
	return orderedIndex
end

function ThisIsMe:sipairs(myTable)
	local sorted = {}
	for n in pairs(myTable) do table.insert(sorted, n) end
	table.sort(sorted, f)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if sorted[i] == nil then return nil
		else return sorted[i], myTable[sorted[i]]
		end
	end
	return iter
end

---------------------------------------------------------------------------------------------------
-- Profile Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:Unit()
	if self.currentUnit == nil then
		self.currentUnit = GameLib.GetPlayerUnit()
		if self.currentUnit ~= nil then
			self:CheckData() -- we've got new data to check
		end
	end
	return self.currentUnit
end

function ThisIsMe:Character()
	if self.currentCharacter == nil and self:Unit() ~= nil then
		self.currentCharacter = self:Unit():GetName()
		if self.currentCharacter ~= nil then
			self:CheckData() -- we've got new data to check
		end
	end
	return self.currentCharacter
end

function ThisIsMe:Faction()
	if (self.currentFaction == nil or self.currentFaction == "?") and self:Unit() ~= nil then
		local factionNum = self:Unit():GetFaction()
		if factionNum  == 166 then
			self.currentFaction = "D"
		elseif factionNum  == 167 then
			self.currentFaction = "E"
		else
			self:Print(9, "Faction unknown: " .. (factionNum or "nil"))
			return "?"
		end
		if self.currentFaction ~= nil then
			self:CheckData() -- we've got new data to check
		end
	end
	return self.currentFaction
end

function ThisIsMe:Profile()
	if self.currentProfile == nil and self:Character() ~= nil then
		self.currentProfile = self.characterProfiles[self:Character()]
		if self.currentProfile ~= nil then
			self:CheckData() -- we've got new data to check
		end
	end
	return self.currentProfile
end

function ThisIsMe:CheckData()
	self:Profile() -- just try to get all the data we can, while we're at it.
		
	if self.profileEmptyCheck ~= true and self:Profile() ~= nil then
		if next(self.currentProfile) == nil or self.currentProfile.Version == nil then
			self.characterProfiles[self:Character()] = self:GetProfileDefaults(self:Character(), self:Unit())
			self.characterProfiles[self:Character()].OwnProfile = true
			self:Print(5, "Profile was empty/unusable; resetting.")
		else
			self:Print(9, "Profile found; Name: " .. self.currentCharacter)
		end
		self.profileEmptyCheck = true
		self:Print(9, "Checked profile for content.")
	end
	
	if self.dataLoadedCheck ~= true and self.dataLoaded == true and self.currentCharacter ~= nil then
		if next(self.characterProfiles) == nil then
			self.characterProfiles[self:Character()] = self:GetProfileDefaults(self:Character(), self:Unit())
		end
		for k, v in self:sipairs(self.characterProfiles) do
			self:UpdateOnlineStatus(k)
		end
		self.dataLoadedCheck = true
		self:Print(9, "Checked loaded data for content.")
	end
	
	if self.commCheck ~= true and self.Comm ~= nil and self.Comm:IsReady() and self.currentFaction ~= nil and self.currentFaction ~= "?" and self.currentCharacter ~= nil then
		self.commCheck = true
		if not self.announcedSelf then
			self:SendPresenceMessage()
		end
	end
	
	if not self.fullyLoaded and self.profileEmptyCheck and self.commCheck and self.dataLoaded and self.dataLoadedCheck then
		self.fullyLoaded = true
		self:Print(1, "TIM fully checked and loaded!")
		if self.dataCheckTimer ~= nil then
			self.dataCheckTimer:Stop()
			self.dataCheckTimer = nil
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Generic UI Functions
-----------------------------------------------------------------------------------------------

function ThisIsMe:CloseAllWindows()
	self.wndMain:Close()
	self.wndOptions:Close()
	self.wndProfile:Close()
end

-- on SlashCommand "/tim"
function ThisIsMe:OnThisIsMeOn()
	self:OpenProfileList()
end

function ThisIsMe:OnClose( wndHandler, wndControl, eMouseButton )
	self:CloseAllWindows()
end

-----------------------------------------------------------------------------------------------
-- Profile List Functions
-----------------------------------------------------------------------------------------------
function ThisIsMe:OpenProfileList()
	self:CloseAllWindows()
	self.wndMain:Invoke()
	
	-- populate the item list
	self:PopulateProfileList()
	if self.seenEveryone ~= true then
		self:SendPresenceRequestMessage()
	end
end

function ThisIsMe:OnEditProfileClick()
	self.profileEdit = true
	self.profileCharacter = self:Character()
	self:ApplyDefaultTextMap(self.profileCharacter)
	self:OpenProfileView()
end

function ThisIsMe:OpenProfileView()
	if self.profileEdit then self.profileCharacter = self:Character() end
	self:CloseAllWindows()
	self.wndProfile:Invoke()
	local Title = self.wndProfile:FindChild("Title")
	if Title ~= nil then
		Title:SetText(self:GetProfileName(self.profileCharacter))
	end
	local okButton = self.wndProfile:FindChild("OkButton")
	if okButton then
		okButton:Show(self.profileEdit, true)
	end
	local cancelButton = self.wndProfile:FindChild("CancelButton")
	if cancelButton then
		if self.profileEdit then
			cancelButton:SetText("Cancel")
		else
			cancelButton:SetText("Close")
		end
	end
	self:PopulateProfileView()
end

-- when the Profile's Cancel button is clicked
function ThisIsMe:OnProfileCancel()
	self:OpenProfileList()
end
-- when the Profile's OK button is clicked
function ThisIsMe:OnProfileOK()
	if self.profileEdit == true and  self.editedProfile ~= nil and not self:CompareTableEqualBoth(self.characterProfiles[self:Character()], self.editedProfile) then
	self.editedProfile.OwnProfile = true
		self.characterProfiles[self:Character()] = self.editedProfile
		self:SendPresenceMessage()
	end
	self:OpenProfileList()
end

function ThisIsMe:OnSave(eLevel)
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Realm then
        return nil
    end
	if self.characterProfiles ~= nil then
		for k, v in pairs(self.characterProfiles) do
			v.ProtocolVersion = nil
			v.PartialSnippets = nil
			v.Online = nil
			v.Name = nil
			v.BufferedMessages = nil
		end
	end
	self.options.useDefaultProtocolVersion = (self.options.protocolVersion == self.defaultProtocolVersion)
	return {characterProfiles = self.characterProfiles, options = self.options}
end

function ThisIsMe:OnRestore(eLevel, tData)
	if GameLib.CodeEnumAddonSaveLevel.Realm then
		if tData.characterProfiles ~= nil then
			if next(tData.characterProfiles) ~= nil then
				self.characterProfiles = {}
				for k, v in pairs(tData.characterProfiles) do
					if v.Persist == nil then
						v.Persist = not self:IsProfileDefault(v)
					end
					if v.Persist == true or v.OwnProfile == true then
						local addTextMap = false
						if v.TextMap == nil then
							addTextMap = true
						end
						self.characterProfiles[k] = self:CopyTable(v, self:GetProfileDefaults(k))
						self.characterProfiles[k].ProtocolVersion = nil
						if self.characterProfiles[k].Messages ~= nil then
							if self.characterProfiles[k].Snippets == nil then
								self.characterProfiles[k].Snippets = self.characterProfiles[k].Messages
							end
							self.characterProfiles[k].Messages = nil
						end
						self:ApplyDefaultTextMap(self.characterProfiles[k])
					end
				end
			end
		end
		self.options = self.options or {}
		if tData.logLevel ~= nil then
			self.options.logLevel = tData.logLevel
		end
		if tData.debugMode ~= nil then
			self.options.debugMode = tData.debugMode
		end
		if tData.options ~= nil then
			self.options = self:CopyTable(tData.options, self.options)
		end
		if self.options.protocolVersion < self.protocolVersionMin then self.options.protocolVersion = self.protocolVersionMin end
		if self.options.protocolVersion > self.protocolVersionMax then self.options.protocolVersion = self.protocolVersionMax end
		if self.options.useDefaultProtocolVersion then
			self.options.protocolVersion = self.defaultProtocolVersion
		end
		self.dataLoaded = true
	end
	self:CheckData()
end

function ThisIsMe:OnOptionsClick( wndHandler, wndControl, eMouseButton )
	self:OpenOptions()
end

function ThisIsMe:OnTestClick( wndHandler, wndControl, eMouseButton )
	local scale = 1
	local nextScale = scale * 32
	for x = 0, 5, 1 do
		self:TestVarIntRange(scale - 2, scale + 2)
		scale = nextScale
		nextScale = nextScale * 33
	end
end

function ThisIsMe:TestVarIntRange(num, numEnd)
	if num < 0 then num = 0 end
	for x = num, numEnd, 1 do
		self:TestVarInt(x)
	end
end

function ThisIsMe:TestVarInt(num)
	local enc = LibCommExt:EncodeVarInt(num)
	local out, msg = LibCommExt:DecodeVarInt(enc)
	self:Print(1, "StartNum: " .. num .. ", Encoded: " .. enc .. ", Decoded: " .. out)
end

function ThisIsMe:TestVarString(str)
	local enc = LibCommExt:EncodeVarString(str)
	local out, msg = LibCommExt:DecodeVarString(enc)
	self:Print(1, "StartStr: " .. str .. ", Encoded: " .. enc .. ", Decoded: " .. out)
end

function ThisIsMe:OnTestCommand(cmd, arg)
	local msg = LibCommExt:EncodeTypeData(2, tonumber(arg))
	self:Print(1, msg)
	local type, num, tmp = LibCommExt:DecodeTypeData(msg)
	self:Print(1, type .. " " .. num)
end

-----------------------------------------------------------------------------------------------
-- ProfileList Functions
-----------------------------------------------------------------------------------------------
function ThisIsMe:ProfileSort(profile1, profile2)
	if profile1 == nil then
		if profile2 == nil then
			return false
		end
		return false
	end
	if profile2 == nil then return false end
	if self.sortByOnline then
		local p1online = self:IsPlayerOnline(profile1.Name)
		local p2online = self:IsPlayerOnline(profile2.Name)
		if p1online and not p2online then return true end
		if p2online and not p1online then return false end
	end
	return profile1.Name < profile2.Name
end

function ThisIsMe:PopulateProfileList()
	if self.profileListSortTimer ~= nil then
		self.profileListSortTimer:Stop()
		self.profileListSortTimer = nil
	end
	self.profileListSortTimer = ApolloTimer.Create(0.1, false, "PopulateProfileListImpl", self)
end

-- populate profile list
function ThisIsMe:PopulateProfileListImpl()
	if self.profileListSortTimer ~= nil then
		self.profileListSortTimer:Stop()
		self.profileListSortTimer = nil
	end
	if self.wndProfileList == nil then return end
	local position = self.wndProfileList:GetVScrollPos()
	-- make sure the profile list is empty to start with
	self:DestroyProfileList()
	
	GeminiLocale:TranslateWindow(Locale, self.wndMain)
	
    -- add profiles
	local ordered = {}
	for k, v in pairs(self.characterProfiles) do
		if k ~= nil and v ~= nil then
			table.insert(ordered, {Name=k, Profile=v, SortFunction="ProfileSort", SortTable=self})
		end
	end
	table.sort(ordered, function(a,b) return a.SortTable[a.SortFunction](a.SortTable, a, b) end)
	for k, v in ipairs(ordered) do
        self:AddItem(v.Name, v.Profile)
	end
	
	-- now all the profiles are added, call ArrangeChildrenVert to list out the list items vertically
	self.wndProfileList:ArrangeChildrenVert()
	
	local testButton = self.wndMain:FindChild("TestButton")
	if testButton then
		testButton:Show(self.options.debugMode == true, true)
	end
	
	local filtersButton = self.wndMain:FindChild("FiltersButton")
	if filtersButton then
		filtersButton:Show(self.options.debugMode == true, true)
	end
	self.wndProfileList:SetVScrollPos(position)
end

-- clear the item list
function ThisIsMe:DestroyProfileList()
	if self.wndProfileList ~= nil then
		local children = self.wndProfileList:GetChildren()
		-- destroy all the wnd inside the list
		for idx, wnd in pairs(children ) do
			wnd:Destroy()
		end
	end

	-- clear the list item array
	self.profileListEntries = {}
	self.wndSelectedListItem = nil
end

-- add an item into the item list
function ThisIsMe:AddItem(name, profile)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "ListItem", self.wndProfileList, self)
	
	-- keep track of the window item created
	self.profileListEntries[wnd] = name
	
	self:SetItem(wnd, name, profile)
	
	wnd:SetData(name)
end

function ThisIsMe:SetItem(item, name, profile)
	if self:IsPlayerOnline(name) then
		item:SetSprite(listBright)
	else
		item:SetSprite(listDull)
	end
	if self.heartbeatTimers == nil or self.heartbeatTimers[name] == nil then self:SchedulePlayerTimeout(name) end
	-- give it a piece of data to refer to 
	local wndItemText = item:FindChild("Name")
	if wndItemText then
		wndItemText:SetText(" " .. self:GetProfileName(name))
		wndItemText:SetTextColor(kcrNormalText)	end
	local wndIngameName = item:FindChild("IngameName")
	if wndIngameName then
		wndIngameName:SetText(" " .. Locale["IngameNameShorthand"] .. ": " .. name)
	end
	local wndVersionText = item:FindChild("Version")
	local upToDate = false
	if wndVersionText then
		if (profile.Version ~= nil and profile.StoredVersion ~= nil and profile.Version == profile.StoredVersion) or name == self:Character() then
			wndVersionText:SetText(" " .. Locale["Uptodate"])
			wndVersionText:SetTextColor(defaultText)
			upToDate = true
		else
			wndVersionText:SetText(" " .. Locale["Outdated"])
			wndVersionText:SetTextColor(defaultText)
		end
		if profile.ProtocolVersion ~= nil and type(profile.ProtocolVersion) == "number" and not self:AllowedProtocolVersion(profile.ProtocolVersion) then
			if profile.ProtocolVersion > self.options.protocolVersion then
				wndVersionText:SetText(" Newer Protocol")
			else
				wndVersionText:SetText(" Outdated Protocol")
			end
			wndVersionText:SetTextColor(redErrorText)
		end
	end
	local wndRaceGender = item:FindChild("RaceGender")
	if wndRaceGender then
		local showGender = false
		local showRace = false
		if profile.Gender ~= nil and profile.Gender >= 3 and profile.Gender ~= 7 then showGender = true end
		if profile.Race ~= nil and profile.Race >= 3 then showRace = true end
		local text = ""
		if showGender then
			text = text .. " " .. self.genders[profile.Gender]
		end
		if showRace then
			text = text .. " " .. self.races[profile.Race]
		end
		wndRaceGender:SetText(text)
	end
	local wndAgeBuild = item:FindChild("AgeBuild")
	if wndAgeBuild then
		wndAgeBuild:SetText("")
	end
	local wndUpdateButton = item:FindChild("UpdateButton")
	if wndUpdateButton then
		wndUpdateButton:SetData(name)
		if upToDate or name == self:Character() then
			wndUpdateButton:Enable(false)
		else
			wndUpdateButton:Enable(self.enableUpdateButton == true and (self:AllowedProtocolVersion(profile.ProtocolVersion) or profile.ProtocolVersion == nil or type(profile.ProtocolVersion) ~= "number"))
		end
	end
	local wndViewButton = item:FindChild("ViewButton")
	if wndViewButton then
		wndViewButton:SetData(name)
	end
	local portrait = item:FindChild("Portrait")
	if portrait then
		if profile.Race == 4 then
			portrait:SetSprite(self.portraitChua)
		elseif self.portraits[tostring(profile.Race or 1)] ~= nil then
			if profile.Gender == 3 or profile.Gender == 5 then
				portrait:SetSprite(self.portraits[tostring(profile.Race or 1)][1])
			elseif profile.Gender == 4 or profile.Gender == 6 then
				portrait:SetSprite(self.portraits[tostring(profile.Race or 1)][2])
			else
				portrait:SetSprite(self.portraitUnknown)
			end
		else
			portrait:SetSprite(self.portraitUnknown)
		end
		if profile.Faction == "D" then
			portrait:SetBGColor(portraitDominion)
		elseif profile.Faction == "E" then
			portrait:SetBGColor(portraitExile)
		else
			portrait:SetBGColor(portraitNeutral)
		end
	end
	GeminiLocale:TranslateWindow(Locale, item)
end

function ThisIsMe:UpdateItemByName(name)
	for k, v in pairs(self.profileListEntries) do
		if v == name then
			self:SetItem(k, v, self.characterProfiles[v])
			break
		end
	end
end

function ThisIsMe:PopulateProfileView()
	if self.profileEdit == true then self.profileCharacter = self:Character() end
	self:Print(1, "Populating profile view: " .. (self.profileCharacter or "literally nobody, your profileCharacter variable is empty"))
	self:DestroyProfileView()
	
	if self.profileCharacter == nil or self.characterProfiles[self.profileCharacter] == nil then return end
	
	local profile = self.characterProfiles[self.profileCharacter]
	
	local item = nil
	
	if self.profileEdit then
		self.editedProfile = self:CopyTable(self.characterProfiles[self.profileCharacter], self:GetProfileDefaults(self.profileCharacter))
		self:ApplyDefaultTextMap(self.editedProfile)
		self.editedProfile.Version = ((self.editedProfile.Version or 1) % (64 * 64)) + 1
		self.editedProfile.StoredVersion = self.editedProfile.Version
		profile = self.editedProfile
		
		item = self:AddProfileEntry(self.wndProfileContainer, Locale["Name"])
		item:AddTextBox(self:GetProfileName(self.profileCharacter), "Name")
		
		item = self:AddProfileEntry(self.wndProfileContainer, Locale["Gender"])
		item:AddDropdownBox(self.genders, profile.Gender or 1, profile, "Gender")
		if self.options.debugMode then item:AddSubButtons(true) end
		
		item = self:AddProfileEntry(self.wndProfileContainer, Locale["Race"])
		item:AddDropdownBox(self.races, profile.Race or 1, profile, "Race")
		if self.options.debugMode then item:AddSubButtons(true) end
		
		item = self:AddProfileEntry(self.wndProfileContainer, Locale["Age"])
		item:AddDropdownBox(self.ages, profile.Age or 1, profile, "Age")
		if self.options.debugMode then item:AddSubButtons(true) end
		
		item = self:AddProfileEntry(self.wndProfileContainer, Locale["Height"])
		item:AddDropdownBox(self.heights, profile.Length or 1, profile, "Length")
		if self.options.debugMode then item:AddSubButtons(true) end
		
		item = self:AddProfileEntry(self.wndProfileContainer, Locale["Body Type"])
		item:AddDropdownBox(self.bodyTypes, profile.BodyType or 1, profile, "BodyType")
		if self.options.debugMode then item:AddSubButtons(true) end
		
		item = self:AddProfileEntry(self.wndProfileContainer, Locale["Hair Length"])
		item:AddDropdownBox(self.hairLength, profile.HairLength or 1, profile, "HairLength")
		if self.options.debugMode then item:AddSubButtons(true) end
		
		item = self:AddProfileEntry(self.wndProfileContainer, Locale["Hair Quality"])
		item:AddDropdownBox(self.hairQuality, profile.HairQuality or 1, profile, "HairQuality")
		if self.options.debugMode then item:AddSubButtons(true) end
		
		item = self:AddProfileEntry(self.wndProfileContainer, Locale["Hair Style"])
		item:AddDropdownBox(self.hairStyle, profile.HairStyle or 1, profile, "HairStyle")
		if self.options.debugMode then item:AddSubButtons(true) end
	else
		self:AddProfileEntry(self.wndProfileContainer, "Name", self:GetProfileName(self.profileCharacter))
		if profile.Gender ~= nil and profile.Gender >= 2 and self.genders[profile.Gender] ~= nil then self:AddProfileEntry(self.wndProfileContainer, "Gender", self.genders[profile.Gender or 2]) end
		if profile.Race ~= nil and profile.Race >= 2 and self.races[profile.Race] ~= nil then self:AddProfileEntry(self.wndProfileContainer, "Race", self.races[profile.Race or 2]) end
		if profile.Age ~= nil and profile.Age >= 2 and self.ages[profile.Age] ~= nil then self:AddProfileEntry(self.wndProfileContainer, "Age", self.ages[profile.Age or 2]) end
		if profile.Length ~= nil and profile.Length >= 2 and self.heights[profile.Length] ~= nil then self:AddProfileEntry(self.wndProfileContainer, "Height", self.heights[profile.Length or 2]) end
		if profile.BodyType ~= nil and profile.BodyType >= 2 and self.bodyTypes[profile.BodyType] ~= nil then self:AddProfileEntry(self.wndProfileContainer, "Body Type", self.bodyTypes[profile.BodyType or 2]) end
		if profile.HairLength ~= nil and profile.HairLength >= 2 and self.hairLength[profile.HairLength] ~= nil then self:AddProfileEntry(self.wndProfileContainer, "Hair Length", self.hairLength[profile.HairLength or 2]) end
		if profile.HairQuality ~= nil and profile.HairQuality >= 2 and self.hairQuality[profile.HairQuality] ~= nil then self:AddProfileEntry(self.wndProfileContainer, "Hair Quality", self.hairQuality[profile.HairQuality or 2]) end
		if profile.HairStyle ~= nil and profile.HairStyle >= 2 and self.hairStyle[profile.HairStyle] ~= nil then self:AddProfileEntry(self.wndProfileContainer, "Hair Style", self.hairStyle[profile.HairStyle or 2]) end
--		if profile.TailSize ~= nil and profile.TailSize >= 2 then self:AddProfileEntry(self.wndProfileContainer, "Tail Size", self.tailSize[profile.TailSize or 2]) end
--		if profile.TailState ~= nil and profile.TailState >= 2 then self:AddProfileEntry(self.wndProfileContainer, "Hair Style", self.tailState[profile.TailState or 2]) end
--		if profile.TailDecoration ~= nil and profile.TailDecoration >= 2 then self:AddProfileEntry(self.wndProfileContainer, "Tail Decoration", self.tailDecoration[profile.TailDecoration or 2]) end
	end
	profile.Snippets = profile.Snippets or {}
	if profile.TextMap ~= nil and profile.TextMap[2] ~= nil then
		for k, v in self:sipairs(profile.TextMap[2]) do
			if type(v) == "table" then
				for k2, v2 in self:sipairs(v) do
					if k2 ~= 1 and type(v2) == "number" and (profile.Snippets[v2] ~= nil or (self.profileEdit and v2 == 2)) then
						item = self:AddProfileEntry(self.wndProfileContainer, "Extra", "")
						item:SetContent(v2, profile, not self.profileEdit)
						if self.profileEdit and self.options.debugMode then item:AddSubButtons(false) end
					end
				end
			end
		end
	else
		for k, v in sipairs(profile.Snippets) do
			if type(k) == "number" and k ~= 1 then
				item = self:AddProfileEntry(self.wndProfileContainer, "Extra", "")
				self:SetContent(k, profile, not self.profileEdit)
				if self.profileEdit and self.options.debugMode then item:AddSubButtons(false) end
			end
		end
	end
	self.wndProfileContainer:ArrangeChildrenVert()
	GeminiLocale:TranslateWindow(Locale, self.wndProfile)
end

-- clear the item list
function ThisIsMe:DestroyProfileView()
	self:ClearAllChildren(self.wndProfileContainer)
end

function ThisIsMe:ClearAllChildren(item)
	if item ~= nil then
		local children = item:GetChildren()
		-- destroy all the wnd inside the list
		for idx, wnd in pairs(children) do
			wnd:Destroy()
		end
	end
end

function ThisIsMe:AddProfileEntry(parent, entryName, defaultText)
	local item = ProfileWindow:new(nil, "ProfileEntry", self.wndProfileContainer, 1)
	item:SetTitle(entryName)
	item:SetOption(defaultText)
	return item
end

function ThisIsMe:CopyTable(table, existingTable)
	if table == nil then return nil end
	if type(table) ~= "table" then return nil end
	local newTable = existingTable or {}
	for k, v in pairs(table) do
		if type(v) ~= "table" then newTable[k] = v
		else newTable[k] = self:CopyTable(v) end
	end
	return newTable
end

function ThisIsMe:CompareTableEqual(table, table2)
	if table == nil and table2 == nil then return true end
	if table == nil or table2 == nil then return false end
	if type(table) ~= type(table2) then return false end
	if type(table) ~= "table" then
		return table == table2
	end
	for k, v in pairs(table) do
		if type(v) == "table" then
			if type(table2[k]) == "table" then
				if not self:CompareTableEqual(v, table2[k]) then return false end
			else return false end
		else
			if v ~= table2[k] then return false end
		end
	end
	return true
end

function ThisIsMe:CompareTableEqualBoth(table, table2)
	return self:CompareTableEqual(table, table2) and self:CompareTableEqual(table2, table)
end

---------------------------------------------------------------------------------------------------
-- ListItem Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:OnUpdateButtonClick( wndHandler, wndControl, eMouseButton )
	local player = wndControl:GetData()
	if player ~= nil then
		self:SendProfileRequestMessage(player)
	end
	self.enableUpdateButton = false
	self.updateButtonTimer = ApolloTimer.Create(2, false, "ReEnableUpdateButton", self)
	self:ResetItemList()
end

function ThisIsMe:ReEnableUpdateButton()
	self.enableUpdateButton = true
	self:ResetItemList()
end

function ThisIsMe:ResetItemList()
	for k, v in pairs(self.profileListEntries) do
		self:SetItem(k, v, self.characterProfiles[v])
	end
end

function ThisIsMe:OnViewButtonClick( wndHandler, wndControl, eMouseButton )
	local player = wndControl:GetData()
	if player ~= nil then
		self.profileCharacter = player
		self.profileEdit = false
		self:OpenProfileView()
		self:Print(9, "Clicked profile view button")
	end
end

---------------------------------------------------------------------------------------------------
-- EntryTextBox Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:OnEntryTextChanged( wndHandler, wndControl, strText )
	if wndControl == nil then return end
	if strText == nil then strText = "" end
	local data = wndControl:GetData()
	if data ~= nil then
		self.editedProfile[data] = wndControl:GetText()
	end
end

function ThisIsMe:OnMessageEntryChanged( wndHandler, wndControl, strText )
	if wndControl == nil then return end
	if strText == nil then strText = "" end
	local data = wndControl:GetData()
	if data ~= nil then
		self.editedProfile.Snippets = self.editedProfile.Snippets or {}
		self.editedProfile.Snippets[data + 0] = wndControl:GetText()
	end
end

function ThisIsMe:ListFunctions(instance, findText)
	for k,v in pairs(getmetatable(instance)) do
		if type(v) == "function" and string.find(k, findText) then
			self:Print(1, k)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Options Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:OpenOptions()
	self:CloseAllWindows()
	self.wndOptions:Invoke()
	local debugText = self.wndOptions:FindChild("DebugLevel")
	if debugText then
		debugText:SetText("  " .. Locale["DebugLevel"] .. ": " .. (self.options.logLevel or 0))
	end
	local debugSlider = self.wndOptions:FindChild("DebugLevelBar")
	if debugSlider then
		debugSlider:SetValue(self.options.logLevel or 0)
	end
	local debugToggle = self.wndOptions:FindChild("DebugModeCheckbox")
	if debugToggle then
		debugToggle:SetCheck(self.options.debugMode == true)
	end
	local protocolText = self.wndOptions:FindChild("ProtocolVersion")
	if protocolText then
		protocolText:SetText("  " .. Locale["Protocol Version"] .. ": " .. (self.options.protocolVersion or self.protocolVersionMin))
	end
	local protocolSlider = self.wndOptions:FindChild("ProtocolVersionBar")
	if protocolSlider then
		protocolSlider:SetValue(self.options.protocolVersion or self.protocolVersionMin)
		protocolSlider:SetMinMax(self.protocolVersionMin, self.protocolVersionMax, 1)
	end
	self.newOptions = self:CopyTable(self.options, {})
end

function ThisIsMe:SetNewOptions(newOptions)
	self.options.logLevel = newOptions.logLevel or self.options.logLevel
	if self.newOptions.debugMode ~= nil then self.options.debugMode = newOptions.debugMode end
	if newOptions.protocolVersion ~= self.options.protocolVersion then
		newOptions.protocolVersion = self:Clamp(newOptions.protocolVersion, self.protocolVersionMin, self.protocolVersionMax)
		if newOptions.protocolVersion ~= self.options.protocolVersion then
			self.options.protocolVersion = newOptions.protocolVersion
			self:SendPresenceMessage()
		end
	end
end

function ThisIsMe:OnOptionsOk( wndHandler, wndControl, eMouseButton )
	self:SetNewOptions(self.newOptions)
	self:OpenProfileList()
end

function ThisIsMe:OnOptionsClose( wndHandler, wndControl, eMouseButton )
	self.newOptions = nil
	self:OpenProfileList()
end

---------------------------------------------------------------------------------------------------
-- OptionsWindow Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:OnDebugLevelChange( wndHandler, wndControl, fNewValue, fOldValue )
	self.newOptions.logLevel = fNewValue
	if self.wndOptions ~= nil then
		local debugText = self.wndOptions:FindChild("DebugLevel")
		if debugText then
			debugText:SetText("  " .. Locale["DebugLevel"] .. ": " .. fNewValue)
		end
	end
end

function ThisIsMe:OnProtocolVersionChange( wndHandler, wndControl, fNewValue, fOldValue )
	self.newOptions.protocolVersion = fNewValue
	if self.wndOptions ~= nil then
		local debugText = self.wndOptions:FindChild("ProtocolVersion")
		if debugText then
			debugText:SetText("  " .. Locale["Protocol Version"] .. ": " .. fNewValue)
		end
	end
end

function ThisIsMe:OnDebugModeToggle( wndHandler, wndControl, eMouseButton )
	self.newOptions.debugMode = wndControl:IsChecked()
end
---------------------------------------------------------------------------------------------------
-- Network Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:CheckComms()
	self:CheckData()
	if self.startupTimer ~= nil then
		self.startupTimer:Stop()
		self.startupTimer = nil
	end
	if self.Comm ~= nil and self.Comm:IsReady() then return end
	self:SetupComms()
end

function ThisIsMe:EchoReceivedMessage(channel, strMessage, strSender)
	self.Comm:OnMessageReceived(channel, strMessage, strSender)
end

function ThisIsMe:SetupComms()
	if self.startupTimer ~= nil then
		return
	end
	self.startupTimer = ApolloTimer.Create(30, false, "SetupComms", self) -- automatically retry if something goes wrong.
	
	if self.Comm ~= nil and self.Comm:IsReady() then
		if self.startupTimer ~= nil then
			self.startupTimer:Stop()
			self.startupTimer = nil
		end
		return
	end
	self.Comm = LibCommExt:GetChannel(self.channel)
	if self.Comm ~= nil then
		self.Comm:AddReceiveCallback("OnMessageReceived", self)
		self.Comm:SetReceiveEcho("EchoReceivedMessage", self)
	else
		self:Print(1, "Failed to open channel")
	end
end

function ThisIsMe:OnMessageReceived(channel, strMessage, strSender)
	self:Print(5, "Received message: " .. strMessage .. " from: " .. strSender)
	if self.characterProfiles[strSender] ~= nil then self:ProcessMessage(channel, strMessage, strSender, self.characterProfiles[strSender].ProtocolVersion)
	else self:ProcessMessage(channel, strMessage, strSender, nil)
	end
end

function ThisIsMe:SchedulePlayerTimeout(player)
	self.heartbeatTimers = self.heartbeatTimers or {}
	if self.heartbeatTimers[strSender] ~= nil then
		self:CancelTimer(self.heartbeatTimers[strSender], true)
	end
	self.heartbeatTimers[player] = self:ScheduleTimer("OnPlayerTimeout", 130, player)
end

function ThisIsMe:OnPlayerTimeout(player)
	if player ~= nil then
		self:UpdateOnlineStatus(player)
	else
		self:Print(9, "Unknown player timed out. This should not happen, but probably will.")
	end
end

function ThisIsMe:UpdateOnlineStatus(player)
	if player == nil then return end
	local profile = self.characterProfiles[player]
	local online = nil
	if (profile.LastHeartbeatTime == nil or os.difftime(os.time(), profile.LastHeartbeatTime) > 120) and player ~= self:Character() then
		online = false
	else
		online = true
	end
	if profile.Online ~= online then
		if self.sortByOnline then
			self:PopulateProfileList()
		else
			self:UpdateItemByName(player)
		end
	end
	profile.Online = online
end

function ThisIsMe:IsPlayerOnline(player)
	return self.characterProfiles[player].Online
end

function ThisIsMe:ProcessMessage(channel, strMessage, strSender, protocolVersion)
	local shouldUpdate = false
	if self.characterProfiles[strSender] == nil then shouldUpdate = true end
	self.characterProfiles[strSender] = self.characterProfiles[strSender] or self:GetProfileDefaults(strSender)
	local profile = self.characterProfiles[strSender]
	profile.LastHeartbeatTime = os.time()
	self:UpdateOnlineStatus(strSender)
	self:SchedulePlayerTimeout(strSender)
	self:UpdateItemByName(strSender)
	
	local shouldProcessBacklog = false
	
	local firstCharacter = strMessage:sub(1,1)
	
	local shouldIgnore = (not self:AllowedProtocolVersion(protocolVersion))
	
	if firstCharacter == "E" or firstCharacter == "D" or firstCharacter == "?" then
		if self.characterProfiles[strSender] == nil then shouldUpdate = true end
		if not (profile.Faction == "E" or profile.Faction == "D") then profile.Faction = firstCharacter end
		if strMessage:len() > 1 then
			protocolVersion = self:DecodeMore1(strMessage:sub(2,3))
			profile.ProtocolVersion = protocolVersion
			if self:AllowedProtocolVersion(protocolVersion) then
				local newVersion = self:DecodeMore1(strMessage:sub(4,5))
				if profile.Version ~= newVersion and protocolVersion >= 4 then self:SendProfileRequestMessage(strSender) end
				profile.Version = newVersion
			end
		end
		shouldProcessBacklog = true
	end
	
	if strMessage:len() == 1 or self:AllowedProtocolVersion(protocolVersion) then
		if firstCharacter == "#" then
			self:SendPresenceMessage()
		end
		if firstCharacter == "~" then
			self:SendBasicProfile()
		end
	end
	if protocolVersion == nil then
		profile.BufferedMessages = profile.BufferedMessages or {}
		table.insert(profile.BufferedMessages, strMessage)
		self:SendVersionRequestMessage(strSender)
		self:Print(1, "Unknown protocol message received from " .. strSender)
		return
	end
	if not shouldIgnore then
		if firstCharacter == "@" then
			self.characterProfiles[strSender] = self:DecodeProfile(strMessage:sub(2, strMessage:len()), profile)
			profile = self.characterProfiles[strSender]
			if self.characterProfiles[strSender] == nil then
				shouldUpdate = shouldUpdate or (profile.StoredVersion ~= profile.Version)
			else
				self:UpdateItemByName(strSender)
			end
			profile.StoredVersion = profile.Version
		end
		if firstCharacter == "$" then
			self:ReceiveTextEntry(strSender, strMessage:sub(2, strMessage:len()))
		end
		self:ReceiveWrappedMessage(strMessage, strSender, protocolVersion)
	end
	
	if shouldUpdate then self:PopulateProfileList() end
	
	if shouldProcessBacklog then
		if profile.BufferedMessages ~= nil then
			if self:AllowedProtocolVersion(protocolVersion) then
				while #profile.BufferedMessages > 0 do
					local message = profile.BufferedMessages[1]
					table.remove(profile.BufferedMessages, 1)
					self:OnMessageReceived(channel, message, strSender)
				end
			end
		end
	end
end

function ThisIsMe:sendHeartbeatMessage()
	self:AddBufferedMessage("*", nil, -10) -- don't check for protocol version, previous versions will just ignore this anyway.
end

function ThisIsMe:EnablePresenceMessage()
	self.presenceMessageEnabled = true
	if self.presenceMessageQueued == true then
		self.presenceMessageQueued = false
		self:SendPresenceMessage()
	end
end

function ThisIsMe:SendPresenceMessage()
	if self.presenceMessageEnabled == false then
		self.presenceMessageQueued = true
		return
	end
	local message = self:Faction()
	message = message .. self:EncodeMore1(self.options.protocolVersion or 4, 2)
	if self.characterProfiles[self:Character()] == nil then self.characterProfiles[self:Character()] = self:GetProfileDefaults(self:Character(), self:Unit()) end
	local profile = self.characterProfiles[self:Character()]
	if profile.Persist == false then
		message = message .. self:EncodeMore1(1, 2)
	else
		message = message .. self:EncodeMore1(self.characterProfiles[self:Character()].Version or 1, 2)
	end
	self:AddBufferedMessage(message, nil, 3)
	self.announcedSelf = true
	self.presenceMessageEnabled = false
	self.presenceMessageTimer = self:ScheduleTimer("EnablePresenceMessage", 10)
end

function ThisIsMe:SendPresenceRequestMessage()
	self:AddBufferedMessage("#", nil, 2)
	self:SendPresenceMessage()
	self.seenEveryone = true
end

function ThisIsMe:EnableVersionRequestMessage(player)
	if player == nil then return end
	self.versionRequestMessageEnabled = self.versionRequestMessageEnabled or {}
	self.versionRequestMessageEnabled[player] = true
	self.versionRequestMessageQueued = self.versionRequestMessageQueued or {}
	if self.versionRequestMessageQueued[player] == true then
		self.versionRequestMessageQueued[player] = false
		self:SendVersionRequestMessage(player)
	end
end

function ThisIsMe:SendVersionRequestMessage(player)
	self.versionRequestMessageEnabled = self.versionRequestMessageEnabled or {}
	if self.versionRequestMessageEnabled[player] == false then
		self.versionRequestMessageQueued = self.versionRequestMessageQueued or {}
		self.versionRequestMessageQueued[player] = true
		return
	end -- nil counts as true
	self:AddBufferedMessage("#", player, 15)
	self.versionRequestMessageEnabled[player] = false
	self.presenceRequestMessageTimer = self:ScheduleTimer("EnableVersionRequestMessage", 10, player)
end

function ThisIsMe:SendProfileRequestMessage(name)
	self.profileRequestBuffer[name] = true
	self.profileRequestTimer = ApolloTimer.Create(5, true, "ProfileRequestTimer", self)
end

function ThisIsMe:ProfileRequestTimer()
	local profileRequestName = next(self.profileRequestBuffer)
	if profileRequestName ~= nil then
		self:AddBufferedMessage("~", profileRequestName, 0)
		self.profileRequestBuffer[profileRequestName] = nil
	else
		if self.profileRequestTimer ~= nil then
			self.profileRequestTimer:Stop()
		end
		self.profileRequestTimer = nil
	end
end

function ThisIsMe:EnableProfileSending()
	self.allowProfileSending = true
	if self.profileSendingQueued == true then
		self:SendBasicProfileDelayed()
		self.profileSendingQueued = false
	end
end

function ThisIsMe:SendBasicProfile()
	if self.allowProfileSending == false then
		self.profileSendingQueued = true
		return
	end
	if self.ProfileSendingCountdown ~= nil then
		self:CancelTimer(self.ProfileSendingCountdown, true)
	end
	self.ProfileSendingCountdown = self:ScheduleTimer("SendBasicProfileDelayed", 2)
end

function ThisIsMe:SendBasicProfileDelayed()
	if self.allowProfileSending == false then return end
	self:Print(5, "Sending profile")
	if self:Profile() ~= nil then
		self:AddBufferedMessage("@" .. self:EncodeProfile(self:Profile()), nil, 1)
		if self:Profile().Snippets ~= nil then
			for k, v in pairs(self:Profile().Snippets) do
				local num = k + 0
				if type(num) == "number" then
					self:SendTextEntry(num, v)
				end
			end
		end
	end
	self.allowProfileSending = false
	self:ScheduleTimer("EnableProfileSending", 30)
end

function ThisIsMe:SendTextEntry(number, text)
	if self.options.protocolVersion <= 4 then
		self:AddBufferedMessage("$" .. self:Encode1(number) .. "AA" .. text, nil, 0)
	else
		self:AddBufferedMessage("$" .. self:Encode1(number) .. text, nil, 0)
	end
end

function ThisIsMe:SendTextMap()
	local textMap = self:Profile().TextMap
	if textMap == nil then return end
	if self.options.protocolVersion <= 4 then return end
	self:AddBufferedMessage("(" .. self:GetTextMapString(textMap), nil, self.options.protocolVersion)
end

function ThisIsMe:GetTextMapString(mapSection)
	if type(mapSection) == "number" then return "n" .. self:Encode1(mapSection)
	elseif type(mapSection) == "table" then
		local text = ""
		local num = 0
		for k, v in self:sipairs(mapSection) do
			if type(k) == "number" then
				local newText = self:GetTextMapString(v)
				text = text .. self:Encode1(k) .. self:EncodeMore1(newText:len(), 2) .. newText
				num = num + 1
			end
		end
		text = "t" .. self:Encode1(num) .. text
		return text
	end
end

function ThisIsMe:ParseTextMapString(mapString)
	if mapString == nil or type(mapString) ~= "string" then return nil end
	local firstCharacter = mapString:sub(1, 1)
	local secondCharacter = mapString:sub(2, 2)
	if firstCharacter == "n" then
		self:Print(9, "Adding number to table: " .. secondCharacter)
		return self:Decode1(secondCharacter)
	elseif firstCharacter == "t" then
		local table = {}
		local num = self:Decode1(secondCharacter)
		local contents = mapString:sub(3, mapString:len())
		self:Print(9, "Adding table to table, with " .. num .. " entries")
		for i=1,num,1 do
			local entryNum = self:Decode1(contents:sub(1,1))
			local length = self:DecodeMore1(contents:sub(2,3))
			table[entryNum] = self:ParseTextMapString(contents:sub(4, length + 3))
			contents = contents:sub(length + 4, contents:len())
		end
		return table
	else self:Print(9, "Error in parsing a text map")
	end
end

function ThisIsMe:ReceiveTextEntry(sender, text)
	if text ~= nil and sender ~= nil then
		--if self.characterProfiles[sender].ProtocolVersion == nil or self.characterProfiles[sender].ProtocolVersion <= 5 then
			local number = self:Decode1(text:sub(1,1))
			local part = self:Decode1(text:sub(2,2))
			local total = self:Decode1(text:sub(3,3))
			local message = text:sub(4, text:len())
			self.characterProfiles[sender].PartialSnippets = self.characterProfiles[sender].PartialSnippets or {}
			self.characterProfiles[sender].PartialSnippets[number] = self.characterProfiles[sender].PartialSnippets[number] or {}
			self.characterProfiles[sender].PartialSnippets[number][part] = message
			local partialMessages = self.characterProfiles[sender].PartialSnippets[number]
			self.characterProfiles[sender].PartialSnippets[number] = {}
			local completeMessage = ""
			for k, v in ipairs(partialMessages) do
				if k >= 1 and k <= total then
					self.characterProfiles[sender].PartialSnippets[number][k] = v
					completeMessage = completeMessage .. v
				end
			end
			self.characterProfiles[sender].Snippets = self.characterProfiles[sender].Snippets or {}
			self.characterProfiles[sender].Snippets[number] = completeMessage
			if number == 2 then
				self:ApplyDefaultTextMap(self.characterProfiles[sender])
			end
		--[[else
			local number = self:Decode1(text:sub(1,1))
			local message = text:sub(offset, text:len())
			self.characterProfiles[sender].Snippets = self.characterProfiles[sender].Snippets or {}
			self.characterProfiles[sender].Snippets[number] = message
		end]]
	end
end

function ThisIsMe:SendWrappedMessage(text, recipient, protocolVersion, priority)
	if protocolVersion == nil then protocolVersion = self.options.protocolVersion end
	if protocolVersion <= 2 then return end
	local pos = 1
	local length = text:len()
	local prefix = ""
	local number = self.wrappedTextNumber or 1
	local sequenceNum = 1
	self.wrappedTextNumber = (number % 64) + 1
	while pos <= length do
		local chunkSize = self.messageCharacterLimit - 6
		if pos == 1 then
			chunkSize = self.messageCharacterLimit - 5
			local protocolVersionNum = ""
			if self.options.protocolVersion >= 4 then
				chunkSize = chunkSize - 2
				prefix = "%" .. self:Encode1(number) .. self:EncodeMore1(protocolVersion, 2) .. self:EncodeMore1(length, 2)
			else
				prefix = "%" .. self:Encode1(number) .. self:EncodeMore1(length, 2)
			end
		elseif pos <= length - self.messageCharacterLimit - 4 then
			chunkSize = self.messageCharacterLimit - 3
			if self.options.protocolVersion >= 4 then
				prefix = "^" .. self:Encode1(number) .. self:Encode1(sequenceNum)
			else
				prefix = "^" .. self:Encode1(number)
			end
		else
			chunkSize = self.messageCharacterLimit - 5
			if self.options.protocolVersion >= 4 then
				prefix = "&" .. self:Encode1(number) .. self:Encode1(sequenceNum) .. self:EncodeMore1(length, 2)
			else
				prefix = "&" .. self:Encode1(number) .. self:EncodeMore1(length, 2)
			end
		end
		self:AddBufferedMessage(prefix .. text:sub(pos, pos + chunkSize - 1), recipient, priority)
		pos = pos + chunkSize
		sequenceNum = sequenceNum + 1
	end
end

function ThisIsMe:ReceiveWrappedMessage(strMessage, strSender, protocolVersion)
	local profile = self.characterProfiles[strSender]
	if profile == nil then return end
	profile.WrappedMessages = profile.WrappedMessages or {}
	local firstCharacter = strMessage:sub(1, 1)
	if not self:AllowedProtocolVersion(protocolVersion) then return false end
	local offset = 0
	if firstCharacter == "%" or firstCharacter == "^" or firstCharacter == "&" then
		local messageID = self:Decode1(strMessage:sub(2 + offset, 2 + offset))
		if protocolVersion >= 4 and firstCharacter ~= "%" then
			local sequenceNum = self:Decode1(strMessage:sub(3 + offset, 3 + offset))
			if profile.WrappedMessages[messageID] == nil or profile.WrappedMessages[messageID].LastSequenceNum == nil then
				profile.WrappedMessages[messageID] = nil -- message received out of sequence
				self:Print(1, "Wrapped message received out of sequence; discarded")
				return
			else
				local expectedSequenceNum = ((profile.WrappedMessages[messageID].LastSequenceNum) % 64) + 1
				if sequenceNum ~= expectedSequenceNum then
					profile.WrappedMessages[messageID] = nil -- message received out of sequence
					self:Print(1, "Wrapped message received out of sequence: " .. sequenceNum .. " instead of " .. expectedSequenceNum .. "; discarded")
					return
				end
			end
			offset = offset + 1
		end
		if firstCharacter == "%" then
			local protocolContained = protocolVersion
			if protocolVersion >= 4 then
				protocolContained = self:DecodeMore1(strMessage:sub(3 + offset, 4 + offset))
				offset = offset + 2
			end
			local length = self:DecodeMore1(strMessage:sub(3 + offset, 4 + offset))
			local content = strMessage:sub(5 + offset, strMessage:len())
			profile.WrappedMessages = profile.WrappedMessages or {}
			profile.WrappedMessages[messageID] = {}
			profile.WrappedMessages[messageID].Content = content
			profile.WrappedMessages[messageID].Length = length
			profile.WrappedMessages[messageID].ProtocolVersion = protocolContained
			profile.WrappedMessages[messageID].LastSequenceNum = 1
		end
		if firstCharacter == "^" then
			local content = strMessage:sub(3 + offset, strMessage:len())
			profile.WrappedMessages[messageID] = profile.WrappedMessages[messageID] or {}
			profile.WrappedMessages[messageID].Content = (profile.WrappedMessages[messageID].Content or "") .. content
			profile.WrappedMessages[messageID].LastSequenceNum = ((profile.WrappedMessages[messageID].LastSequenceNum) % 64) + 1
		end
		if firstCharacter == "&" then
			local length = self:DecodeMore1(strMessage:sub(3 + offset, 4 + offset))
			local content = strMessage:sub(5 + offset, strMessage:len())
			profile.WrappedMessages[messageID] = profile.WrappedMessages[messageID] or {}
			profile.WrappedMessages[messageID].Content = (profile.WrappedMessages[messageID].Content or "") .. content
			if profile.WrappedMessages[messageID].Content:len() == length then
				self:ProcessMessage(channel, profile.WrappedMessages[messageID].Content, strSender, profile.WrappedMessages[messageID].ProtocolVersion)
			end
			profile.WrappedMessages[messageID] = nil
		end
	end
end

function ThisIsMe:OnMessageSent(channel, eResult, idMessage)
end

function ThisIsMe:OnMessageThrottled(channel, eResult, idMessage)
	self:Print(1, "A message got throttled")
end

function ThisIsMe:OnTimer()
	self:messageLoop()
end

function ThisIsMe:messageLoop()
	if #self.messageQueue <= 0 then
		self.sendTimer:Stop()
		self.sendTimer = nil
	else
		local charactersRemaining = self.messageCharacterLimit
		for i = 1,self.messagesPerSecond,1 do
			local message = self.messageQueue[1]
			if message ~= nil and message.Message:len() <= charactersRemaining then
				charactersRemaining = charactersRemaining - message.Message:len()
				if self:SendMessage(message.Message, message.Recipient) then
					table.remove(self.messageQueue, 1)
				end
			end
		end
	end
end

function ThisIsMe:AddBufferedMessage(message, recipient, protocolVersion, priority)
	self:CheckComms()
	if recipient == nil then
		self:Print(9, "Sending message: " .. message)
	else
		self:Print(9, "Sending message to " .. recipient .. ": " .. message)
	end
	if message:len() > self.messageCharacterLimit then
		self:SendWrappedMessage(message, recipient, protocolVersion or self.options.protocolVersion, priority or 0)
	else
		self.Comm:SendMessage(recipient, message, protocolVersion or self.options.protocolVersion, priority or 0)
	end
	if recipient == nil then
		if self.MyHeartbeatTimer ~= nil then
			self.MyHeartbeatTimer:Stop()
			self.MyHeartbeatTimer = nil
		end
		self.MyHeartbeatTimer = ApolloTimer.Create(60, true, "sendHeartbeatMessage", self)
	end
end

---------------------------------------------------------------------------------------------------
-- Encoding/Decoding Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:Encode1(numToEncode)
	return LibCommExt:Encode1(numToEncode)
end

function ThisIsMe:EncodeMore1(num, amount)
	return LibCommExt:EncodeMore1(num, amount)
end

function ThisIsMe:Decode1(charToDecode) 
	return LibCommExt:Decode1(charToDecode)
end

function ThisIsMe:DecodeMore1(str, amount)
	return LibCommExt:DecodeMore1(str, amount)
end

function ThisIsMe:AllowedProtocolVersion(num)
	if num == nil or type(num) ~= "number" then return nil end
	if num >= 1 and num <= 5 then return true end
	return false
end

function ThisIsMe:AddEncodedValue(value, protocolVersion, protocolVersionMin, protocolVersionMax)
	if protocolVersionMin ~= nil and protocolVersion < protocolVersionMin then return "" end
	if protocolVersionMax ~= nil and protocolVersion > protocolVersionMax then return "" end
	return value
end

function ThisIsMe:EncodeProfile(profile)
	if profile == nil then
		return nil
	end
	local protocolVersion = profile.ProtocolVersion or self.options.protocolVersion -- should always be filled in anyway.
	local ret = "" -- to add: ear/tail size/quality, hair colour, streak colour, eye colour, facial hair style
	ret = ret .. self:EncodeMore1(profile.Version or 1, 2)
	ret = ret .. self:Encode1(profile.HairStyle or 1)
	ret = ret .. self:Encode1(profile.HairLength or 1)
	ret = ret .. self:Encode1(profile.HairQuality or 1)
	ret = ret .. self:Encode1(profile.HairColour or 1)
	ret = ret .. self:Encode1(profile.HairStreaks or 1)
	ret = ret .. self:Encode1(profile.Age or 1)
	ret = ret .. self:Encode1(profile.Gender or 1)
	ret = ret .. self:Encode1(profile.Race or 1)
	ret = ret .. self:AddEncodedValue(self:Encode1(1), protocolVersion, nil, 4) -- Sexuality, to be ignored
	ret = ret .. self:AddEncodedValue(self:Encode1(1), protocolVersion, nil, 4) -- Relationship, also to be ignored
	ret = ret .. self:Encode1(profile.EyeColour or 1)
	ret = ret .. self:Encode1(profile.Length or 1)
	ret = ret .. self:Encode1(profile.BodyType or 1)
	if profile.Scars ~= nil then
		ret = ret .. self:Encode1((#profile.Scars or 0) + 1)
		for k, v in ipairs(profile.Scars) do
			ret = ret .. self:Encode1(v or 1)
		end
	else ret = ret .. self:Encode1(1)
	end
	if profile.Tattoos ~= nil then
		ret = ret .. self:Encode1((#profile.Tattoos or 0) + 1)
		for k, v in ipairs(profile.Tattoos) do
			ret = ret .. self:Encode1(v or 1)
		end
	else ret = ret .. self:Encode1(1)
	end
	if profile.Talents ~= nil and protocolVersion <= 4 then
		ret = ret .. self:Encode1((#profile.Talents or 0) + 1)
		for k, v in ipairs(profile.Talents) do
			ret = ret .. self:Encode1(v or 1)
		end
	else ret = ret .. self:Encode1(1)
	end
	if profile.Disabilities ~= nil then
		ret = ret .. self:Encode1((#profile.Disabilities or 0) + 1)
		for k, v in ipairs(profile.Disabilities) do
			ret = ret .. self:Encode1(v or 1)
		end
	else ret = ret .. self:Encode1(1)
	end
	return ret
end

function ThisIsMe:DecodeGetFirstCharacters(inputTable, num, protocolVersion, protocolVersionMin, protocolVersionMax)
	if protocolVersionMin ~= nil and protocolVersion < protocolVersionMin then return nil end
	if protocolVersionMax ~= nil and protocolVersion > protocolVersionMax then return nil end
	local ret = inputTable.Message:sub(1, num)
	inputTable.Message = inputTable.Message:sub(num + 1, inputTable.Message:len())
	return ret
end

function ThisIsMe:DecodeProfile(input, profile)
	if input == nil then
		return nil
	end
	local protocolVersion = profile.ProtocolVersion or self.options.protocolVersion -- should always be filled in anyway.
	self:Print(9, "Received a profile with protocol version " .. protocolVersion)
	local inputTable = {Message = input}
	profile.Version = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 2, protocolVersion, nil, nil)) or profile.Version
	profile.HairStyle = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or profile.HairStyle
	profile.HairLength = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or profile.HairLength
	profile.HairQuality = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or profile.HairQuality
	profile.HairColour = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or profile.HairColour
	profile.HairStreaks = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or profile.HairStreaks
	profile.Age = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or profile.Age
	profile.Gender = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or profile.Gender
	profile.Race = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, 2, nil)) or profile.Race -- only in ProtocolVersion 2 and up
	self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, 4)) -- Sexuality, to be ignored
	self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, 4)) -- Relationship, also to be ignored
	profile.EyeColour = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or profile.EyeColour
	profile.Length = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or profile.Length
	profile.BodyType = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or profile.BodyType
	local amount = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) - 1
	profile.Scars = {}
	for i = 1, amount, 1 do
		profile.Scars[i] = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or 1
	end
	amount = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) - 1
	profile.Tattoos = {}
	for i = 1, amount, 1 do
		profile.Tattoos[i] = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or 1
	end
	if protocolVersion <= 4 then
		amount = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) - 1
		profile.Talents = nil
		for i = 1, amount, 1 do
			self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil))
		end
	end
	amount = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) - 1
	profile.Disabilities = {}
	for i = 1, amount, 1 do
		profile.Disabilities[i] = self:DecodeMore1(self:DecodeGetFirstCharacters(inputTable, 1, protocolVersion, nil, nil)) or 1
	end
	profile.Persist = not self:IsProfileDefault(profile)
	return profile
end

function ThisIsMe:GetProfileName(name)
	local profile = self.characterProfiles[name]
	if profile ~= nil then
		if profile.TextMap[1] ~= nil and profile.TextMap[1][1] ~= nil then
			local map = profile.TextMap[1][1]
			if profile.Snippets[map] ~= nil then return profile.Snippets[map] end
		end
	end
	if profile.Name ~= nil then return profile.Name end
	return name
end

function ThisIsMe:GetDefaultTextMap()
	return {
		{[1] = 1},
		{
			[3] = {
				[1] = 3,
				[3] = 2
			}
		}
	}
end

function ThisIsMe:ApplyDefaultTextMap(profile)
	if profile == nil then return end
	if type(profile) == "string" then profile = self.characterProfiles[profile] end
	profile.Snippets = profile.Snippets or {}
	profile.Snippets[3] = "Extra"
	profile.TextMap = self:GetDefaultTextMap()
end

function ThisIsMe:GetProfile(profileName)
	if self.characterProfiles[profileName] == nil then
		local newProfile = {}
		self.characterProfiles[profileName] = newProfile
		table.insert(self.sortedCharacterProfiles, {Name=profileName, Profile=newProfile, SortFunction="ProfileSort", SortTable=self})
		self:SortCharacterProfiles();
	end
	return self.characterProfiles[profileName]
end

function ThisIsMe:SortCharacterProfiles()
	table.sort(self.sortedCharacterProfiles, function(a,b) return a.SortTable[a.SortFunction](a.SortTable, a, b) end)
end

function ThisIsMe:GetProfileDefaults(name, unit)
	local profile = {}
	profile.Faction = "?"
	profile.Age = 1
	profile.Race = self:GetRaceEnum(unit) or 1
	profile.Gender = self:GetGenderEnum(unit) or 1
	profile.EyeColour = 1
	profile.BodyType = 1
	profile.Length = 1
	profile.HairColour = 1
	profile.HairStreaks = 1
	profile.HairStyle = 1
	profile.HairLength = 1
	profile.HairQuality = 1
	profile.TailSize = 1
	profile.TailState = 1
	profile.TailDecoration = 1
	profile.Tattoos = {} -- body modifications
	profile.Scars = {}
	profile.Talents = {}
	profile.Disabilities = {} -- list as physiognomy or anatomy ingame.
	profile.FacialHair = 1
	profile.Version = 2
	profile.StoredVersion = 1
	profile.ProtocolVersion = nil -- just to make sure.
	profile.Snippets = {}
	self:ApplyDefaultTextMap(profile)
	profile.Persist = false
	return profile
end

function ThisIsMe:IsProfileDefault(profile)
	if profile == self:Profile() then return false end
	if profile.Persist == true then return false end
	if profile.Age ~= 1 then return false end
	if profile.EyeColour ~= 1 then return false end
	if profile.BodyType ~= 1 then return false end
	if profile.Length ~= 1 then return false end
	if profile.HairColour ~= 1 then return false end
	if profile.HairStreaks ~= 1 then return false end
	if profile.HairStyle ~= 1 then return false end
	if profile.HairLength ~= 1 then return false end
	if profile.HairQuality ~= 1 then return false end
	if profile.TailSize ~= 1 then return false end
	if profile.TailState ~= 1 then return false end
	if profile.TailDecoration ~= 1 then return false end
	if profile.FacialHair ~= 1 then return false end
	if profile.TailDecoration ~= 1 then return false end
--	if profile.Version ~= 2 then return false end
	if #profile.Tattoos > 0 then return false end
	if profile.Talents == nil or #profile.Talents > 0 then return false end
	if #profile.Disabilities > 0 then return false end
	if #profile.Scars > 0 then return false end
	if profile.Snippets ~= nil then
		for k, v in pairs(profile.Snippets) do
			if v:len() > 0 and v ~= "Extra" then return false end
		end
	end
	return true
end

-----------------------------------------------------------------------------------------------
-- ProfileWindow Functions
-----------------------------------------------------------------------------------------------

ProfileWindow = {}

function ProfileWindow:new(o, windowName, parent)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	if windowName ~= nil then
		o.ownedWindow = Apollo.LoadForm(self:XmlDoc(), windowName, parent, self)
		o.ownedWindow:SetData(o)
		if windowName == "ProfileEntry" and o.ownedWindow ~= nil then
			o.titleText = o.ownedWindow:FindChild("EntryText")
			o.optionFrame = o.ownedWindow:FindChild("OptionFrame")
			o.contentFrame = o.ownedWindow:FindChild("AdditionalFrame")
			
			o.wndButtonsFrame = o.ownedWindow:FindChild("ButtonsWindow")
			o.wndButtonsContainer = o.ownedWindow:FindChild("ButtonsContainer")
		end
	end
	return o
end

function ProfileWindow:Print(logLevel, text)
	ThisIsMeInst:Print(logLevel, text)
end

function ProfileWindow:XmlDoc()
	return ThisIsMeInst.xmlDoc
end

function ProfileWindow:is(window)
	if getmetatable(window) == getmetatable(self) then return true end
	return false
end

function ProfileWindow:GetWindowAbsolutePosition(window)
	local position = window:GetClientRect() -- might want to change this to GetRect too. Otherwise I'm just gonna get rect.
	local x = position.nLeft
	local y = position.nTop
	local newWindow = window:GetParent()
	local left, top, right, bottom
	while newWindow ~= nil do
		left, top, right, bottom = newWindow:GetRect()
		x = x + left
		y = y + top
		newWindow = newWindow:GetParent()
	end
	return {nLeft = x, nTop = y, nRight = x + position.nWidth, nBottom = y + position.nHeight, nWidth = position.nWidth, nHeight = position.nHeight}
end

function ProfileWindow:RecalculateSize()
	local size = 0
	for k, v in pairs(self.ownedWindow:GetChildren()) do
		local wrapper = v:GetData()
		if self:is(wrapper) then
			wrapper:RecalculateSize()
			size = size + v:GetHeight()
		end
	end
	if self.title ~= nil or self.option ~= nil then
		size = size + 30
	end
	if self.content ~= nil then
		size = size + 300
	end
	return size + 6
end

function ProfileWindow:GetHeight()
	if self.ownedWindow == nil then return 0 end
	local left, top, right, bottom = self.ownedWindow:GetAnchorOffsets()
	return bottom - top
end

function ProfileWindow:SetTitle(title)
	self.title = title
	if self.titleText ~= nil then self.titleText:SetText(title) end
end

function ProfileWindow:SetOption(option)
	self.option = option
	if self.optionFrame ~= nil then self.optionFrame:SetText(option) end
end

function ProfileWindow:SetContent(content, profile, readonly)
	if type(content) == "string" then
		self:AddContentBox(content, 0, readonly)
	elseif type(content) == "number" then
		profile.Snippets = profile.Snippets or {}
		profile.Snippets[content] = profile.Snippets[content] or ""
		self:AddContentBox(profile.Snippets[content] or "", content, readonly)
	elseif type(content) == "table" then
		for k, v in sipairs(content) do
			local item = self:AddSubWindow()
			item:SetContent(v, profile, readonly)
		end
	end
end

function ProfileWindow:AddSubButtons(readonly)
	if not (self.wndButtonsFrame and self.wndButtonsContainer and self.optionFrame) then return end
	self.wndButtonsFrame:Show(true, true)
	
	local left, top, right, bottom = self.optionFrame:GetAnchorOffsets()
	right = -95
	if readonly then right = -35 end
	self.optionFrame:SetAnchorOffsets(left, top, right, bottom)
	left, top, right, bottom = self.wndButtonsFrame:GetAnchorOffsets()
	left = -92
	if readonly then left = -32 end
	self.wndButtonsFrame:SetAnchorOffsets(left, top, right, bottom)
	
	self.wndButtonsContainer:FindChild("UpButton"):Show(not readonly, true)
	self.wndButtonsContainer:FindChild("DownButton"):Show(not readonly, true)
	self.wndButtonsContainer:FindChild("RemoveButton"):Show(not readonly, true)
	self.wndButtonsContainer:ArrangeChildrenHorz()
end

function ProfileWindow:AddTextBox(defaultText, variableName)
	if self.optionFrame then
		self:ClearAllChildren(self.optionFrame)
		local textbox = Apollo.LoadForm(self:XmlDoc(), "EntryTextBox", self.optionFrame, ThisIsMeInst)
		local entryText = textbox:FindChild("TextBox")
		if entryText then
			entryText:SetText(defaultText)
			entryText:SetData(variableName)
			entryText:AddEventHandler("EditBoxChanged", "OnEntryTextChanged", self)
		end
		return textbox
	end
end

function ProfileWindow:AddContentBox(text, number, readonly)
	if self.contentFrame then
		self.ownedWindow:SetAnchorOffsets(0,0,0,150)
		self:ClearAllChildren(self.contentFrame)
		local textbox = Apollo.LoadForm(self:XmlDoc(), "LargeTextBox", self.contentFrame, ThisIsMeInst)
		local entryText = textbox:FindChild("TextBox")
		if entryText then
			entryText:SetText(text)
			if readonly then
				entryText:SetStyleEx("ReadOnly", true)
			else
				entryText:SetData(number)
				entryText:AddEventHandler("EditBoxChanged", "OnMessageEntryChanged", self)
			end
		end
		return textbox
	end
end

function ProfileWindow:AddSubWindow()
	return self:new({}, "ProfileEntry", self.ownedWindow)
end

function ProfileWindow:AddDropdownBox(list, selected, table, entryName)
	if self.optionFrame then
		self:ClearAllChildren(self.optionFrame)
		local menu = Apollo.LoadForm(self:XmlDoc(), "DropdownMenu", self.optionFrame, self)
		local entryText = menu:FindChild("DropdownButton")
		local window = Apollo.LoadForm(self:XmlDoc(), "DropdownWindow", nil, self)
		if entryText then
			entryText:SetText(list[selected] or "")
			if window then
				entryText:SetData(window)
				entryText:AttachWindow(window)
				window:SetData(entryText)
				window:Close()
			end
		end
		if window == nil then return end
		local container = window:FindChild("DropdownContainer")
		if container == nil then return end
		for k, v in ipairs(list) do
			local newEntry = Apollo.LoadForm(self:XmlDoc(), "DropdownEntry", container, self)
			local entryButton = newEntry:FindChild("DropdownEntryButton")
			entryButton:SetText(v)
			entryButton:SetData({Parent = self.ownedWindow, Table = table, Entry = entryName, Number = k})
		end
		container:ArrangeChildrenVert()
		return menu
	end
end

function ProfileWindow:OnDropdownSelection( wndHandler, wndControl, eMouseButton )
	local data = wndControl:GetData()
	if data == nil or type(data) ~= "table" then return end
	self:Print(9, "OnDropdownSelection")
	if data.Parent == nil or data.Number == nil or data.Table == nil or data.Entry == nil then return end
	local button = data.Parent:FindChild("DropdownButton")
	if button ~= nil then
		button:SetCheck(false)
		button:SetText(wndControl:GetText())
		self:Print(9, "Everything works")
	end
	data.Table[data.Entry] = data.Number
end

function ProfileWindow:OnDropdownOpen( wndHandler, wndControl, eMouseButton )
	local dropdown = wndControl:GetData()
	if dropdown ~= nil then
		local container = dropdown:FindChild("DropdownContainer")
		local numItems = 3
		if container ~= nil then
			numItems = #container:GetChildren()
		end
		dropdown:Invoke()
		local pos = self:GetWindowAbsolutePosition(wndControl)
		dropdown:SetAnchorOffsets(pos.nLeft - 7, pos.nBottom, pos.nRight + 7, pos.nBottom + 14 + numItems * 36)
		dropdown:SetAnchorPoints(0, 0, 0, 0)
	end
end

function ProfileWindow:OnDropdownClose( wndHandler, wndControl )
	local button = wndControl:GetData()
	if button ~= nil then
		button:SetCheck(false)
	end
end

function ProfileWindow:ClearAllChildren(item)
	if item ~= nil then
		local children = item:GetChildren()
		for idx, wnd in pairs(children) do
			wnd:Destroy()
		end
	end
end

-----------------------------------------------------------------------------------------------
-- ThisIsMe Instance
-----------------------------------------------------------------------------------------------

ThisIsMeInst = ThisIsMe:new()
ThisIsMeInst:Init()
