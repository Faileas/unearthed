--[[--
Written by Syrae
Modified by Drago
Special thanks to the folks in #wowuidev
--]]--

-- This will be set once when the addon is first loaded (ADDON_LOADED) and then never set after that.
local VERSION = nil
local ADDONNAME = "Unearthed"
UNEARTHED_DEBUG = false

unearthedEvents = {
    ["ADDON_LOADED"] = "",
    ["ARTIFACT_DIG_SITE_UPDATED"] = "",
    ["CHAT_MSG_CURRENCY"] = "",
    ["PLAYER_ALIVE"] = "",
    ["BAG_UPDATE"] = "",
    ["ARTIFACT_COMPLETE"] = "",
}
PLAYER_IS_LOADED = false

--KeystoneItemID = RaceName
local KEYSTONE_VALUE = 12
local keystones = {
    ["Dwarf"] = 52843,
    ["Draenei"] = 64394,
    ["Night Elf"] = 63127,
    ["Nerubian"] = 64396,
    ["Orc"] = 64392,
    ["Tol'vir"] = 64397,
    ["Troll"] = 63128,
    ["Vrykul"] = 64395,
}

--The race for the currently working on artifact
currentRace = nil

--Set on login/load (PLAYER_LOGIN)
-- A table of projects with the race name string as the key
-- raceName = {
--      raceID, 
--      name (current artifact name. Unused and unset),
--      currentFragments,
--      requiredFragments,
--      numKeystones (available in inventory), 
--      numSockets (for the keystones), 
--      showCompletionAlert, 
--      showKeystoneAlert }
archaeologyProjects = {}

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
		ue_updateArchaeologyProjects()
	end
end

function unearthedEvents:PLAYER_ALIVE(...)
	if  # archaeologyProjects == 0 then
        ue_updateArchaeologyProjects()
	end	
    ue_updateKeystoneCount()
    PLAYER_IS_LOADED = true
end

function ue_updateArchaeologyProjects()
    local numRaces = GetNumArchaeologyRaces()
    for i=1,numRaces do
        local raceName, texture, itemID, currency = GetArchaeologyRaceInfo(i)
        archaeologyProjects[raceName] = {}
        archaeologyProjects[raceName]["raceID"] = i
        if archaeologyProjects[raceName]["currentFragments"] == nil then
            ue_updateCurrentProjectInfo(raceName)
        end
        if archaeologyProjects[raceName]["showCompletionAlert"] == nil then archaeologyProjects[raceName]["showCompletionAlert"] = true end
        if archaeologyProjects[raceName]["showKeystoneAlert"] == nil then archaeologyProjects[raceName]["showKeystoneAlert"] = true end
    end
end

function ue_updateCurrentProjectInfo(race)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ue_updateCurrentProjectInfo()") end
    currentProject = archaeologyProjects[race]
    SetSelectedArtifact(currentProject["raceID"])
    currentProject["currentFragments"], _, currentProject["requiredFragments"] = GetArtifactProgress()
    currentProject["name"],_,_,_,_,currentProject["numSockets"],_ = GetSelectedArtifactInfo()
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: You now have "..currentProject["currentFragments"].."/"..currentProject["requiredFragments"].." "..race.." fragments.") end
end

function ue_solveAlert()
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ue_solveAlert()") end
    if currentRace == nil then return end
    currentProject = archaeologyProjects[currentRace]
    
    if CanSolveArtifact() == 1 and currentProject["showCompletionAlert"] then
		message = strconcat("You can now solve the ",currentRace," artifact!")
		currentProject["showCompletionAlert"] = false
		alert(message)
	elseif CanSolveArtifact() ~= 1 then
        if currentProject["numSockets"] > 0 and currentProject["numKeystones"] > 0 then
            if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Keystones and sockets found. Checking if we have enough.") end
            keystoneHelp = math.min(currentProject["numSockets"], currentProject["numKeystones"])*KEYSTONE_VALUE
            if keystoneHelp+currentProject["currentFragments"] >= currentProject["requiredFragments"] then
                if currentProject["showKeystoneAlert"] then
                    message = strconcat("You can now solve the ",currentRace," artifact with keystones!")
                    currentProject["showKeystoneAlert"] = false
                    alert(message)
                else
                    --No longer solvable, so let's reset it
                    currentProject["showCompletionAlert"] = true
                    currentProject["showKeystoneAlert"] = true
                end
            else
                --No longer solvable, so let's reset it
                currentProject["showCompletionAlert"] = true
                currentProject["showKeystoneAlert"] = true
            end
        end
	end
end

function ue_updateKeystoneCount()
    for race,itemID in pairs(keystones) do
        if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: setting keystone counts for ",race,": ",GetItemCount(itemID)) end
        archaeologyProjects[race]["numKeystones"] = GetItemCount(itemID)  
    end
end

function unearthedEvents:CHAT_MSG_CURRENCY(...)
	if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: CHAT_MSG_CURRENCY") end
    local lootMsg = ...
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: '"..lootMsg.."'") end
	
    --Exit handler if this isn't an Archaeology loot message
	if string.find(lootMsg,PROFESSIONS_ARCHAEOLOGY) == nil then return end
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Archaeology loot message found.") end
    
	currentRace, lootedFragments = string.match(lootMsg, "h%[(.-) Archaeology Fragment.*x(%d+).*")
    if currentRace == nil then return end 
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Found "..currentRace.." x"..lootedFragments) end
    
	ue_updateCurrentProjectInfo(currentRace)
    
    --Warning for approaching maximum fragments
    --This will warn EVERY TIME the user is over the warning threshold
    if (archaeologyProjects[currentRace]["currentFragments"]/200) > .90 then alert("You have "..archaeologyProjects[currentRace]["currentFragments"].." of 200 maximum "..name.." fragments") end
    
    --Alert that the user is now able to solve the project
    if currentRace ~= nil then
        ue_solveAlert()
    end
end

function unearthedEvents:BAG_UPDATE(...)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: BAG_UPDATE") end
    if not PLAYER_IS_LOADED then return end --Make sure we don't run all our logic before we care.
    ue_updateKeystoneCount()
    --Make sure we've actually got an project to check before we start alerting
    --We will only alert if we are doing Archaeology in the field and only for the current project
    if currentRace ~= nil then
        ue_solveAlert()
    end
end

function unearthedEvents:ARTIFACT_COMPLETE(...)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ARTIFACT_COMPLETE") end
    if currentRace ~= nil then
        ue_updateCurrentProjectInfo(currentRace)
        ue_solveAlert()
        currentProject["showCompletionAlert"] = true
        currentProject["showKeystoneAlert"] = true
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
		print ("Unhandled event:", event, ...)
	end
end

UnearthedEventFrame:SetScript("OnEvent", UnearthedEventFrame_OnEvent)