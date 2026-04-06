--[[
CrystalBuff
Automatically tracks and corrects your current crystal buff (Signet, Sanction, Sigil) based on your zone.
Copyright (c) 2025 Seekey
https://github.com/seekey13/CrystalBuff

This addon is designed for Ashita v4 and the CatsEyeXI private server.
]]

addon.name      = 'CrystalBuff';
addon.author    = 'Seekey';
addon.version   = '1.5';
addon.desc      = 'Tracks and corrects crystal buff (Signet, Sanction, Sigil) based on current zone.';
addon.link      = 'https://github.com/seekey13/CrystalBuff';

require('common');
local chat = require('chat')
local zone_buffs = require('zone_buffs');

-- Custom print functions for categorized output.
local function printf(fmt, ...)  print(chat.header(addon.name) .. chat.message(fmt:format(...))) end
local function warnf(fmt, ...)   print(chat.header(addon.name) .. chat.warning(fmt:format(...))) end
local function errorf(fmt, ...)  print(chat.header(addon.name) .. chat.error  (fmt:format(...))) end

local last_buffs = {}
local pending_buff_check = false

-- Buff array constants
local MAX_BUFF_SLOTS = 31 -- Maximum buff slot index (0-31)
local INVALID_BUFF_ID = 255 -- Invalid/empty buff slot marker

-- Packet ID constants
local PKT_ZONE_IN = 0x0A -- Zone in packet

-- Buff IDs mapped to name and correction command (single source of truth).
local tracked_buffs = {
    [253] = { name = 'Signet',   command = '!signet'   },
    [256] = { name = 'Sanction', command = '!sanction' },
    [268] = { name = 'Sigil',    command = '!sigil'    },
}
local buff_commands = {}
for _, v in pairs(tracked_buffs) do buff_commands[v.name] = v.command end

-- GetEventSystemActive Code From Thorny
local pEventSystem = ashita.memory.find('FFXiMain.dll', 0, "A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3", 0, 0);
local function is_event_system_active()
    if (pEventSystem == 0) then
        return false;
    end
    local ptr = ashita.memory.read_uint32(pEventSystem + 1);
    if (ptr == 0) then
        return false;
    end

    return (ashita.memory.read_uint8(ptr) == 1);
end

-- Returns the player object.
local function get_player()
    local ok, player = pcall(function()
        return AshitaCore:GetMemoryManager():GetPlayer()
    end)
    if not ok or not player then
        return nil
    end
    return player
end

-- Returns true if the player data has not finished loading yet.
local function is_loading()
    local player = get_player()
    if not player then return true end
    local level = player:GetMainJobLevel()
    return not level or level == 0
end

-- Returns the current zone ID.
local function get_zone()
    local ok, zone_id = pcall(function()
        return AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    end)
    if not ok then
        errorf('Error: Failed to get current zone.')
        return nil
    end
    return zone_id
end

-- Queues a command to be executed by the chat manager.
local function queue_command(cmd)
    AshitaCore:GetChatManager():QueueCommand(-1, cmd)
end

-- Returns the player's current buffs as a filtered table.
local function get_buffs()
    local player = get_player()
    if not player then
        return nil
    end
    
    local ok_buffs, buffs = pcall(function()
        return player:GetBuffs()
    end)
    
    if not ok_buffs or not buffs then
        return nil
    end
    
    -- Filter out invalid buffs (ID 255 or 0) and convert to table
    local valid_buffs = {}
    for i = 0, MAX_BUFF_SLOTS do
        local buff_id = buffs[i]
        if buff_id and buff_id ~= INVALID_BUFF_ID and buff_id > 0 then
            table.insert(valid_buffs, buff_id)
        end
    end
    
    return valid_buffs
end

-- Returns the Ashita resource name for the given zone_id.
local function get_zone_name(zone_id)
    local ok, name = pcall(function()
        return AshitaCore:GetResourceManager():GetString('zones.names', zone_id)
    end)
    return (ok and name) or ('Unknown Zone [' .. tostring(zone_id) .. ']')
end

-- Finds the first matching tracked buff in player's buffs.
local function get_current_buff(buffs)
    if not buffs then return nil end
    for _, buff_id in ipairs(buffs) do
        if tracked_buffs[buff_id] then
            return tracked_buffs[buff_id].name
        end
    end
end

-- Returns true if the buff arrays differ.
local function buffs_changed(new, old)
    if #new ~= #old then return true end
    for i = 1, #new do
        if new[i] ~= old[i] then return true end
    end
    return false
end

-- Main loop: checks and corrects buff when pending or buffs changed.
local function check_and_correct_buff()
    if is_loading() then return end
    if is_event_system_active() then return end

    local buffs = get_buffs()
    if buffs and buffs_changed(buffs, last_buffs) then
        last_buffs = buffs
        pending_buff_check = true
    end

    if not pending_buff_check then return end

    local zone_id = get_zone()
    if not zone_id then return end

    if zone_buffs.non_combat_zones[zone_id] then
        pending_buff_check = false
        return
    end

    local required_buff = zone_buffs.get_zone_buff(zone_id)
    if not required_buff then
        pending_buff_check = false
        return
    end

    local found_buff = get_current_buff(buffs)
    if found_buff == required_buff then
        pending_buff_check = false
    else
        local cmd = buff_commands[required_buff]
        printf('Mismatch detected, issuing command: %s', cmd)
        queue_command(cmd)
        pending_buff_check = false
    end
end

ashita.events.register('d3d_present', 'cb_present', function()
    check_and_correct_buff()
end)

ashita.events.register('load', 'cb_load', function()
    pending_buff_check = true
end)

ashita.events.register('packet_in', 'cb_packet_in', function(e)
    if e.id == PKT_ZONE_IN then
        pending_buff_check = true
    end
end)