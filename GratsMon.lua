-- GratsMon
-- July 20, 2022
-- Music listened to while writing this: Vangelis, Jean Michel Jarre, Jerry Goldsmith

-- This was written because I was playing Everquest II while I had covid since it was all I *could* do, and it happened to be at a time when there was 2x XP bonus and 2x XP potions. 4x XP!!
-- Well, people were dinging left and right and I thought it would be good to automate saying "ding", simply to be friendly.
-- .....EQ2 addons are insanely horrible to write, so I came back to WoW and wrote it.

-- If there's enough interest, I could do a UI for options, but I suspect this will be a simple one-off addon.

GratsMon_AppName = "GratsMon"

local timeSinceLastDing = time()
local dingDelayInSeconds = 60

local dingStrings = {"grats", "Grats", "ding!", "woot!", "gj"};

local showGrats = true

oldTable, newTable = {}, {}

local events = {}
local frame = CreateFrame("Frame")

local doCopy = true

-- Set this to 0 for no debugging
local maxDebugLevel = 3

--------------------------------------------------------------
-- GratsMon_DebugPrint
-- Use this with _DebugLog to dump the logs somewhere that you can scroll through them later.
-- If you don't have _DebugLog and set maxDebugLevel to > 0, all debug messages will go to the console.
--------------------------------------------------------------
local function GratsMon_DebugPrint(category, level, ...)
    if tonumber(level) > maxDebugLevel then
        return
    end

    if DLAPI then
        local argArray = {...}
        local paramString = ""
        for arg = 1,#argArray
        do
            paramString = paramString .. argArray[arg]
        end
        -- Not dealing with warnings or errors. This is a simple addon.
        DLAPI.DebugLog(GratsMon_AppName, "OK~"..category.."~"..level.."~"..paramString)
    else
        print(...)
    end
end

--------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------
local function GratsMon_GetVersion()
	return tostring(GetAddOnMetadata(GratsMon_AppName, "Version"));
end

local function GratsMon_ResetTimer()
    GratsMon_DebugPrint("Timer", 1, "Resetting timer")
    timeSinceLastDing = time()
end

--------------------------------------------------------------
-- Table functions
--------------------------------------------------------------
local function GratsMon_ClearTable(tableToClear)
    for index in pairs(tableToClear) do
        tableToClear[index] = nil
    end
end

local function GratsMon_DumpTable(tableToDump)
    for index, data in ipairs(tableToDump) do
        GratsMon_DebugPrint("Dump", 1, index)
        for key, value in pairs(data) do
            GratsMon_DebugPrint("Dump", 1, "Key: ", key)
            GratsMon_DebugPrint("Dump", 1, "Value: ", value)
        end
    end
end

local function GratsMon_FindIndex(indexToFind, tableToSearch)
    local index, found = 1, false
    GratsMon_DebugPrint("Index", 1, "Index: ", index)
    GratsMon_DebugPrint("Index", 1, "TableToSearch count: ", #tableToSearch)
    if #tableToSearch == 0 then
        return "", 0
    end

    while not found do
        if index > #tableToSearch then
            GratsMon_DebugPrint("Index", 1, "Couldn't find: ", indexToFind)
            return
        end
        local record = tableToSearch[index]
        if record["index"] == indexToFind then
            GratsMon_DebugPrint("Index", 1, "We found: ", indexToFind)
            found = true
            return record["name"], record["level"]
        else
            index = index + 1
        end
    end
end

local function GratsMon_CopyNewToOld(fromCheck)
    if fromCheck ~= nil then
        if (fromCheck == true) and (doCopy == false) then
            GratsMon_DebugPrint("***", 1, "Not doing the copy")
            return
        end
    end
    GratsMon_ClearTable(oldTable)
    GratsMon_DebugPrint("***", 1, "Cleared oldTable, copyNewToOld")
    for index = 1, #newTable do
        local record = newTable[index]
        newRec = { ["name"] = record["name"], ["index"] = record["index"], ["level"] = record["level"]}
        table.insert(oldTable, newRec)
    end
    GratsMon_DebugPrint("***", 1, "Old table after copy: ")
    GratsMon_DumpTable(oldTable)
end

--------------------------------------------------------------
-- Instance and party functions
--------------------------------------------------------------
local function GratsMon_IsInProperInstance()
    if IsInInstance() == false then
        GratsMon_DebugPrint("Instance", 1, "Player is not in an instance. Ignoring all events until we're in one")
        return false
    else
        GratsMon_DebugPrint("Instance", 1, "Checking instance type...")
        local name, instanceType, difficultyID, _, maxPlayers, _, _, _, instanceGroupSize, _ = GetInstanceInfo()
        --GratsMon_DebugPrint("Name: ", name)
        --GratsMon_DebugPrint("Type: ", instanceType)

        -- 1 - Normal
        -- 2 - Heroic
        -- 23 - Mythic
        -- wowpedia.fandom.com/wiki/DifficultyID
        -- no need to define all the difficultyID types if we're just looking for ID 1.

        GratsMon_DebugPrint("Instance", 1, "Difficulty: ", difficultyID)

        -- If the player's not in a normal instance where players can ding, ignore everything.
        if difficultyID ~= 1 then
            GratsMon_DebugPrint("Instance", 1, "Player is not in a normal instance. Ignoring all events until player leaves")
            doCopy = true
            return false
        else
            GratsMon_DebugPrint("Instance", 1, "We're in a proper 5-man instance")
            --GratsMon_GetPartyMemberNames()
            --GratsMon_CopyNewToOld(true)
            doCopy = false
            return true
        end
    end
end

local function GratsMon_GetPartyMemberNames()
    if GratsMon_IsInProperInstance() == false then
        return
    end
    GratsMon_ClearTable(newTable)
    for index = 1, GetNumGroupMembers()-1 do
        local partyIndex = "party"..index
        local name = UnitName(partyIndex)
        GratsMon_DebugPrint("Name", 3, "Level of "..name.." - "..partyIndex..": ", UnitLevel(partyIndex))
        newRec = { ["name"] = name, ["index"] = partyIndex, ["level"] = UnitLevel(partyIndex)}
        table.insert(newTable, newRec)
    end
    GratsMon_DebugPrint("Name", 1, "---")
    --GratsMon_DumpTable(newTable)
end

function GratsMon_HandleDingIndex(index)
    if showGrats ~= true then
        GratsMon_DebugPrint("Ding", 1, GratsMon_AppName.." turned off. Doing nothing")
        return
    end

    if time() - timeSinceLastDing < dingDelayInSeconds then
        GratsMon_DebugPrint("Ding", 1, "Too soon to announce dings")
        return
    else
        GratsMon_GetPartyMemberNames()
        --GratsMon_DebugPrint("***", 1, "OldTable before find:")
        --GratsMon_DumpTable(oldTable)
        -- oldTable is getting blown away before we get here for some reason.
        oldName, oldLevel = GratsMon_FindIndex(index, oldTable)
        newName, newLevel = GratsMon_FindIndex(index, newTable)

        if oldName == newName then
            GratsMon_DebugPrint("Ding", 2, "Found: ", oldName)
            GratsMon_DebugPrint("Ding", 2, "Old level: ", oldLevel)
            GratsMon_DebugPrint("Ding", 2, "New level: ", newLevel)
            if (oldLevel < newLevel) and (oldLevel > 0) then
                GratsMon_DebugPrint("Ding", 1, " ** "..newName.." dinged to "..newLevel)
                GratsMon_DebugPrint("Ding", 1, "Announce DING!")
                dingString = dingStrings[math.random(#dingStrings)]
                C_Timer.After(3, function() SendChatMessage(dingString, "INSTANCE_CHAT") end)
                GratsMon_ResetTimer()
                GratsMon_CopyNewToOld()
            end
        else
            GratsMon_DebugPrint("Ding", 1, "Old name for "..oldName..", "..index.." seems to be gone")
        end
    end
end

--------------------------------------------------------------
-- Slash functions
--------------------------------------------------------------
local function GratsMon_HandleAddonCommands(msg, editbox)
    print("Command: ", msg)

    GratsMon_DebugPrint("Command", 5, msg)

    if (msg == "on") then
        if (showGrats == true) then
            print(GratsMon_AppName.." already on")
        else
            showGrats = true
            print(GratsMon_AppName.." on")
        end
    elseif (msg == "off") then
        if (showGrats == false) then
            print(GratsMon_AppName.." already off")
        else
            showGrats = false
            print(GratsMon_AppName.." off")
        end
    elseif (msg == "") then
        print("GratsMon: ", showGrats)
    else
        print("Unknown command: ", msg)
    end
end

function GratsMon_SetupSlashCommands()
    SLASH_GRATSMON1 = "/GratsMon"
    SlashCmdList["GRATSMON"] = GratsMon_HandleAddonCommands
end

--------------------------------------------------------------
-- Event table functions
--------------------------------------------------------------
function events:ADDON_LOADED(...)
    local argin1, argin2, _, _, _, _ = ...

    if argin1 == GratsMon_AppName then
        DEFAULT_CHAT_FRAME:AddMessage("|cff55BFFF"..GratsMon_AppName.."|cffffffff "..GratsMon_GetVersion())
        GratsMon_DebugPrint("Addon", 1, "GratsMon loaded: ", argin1)
        if GratsMon_IsInProperInstance() == true then
            GratsMon_ResetTimer()
        end
        GratsMon_SetupSlashCommands()
    end
end

function events:UNIT_LEVEL(...)
    local arg1 = ...;

    -- Arguemnts can be (that I've found so far): player, partyX, bossX, partypetX, nameplateX, raidX, target, npc
    -- Ignore everything except partyX
    GratsMon_DebugPrint("Level", 1, "UNIT_LEVEL Payload: ", arg1);

    -- If someone leaves the group, when the next person joins, UNIT_LEVEL is triggered before GROUP_ROSTER_UPDATE.
    -- The solution seems to be that CHAT_MSG_SYSTEM has "Soandso has joined the group" before other events, so use that as a trigger.
    if GratsMon_IsInProperInstance() == false then
        GratsMon_DebugPrint("Level", 1, "Got a UNIT_LEVEL, but not in a 5-man. Ignoring")
    else
        -- There can be a partypetX or partyX. We need to make sure we chcek for the right one.
        if (string.find(arg1, "party") ~= ni) and (string.find(arg1, "partypet") == nil) then
            GratsMon_HandleDingIndex(arg1)
        end
    end
end

function events:ZONE_CHANGED_NEW_AREA(...)
    if GratsMon_IsInProperInstance() == false then
        GratsMon_ClearTable(oldTable)
        GratsMon_ClearTable(newTable)
        GratsMon_DebugPrint("Zone", 1, "Zone changed - not in a 5-man instance")
        showGrats = false
    else
        showGrats = true
        GratsMon_DebugPrint("Zone", 1, "Zone changed to a 5-man instance")
        GratsMon_GetPartyMemberNames()
        GratsMon_CopyNewToOld()
    end
    GratsMon_ResetTimer()
end

function events:GROUP_ROSTER_UPDATE(...)
-- This is here for my own curiosity about how the events work.
-- When does GROUP_ROSTER_UPDATE happen vs. other events like CHAT... and UNIT_LEVEL?
-- Note: This function isn't always accurate. Someone will leave and will return a 5 for a few seconds, then retrun a 4.
    GratsMon_DebugPrint("Roster", 1, "Roster updated. Number of members: ", GetNumGroupMembers())
    GratsMon_GetPartyMemberNames()
    GratsMon_CopyNewToOld()
end

frame:SetScript("OnEvent", function(self, event, ...)
    events[event](self, ...);
end);

function GratsMon_OnLoad(self)
    GratsMon_DebugPrint("OnLoad", 1, "Registering...")
    for k, v in pairs(events) do
        GratsMon_DebugPrint("OnLoad", 1, "Registered: ", k)
        frame:RegisterEvent(k)
    end
end



