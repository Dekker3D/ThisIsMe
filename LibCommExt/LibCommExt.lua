-----------------------------------------------------------------------------------------------
-- Client Lua Script for LibCommExt
-- Copyright (c) Dekker3D. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "ChatSystemLib"
require "ChatChannelLib"

local PACKAGENAME, MAJOR, MINOR, PATCH = "LibCommExt", 1, 0, 1
local PACKAGESTRING = PACKAGENAME .. "-" .. MAJOR .. "." .. MINOR

local APkg = Apollo.GetPackage(PACKAGESTRING)
if APkg and (APkg.nVersion or 0) >= PATCH then
	return -- no upgrade needed
end

local LibCommExt = APkg and APkg.tPackage or {}

local CommExtChannel = {}

---------------------------------------------------------------------------------------------------
-- LibCommExt Functions
---------------------------------------------------------------------------------------------------

function LibCommExt:Print(strToPrint)
	if strToPrint ~= nil then
	 	Print("LibCommExt: " .. strToPrint)
	end
end

function LibCommExt:EnsureInit()
	if self.Initialized ~= true then
		self.ChannelTable = self.ChannelTable or {}
		setmetatable(self.ChannelTable, {__mode = "v"})
		self.Queue = self.Queue or {}
		self.WaitTicks = 0 -- for dealing with large messages
		Event_FireGenericEvent("OneVersion_ReportAddonInfo", PACKAGENAME, MAJOR, MINOR, PATCH)
		self.Initialized = true
		
		self.TNumber = 0
		self.TString = 1
		self.TTable = 2
		self.TBool = 3
		self.TDecimal = 4 -- Only exists for future compatability
		self.Types = {
			[self.TNumber] = "Number",
			[self.TString] = "String",
			[self.TTable] = "Table",
			[self.TBool] = "Bool",
			[self.TDecimal] = "Decimal",
		}
		
		for k, v in pairs(self.Types) do
			self.Types[v] = k
		end
		
		ApolloTimer.Create(5, true, "HookChat", self)
	end
end

function LibCommExt:HookChat()
	if self.hooked ~= true then
		self:Print("Hooked!")
		aChatLog = Apollo.GetAddon("ChatLog")

		if not aChatLog then
			aChatLog = Apollo.GetAddon("BetterChatLog")
		end

		if not aChatLog then
			aChatLog = Apollo.GetAddon("ChatFixed")
		end

		if not aChatLog then
			aChatLog = Apollo.GetAddon("ImprovedChatLog")
		end

		if not aChatLog then
			aChatLog = Apollo.GetAddon("FixedChatLog")
		end

		if aChatLog and aChatLog.OnChatMessage then
			fChatLog_OnChatMessage = aChatLog.OnChatMessage
			aChatLog.OnChatMessage = self.ChatLog_OnChatMessage
		end
		self.hooked = true
	end
	if self.initialized and self.hooked then self.Ready = true end
end

function LibCommExt.ChatLog_OnChatMessage(self, channelCurrent, tMessage)
	if self.ChannelTable ~= nil then
		for k, _ in ipairs(self.ChannelTable) do
			if string.match(channelCurrent:GetName(), k) then return end
		end
	end
	fChatLog_OnChatMessage(self, channelCurrent, tMessage)
end

function LibCommExt:GetChannel(channelName, version)
	self:EnsureInit()
	if channelName == nil or type(channelName) ~= "string" then return end
	if self.ChannelTable[channelName] == nil then
		self.ChannelTable[channelName] = CommExtChannel:new(channelName, version)
	end
	return self.ChannelTable[channelName]
end

function LibCommExt:AddToQueue(message)
	self:EnsureInit()
	self.SequenceNum = (self.SequenceNum or 0) + 1
	message.SequenceNum = self.SequenceNum
	table.insert(self.Queue, message)
	
	table.sort(self.Queue, function(a,b)
		if a == nil and b == nil then return false end
		if a == nil then return true end -- a should go at the end
		if b == nil then return false end -- b should go at the end
		if a.Priority ~= b.Priority then
			if a.Priority == nil then return true end
			if b.Priority == nil then return false end
			return a.Priority > b.Priority -- higher priority goes lower in the list
		end
		return a.SequenceNum < b.SequenceNum
	end)
	
	if self.Timer == nil then -- Start sending immediately if we've run out of messages and had been waiting.
		self:MessageLoop()
		self.Timer = ApolloTimer.Create(1, true, "MessageLoop", self)
	end
end

function LibCommExt:IsTableEmpty(table)
	return next(table) == nil
end

function LibCommExt:MessageLoop()
	self.WaitTicks = (self.WaitTicks or 0) - 1
	if self.WaitTicks > 0 then return end
	self:EnsureInit()
	if self:IsTableEmpty(self.Queue) then
		self.Timer:Stop()
		self.Timer = nil
		return
	end
	self.CharactersSent = 0
	self.RemainingCharacters = 90 -- safety margin. We don't want to get throttled, and some addons might use minimal amounts of traffic and not want this library.
	self.FirstMessage = true
	for _, v in ipairs(self.Queue) do
		if self.RemainingCharacters > 0 then -- not just using continue because apparently in LUA that can break stuff?
			self.CurrentMessage = v
			--pcall(function() self:HandleMessage() end)
			self:HandleMessage()
		end
	end
end

function LibCommExt:HandleMessage()
	self:EnsureInit()
	if self.CurrentMessage ~= nil and self.CurrentMessage.Message ~= nil then
		local sent = self.CurrentMessage.SendingChannel:HandleQueue(self.CurrentMessage, self.RemainingCharacters, self.First)
		self.CharactersSent = self.CharactersSent + sent
		self.RemainingCharacters = self.RemainingCharacters - sent
		if sent > 0 then
			self:RemoveFromList(self.Queue, self.CurrentMessage)
			if self.CharactersSent <= 100 then
				self.WaitTicks = 1
			else
				self.WaitTicks = math.ceil(self.CharactersSent / 100) * 2
			end
		end
	end
end

function LibCommExt:RemoveFromList(targetTable, item)
	local key = nil
	for k, v in pairs(targetTable) do
		if v == item then
			key = k
			break
		end
	end
	if key ~= nil then
		table.remove(targetTable, key)
	end
end

function LibCommExt:FilterList(table, func)
	local keysArray = {}
	local keysTable = {}
	for k, v in pairs(table) do
		if func(v) then
			if type(k) == "number" then
				table.insert(keysArray, k)
			else
				table.insert(keysTable, k)
			end
		end
	end
	for k, v in pairs(keysTable) do
		table[v] = nil
	end
	table.sort(keysArray, function(a,b) return a > b end)
	for v in ipairs(keysArray) do
		table.remove(table, v) -- remove in reverse order.
	end
end

function LibCommExt:RemoveMessageFromQueue(message)
	self:RemoveFromList(self.Queue, message)
end

function LibCommExt:Encode(numToEncode)
	return self:Encode0(numToEncode)
end

function LibCommExt:Encode0(numToEncode) -- 0-indexed
	return self:Encode1(numToEncode+1)
end

function LibCommExt:Encode1(numToEncode) -- 1-indexed
	if numToEncode == nil or numToEncode < 1 or numToEncode > 64 then
		return '-'
	end
	local b64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	return b64:sub(numToEncode, numToEncode)
end

function LibCommExt:EncodeMore(num, amount) -- "amount" gives the number of characters to use to encode this number.
	return self:EncodeMore0(num, amount)
end

function LibCommExt:EncodeMore0(num, amount) -- 0-indexed
	if num == nil or amount == nil then return end
	local ret = ""
	for i=1, amount, 1 do
		ret = ret .. self:Encode0((num % 64))
		num = num / 64
	end
	return ret
end

function LibCommExt:EncodeMore1(num, amount) -- 1-indexed
	return self:EncodeMore0(num-1, amount)
end

function LibCommExt:Decode(charToDecode)
	return self:Decode0(charToDecode)
end

function LibCommExt:Decode0(charToDecode) -- 0-indexed
	return self:Decode1(charToDecode) - 1
end

function LibCommExt:Decode1(charToDecode) -- 1-indexed
	if charToDecode == '-' then
		return nil
	end
	local b64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	return string.find(b64, charToDecode, 1)
end

function LibCommExt:DecodeMore(str, amount) -- "amount" is optional and gives the number of characters to decode. Will decode entire string otherwise.
	return self:DecodeMore0(str, amount)
end

function LibCommExt:DecodeMore0(str, amount) -- 0-indexed
	if str == nil then return nil end
	if amount ~= nil and type(amount) == "number" and str:len() > amount then
		str = str:sub(1, amount)
	end
	local num = 0
	local mult = 1
	for i=1, str:len(), 1 do
		num = num + (self:Decode0(str:sub(i,i))) * mult
		mult = mult * 64
	end
	return num
end

function LibCommExt:DecodeMore1(str, amount) -- 1-indexed
	local ret = self:DecodeMore0(str, amount)
	if ret == nil then return nil end
	return ret + 1
end

function LibCommExt:EncodeVarIntMSB(num, high)
	if num < 0 then num = 0 - num end
	if high == nil or high == false then high = 0
	else high = 32 end
	if num >= 32 then return self:EncodeVarIntMSB(math.floor(num / 32) - 1, true) .. self:Encode((num % 32) + 1 + high) end
	return self:Encode(num + 1 + high)
end

function LibCommExt:EncodeVarInt(num, high)
	if num < 0 then num = 0 - num end
	if high == nil or high == false then high = 0
	else high = 32 end
	if num >= 32 then return self:Encode((num % 32) + 1 + 32) .. self:EncodeVarInt(math.floor(num / 32) - 1, true) end
	return self:Encode(num + 1)
end

function LibCommExt:DecodeVarIntMSB(message)
	local num = 0
	local steps = 1
	while true do
		nextNum = self:Decode(message:sub(steps, steps)) - 1
		if nextNum >= 32 then
			num = num * 32 + nextNum - 31
		else
			num = num * 32 + nextNum
			return num, message:sub(steps + 1)
		end
		steps = steps + 1
	end
	return 0, message
end

function LibCommExt:DecodeVarInt(message)
	local num = 0
	local steps = 1
	local scale = 1
	while true do
		nextNum = self:Decode(message:sub(steps, steps)) - 1
		if steps > 1 then num = num + scale end
		if nextNum >= 32 then
			num = num + (nextNum - 32) * scale
		else
			num = num + nextNum * scale
			return num, message:sub(steps + 1)
		end
		steps = steps + 1
		scale = scale * 32
	end
	return 0, message
end

function LibCommExt:VarIntLength(num)
	if type(num) ~= "number" then return nil end
	if num < 0 then num = -num end
	local limit = 32
	for i=1,10,1 do
		if num < limit then return i end
		limit = (limit + 1) * 32
	end
	return nil
end

function LibCommExt:EncodeVarString(string)
	return self:EncodeVarInt(string:len()) .. string
end

function LibCommExt:DecodeVarString(msg)
	local num = 0
	num, msg = self:DecodeVarInt(msg)
	if num > 0 then
		return msg:sub(1, num), msg:sub(num)
	end
	return "", msg
end

function LibCommExt:EncodeVarIntLimit(num, limit, add)
	local halfLimit = math.floor(limit / 2)
	if num < halfLimit then return self:Encode0(num + add * limit) end
	return self:Encode0((num % halfLimit) + halfLimit + add * limit) .. self:EncodeVarInt((num / halfLimit) - 1)
end

function LibCommExt:DecodeVarIntLimit(limit, message)
	local num = self:Decode0(message:sub(1,1))
	local varint = num % limit
	local add = (num - varint) / limit
	local halfLimit = math.floor(limit / 2)
	if varint < halfLimit then return varint, add, message:sub(2) end
	
	local extraNum = 0
	extraNum, message = self:DecodeVarInt(message:sub(2))
	return varint + extraNum * halfLimit, add, message
end

function LibCommExt:EncodeTypeData(typeEnum, tokenEnum)
	typeEnum = typeEnum - 1 -- 0-index because 1-index breaks my brain
	tokenEnum = tokenEnum - 1
	if typeEnum < 0 or typeEnum > 7 then typeEnum = 0 end
	if tokenEnum < 0 then tokenEnum = 0 end
	return self:EncodeVarIntLimit(tokenEnum, 8, typeEnum)
end

function LibCommExt:DecodeTypeData(message)
	local tokenEnum = -1
	local typeEnum = -1
	tokenEnum, typeEnum, message = self:DecodeVarIntLimit(8, message)
	return typeEnum + 1, tokenEnum + 1, message -- back to 1-index
end

function LibCommExt:EncodeToken(token)
	self:EnsureInit()
	if token.Type < 1 or token.Type > 8 or token.TokenEnum < 1 or token.Value == nil then return "" end
	if not (token.Type == self.TNumber or token.Type == self.TString or token.Type == self.TBool or token.Type == self.TDecimal) then return "" end
	local message = nil
	local tokenValueCopy = token.Value
	if token.Type == self.TNumber then
		if tokenValueCopy < 0 then
			tokenValueCopy = -tokenValueCopy
			message = self:EncodeTypeData(2, token.TokenEnum)
		else
			message = self:EncodeTypeData(1, token.TokenEnum)
		end
		return message .. self:EncodeVarInt(tokenValueCopy)
	elseif token.Type == self.TString then
		return self:EncodeTypeData(3, token.TokenEnum) .. self:EncodeVarString(tokenValueCopy)
	elseif token.Type == self.TTable then
		return self:EncodeTypeData(4, token.TokenEnum) .. self:EncodeVarString("") -- nonfunctional for now.
	elseif token.Type == self.TBool then
		if token.Value == true then
			return self:EncodeTypeData(5, token.TokenEnum)
		elseif token.Value == false then
			return self:EncodeTypeData(6, token.TokenEnum)
		else return ""
		end
	end
	return ""
end

function LibCommExt:DecodeToken(message)
	self:EnsureInit()
	local typeEnum = 1
	local token = {
		Type=-1,
		TokenEnum=-1,
		Value=nil
	}
	type, token.TokenEnum, message = self:DecodeTypeData(message)
	if typeEnum == 1 or typeEnum == 2 then
		token.Type = self.TNumber
		token.Value, message = self:DecodeVarInt(message)
		if typeEnum == 2 then token.Value = -token.Value end
	elseif typeEnum == 3 then
		token.Type = self.TString
		token.Value, message = self:DecodeVarString(message)
	elseif typeEnum == 4 then
		token.Type = self.TTable
		token.Value = {} -- nonfunctional for now.
	elseif typeEnum == 5 then
		token.Type = self.TBool
		token.Value = true
	elseif typeEnum == 6 then
		token.Type = self.TBool
		token.Value = false
	end
	return token, message
end

function LibCommExt:EncodeMessage(messageTable)
	local out = ""
	for k, v in pairs(messageTable) do
		if type(k) == "number" and k >= 1 then
			out = out .. self:EncodeToken(v)
		end
	end
	
	-- First char has bool hasMessageID + VarInt messageVersion
	local header = ""
	local messageVersion = (messageTable.MessageVersion or 1) - 1
	local hasMessageID = 0
	if messageTable.Reliable == true and type(messageTable.MessageID) == "number" and messageTable.MessageID >= 1 then hasMessageID = 1 end
	header = self:EncodeVarIntLimit(messageVersion, 32, hasMessageID)
	if hasMessageID == 1 then header = header .. self:EncodeVarInt(messageTable.MessageID) end
	return header .. out
end

function LibCommExt:DecodeMessage(message)
	local messageVersion = -1
	local hasMessageID = -1
	messageVersion, hasMessageID, message = self:DecodeVarIntLimit(32, message)
	local messageTable = {}
	messageTable.Reliable = false
	messageTable.MessageVersion = messageVersion + 1
	if hasMessageID == 1 then
		local messageID = -1
		messageID, message = self:DecodeVarInt(message)
		messageTable.MessageID = messageID + 1
		messageTable.Reliable = true
	end
	
	local iterations = 100 -- Just to avoid infinite loops.
	
	while(message:len() > 0 and iterations > 0) do
		local token = nil
		token, message = self:DecodeToken(message)
		messageTable[tonumber(token.TokenEnum)] = token
		iterations = iterations - 1
	end
end

function LibCommExt:HideChannel(id)
    if not aChatLog then
        return
    end

    if not aChatLog.tChatWindows then
        return
    end

	for key, wnd in pairs(aChatLog.tChatWindows) do
		local tData = wnd:GetData()

    	if tData.tViewedChannels then
    		tData.tViewedChannels[id] = false

    		aChatLog:HelperRemoveChannelFromAll(id)
    	end
    end
end

function LibCommExt:OnDependencyError(strDependency, strError)
    -- ignore dependency errors, because we only did set dependecies to ensure to get loaded after the specified addons
    return true
end

---------------------------------------------------------------------------------------------------
-- CommExtChannel Functions
---------------------------------------------------------------------------------------------------


function CommExtChannel:new(channelName, version)
	if channelName == nil or type(channelName) ~= "string" then return end
	o = {}
	setmetatable(o, self)
	self.__index = self
	o.Channel = channelName
	o.CommVersion = version or 1 -- 1 is bare messages, anything else will implement some fancy functionality.
	o.MessageLength = 80
	o.NextWrappedMessageID = 1
	o.Callbacks = {}
	o:Connect()
	return o
end

function CommExtChannel:IsValidVersion(version)
	if version < 1 or version > 2 or type(version) ~= "number" then return false end
	return true
end

function CommExtChannel:Print(strToPrint)
	if strToPrint ~= nil then
	 	Print("CommExtChannel: " .. strToPrint)
	end
end

function CommExtChannel:Connect()
    if LibCommExt.Ready ~= true or self.Channel == nil or type(self.Channel) ~= "string" or self.Channel:len() <= 0 then return end
	if self.Comm ~= nil then return end
	local chatActive = false

    for idx, channelCurrent in ipairs(ChatSystemLib.GetChannels()) do
    	if channelCurrent:GetName() == self.Channel then
    		chatActive = true
    		self.Comm = channelCurrent
    	end
    end

    if not chatActive then
    	ChatSystemLib.JoinChannel(self.Channel)
    end

    if self.Comm then
    	LibCommExt:HideChannel(self.Comm:GetUniqueId())
    else
    	ApolloTimer.Create(1, false, "Connect", self)
    end
end

function CommExtChannel:IsReady()
	if LibCommExt.hooked then
		if self.Comm == nil then
			self:Connect()
			return false
		else
			return true
		end
	end
	return false
end

function CommExtChannel:AddReceiveCallback(callback, owner)
	if type(callback) == "function" then
		table.insert(self.Callbacks, {Callback = callback, Owner = owner})
	elseif type(callback) == "string" then
		table.insert(self.Callbacks, {Callback = owner[callback], Owner = owner})
	end
end

function CommExtChannel:OnMessageReceived(channel, strMessage, strSender)
	for k, v in pairs(self.Callbacks) do
		v.Callback(v.Owner, channel, strMessage, strSender)
	end
end

function CommExtChannel:SendPublicMessage(message, version, priority)
	self:SendMessage(nil, message, version, priority)
end

function CommExtChannel:SendPrivateMessage(recipient, message, version, priority)
	self:SendMessage(recipient, message, version, priority)
end

function CommExtChannel:SendMessage(recipient, message, version, priority) -- secretly doubles as the non-private-message function.
	LibCommExt:EnsureInit()
	LibCommExt:AddToQueue({Message = message, Recipient = recipient, Version = version, Priority = priority, SendingChannel = self})
end

function CommExtChannel:SendActualMessage(message)
	if message == nil or message.Message == nil then
		return true
	end
	if self.Comm == nil then
		self:Connect()
		return false
	end
	if message.Recipient == nil then
		self.Comm:Send(message.Message)
		return true
	else
		if self.Comm:SendPrivateMessage(message.Recipient, message.Message) then
			return true
		end
	end
	return false
end

function CommExtChannel:HandleQueue(message, remainingChars, first)
	if message.Message:len() <= remainingChars or first then
		if self:SendActualMessage(message) then
			self:Print("Test SendActualMessage")
			return message.Message:len()
		end
	end
	return 0
end

function CommExtChannel:Encode(numToEncode)
	return LibCommExt:Encode1(numToEncode)
end

function CommExtChannel:EncodeMore(num, amount)
	return LibCommExt:EncodeMore1(num, amount)
end

function CommExtChannel:Decode(charToDecode) 
	return LibCommExt:Decode1(charToDecode)
end

function CommExtChannel:DecodeMore(str, amount)
	return LibCommExt:DecodeMore1(str, amount)
end

function CommExtChannel:WrapAndSendMessage(messageTable)
	local strMessage = LibCommExt:EncodeMessage(messageTable)
	local length = strMessage:len()
	local messageCount = length / (self.MessageLength - 10)
	local prefix = LibCommExt:EncodeVarIntLimit(self.CommVersion, 16, 1) .. LibCommExt:Encode1(self.NextWrappedMessageID) -- message ID is 1.
	self.NextWrappedMessageID = (self.NextWrappedMessageID % 64) + 1
	local headerLength = LibCommExt:VarIntLength(messageCount) * 2 + prefix:len()
	local message = nil -- current message being handled
	if length <= 0 then return end
	local parts = {}
	local num = 1
	repeat
		local messageLength = self.MessageLength - headerLength
		if messageLength < length then
			message = strMessage:sub(1, messageLength)
			strMessage = strMessage:sub(messageLength + 1)
			length = strMessage:len()
		else
			message = strMessage
			strMessage = ""
			length = 0
		end
		parts[num] = message
		num = num + 1
	until length <= 0
	for k, v in ipairs(parts) do
		local header = prefix .. LibCommExt:EncodeVarInt(k - 1)
		if k == 1 then header = header .. LibCommExt:EncodeVarInt(#parts - 1) end
		self:SendMessage(nil, header .. v, self.CommVersion, messageTable.Priority or 1)
	end
end

function CommExtChannel:ReceiveWrappedMessage(strMessage)
	
end

LibCommExt:EnsureInit()

Apollo.RegisterPackage(LibCommExt, PACKAGESTRING, PATCH, {
		"ChatLog",
        "BetterChatLog",
        "ChatFixed",
        "ImprovedChatLog",
        "FixedChatLog",
        "ChatAdvanced",
        "ChatSplitter",
        "ChatLinks"
		})