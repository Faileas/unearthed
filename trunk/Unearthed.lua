--[[--
Written by Syrae

Special thanks to the folks in #wowuidev
--]]--

-- This will be set once when the addon is first loaded (ADDON_LOADED) and then never set after that.
local VERSION = nil
local ADDONNAME = "Unearthed"
local freeBagSpace = 0

local currentArtifact = {
	["race"] = "",
	["lootedFragments"] = "",
	["currentFragments"] = "",
	["adjustment"] = "",
	["requiredFragments"] = "",
}

--Set on login/load (PLAYER_LOGIN)
local archaeologyRaces = {}

local events = {
	--["ARCHAEOLOGY_CLOSED"],
    --["ARCHAEOLOGY_TOGGLE"],
	["ADDON_LOADED"] = "",
    --["ARTIFACT_COMPLETE"] = "",
    ["ARTIFACT_DIG_SITE_UPDATED"] = "",
    --["ARTIFACT_HISTORY_READY"],
    --["ARTIFACT_UPDATE"] = "",
	--["CURRENCY_DISPLAY_UPDATE"] = "",
	["CHAT_MSG_LOOT"] = "",
	--["CHAT_MSG_SKILL"]
	["PLAYER_LOGIN"] = "",
}

local UnearthedEventFrame = CreateFrame("Frame", "UnearthedEventFrame", UIParent)

for event, handler in pairs(events) do
	UnearthedEventFrame:RegisterEvent(event)
end

local function calcFreeSpace(self)
	--Figure out current free bag space
	freeBagSpace = 0
	for i=0,4 do
		free, _ = GetContainerNumFreeSlots(i)
		freeBagSpace = freeBagSpace + free
	end
end

--SolveArtifact() seems to be protected.  We can try adding a button for this later.
local function autoSolve(self) 
	--TODO: swap this to a bag space event handler
	calcFreeSpace()
	if CanSolveArtifact() == 1 and freeBagSpace > 0 then
		print ("Solving",currentArtifact["race"],"artifact.")
		SolveArtifact()
	end
end

function events:ADDON_LOADED(...)
	addonName = ...
	if addonName == ADDONNAME then
		VERSION = GetAddOnMetadata("Unearthed", "Version")
		print ("Unearthed", VERSION, "loaded")
	end
end

function events:PLAYER_LOGIN(...)
	local numRaces = GetNumArchaeologyRaces();
	for i=1,numRaces do
		local name, currency, texture, itemID = GetArchaeologyRaceInfo(i)
		archaeologyRaces[name] = i
	end	
end

function events:CHAT_MSG_LOOT(...)
	lootMsg = ...
	--Exit handler if this isn't an Archaeology loot message
	if string.find(lootMsg,PROFESSIONS_ARCHAEOLOGY) == nil then
		return
	end
	
	--print ("Event handler: CHAT_MSG_LOOT")
	currentArtifact["race"], currentArtifact["lootedFragments"]= string.match(lootMsg, ": (%a+) .* x(%d+)")
	--print ("Captures:", currentArtifact["race"], ",", currentArtifact["lootedFragments"])
	
	SetSelectedArtifact(archaeologyRaces[currentArtifact["race"]])
	currentArtifact["currentFragments"], currentArtifact["adjustment"], currentArtifact["requiredFragments"] = GetArtifactProgress()
	
	if CanSolveArtifact() == 1 then
		message = strconcat("You can now solve the ",currentArtifact["race"]," artifact!")
		RaidNotice_AddMessage( RaidBossEmoteFrame, message, ChatTypeInfo["RAID_BOSS_EMOTE"] );
		PlaySound("RaidBossEmoteWarning");

		--print (message)
	else
		print (currentArtifact["race"],"artifact progress:",currentArtifact["currentFragments"].."/"..currentArtifact["requiredFragments"])
	end
end

function events:ARTIFACT_DIG_SITE_UPDATED(...)
	print ("Dig site exhausted.")
end

function UnearthedEventFrame_OnEvent(self, event, ...)
	--print ("Entered OnEvent")
	local handler = events[event]
	if handler ~= "" then
		--print ("Event handler:", event, ...)
		handler(self,...)
	else
		print ("Event handler:", event, ...)
	end
end

UnearthedEventFrame:SetScript("OnEvent", UnearthedEventFrame_OnEvent)
