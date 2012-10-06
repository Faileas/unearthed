--[[--
Written by Syrae
Modified by Drago
Special thanks to the folks in #wowuidev
--]]--

-- This will be set once when the addon is first loaded (ADDON_LOADED) and then never set after that.
local VERSION = nil
local ADDONNAME = "Unearthed"
local REVISION = tonumber(strmatch("$Revision: 20 $", "%d+"))
local DIG_SITE_UPDATED = true
local MAX_FRAGMENTS = 200 -- Character can only have up to 200 fragments per race
UNEARTHED_DEBUG = false

unearthedEvents = {
    --Loading events in approximate order that they occur
    --["ADDON_LOADED"] = "", --Happens multiple times
    --["SPELLS_CHANGED"] = "",
    ["PLAYER_LOGIN"] = "", 
    --["PLAYER_ENTERING_WORLD"] = "",
    --["PLAYER_ALIVE"] = "",
    --Archaeology related events
    ["ARTIFACT_DIG_SITE_UPDATED"] = "",
    ["ARTIFACT_COMPLETE"] = "",
    ["ARTIFACT_UPDATE"] = "",
    ["CHAT_MSG_CURRENCY"] = "",
    ["BAG_UPDATE"] = "",
    ["UNIT_SPELLCAST_SUCCEEDED"] = "",
}
PLAYER_IS_LOADED = false

--KeystoneItemID = RaceName
local KEYSTONE_VALUE = 12
local keystones = {
    ["Dwarf"] = 52843,
    ["Draenei"] = 64394,
    ["Mogu"] = 79869,
    ["Night Elf"] = 63127,
    ["Nerubian"] = 64396,
    ["Orc"] = 64392,
    ["Pandaren"] = 79868,
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
ue_archaeologyProjects = {}

local UnearthedEventFrame = CreateFrame("Frame", "UnearthedEventFrame", UIParent)

for event, handler in pairs(unearthedEvents) do
    UnearthedEventFrame:RegisterEvent(event)
end

local function alert(message)
	RaidNotice_AddMessage( RaidBossEmoteFrame, message, ChatTypeInfo["RAID_BOSS_EMOTE"] );
	PlaySound("RaidBossEmoteWarning");
end

function unearthedEvents:ADDON_LOADED(...)
    if UNEARTHED_DEBUG then 
        print ("UNEARTHED_DEBUG: ADDON_LOADED")
        --print ("UNEARTHED_DEBUG: Hearthstone detected: "..GetItemCount(64488))
        --local raceName, _, _, currency, requiredFragments = GetArchaeologyRaceInfo(1)
        --print ("UNEARTHED_DEBUG: Archaeology race read:"..raceName)
    end
end

-- Debug only
function unearthedEvents:SPELLS_CHANGED(...)
    if UNEARTHED_DEBUG then 
        print ("UNEARTHED_DEBUG: SPELLS_CHANGED")
        print ("UNEARTHED_DEBUG: Hearthstone detected: "..GetItemCount(64488))
        local raceName, _, _, currency, requiredFragments = GetArchaeologyRaceInfo(1)
        print ("UNEARTHED_DEBUG: Archaeology race read:"..raceName)
    end
end

-- First time we can look at our bag inventory for Keystones and check our Archaeology status
-- Seems to also only be called once on login and once on /console reloadui
function unearthedEvents:PLAYER_LOGIN(...)
    if UNEARTHED_DEBUG then 
        print ("UNEARTHED_DEBUG: PLAYER_LOGIN")
        --print ("UNEARTHED_DEBUG: Hearthstone detected: "..GetItemCount(64488))
        --local raceName, _, _, currency, requiredFragments = GetArchaeologyRaceInfo(1)
        --print ("UNEARTHED_DEBUG: Archaeology race read:"..raceName)
    end
    addonName = ...
	if addonName == ADDONNAME then
		VERSION = GetAddOnMetadata("Unearthed", "Version")
		print ("Unearthed", VERSION, "loaded")
		ue_updateArchaeologyProjects()
	end
    if  # ue_archaeologyProjects == 0 then
        ue_updateArchaeologyProjects()
	end	
    ue_updateKeystoneCount()
    PLAYER_IS_LOADED = true
end

-- Debug only
function unearthedEvents:PLAYER_ENTERING_WORLD(...)
    if UNEARTHED_DEBUG then 
        print ("UNEARTHED_DEBUG: PLAYER_ENTERING_WORLD")
        print ("UNEARTHED_DEBUG: Hearthstone detected: "..GetItemCount(64488))
        local raceName, _, _, currency, requiredFragments = GetArchaeologyRaceInfo(1)
        print ("UNEARTHED_DEBUG: Archaeology race read:"..raceName)
    end
end

-- Debug only
function unearthedEvents:PLAYER_ALIVE(...)
    -- if UNEARTHED_DEBUG then 
        -- print ("UNEARTHED_DEBUG: PLAYER_ALIVE")
        -- print ("UNEARTHED_DEBUG: Hearthstone detected: "..GetItemCount(64488))
        -- local raceName, _, _, currency, requiredFragments = GetArchaeologyRaceInfo(1)
        -- print ("UNEARTHED_DEBUG: Archaeology race read:"..raceName)
    -- end
end

function ue_updateArchaeologyProjects()
    local numRaces = GetNumArchaeologyRaces()
    for i=1,numRaces do
        local raceName, _, _, currency, requiredFragments = GetArchaeologyRaceInfo(i)
        -- Table is itself if not nil, otherwise construct it
        ue_archaeologyProjects[raceName] = ue_archaeologyProjects[raceName] or {}
        ue_archaeologyProjects[raceName]["raceID"] = i
        ue_archaeologyProjects[raceName]["currentFragments"] = currency
        ue_archaeologyProjects[raceName]["requiredFragments"] = requiredFragments
        local artifactName, _, _, _, _, numKeystones, _ = GetActiveArtifactByRace(i)
        ue_archaeologyProjects[raceName]["artifactName"] = artifactName
        ue_archaeologyProjects[raceName]["numSockets"] = numKeystones
        if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: You now have "..ue_archaeologyProjects[raceName]["currentFragments"].."/"..ue_archaeologyProjects[raceName]["requiredFragments"].." "..raceName.." fragments.") end
        if ue_archaeologyProjects[raceName]["showCompletionAlert"] == nil then ue_archaeologyProjects[raceName]["showCompletionAlert"] = true end
        if ue_archaeologyProjects[raceName]["showKeystoneAlert"] == nil then ue_archaeologyProjects[raceName]["showKeystoneAlert"] = true end 
    end
end

function ue_updateArchaeologyProject(raceName)
        local raceName, _, _, currency, requiredFragments = GetArchaeologyRaceInfo(i)
        -- Table is itself if not nil, otherwise construct it
        ue_archaeologyProjects[raceName] = ue_archaeologyProjects[raceName] or {}
        ue_archaeologyProjects[raceName]["raceID"] = i
        ue_archaeologyProjects[raceName]["currentFragments"] = currency
        ue_archaeologyProjects[raceName]["requiredFragments"] = requiredFragments
        local artifactName, _, _, _, _, numKeystones, _ = GetActiveArtifactByRace(i)
        ue_archaeologyProjects[raceName]["artifactName"] = artifactName
        ue_archaeologyProjects[raceName]["numSockets"] = numKeystones
        if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: You now have "..ue_archaeologyProjects[raceName]["currentFragments"].."/"..ue_archaeologyProjects[raceName]["requiredFragments"].." "..raceName.." fragments.") end
        if ue_archaeologyProjects[raceName]["showCompletionAlert"] == nil then ue_archaeologyProjects[raceName]["showCompletionAlert"] = true end
        if ue_archaeologyProjects[raceName]["showKeystoneAlert"] == nil then ue_archaeologyProjects[raceName]["showKeystoneAlert"] = true end 
end

-- Deprecated
function ue_updateCurrentProjectInfo(race)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ue_updateCurrentProjectInfo()") end
    currentProject = ue_archaeologyProjects[race]
    --SetSelectedArtifact(currentProject["raceID"])
    currentProject["currentFragments"], _, currentProject["requiredFragments"] = GetArtifactProgress()
    currentProject["artifactName"],_,_,_,_,currentProject["numSockets"],_ = GetSelectedArtifactInfo()
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: You now have "..currentProject["currentFragments"].."/"..currentProject["requiredFragments"].." "..race.." fragments.") end
end

-- Make best effort to store current selected artifact and revert to that when we're done
function ue_canSolveArtifact(race)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ue_canSolveArtifact("..race..")") end
    ue_SelectedArtifact, _, _, _, _, _, _, _, _ = GetSelectedArtifactInfo()
    
    -- If we have nothing to revert to, then we can just quickly check do our stuff and leave the function
    if ue_SelectedArtifact == nil then
        if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: No currently selected artifact") end
        SetSelectedArtifact(ue_archaeologyProjects[race]["raceID"])
        return CanSolveArtifact()
    end
    
    local selectedRaceID = nil
    for race in pairs(ue_archaeologyProjects) do
        if ue_archaeologyProjects[race]["artifactName"] == ue_SelectedArtifact then 
            selectedRaceID = ue_archaeologyProjects[race]["raceID"]
            if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Currently selected artifact is the "..race.." artifact.") end
        end
    end
    
    -- If we couldn't find the current artifact, update our info and try again
    if selectedRaceID == nil then
        ue_updateArchaeologyProjects()
        for race in pairs(ue_archaeologyProjects) do
            if ue_archaeologyProjects[race]["artifactName"] == ue_SelectedArtifact then 
                selectedRaceID = ue_archaeologyProjects[race]["raceID"]
                if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Currently selected artifact is the "..race.." artifact.") end
            end
        end
    end
    
    -- If we still can't find it, then don't try to figure out if it's solvable
    if selectedRaceID == nil then
        if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Could not find a match for the currently selected artifact: "..ue_SelectedArtifact) end
        return false
    else
        SetSelectedArtifact(ue_archaeologyProjects[race]["raceID"])
        isSolvable = CanSolveArtifact()
        SetSelectedArtifact(selectedRaceID)
    end
    return isSolvable
end

function ue_solveAlert()
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ue_solveAlert() for "..ue_currentRace) end
    if ue_currentRace == nil then return end
    local currentProject = ue_archaeologyProjects[ue_currentRace]
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: currentProject = "..currentProject["artifactName"]) end
    
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
    keystoneCountUpdated = false
    for race, itemID in pairs(keystones) do
        --if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: setting keystone counts for ",race,": ",GetItemCount(itemID)) end
        keystoneCountUpdated = keystoneCountUpdated or (ue_archaeologyProjects[race]["numKeystones"] ~= GetItemCount(itemID))
        ue_archaeologyProjects[race]["numKeystones"] = GetItemCount(itemID)
    end
    if keystoneCountUpdated and UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Keystone count changed.") end
    return keystoneCountUpdated
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
    if (ue_archaeologyProjects[ue_currentRace]["currentFragments"]/MAX_FRAGMENTS) > .90 then alert("You have "..ue_archaeologyProjects[ue_currentRace]["currentFragments"].." of 200 maximum "..ue_currentRace.." fragments") end
    
    --Alert that the user is now able to solve the project
    if ue_currentRace ~= nil then
        ue_solveAlert()
    end
end

function unearthedEvents:BAG_UPDATE(...)
    --if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: BAG_UPDATE") end
    if not PLAYER_IS_LOADED then return end --Make sure we don't run all our logic before we care.
    keystoneCountUpdated = ue_updateKeystoneCount()
    --Make sure we've actually got an project to check before we start alerting
    --We will only alert if we are doing Archaeology in the field and only for the current project
    if keystoneCountUpdated and ue_currentRace ~= nil then
        ue_solveAlert()
    end
end

function unearthedEvents:ARTIFACT_COMPLETE(...)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ARTIFACT_COMPLETE") end
    ue_updateArchaeologyProjects()
    if ue_currentRace ~= nil then
        ue_solveAlert()
        ue_archaeologyProjects[ue_currentRace]["showCompletionAlert"] = true
        ue_archaeologyProjects[ue_currentRace]["showKeystoneAlert"] = true
    end
end

function unearthedEvents:ARTIFACT_UPDATE(...)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ARTIFACT_UPDATE") end
    ue_updateArchaeologyProjects()
end

function unearthedEvents:ARTIFACT_DIG_SITE_UPDATED(...)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: ARTIFACT_DIG_SITE_UPDATED") end
	-- This event fires when we cross between zone boundries (like expansions/CRZs)
    -- Let's only fire alert when we have actually done a dig recently
    if not DIG_SITE_UPDATED then
        alert("Dig site exhausted")
        DIG_SITE_UPDATED = true
    end
end

function unearthedEvents:UNIT_SPELLCAST_SUCCEEDED(...)
    _, spellName, _, _, spellID = ...
    if spellID == 80451 then
        if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: UNIT_SPELLCAST_SUCCEEDED - Survey cast") end
        --We've done some digging recently, so we should be able to accept new messages.
        DIG_SITE_UPDATED = false
    end
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