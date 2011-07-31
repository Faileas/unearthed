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
    --["BAG_UPDATE"] = "",  -- Added after the player is loaded in PLAYER_ALIVE
}

--KeystoneItemID = RaceName
local KEYSTONE_VALUE = 12
keystones = {
    ["Dwarf"] = 52843,
    ["Draenei"] = 64394,
    ["Night Elf"] = 63127,
    ["Nerubian"] = 64396,
    ["Orc"] = 64392,
    ["Tol'vir"] = 64397,
    ["Troll"] = 63128,
    ["Vrykul"] = 64395,
}

--Set in updateCurrentArtifactInfo
currentArtifact = {
	["race"] = "",
    ["name"] = "", --unused
	["lootedFragments"] = "",
	["currentFragments"] = "",
    ["numSockets"] = "",
	["requiredFragments"] = "",
}

--Set on login/load (PLAYER_LOGIN)
-- RaceName = {RaceID, ShowCompletionAlert, NumKeystonesInInventory}
archaeologyRaces = {}

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
        updateSocketInfo()
	end
end

function unearthedEvents:PLAYER_ALIVE(...)
	if  # archaeologyRaces == 0 then
	    updateArchaeologyRaces()
		UnearthedEventFrame:UnregisterEvent("PLAYER_ALIVE")
        --Registering this after we load to prevent a lot of initial calls to this.
        unearthedEvents["BAG_UPDATE"] = ""
        UnearthedEventFrame:RegisterEvent("BAG_UPDATE")
        --Then we force call this funtion once to do our initial load.
        updateSocketInfo()
	end	
end

function updateArchaeologyRaces()
    local numRaces = GetNumArchaeologyRaces()
    for i=1,numRaces do
        local name, texture, itemID, currency = GetArchaeologyRaceInfo(i)
        archaeologyRaces[name] = {}
        archaeologyRaces[name][0] = i
        if archaeologyRaces[name][1] == nil then archaeologyRaces[name][1] = true end
        archaeologyRaces[name][2] = 0 --Default for categories (like Fossils) which never have keystones
    end
end

function updateCurrentArtifactInfo(race)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: updateCurrentArtifactInfo()") end
    SetSelectedArtifact(archaeologyRaces[race][0])
    currentArtifact["race"] = race
    currentArtifact["currentFragments"], _, currentArtifact["requiredFragments"] = GetArtifactProgress()
    currentArtifact["name"],_,_,_,_,currentArtifact["numSockets"],_ = GetSelectedArtifactInfo()
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: You now have "..currentArtifact["currentFragments"].."/"..currentArtifact["requiredFragments"].." "..currentArtifact["race"].." fragments.") end
end

function solveAlert()
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: solveAlert()") end
    if CanSolveArtifact() == 1 and archaeologyRaces[currentArtifact["race"]][1] then
		message = strconcat("You can now solve the ",currentArtifact["race"]," artifact!")
		archaeologyRaces[currentArtifact["race"]][1] = false
		alert(message)
	elseif CanSolveArtifact() ~= 1 then
        if currentArtifact["numSockets"] > 0 and archaeologyRaces[currentArtifact["race"]][2] > 0 then
            keystoneHelp = math.min(currentArtifact["numSockets"], archaeologyRaces[currentArtifact["race"]][2])*KEYSTONE_VALUE
            if keystoneHelp+currentArtifact["currentFragments"] >= currentArtifact["requiredFragments"] 
                    and archaeologyRaces[currentArtifact["race"]][1] then
                message = strconcat("You can now solve the ",currentArtifact["race"]," artifact with keystones!")
                archaeologyRaces[currentArtifact["race"]][1] = false
                alert(message)
            end
        else
            archaeologyRaces[currentArtifact["race"]][1] = true
        end
	end
end

function updateSocketInfo()
    for race in pairs(keystones) do
        --if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: setting socket counts for ",race,": ",GetItemCount(keystones[race])) end
        archaeologyRaces[race][2] = GetItemCount(keystones[race])  
    end
end

function unearthedEvents:CHAT_MSG_CURRENCY(...)
	if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: CHAT_MSG_CURRENCY") end
    local lootMsg = ...
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: '"..lootMsg.."'") end
	
    --Exit handler if this isn't an Archaeology loot message
	if string.find(lootMsg,PROFESSIONS_ARCHAEOLOGY) == nil then return end
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Archaeology loot message found.") end
    
	race, currentArtifact["lootedFragments"] = string.match(lootMsg, "h%[(.-) Archaeology Fragment.*x(%d+).*")
    if race == nil then return end 
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: Found "..race.." x"..currentArtifact["lootedFragments"]) end
    
	updateCurrentArtifactInfo(race)
    
    --Warning for approaching maximum fragments
    --This will warn EVERY TIME the user is over the warning threshold
    if (currentArtifact["requiredFragments"]/200) > .90 then alert("You have "..currentArtifact["requiredFragments"].." of 200 maximum "..name.." fragments") end
    
    --Alert that the user is now able to solve the project
    solveAlert()
end

function unearthedEvents:BAG_UPDATE(...)
    if UNEARTHED_DEBUG then print ("UNEARTHED_DEBUG: BAG_UPDATE") end
    updateSocketInfo()
    solveAlert()
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