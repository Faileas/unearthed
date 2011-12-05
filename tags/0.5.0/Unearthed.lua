--[[--
Written by Syrae
Modified by Drago
Special thanks to the folks in #wowuidev
--]]--

-- This will be set once when the addon is first loaded (ADDON_LOADED) and then never set after that.
local VERSION = nil
local ADDONNAME = "Unearthed"
local REVISION = tonumber(strmatch("$Revision: 20 $", "%d+"))
UNEARTHED_DEBUG = false

unearthedEvents = {
    ["ADDON_LOADED"] = "",
    ["ARTIFACT_DIG_SITE_UPDATED"] = "",
    ["CHAT_MSG_CURRENCY"] = "",
    ["PLAYER_ALIVE"] = "",
    ["BAG_UPDATE"] = "",
    ["ARTIFACT_COMPLETE"] = "",
}
local PLAYER_IS_LOADED = false

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
ue_currentRace = nil

--Set on login/load (PLAYER_LOGIN)
-- A table of projects with the race name string as the key
-- raceName = {
--      raceID, 
--      artifactName,
--      currentFragments,
--      requiredFragments,
--      numKeystones (available in inventory), 
--      numSockets (for the keystones), 
--      showCompletionAlert, 
--      showKeystoneAlert }
local archaeologyProjects = {}

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
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: PLAYER_ALIVE") end
	if  # archaeologyProjects == 0 then
        ue_updateArchaeologyProjects()
	end	
    ue_updateKeystoneCount()
    PLAYER_IS_LOADED = true
end

function ue_updateArchaeologyProjects()
    local numRaces = GetNumArchaeologyRaces()
    for i=1,numRaces do
        local raceName, _, _, currency, requiredFragments = GetArchaeologyRaceInfo(i)
        -- Table is itself if not nil, otherwise construct it
        archaeologyProjects[raceName] = archaeologyProjects[raceName] or {}
        archaeologyProjects[raceName]["raceID"] = i
        archaeologyProjects[raceName]["currentFragments"] = currency
        archaeologyProjects[raceName]["requiredFragments"] = requiredFragments
        local artifactName, _, _, _, _, numKeystones, _ = GetActiveArtifactByRace(i)
        archaeologyProjects[raceName]["artifactName"] = artifactName
        archaeologyProjects[raceName]["numSockets"] = numKeystones
        if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: You now have "..archaeologyProjects[raceName]["currentFragments"].."/"..archaeologyProjects[raceName]["requiredFragments"].." "..raceName.." fragments.") end
        if archaeologyProjects[raceName]["showCompletionAlert"] == nil then archaeologyProjects[raceName]["showCompletionAlert"] = true end
        if archaeologyProjects[raceName]["showKeystoneAlert"] == nil then archaeologyProjects[raceName]["showKeystoneAlert"] = true end 
    end
end

function ue_updateArchaeologyProject(raceName)
        local raceName, _, _, currency, requiredFragments = GetArchaeologyRaceInfo(i)
        -- Table is itself if not nil, otherwise construct it
        archaeologyProjects[raceName] = archaeologyProjects[raceName] or {}
        archaeologyProjects[raceName]["raceID"] = i
        archaeologyProjects[raceName]["currentFragments"] = currency
        archaeologyProjects[raceName]["requiredFragments"] = requiredFragments
        local artifactName, _, _, _, _, numKeystones, _ = GetActiveArtifactByRace(i)
        archaeologyProjects[raceName]["artifactName"] = artifactName
        archaeologyProjects[raceName]["numSockets"] = numKeystones
        if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: You now have "..archaeologyProjects[raceName]["currentFragments"].."/"..archaeologyProjects[raceName]["requiredFragments"].." "..raceName.." fragments.") end
        if archaeologyProjects[raceName]["showCompletionAlert"] == nil then archaeologyProjects[raceName]["showCompletionAlert"] = true end
        if archaeologyProjects[raceName]["showKeystoneAlert"] == nil then archaeologyProjects[raceName]["showKeystoneAlert"] = true end 
end

-- Deprecated
function ue_updateCurrentProjectInfo(race)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ue_updateCurrentProjectInfo()") end
    currentProject = archaeologyProjects[race]
    --SetSelectedArtifact(currentProject["raceID"])
    currentProject["currentFragments"], _, currentProject["requiredFragments"] = GetArtifactProgress()
    currentProject["artifactName"],_,_,_,_,currentProject["numSockets"],_ = GetSelectedArtifactInfo()
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: You now have "..currentProject["currentFragments"].."/"..currentProject["requiredFragments"].." "..race.." fragments.") end
end

-- Make best effort to store current selected artifact and revert to that when we're done
function ue_canSolveArtifact(race)
    ue_SelectedArtifact, _, _, _, _, _, _, _, _ = GetSelectedArtifactInfo()
    
    -- If we have nothing to revert to, then we can just quickly check do our stuff and leave the function
    if ue_SelectedArtifact == nil then
        if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: No currently selected artifact") end
        SetSelectedArtifact(archaeologyProjects[race]["raceID"])
        return CanSolveArtifact()
    end
    
    local selectedRaceID = nil
    for race in pairs(archaeologyProjects) do
        if archaeologyProjects[race]["artifactName"] == ue_SelectedArtifact then 
            selectedRaceID = archaeologyProjects[race]["raceID"]
            if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Currently selected artifact is the "..race.." artifact.") end
        end
    end
    
    -- If we couldn't find the current artifact, update our info and try again
    if selectedRaceID == nil then
        ue_updateArchaeologyProjects()
        for race in pairs(archaeologyProjects) do
            if archaeologyProjects[race]["artifactName"] == ue_SelectedArtifact then 
                selectedRaceID = archaeologyProjects[race]["raceID"]
                if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Currently selected artifact is the "..race.." artifact.") end
            end
        end
    end
    
    -- If we still can't find it, then don't try to figure out if it's solvable
    if selectedRaceID == nil then
        if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Could not find a match for the currently selected artifact: "..ue_SelectedArtifact) end
        return false
    else
        SetSelectedArtifact(archaeologyProjects[race]["raceID"])
        isSolvable = CanSolveArtifact()
        SetSelectedArtifact(selectedRaceID)
    end
    return isSolvable
end

function ue_solveAlert()
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ue_solveAlert() for "..ue_currentRace) end
    if ue_currentRace == nil then return end
    local currentProject = archaeologyProjects[ue_currentRace]
    
    isSolvable = ue_canSolveArtifact(ue_currentRace)
    
    if isSolvable == 1 and currentProject["showCompletionAlert"] then
		message = strconcat("You can now solve the ",ue_currentRace," artifact!")
        if UNEARTHED_DEBUG then print (strconcat("You can now solve the ",ue_currentRace," artifact!")) end
		currentProject["showCompletionAlert"] = false
		alert(message)
	elseif isSolvable ~= 1 then
        if currentProject["numSockets"] > 0 and currentProject["numKeystones"] > 0 then
            if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Keystones and sockets found. Checking if we have enough.") end
            keystoneHelp = math.min(currentProject["numSockets"], currentProject["numKeystones"])*KEYSTONE_VALUE
            if keystoneHelp+currentProject["currentFragments"] >= currentProject["requiredFragments"] then
                if currentProject["showKeystoneAlert"] then
                    message = strconcat("You can now solve the ",ue_currentRace," artifact with keystones!")
                    if UNEARTHED_DEBUG then print (strconcat("UNEARTHED_DEBUG: You can now solve the ",ue_currentRace," artifact with keystones!")) end
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
    for race, itemID in pairs(keystones) do
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
    
	ue_currentRace, lootedFragments = string.match(lootMsg, "h%[(.-) Archaeology Fragment.*x(%d+).*")
    if ue_currentRace == nil then return end 
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Found "..ue_currentRace.." x"..lootedFragments) end
    
	ue_updateArchaeologyProjects()
    
    --Warning for approaching maximum fragments
    --This will warn EVERY TIME the user is over the warning threshold
    if (archaeologyProjects[ue_currentRace]["currentFragments"]/200) > .90 then alert("You have "..archaeologyProjects[ue_currentRace]["currentFragments"].." of 200 maximum "..ue_currentRace.." fragments") end
    
    --Alert that the user is now able to solve the project
    if ue_currentRace ~= nil then
        ue_solveAlert()
    end
end

function unearthedEvents:BAG_UPDATE(...)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: BAG_UPDATE") end
    if not PLAYER_IS_LOADED then return end --Make sure we don't run all our logic before we care.
    ue_updateKeystoneCount()
    --Make sure we've actually got an project to check before we start alerting
    --We will only alert if we are doing Archaeology in the field and only for the current project
    if ue_currentRace ~= nil then
        ue_solveAlert()
    end
end

function unearthedEvents:ARTIFACT_COMPLETE(...)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ARTIFACT_COMPLETE") end
    if ue_currentRace ~= nil then
        ue_updateArchaeologyProjects()
        ue_solveAlert()
        archaeologyProjects[ue_currentRace]["showCompletionAlert"] = true
        archaeologyProjects[ue_currentRace]["showKeystoneAlert"] = true
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