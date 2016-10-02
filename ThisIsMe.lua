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
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressed")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")
local redErrorText = ApolloColor.new("AddonError")
local defaultText = ApolloColor.new("UI_WindowTextDefault")
local listDefault = "CRB_Basekit:kitInnerFrame_MetalGold_FrameBright2"
local listSelected = "CRB_Basekit:kitInnerFrame_MetalGold_FrameBright"
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function ThisIsMe:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.tItems = {} -- keep track of all the list items
	o.wndSelectedListItem = nil -- keep track of which list item is currently selected
	
	o.characterProfiles = {}
	
	o.messageQueue = {}
	o.privateMessageQueue = {}
	
	o.seenEveryone = false
		
	o.hairStyle = {
		"N/A",
		"Other",
		"Plain",
		"Pig-tails",
		"Pony-tail",
		"Mohawk",
		"Dreadlocks",
		"Pompadour",
		"Mullet",
		"Comb-over"
	}
	
	o.hairLength = {
		{"N/A",
		"Other",
		"Bald",
		"Short",
		"Shoulder-Length",
		"Waist-Length",
		"Ass-Length"},
		{"N/A",
		"Other",
		"Bald",
		"Small",
		"Medium",
		"Large",
		"Huge"}
	}
	
	o.hairQuality = {
		"N/A",
		"Other",
		"Lustrous",
		"Glossy",
		"Dull",
		"Gelled",
		"Styled",
		"Well Kept",
		"Neatly Combed",
		"Plain",
		"Messy",
		"Untamed",
		"Leafy",
		"Unclean",
		"Ragged",
		"Very Curly",
		"Curly",
		"Spikey",
		"Braided",
		"Crystalline",
		"Full",
		"Thinning"
	}
	
	o.hairColour = {
		"N/A",
		"Other",
		"Gray"
	}
	
	o.tailSizes = {
		"N/A",
		"Other",
		"Long",
		"Short",
		"Cut Off",
		"Cut Short",
		"Thick",
		"Muscular",
		"Thin",
		"Ratty"
	}
	
	o.tailStates = {
		"N/A",
		"Other",
		"Fluffy",
		"Gloriously Fluffy",
		"Bald",
		"Patchy",
		"Scaled",
		"Leathery",
		"Cracked",
		"Dirty"
	}
	
	o.tailDecorations = {
		"N/A",
		"Other",
		"Circlet/Band",
		"Pierced - Loops",
		"Pierced - Studs"
	}
	
	o.talentTypes = {
		"N/A",
		"Other",
		"Jack of all trades",
		"Fire Magic",
		"Water Magic",
		"Earth Magic",
		"Air Magic",
		"Logic Magic",
		"Life Magic",
		"Nature-Speaker",
		"Weave Using",
		"Technomancer",
		"Alchemy",
		"Voodoo",
		"Excellent Hearing",
		"Excellent Sight",
		"Excellent Smell",
		"Heightened Senses",
		"Marksmanship",
		"Hunting",
		"Combat/Battle",
		"Military Strategy",
		"Engineering",
		"Hacking",
		"Piloting",
		"Racing",
		"Healing/Medicine",
		"Cooking",
		"Brewing",
		"Tea-Making",
		"Diplomacy",
		"Storytelling",
		"Comforting"
	}
	
	o.genders = {
		"N/A",
		"Other",
		"Male",
		"Female",
		"Transmale",
		"Transfemale",
		"Genderless" -- tempted to add "Mayonnaise"
	}
	
	o.races = {
		"N/A",
		"Other",
		"Aurin",
		"Chua",
		"Draken",
		"Granok",
		"Human",
		"Mechari",
		"Mordesh",
		"Cassian Highborn",
		"Cassian Lowborn",
		"Mixed"
	}
	
	o.portraits = {
		["3"]={"charactercreate:sprCharC_Finalize_RaceAurinM", "charactercreate:sprCharC_Finalize_RaceAurinF"},
		["5"]={"charactercreate:sprCharC_Finalize_RaceDrakenM", "charactercreate:sprCharC_Finalize_RaceDrakenF"},
		["6"]={"charactercreate:sprCharC_Finalize_RaceGranokM", "charactercreate:sprCharC_Finalize_RaceGranokF"},
		["7"]={"charactercreate:sprCharC_Finalize_RaceExileM", "charactercreate:sprCharC_Finalize_RaceExileF"},
		["8"]={"charactercreate:sprCharC_Finalize_RaceMechariM", "charactercreate:sprCharC_Finalize_RaceMechariF"},
		["9"]={"charactercreate:sprCharC_Finalize_RaceMordeshM", "charactercreate:sprCharC_Finalize_RaceMordeshF"}
	}
	o.portraitUnknown = "charactercreate:sprCharC_Finalize_SkillLevel1"
	o.portraitChua = "charactercreate:sprCharC_Finalize_RaceChua"
	o.portraitCassian = {"charactercreate:sprCharC_Finalize_RaceDomM", "charactercreate:sprCharC_Finalize_RaceDomF"}
	
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
	
	o.protocolVersionMin = 3
	o.protocolVersionMax = 4
	
	o.options = {}
	o.options.logLevel = 0
	o.options.debugMode = false
	o.options.protocolVersion = 3
	
    return o
end

-----------------------------------------------------------------------------------------------
-- Initialization Functions
-----------------------------------------------------------------------------------------------

function ThisIsMe:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function ThisIsMe:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("ThisIsMe.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
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
		self.wndItemList = self.wndMain:FindChild("ItemList")
	    self.wndMain:Show(false, true)

		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("tim", "OnThisIsMeOn", self)
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
		self:OnInterfaceMenuListHasLoaded()
		Apollo.RegisterEventHandler("ToggleMyAddon", "OnThisIsMeOn", self)

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
		self.wndOptions:Show(false, true)
	end
	self.startupTimer = ApolloTimer.Create(5, false, "CheckComms", self)
	self.dataCheckTimer = ApolloTimer.Create(1, true, "CheckData", self)
end

function ThisIsMe:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "This Is Me", {"ToggleMyAddon", "", "CRB_HUDAlerts:sprAlert_CallBase"})
end

---------------------------------------------------------------------------------------------------
-- Utility Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:Print(logLevel, strToPrint)
	if type(logLevel) == "number" and logLevel <= self.options.logLevel and self.options.debugMode == true then
		if self.errorBuffer then
			table.insert(self.errorMessages, strToPrint)
		else
		 	Print("TIM: " .. strToPrint)
		end
	end
end

function getCharAt(input, num)
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
		if unitRace == GameLib.CodeEnumRace.Aurin then race = 3
		elseif unitRace == GameLib.CodeEnumRace.Chua then race = 4
		elseif unitRace == GameLib.CodeEnumRace.Draken then race = 5
		elseif unitRace == GameLib.CodeEnumRace.Granok then race = 6
		elseif unitRace == GameLib.CodeEnumRace.Human then race = 7
		elseif unitRace == GameLib.CodeEnumRace.Mechari then race = 8
		elseif unitRace == GameLib.CodeEnumRace.Mordesh then race = 9
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
		else gender = 7 end
		return gender
	end
end

function ThisIsMe:Clamp(num, min, max)
	if num < min then return min end
	if num > max then return max end
	return num
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
	if self.currentFaction == nil and self:Unit() ~= nil then
		local factionNum = self:Unit():GetFaction()
		if factionNum  == 166 then
			self.currentFaction = "D"
		elseif factionNum  == 167 then
			self.currentFaction = "E"
		else
			self.currentFaction = "?"
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
	
	if self.profileEmptyCheck ~= true and self.currentProfile ~= nil then
		if next(self:Profile()) == nil or self:Profile().Version == nil then
			self.characterProfiles[self:Character()] = self:GetProfileDefaults(self:Character(), self:Unit())
			self:Print(5, "Profile was empty/unusable; resetting.")
		else
			self:Print(9, "Profile found; Name: " .. self.currentCharacter)
		end
		self.profileEmptyCheck = true
		self:Print(9, "Checked profile for content.")
	end
	
	if self.profileContentCheck ~= true and self.currentUnit ~= nil and self.currentProfile ~= nil then
		if self.currentProfile.Race == nil or self.races[self.currentProfile.Race] == nil or self.currentProfile.Race == 1 then
			self.currentProfile.Race = self:GetRaceEnum(self.currentUnit) or 1
		end
		if self.currentProfile.Gender == nil or self.genders[self.currentProfile.Gender] == nil or self.currentProfile.Gender == 1 then
			self.currentProfile.Gender = self:GetGenderEnum(self.currentUnit) or 1
		end
		self.profileContentCheck = true
	end
	
	if self.dataLoadedCheck ~= true and self.dataLoaded == true and self.currentCharacter ~= nil then
		if next(self.characterProfiles) == nil then
			self.characterProfiles[self.currentCharacter] = self:GetProfileDefaults(self.currentCharacter, self.currentUnit)
		end
		self.dataLoadedCheck = true
		self:Print(9, "Checked loaded data for content.")
	end
	
	if self.commCheck ~= true and self.Comm ~= nil and self.Comm:IsReady() and self.currentFaction ~= nil and self.currentCharacter ~= nil then
		self.commCheck = true
		if not self.announcedSelf then
			self:SendPresenceMessage()
		end
	end
	
	if not self.fullyLoaded and self.profileEmptyCheck and self.profileContentCheck and self.commCheck and self.dataLoaded and self.dataLoadedCheck then
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
	self:PopulateItemList()
	if self.seenEveryone ~= true then
		self:SendPresenceRequestMessage()
	end
end

function ThisIsMe:OnEditProfileClick()
	self.profileEdit = true
	self.profileCharacter = self:Character()
	self:OpenProfileView()
end

function ThisIsMe:OpenProfileView()
	if self.profileEdit then self.profileCharacter = self:Character() end
	self:CloseAllWindows()
	self.wndProfile:Invoke()
	local Title = self.wndProfile:FindChild("Title")
	if Title ~= nil then
		if self.characterProfiles[self.profileCharacter] ~= nil and self.characterProfiles[self.profileCharacter].Name ~= nil then
			Title:SetText(self.characterProfiles[self.profileCharacter].Name)
		elseif self.profileCharacter ~= nil then
			Title:SetText(self.profileCharacter)
		end
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
	self:PopulateProfileList()
end

-- when the Profile's Cancel button is clicked
function ThisIsMe:OnProfileCancel()
	self:OpenProfileList()
end
-- when the Profile's OK button is clicked
function ThisIsMe:OnProfileOK()
	if self.profileEdit == true and  self.editedProfile ~= nil and not self:CompareTableEqualBoth(self.characterProfiles[self:Character()], self.editedProfile) then
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
		end
	end
	return {characterProfiles = self.characterProfiles, options = self.options}
end

function ThisIsMe:OnRestore(eLevel, tData)
	if GameLib.CodeEnumAddonSaveLevel.Realm then
		if tData.characterProfiles ~= nil then
			if next(tData.characterProfiles) ~= nil then
				self.characterProfiles = {}
				for k, v in pairs(tData.characterProfiles) do
					self.characterProfiles[k] = self:CopyTable(v, self:GetProfileDefaults(k))
					self.characterProfiles[k].ProtocolVersion = nil
					if self.characterProfiles[k].Messages ~= nil then
						if self.characterProfiles[k].Snippets == nil then
							self.characterProfiles[k].Snippets = self.characterProfiles[k].Messages
						end
						self.characterProfiles[k].Messages = nil
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
		self.dataLoaded = true
	end
	self:CheckData()
end

function ThisIsMe:OnOptionsClick( wndHandler, wndControl, eMouseButton )
	self:OpenOptions()
end

function ThisIsMe:OnTestClick( wndHandler, wndControl, eMouseButton )
	local profile = self:GetProfileDefaults("Test", nil)
	profile.Race = 3
	profile.Gender = 4
	profile.HairQuality = 6
	profile.ProtocolVersion = 2
	self:DecodeProfile(self:EncodeProfile(profile), self:GetProfileDefaults("Test2", nil))
	self:Print(9, "Race: " .. profile.Race .. ", gender: " .. profile.Gender .. ", hair quality: " .. profile.HairQuality)
end

-----------------------------------------------------------------------------------------------
-- ItemList Functions
-----------------------------------------------------------------------------------------------
function ProfileSort(profile1, profile2)
	if profile1 == nil then
		if profile2 == nil then
			return false
		end
		return false
	end
	if profile2 == nil then return false end
	return profile1.Name < profile2.Name
end

-- populate item list
function ThisIsMe:PopulateItemList()
	-- make sure the item list is empty to start with
	self:DestroyItemList()
	
    -- add profiles
	local ordered = {}
	for k, v in pairs(self.characterProfiles) do
		if k ~= nil and v ~= nil then
			table.insert(ordered, {Name=k, Profile=v})
		end
	end
	table.sort(ordered, ProfileSort)
	for k, v in ipairs(ordered) do
        self:AddItem(v.Name, v.Profile)
	end
	
	-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
	self.wndItemList:ArrangeChildrenVert()
	
	local testButton = self.wndMain:FindChild("TestButton")
	if testButton then
		testButton:Show(self.options.debugMode == true, true)
	end
end

-- clear the item list
function ThisIsMe:DestroyItemList()
	if self.wndItemList ~= nil then
		local children = self.wndItemList:GetChildren()
		-- destroy all the wnd inside the list
		for idx, wnd in pairs(children ) do
			wnd:Destroy()
		end
	end

	-- clear the list item array
	self.tItems = {}
	self.wndSelectedListItem = nil
end

-- add an item into the item list
function ThisIsMe:AddItem(name, profile)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "ListItem", self.wndItemList, self)
	
	-- keep track of the window item created
	self.tItems[wnd] = name
	
	self:SetItem(wnd, name, profile)
	
	wnd:SetData(name)
end

function ThisIsMe:SetItem(item, name, profile)
	-- give it a piece of data to refer to 
	local wndItemText = item:FindChild("Name")
	if wndItemText then
		wndItemText:SetText(" " .. (profile.Name or name or ""))
		wndItemText:SetTextColor(kcrNormalText)
		item:SetSprite(listDefault)
	end
	local wndIngameName = item:FindChild("IngameName")
	if wndIngameName then
		wndIngameName:SetText(" IG: " .. name)
	end
	local wndVersionText = item:FindChild("Version")
	local upToDate = false
	if wndVersionText then
		if (profile.Version ~= nil and profile.StoredVersion ~= nil and profile.Version == profile.StoredVersion) or name == self:Character() then
			wndVersionText:SetText(" Up to date")
			wndVersionText:SetTextColor(defaultText)
			upToDate = true
		else
			wndVersionText:SetText(" Outdated!")
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
		local text = " "
		if showGender then
		text = text .. self.genders[profile.Gender]
		end
		if showRace then
			if showGender then text = text .. " " end
			text = text .. self.races[profile.Race]
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
	end
end

function ThisIsMe:UpdateItemByName(name)
	for k, v in pairs(self.tItems) do
		if v == name then
			self:SetItem(k, v, self.characterProfiles[v])
			break
		end
	end
end

-- when a list item is selected
function ThisIsMe:OnListItemSelected(wndHandler, wndControl)
    -- make sure the wndControl is valid
    if wndHandler ~= wndControl then
        return
    end
    
    -- change the old item's text color back to normal color
    local wndItemText
    if self.wndSelectedListItem ~= nil then
        wndItemText = self.wndSelectedListItem:FindChild("Name")
        wndItemText:SetTextColor(kcrNormalText)
		self.wndSelectedListItem:SetSprite(listDefault)
    end
    
	-- wndControl is the item selected - change its color to selected
	self.wndSelectedListItem = wndControl
	wndItemText = self.wndSelectedListItem:FindChild("Name")
    wndItemText:SetTextColor(kcrSelectedText)
	self.wndSelectedListItem:SetSprite(listSelected)
    
	self.profileCharacter = self.wndSelectedListItem:GetData()
end

function ThisIsMe:PopulateProfileList()
	if self.profileEdit == true then self.profileCharacter = self:Character() end
	self:Print(1, "Populating profile view: " .. (self.profileCharacter or "literally nobody, your currentCharacter variable is empty"))
	self:DestroyProfileView()
	
	if self.profileCharacter == nil or self.characterProfiles[self.profileCharacter] == nil then return end
	
	local profile = self.characterProfiles[self.profileCharacter]
	
	local item = nil
	
	if self.profileEdit then
		self.editedProfile = self:CopyTable(self.characterProfiles[self.profileCharacter], self:GetProfileDefaults(self.profileCharacter))
		self.editedProfile.Version = ((self.editedProfile.Version or 1) % (64 * 64)) + 1
		self.editedProfile.StoredVersion = self.editedProfile.Version
		profile = self.editedProfile
		item = self:AddProfileEntry(self.wndProfileContainer, "Name")
		self:AddTextBox(item, profile.Name or self.profileCharacter or "Name", "Name")
		
		if self.options.debugMode then
			item = self:AddProfileEntry(self.wndProfileContainer, "Gender")
			self:AddDropdownBox(item, self.genders, profile.Gender or 1, profile, "Gender")
			item = self:AddProfileEntry(self.wndProfileContainer, "Race")
			self:AddDropdownBox(item, self.races, profile.Race or 1, profile, "Race")
			item = self:AddProfileEntry(self.wndProfileContainer, "Hair Length")
			self:AddDropdownBox(item, self.hairLength[1], profile.HairLength or 1, profile, "Hair Length")
			item = self:AddProfileEntry(self.wndProfileContainer, "Hair Quality")
			self:AddDropdownBox(item, self.hairQuality, profile.HairQuality or 1, profile, "Hair Quality")
			item = self:AddProfileEntry(self.wndProfileContainer, "Hair Style")
			self:AddDropdownBox(item, self.hairStyle, profile.HairStyle or 1, profile, "Hair Style")
		end
		
		item = self:AddProfileEntry(self.wndProfileContainer, "Extra")
		if profile.Snippets ~= nil then
			self:AddMessageTextBox(item, profile.Snippets[2] or "", 2)
		else
			self:AddMessageTextBox(item, "", 2)
		end
	else
		self:AddProfileEntry(self.wndProfileContainer, "Name", profile.Name or self.profileCharacter or "Name")
		if profile.Gender ~= nil and profile.Gender >= 2 then self:AddProfileEntry(self.wndProfileContainer, "Gender", self.genders[profile.Gender or 2]) end
		if profile.Race ~= nil and profile.Race >= 2 then self:AddProfileEntry(self.wndProfileContainer, "Race", self.races[profile.Race or 2]) end
		if profile.HairLength ~= nil and profile.HairLength >= 2 then self:AddProfileEntry(self.wndProfileContainer, "Hair Length", self.hairLength[1][profile.HairLength or 2]) end
		if profile.HairQuality ~= nil and profile.HairQuality >= 2 then self:AddProfileEntry(self.wndProfileContainer, "Hair Quality", self.hairQuality[profile.HairQuality or 2]) end
		if profile.HairStyle ~= nil and profile.HairStyle >= 2 then self:AddProfileEntry(self.wndProfileContainer, "Hair Style", self.hairStyle[profile.HairStyle or 2]) end
		if profile.Snippets ~= nil then
			for k, v in pairs(profile.Snippets) do
				if type(k) == "number" and k ~= 1 then
					item = self:AddProfileEntry(self.wndProfileContainer, "Extra", "")
					self:AddMessageDisplayBox(item, v)
				end
			end
		end
	end
	self.wndProfileContainer:ArrangeChildrenVert()
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
	local item = Apollo.LoadForm(self.xmlDoc, "ProfileEntry", self.wndProfileContainer, self)
	local entryText = item:FindChild("EntryText")
	entryText:SetText(entryName)
	local optionFrame = item:FindChild("OptionFrame")
	optionFrame:SetText(defaultText or "")
	return item
end

function ThisIsMe:AddTextBox(item, defaultText, variableName)
	if item == nil then return end
	local wndOptionFrame = item:FindChild("OptionFrame")
	if wndOptionFrame then
		self:ClearAllChildren(wndOptionFrame)
		local textbox = Apollo.LoadForm(self.xmlDoc, "EntryTextBox", wndOptionFrame, self)
		local entryText = textbox:FindChild("TextBox")
		if entryText then
			entryText:SetText(defaultText)
			entryText:SetData(variableName)
			entryText:AddEventHandler("EditBoxChanged", "OnEntryTextChanged", self)
		end
		return textbox
	end
end

function ThisIsMe:AddMessageTextBox(item, defaultText, number)
	if item == nil then return end
	local wndOptionFrame = item:FindChild("AdditionalFrame")
	if wndOptionFrame then
		item:SetAnchorOffsets(0,0,0,150)
		self:ClearAllChildren(wndOptionFrame)
		local textbox = Apollo.LoadForm(self.xmlDoc, "LargeTextBox", wndOptionFrame, self)
		local entryText = textbox:FindChild("TextBox")
		if entryText then
			entryText:SetText(defaultText)
			entryText:SetData(number)
			entryText:AddEventHandler("EditBoxChanged", "OnMessageEntryChanged", self)
		end
		return textbox
	end
end

function ThisIsMe:AddMessageDisplayBox(item, text)
	if item == nil then return end
	local wndOptionFrame = item:FindChild("AdditionalFrame")
	if wndOptionFrame then
		item:SetAnchorOffsets(0,0,0,150)
		self:ClearAllChildren(wndOptionFrame)
		local textbox = Apollo.LoadForm(self.xmlDoc, "LargeTextBox", wndOptionFrame, self)
		local entryText = textbox:FindChild("TextBox")
		if entryText then
			entryText:SetText(text)
			entryText:SetStyleEx("ReadOnly", true)
		end
		return textbox
	end
end

function ThisIsMe:AddDropdownBox(item, list, selected, table, entryName)
	if item == nil then return end
	local wndOptionFrame = item:FindChild("OptionFrame")
	if wndOptionFrame then
		self:ClearAllChildren(wndOptionFrame)
		local menu = Apollo.LoadForm(self.xmlDoc, "DropdownMenu", wndOptionFrame, self)
		local entryText = menu:FindChild("DropdownButton")
		local window = menu:FindChild("DropdownWindow")
		if entryText then
			entryText:SetText(list[selected] or "")
			if window then
				entryText:AttachWindow(window)
				window:Close()
			end
		end
		if item == nil then return end
		container = item:FindChild("DropdownContainer")
		if container == nil then return end
		for k, v in ipairs(list) do
			local newEntry = Apollo.LoadForm(self.xmlDoc, "DropdownEntry", container, self)
			newEntry:SetText(v)
			newEntry:SetData({Parent = item, Table = table, Entry = entryname, Number = k})
			newEntry:SetFocus()
		end
		window:SetAnchorOffsets(0, 0, 0, 6 + (30 * #list))
		container:ArrangeChildrenVert()
		return menu
	end
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
-- DropdownEntry Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:OnDropdownSelection( wndHandler, wndControl, eMouseButton )
	self:Print(1, "Pressed button")
	local data = wndControl:GetData()
	if data == nil or data ~= "table" then return end
	if data.Parent == nil or data.Number == nil or data.Table == nil or data.Entry == nil then return end
	data.Parent:SetCheck(false)
	data.Parent:SetText(wndControl:GetText())
	data.Table[data.Entry] = data.Number
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
	for k, v in pairs(self.tItems) do
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
	local data = wndControl:GetData()
	if data ~= nil then
		self.editedProfile[data] = wndControl:GetText()
	end
end

function ThisIsMe:OnMessageEntryChanged( wndHandler, wndControl, strText )
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
		debugText:SetText("  Debug Level: " .. (self.options.logLevel or 0))
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
		protocolText:SetText("  Protocol Version: " .. (self.options.protocolVersion or self.protocolVersionMin))
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
	self.options.debugMode = newOptions.debugMode or self.options.debugMode
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
			debugText:SetText("  Debug Level: " .. fNewValue)
		end
	end
end

function ThisIsMe:OnProtocolVersionChange( wndHandler, wndControl, fNewValue, fOldValue )
	self.newOptions.protocolVersion = fNewValue
	if self.wndOptions ~= nil then
		local debugText = self.wndOptions:FindChild("ProtocolVersion")
		if debugText then
			debugText:SetText("  Protocol Version: " .. fNewValue)
		end
	end
end

function ThisIsMe:OnDebugModeToggle( wndHandler, wndControl, eMouseButton )
	self.newOptions.debugMode = wndControl:IsChecked()
end

---------------------------------------------------------------------------------------------------
-- DropdownMenu Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:OnDropdownWindowClosed( wndHandler, wndControl )
	local window = Apollo.GetMouseTargetWindow()
	self:Print(1, "Current window's text: " .. window:GetText())
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

function ThisIsMe:SetupComms()
	if self.startupTimer ~= nil then
		return
	end
	self.startupTimer = ApolloTimer.Create(30, false, "SetupComms", self) -- automatically retry if something goes wrong.
	
	if self.Comm ~= nil and self.Comm:IsReady() then
		return
	end
	self.Comm = ICCommLib.JoinChannel(self.channel, ICCommLib.CodeEnumICCommChannelType.Global)
	if self.Comm ~= nil then
		self.Comm:SetJoinResultFunction("OnJoinResult", self)
		self.Comm:SetReceivedMessageFunction("OnMessageReceived", self)
		self.Comm:SetSendMessageResultFunction("OnMessageSent", self)
		self.Comm:SetThrottledFunction("OnMessageThrottled", self)
	else
		self:Print(1, "Failed to open channel")
	end
end

function ThisIsMe:OnJoinResult(channel, eResult)
	if self.startupTimer ~= nil then
		self.startupTimer:Stop()
		self.startupTimer = nil
	end
	
	if eResult == ICCommLib.CodeEnumICCommJoinResult.Join then
		self:Print(9, string.format('Joined ICComm Channel "%s"', channel:GetName()))
		if channel:IsReady() then
			self:Print(9, 'Channel is ready to transmit')
		else
			self:Print(1, 'Channel is not ready to transmit')
		end
	elseif eResult == ICCommLib.CodeEnumICCommJoinResult.BadName then
		self:Print(1, 'Channel ' .. channel .. ' has a bad name.')
	elseif eResult == ICCommLib.CodeEnumICCommJoinResult.Left then
		self:Print(1, 'Failed to join channel')
	elseif eResult == ICCommLib.CodeEnumICCommJoinResult.MissingEntitlement then
		self:Print(1, 'Failed to join channel')
	elseif eResult == ICCommLib.CodeEnumICCommJoinResult.NoGroup then
		self:Print(1, 'Failed to join channel')
	elseif eResult == ICCommLib.CodeEnumICCommJoinResult.NoGuild then
		self:Print(1, 'Failed to join channel')
	elseif eResult == ICCommLib.CodeEnumICCommJoinResult.TooManyChannels then
		self:Print(1, "You are in too many channels to join the TIM channel")
	else
		self:Print(1, 'Failed to join channel; join result: ' .. eResult)
	end
end

function ThisIsMe:OnMessageReceived(channel, strMessage, strSender)
	self:Print(5, "Received message: " .. strMessage .. " from: " .. strSender)
	if self.characterProfiles[strSender] ~= nil then self:ProcessMessage(channel, strMessage, strSender, self.characterProfiles[strSender].ProtocolVersion)
	else self:ProcessMessage(channel, strMessage, strSender, nil)
	end
end

function ThisIsMe:ProcessMessage(channel, strMessage, strSender, protocolVersion)
	if self.characterProfiles[strSender] == nil then shouldUpdate = true end
	self.characterProfiles[strSender] = self.characterProfiles[strSender] or self:GetProfileDefaults(strSender)
	local profile = self.characterProfiles[strSender]
	
	local shouldUpdate = false
	local shouldProcessBacklog = false
	
	local firstCharacter = strMessage:sub(1,1)
	
	local shouldIgnore = (not self:AllowedProtocolVersion(protocolVersion))
	
	if firstCharacter == "E" or firstCharacter == "D" or firstCharacter == "?" then
		shouldUpdate = true
		profile.Faction = firstCharacter
		if strMessage:len() > 1 then
			protocolVersion = self:DecodeMore(strMessage:sub(2,3))
			profile.ProtocolVersion = protocolVersion
			if self:AllowedProtocolVersion(protocolVersion) then
				local newVersion = self:DecodeMore(strMessage:sub(4,5))
				profile.Version = newVersion
			end
		end
		shouldProcessBacklog = true
	end
	
	if protocolVersion == nil then
		profile.BufferedMessages = profile.BufferedMessages or {}
		table.insert(profile.BufferedMessages, strMessage)
		self:AddBufferedMessage("#", strSender)
		self:Print(1, "Unknown protocol message received from " .. strSender)
		return
	end	
	if firstCharacter == "#" and not shouldIgnore then
		self:SendPresenceMessage()
		self.seenEveryone = true
	end
	if firstCharacter == "@" and not shouldIgnore then
		self.characterProfiles[strSender] = self:DecodeProfile(strMessage:sub(2, strMessage:len()), profile)
		profile = self.characterProfiles[strSender]
		shouldUpdate = shouldUpdate or (profile.StoredVersion ~= profile.Version)
		profile.StoredVersion = profile.Version
	end
	if firstCharacter == "~" and not shouldIgnore then
		self:SendBasicProfile()
	end
	if firstCharacter == "$" and not shouldIgnore then
		self:ReceiveTextEntry(strSender, strMessage:sub(2, strMessage:len()))
	end
	if not shouldIgnore then
		self:ReceiveWrappedMessage(strMessage, strSender, protocolVersion)
	end
	
	if shouldUpdate then self:PopulateItemList() end
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

function ThisIsMe:SendPresenceMessage()
	if self:Faction() ~= nil then
		local message = self:Faction()
		if self.options.protocolVersion ~= nil then
			message = message .. self:EncodeMore(self.options.protocolVersion, 2)
		end
		if self.characterProfiles[self:Character()] == nil then self.characterProfiles[self:Character()] = self:GetProfileDefaults(self:Character(), self:Unit()) end
		if self.characterProfiles[self:Character()].Version ~= nil then
			message = message .. self:EncodeMore(self.characterProfiles[self:Character()].Version, 2)
		end
		self:AddBufferedMessage(message)
		self.announcedSelf = true
	end
end

function ThisIsMe:SendPresenceRequestMessage()
	self:AddBufferedMessage("#")
	if self:Faction() ~= nil then
		self:SendPresenceMessage()
	end
	self.seenEveryone = true
end

function ThisIsMe:SendProfileRequestMessage(name)
	self:AddBufferedMessage("~", name)
end

function ThisIsMe:SendBasicProfile()
	self:Print(5, "Sending profile")
	if self:Profile() ~= nil then
		self:AddBufferedMessage("@" .. self:EncodeProfile(self:Profile()))
		if self:Profile().Name ~= nil then
			self:SendTextEntry(1, self:Profile().Name)
		end
		if self:Profile().Snippets ~= nil then
			for k, v in pairs(self:Profile().Snippets) do
				local num = k + 0
				if type(num) == "number" and num ~= 1 then
					self:SendTextEntry(num, v)
				end
			end
		end
	end
end

function ThisIsMe:SendTextEntry(number, text)
	if self.options.protocolVersion <= 2 then
		local num = math.floor(text:len() / 75) + 1
		local pos = 0
		local parts = {}
		for i=1,num do
			parts[i] = text:sub(pos, pos + 74)
			pos = pos + 75
		end
		for k, v in pairs(parts) do
			self:AddBufferedMessage("$" .. self:Encode(number) .. self:Encode(k) .. self:Encode(#parts) .. v)
		end
	else
		self:AddBufferedMessage("$" .. self:Encode(number) .. "AA" .. text)
	end
end

function ThisIsMe:ReceiveTextEntry(sender, text)
	if text ~= nil and sender ~= nil then
		local number = self:Decode(text:sub(1,1))
		local part = self:Decode(text:sub(2,2))
		local total = self:Decode(text:sub(3,3))
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
		if number == 1 then self.characterProfiles[sender].Name = completeMessage end
	end
end

function ThisIsMe:SendWrappedMessage(text, recipient, protocolVersion)
	if self.options.protocolVersion <= 1 then return end
	local pos = 1
	local length = text:len()
	local prefix = ""
	local number = self.wrappedTextNumber or 1
	local sequenceNum = 1
	self.wrappedTextNumber = (number % 64) + 1
	while pos <= length do
		local chunkSize = self.messageCharacterLimit - 5
		if pos == 1 then
			chunkSize = self.messageCharacterLimit - 4
			local protocolVersionNum = ""
			if self.options.protocolVersion >= 4 then
				chunkSize = chunkSize - 3
				prefix = "%" .. self:Encode(number) .. self:EncodeMore(protocolVersion, 2) .. self:EncodeMore(length, 2)
			else
				prefix = "%" .. self:Encode(number) .. self:EncodeMore(length, 2)
			end
		elseif pos <= length - self.messageCharacterLimit - 4 then
			chunkSize = self.messageCharacterLimit - 2
			if self.options.protocolVersion >= 4 then
				prefix = "^" .. self:Encode(number) .. self:Encode(sequenceNum)
			else
				prefix = "^" .. self:Encode(number)
			end
		else
			chunkSize = self.messageCharacterLimit - 4
			if self.options.protocolVersion >= 4 then
				prefix = "&" .. self:Encode(number) .. self:Encode(sequenceNum) .. self:EncodeMore(length, 2)
			else
				prefix = "&" .. self:Encode(number) .. self:EncodeMore(length, 2)
			end
		end
		self:AddBufferedMessage(prefix .. text:sub(pos, pos + chunkSize - 1), recipient)
		pos = pos + chunkSize
		sequenceNum = sequenceNum + 1
	end
end

function ThisIsMe:ReceiveWrappedMessage(strMessage, strSender, protocolVersion)
	local profile = self.characterProfiles[strSender]
	if profile == nil then return end
	local firstCharacter = strMessage:sub(1, 1)
	if not self:AllowedProtocolVersion(protocolVersion) or protocolVersion < 3 then return false end
	local offset = 0
	if firstCharacter == "%" or firstCharacter == "^" or firstCharacter == "&" then
		local messageID = self:Decode(strMessage:sub(2 + offset, 2 + offset))
		if protocolVersion >= 4 and firstCharacter ~= "%" then
			local sequenceNum = self:Decode(strMessage:sub(3 + offset, 3 + offset))
			if sequenceNum ~= ((profile.WrappedMessages[messageID].LastSequenceNum or 1) % 64) + 1 then
				profile.WrappedMessages[messageID] = nil -- message received out of sequence
				return
			end
			offset = offset + 1
		end
		if firstCharacter == "%" then
			local protocolContained = protocolVersion
			if protocolVersion >= 4 then
				protocolContained = self:DecodeMore(strMessage:sub(3 + offset, 4 + offset))
				offset = offset + 2
			end
			local length = self:DecodeMore(strMessage:sub(3 + offset, 4 + offset))
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
		end
		if firstCharacter == "&" then
			local length = self:DecodeMore(strMessage:sub(3 + offset, 4 + offset))
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

function ThisIsMe:CheckUnknownProtocol(protocolVersion, sender)
	if protocolVersion == nil then
		if sender ~= nil then
			self:AddBufferedMessage("#", sender, nil)
		end
		return true
	end
	return false
end

function ThisIsMe:OnTimer()
	self.messageLoop()
end

function ThisIsMe:messageLoop()
	if #self.messageQueue <= 0 and #self.privateMessageQueue <= 0 then
		self.sendTimer:Stop()
		self.sendTimer = nil
	else
		if #self.messageQueue > 0 then
			local handled = false
			if self.messageQueue[1].Message == nil then handled = true 
			elseif self.messageQueue[1].Message:len() > self.messageCharacterLimit or self.messageQueue[1].ProtocolVersion ~= self.options.protocolVersion then
				handled = true
				self:SendWrappedMessage(self.messageQueue[1].Message, self.messageQueue[1].Recipient, self.messageQueue[1].ProtocolVersion or self.options.protocolVersion)
			elseif self:SendMessage(self.messageQueue[1].Message, self.messageQueue[1].Recipient) then handled = true end
			if handled then
				table.remove(self.messageQueue, 1)
			end
		end
	end
end

function ThisIsMe:AddBufferedMessage(message, recipient, protocolVersion)
	if self.messageQueue == nil then self.messageQueue = {} end
	table.insert(self.messageQueue, {Recipient = recipient, Message = message, ProtocolVersion = protocolVersion or self.options.protocolVersion})
	if self.sendTimer == nil then
		self.sendTimer = ApolloTimer.Create(1.0, true, "messageLoop", self)
		self:messageLoop()
	end
end

function ThisIsMe:SendMessage(message, recipient)
	if message == nil then
		return true
	end
	if self.Comm == nil then
		self:SetupComms()
		return false
	elseif not self.Comm:IsReady() then
		self:SetupComms()
		return false
	end
	if recipient ~= nil then
		if self.Comm:SendMessage(message) then
			self:Print(5, "Message Sent: " .. message)
			return true
		end
	else
		if self.Comm:SendMessage(message, recipient) then
			if recipient ~= nil then
				self:Print(5, "Message Sent to " .. recipient .. ": " .. message)
			else
				self:Print(5, "Message Sent: " .. message)
			end
			return true
		end
	end
	self:Print(5, "Message sending failed: " .. message)
	return false
end

---------------------------------------------------------------------------------------------------
-- Encoding/Decoding Functions
---------------------------------------------------------------------------------------------------

function ThisIsMe:Encode(numToEncode)
	if numToEncode == nil then
		return '-'
	end
	local b64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	return b64:sub(numToEncode,numToEncode)
end

function ThisIsMe:EncodeMore(num, amount)
	if num == nil or amount == nil then return end
	num = num - 1
	local ret = ""
	for i=1, amount, 1 do
		ret = ret .. self:Encode((num % 64) + 1)
		num = num / 64
	end
	return ret
end

function ThisIsMe:Decode(charToDecode) 
	if charToDecode == '-' then
		return nil
	end
	local b64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	return string.find(b64, charToDecode,1)
end

function ThisIsMe:DecodeMore(str)
	if str == nil then return 0 end
	local num = 0
	local mult = 1
	for i=1, str:len(), 1 do
		num = num + (self:Decode(str:sub(i,i)) - 1) * mult
		mult = mult * 64
	end
	return num + 1
end

function ThisIsMe:AllowedProtocolVersion(num)
	if num == nil or type(num) ~= "number" then return nil end
	if num >= 1 and num <= 4 then return true end
	return false
end

function ThisIsMe:EncodeProfile(profile)
	if profile == nil then
		return nil
	end
	local protocolVersion = profile.ProtocolVersion or self.options.protocolVersion -- should always be filled in anyway.
	local ret = ""
	ret = ret .. self:EncodeMore(profile.Version or 1, 2)
	ret = ret .. self:Encode(profile.HairStyle or 1)
	ret = ret .. self:Encode(profile.HairLength or 1)
	ret = ret .. self:Encode(profile.HairQuality or 1)
	ret = ret .. self:Encode(profile.HairColour or 1)
	ret = ret .. self:Encode(profile.HairStreaks or 1)
	ret = ret .. self:Encode(profile.Age or 1)
	ret = ret .. self:Encode(profile.Gender or 1)
	if protocolVersion >= 2 then ret = ret .. self:Encode(profile.Race or 1) end
	ret = ret .. self:Encode(profile.Sexuality or 1)
	ret = ret .. self:Encode(profile.Relationship or 1)
	ret = ret .. self:Encode(profile.EyeColour or 1)
	ret = ret .. self:Encode(profile.Length or 1)
	ret = ret .. self:Encode(profile.BodyType or 1)
	if profile.Scars ~= nil then
		ret = ret .. self:Encode((#profile.Scars or 0) + 1)
		for k, v in ipairs(profile.Scars) do
			ret = ret .. self:Encode(v or 1)
		end
	else ret = ret .. self:Encode(1)
	end
	if profile.Tattoos ~= nil then
		ret = ret .. self:Encode((#profile.Tattoos or 0) + 1)
		for k, v in ipairs(profile.Tattoos) do
			ret = ret .. self:Encode(v or 1)
		end
	else ret = ret .. self:Encode(1)
	end
	if profile.Talents ~= nil then
		ret = ret .. self:Encode((#profile.Talents or 0) + 1)
		for k, v in ipairs(profile.Talents) do
			ret = ret .. self:Encode(v or 1)
		end
	else ret = ret .. self:Encode(1)
	end
	if profile.Disabilities ~= nil then
		ret = ret .. self:Encode((#profile.Disabilities or 0) + 1)
		for k, v in ipairs(profile.Disabilities) do
			ret = ret .. self:Encode(v or 1)
		end
	else ret = ret .. self:Encode(1)
	end
	return ret
end

function ThisIsMe:DecodeProfile(input, profile)
	if input == nil then
		return nil
	end
	local protocolVersion = profile.ProtocolVersion or self.options.protocolVersion -- should always be filled in anyway.
	self:Print(9, "Received a profile with protocol version " .. protocolVersion)
	local offset = 0
	for i = 1, input:len(), 1 do
		local actualNum = i + offset
		local char = getCharAt(input, actualNum)
		local protocolOffset1 = 0
		if protocolVersion >= 2 then protocolOffset1 = 1 end
		if char ~= nil then
			if i == 1 then
				profile.Version = self:DecodeMore(input:sub(1,2))
				offset = offset + 1
			elseif i == 2 then profile.HairStyle = self:Decode(char)
			elseif i == 3 then profile.HairLength = self:Decode(char) -- include race, and check for other missing stuff!
			elseif i == 4 then profile.HairQuality = self:Decode(char)
			elseif i == 5 then profile.HairColour = self:Decode(char)
			elseif i == 6 then profile.HairStreaks = self:Decode(char)
			elseif i == 7 then profile.Age = self:Decode(char)
			elseif i == 8 then profile.Gender = self:Decode(char)
			elseif i == 9 and protocolOffset1 >= 1 then profile.Race = self:Decode(char)
			elseif i == 9 + protocolOffset1 then profile.Sexuality = self:Decode(char)
			elseif i == 10 + protocolOffset1 then profile.Relationship = self:Decode(char)
			elseif i == 11 + protocolOffset1 then profile.EyeColour = self:Decode(char)
			elseif i == 12 + protocolOffset1 then profile.Length = self:Decode(char)
			elseif i == 13 + protocolOffset1 then profile.BodyType = self:Decode(char)
			elseif i == 14 + protocolOffset1 then
				profile.Scars = {}
				local amount = self:Decode(char) - 1
				for j = 1, amount, 1 do
					profile.Scars[j] = self:Decode(getCharAt(input, actualNum + j))
				end
				offset = offset + amount
			elseif i == 15 + protocolOffset1 then
				profile.Tattoos = {}
				local amount = self:Decode(char) - 1
				for j = 1, amount, 1 do
					profile.Tattoos[j] = self:Decode(getCharAt(input, actualNum + j))
				end
				offset = offset + amount
			elseif i == 16 + protocolOffset1 then
				profile.Talents = {}
				local amount = self:Decode(char) - 1
				for j = 1, amount, 1 do
					profile.Talents[j] = self:Decode(getCharAt(input, actualNum + j))
				end
				offset = offset + amount
			elseif i == 17 + protocolOffset1 then
				profile.Disabilities = {}
				local amount = self:Decode(char) - 1
				for j = 1, amount, 1 do
					profile.Disabilities[j] = self:Decode(getCharAt(input, actualNum + j))
				end
				offset = offset + amount
			end
		end
	end
	return profile
end

function ThisIsMe:GetProfileDefaults(name, unit)
	local profile = {}
	profile.Faction = "?"
	profile.Name = name or nil
	profile.Age = 1
	profile.Race = self:GetRaceEnum(unit) or 1
	profile.Gender = self:GetGenderEnum(unit) or 1
	profile.Sexuality = 1
	profile.Relationship = 1
	profile.EyeColour = 1
	profile.BodyType = 1
	profile.Length = 1
	profile.HairColour = 1
	profile.HairStreaks = 1
	profile.HairStyle = 1
	profile.HairLength = 1
	profile.HairQuality = 1
	profile.Tattoos = {}
	profile.Scars = {}
	profile.Talents = {}
	profile.Disabilities = {}
	profile.FacialHair = 1
	profile.Version = 2
	profile.StoredVersion = 1
	profile.ProtocolVersion = nil -- just to make sure.
	return profile
end

-----------------------------------------------------------------------------------------------
-- ThisIsMe Instance
-----------------------------------------------------------------------------------------------
local ThisIsMeInst = ThisIsMe:new()
ThisIsMeInst:Init()
