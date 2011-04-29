--[[--
Written by Syrae
Modified by Drago
Special thanks to the folks in #wowuidev
--]]--

-- This will be set once when the addon is first loaded (ADDON_LOADED) and then never set after that.
local VERSION = nil
local ADDONNAME = "Unearthed"

local currentArtifact = {
	["race"] = "",
	["lootedFragments"] = "",
	["currentFragments"] = "",
	["adjustment"] = "",
	["requiredFragments"] = "",
}

--Set on login/load (PLAYER_LOGIN)
local archaeologyRaces = {}

unearthedEvents = {
    ["ADDON_LOADED"] = "",
    ["ARTIFACT_DIG_SITE_UPDATED"] = "",
    ["CHAT_MSG_CURRENCY"] = "",
    ["PLAYER_ALIVE"] = "",
}

local UnearthedEventFrame = CreateFrame("Frame", "UnearthedEventFrame", UIParent)

for event, handler in pairs(unearthedEvents) do
	UnearthedEventFrame:RegisterEvent(event)
end

local function alert(message)
	RaidNotice_AddMessage( RaidBossEmoteFrame, message, ChatTypeInfo["RAID_BOSS_EMOTE"] );
	PlaySound("RaidBossEmoteWarning");
end

function unearthedEvents:ADDON_LOADED(...)
	addonName = ...
	if addonName == ADDONNAME then
		VERSION = GetAddOnMetadata("Unearthed", "Version")
		print ("Unearthed", VERSION, "loaded")
		updateArchaeologyRaces()
	end
end

function unearthedEvents:PLAYER_ALIVE(...)
	if  # archaeologyRaces == 0 then
	    updateArchaeologyRaces()
		UnearthedEventFrame:UnregisterEvent("PLAYER_ALIVE")
	end	
end

function updateArchaeologyRaces()
		local numRaces = GetNumArchaeologyRaces()
		for i=1,numRaces do
			local name, texture, itemID, currency = GetArchaeologyRaceInfo(i)
			archaeologyRaces[name] = {}
			archaeologyRaces[name][0] = i
			if archaeologyRaces[name][1] == nil then archaeologyRaces[name][1] = true end
		end
end

function unearthedEvents:CHAT_MSG_CURRENCY(...)
	local lootMsg = ...
	--Exit handler if this isn't an Archaeology loot message
	if string.find(lootMsg,PROFESSIONS_ARCHAEOLOGY) == nil then return end
	currentArtifact["race"], currentArtifact["lootedFragments"] = string.match(lootMsg, ": (.-) Archaeology Fragment x(%d+).*")
	if currentArtifact["race"] == nil then return end -- For when we get the tablets/scrolls/etc
	local name, texture, itemID, currentTotal = GetArchaeologyRaceInfo(archaeologyRaces[currentArtifact["race"]][0])
	if (currentTotal/200) > .90 then alert("You have "..currentTotal.." of 200 maximum "..name.." fragments") end
	SetSelectedArtifact(archaeologyRaces[currentArtifact["race"]][0])
	currentArtifact["currentFragments"], currentArtifact["adjustment"], currentArtifact["requiredFragments"] = GetArtifactProgress()
	
	if CanSolveArtifact() == 1 and archaeologyRaces[currentArtifact["race"]][1] then
		message = strconcat("You can now solve the ",currentArtifact["race"]," artifact!")
		archaeologyRaces[currentArtifact["race"]][1] = false
		alert(message)
	else
	end
end

function unearthedEvents:ARTIFACT_DIG_SITE_UPDATED(...)
	alert("Dig site exhausted")
end

function UnearthedEventFrame_OnEvent(self, event, ...)
	--print ("Entered OnEvent")
	local handler = unearthedEvents[event]
	if handler ~= "" then
		--print ("Event handler:", event, ...)
		handler(self,...)
	else
		print ("Event handler:", event, ...)
	end
end

UnearthedEventFrame:SetScript("OnEvent", UnearthedEventFrame_OnEvent)