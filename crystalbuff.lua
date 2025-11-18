--[[
CrystalBuff
Automatically tracks and corrects your current crystal buff (Signet, Sanction, Sigil) based on your zone.
Copyright (c) 2025 Seekey
https://github.com/seekey13/CrystalBuff

This addon is designed for Ashita v4 and the CatsEyeXI private server.
]]

addon.name      = 'CrystalBuff';
addon.author    = 'Seekey';
addon.version   = '1.4';
addon.desc      = 'Tracks and corrects crystal buff (Signet, Sanction, Sigil) based on current zone.';
addon.link      = 'https://github.com/seekey13/CrystalBuff';

require('common');
local chat = require('chat')
local zone_buffs = require('zone_buffs');

-- Custom print functions for categorized output.
local function printf(fmt, ...)  print(chat.header(addon.name) .. chat.message(fmt:format(...))) end
local function warnf(fmt, ...)   print(chat.header(addon.name) .. chat.warning(fmt:format(...))) end
local function errorf(fmt, ...)  print(chat.header(addon.name) .. chat.error  (fmt:format(...))) end

local last_zone = nil
local last_buffs = {}
local last_command_time = 0
local COMMAND_COOLDOWN = 10 -- seconds; rate limit for issuing correction commands
local debug_mode = false -- Toggle for debug output

-- Timing constants
local BUFF_UPDATE_DELAY = 1 -- seconds; delay to allow buff data to fully update
local COMMAND_DELAY = 10 -- seconds; delay after zone-in or load to allow data to fully load

-- Buff array constants
local MAX_BUFF_SLOTS = 31 -- Maximum buff slot index (0-31)
local INVALID_BUFF_ID = 255 -- Invalid/empty buff slot marker

-- Packet ID constants
local PKT_ZONE_IN = 0x0A -- Zone in packet
local PKT_BUFF_UPDATE = 0x037 -- Buff update packet

-- Buff IDs for Signet, Sanction, and Sigil.
local tracked_buffs = {
    [253] = 'Signet',
    [256] = 'Sanction',
    [268] = 'Sigil'
}

-- Chat command mapping for each buff type.
local required_buff_commands = {
    ['Signet'] = '!signet',
    ['Sanction'] = '!sanction',
    ['Sigil'] = '!sigil'
}

-- GetEventSystemActive Code From Thorny
local pEventSystem = ashita.memory.find('FFXiMain.dll', 0, "A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3", 0, 0);
local function get_event_system_active()
    if (pEventSystem == 0) then
        return false;
    end
    local ptr = ashita.memory.read_uint32(pEventSystem + 1);
    if (ptr == 0) then
        return false;
    end

    return (ashita.memory.read_uint8(ptr) == 1);
end

--[[
get_required_buff:
Uses zone_buffs.lua to determine the required buff for a zone.
Returns the buff type (Signet, Sanction, Sigil) or nil for zones that should be ignored.
]]
local function get_required_buff(zone_id)
    return zone_buffs.get_zone_buff(zone_id)
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
            return tracked_buffs[buff_id]
        end
    end
    return nil
end

-- Returns true if the buff arrays differ.
local function buffs_changed(new, old)
    local new_buffs = new or {}
    local old_buffs = old or {}
    
    if #new_buffs ~= #old_buffs then return true end
    
    for i = 1, #new_buffs do
        if new_buffs[i] ~= old_buffs[i] then
            return true
        end
    end
    
    return false
end

-- Returns true if the world is ready (not zoning and player entity exists).
local function is_world_ready()
    local player = get_player()
    if not player then
        return false
    end
    local entity = GetPlayerEntity and GetPlayerEntity()
    return player and not player.isZoning and entity
end

-- Main logic: prints status and issues a buff command if needed.
local function check_and_correct_buff_status()
    local zone_id = get_zone()
    if not zone_id then
        return
    end

    local zone_name = get_zone_name(zone_id)

    -- Skip non-combat zones
    if zone_buffs.non_combat_zones[zone_id] then
        if debug_mode then
            printf('Zone "%s" (%u) is a non-combat/city zone. No buff check needed.', zone_name, zone_id)
        end
        return
    end

    local required_buff = get_required_buff(zone_id)
    
    -- Skip zones that don't require a buff
    if not required_buff then
        if debug_mode then
            printf('Zone "%s" (%u) requires no crystal buff.', zone_name, zone_id)
        end
        return
    end

    if debug_mode then
        printf('Current Zone: %s (%u)', zone_name, zone_id)
        printf('Required Buff: %s', required_buff)
    end

    local buffs = get_buffs()
    if not buffs then
        return
    end

    local found_buff = get_current_buff(buffs)
    if debug_mode then
        printf('Current Crystal Buff: %s', found_buff or 'None')
    end

    if required_buff_commands[required_buff] and found_buff ~= required_buff then
        local now = os.time()
        if (now - last_command_time) >= COMMAND_COOLDOWN then
            -- Check if event system is active before issuing command
            if get_event_system_active() then
                if debug_mode then
                    warnf('Event system is active, skipping command.')
                end
                return
            end
            
            local cmd = required_buff_commands[required_buff]
            printf('Mismatch detected, issuing command: %s', cmd)
            queue_command(cmd)
            last_command_time = now
        else
            local remaining = COMMAND_COOLDOWN - (now - last_command_time)
            warnf('Command cooldown in effect, %d seconds remaining.', remaining)
        end
    end
end

-- Updates last_zone and triggers buff check.
local function update_zone_and_check()
    local zone_id = get_zone()
    if not zone_id then
        return false
    end
    if zone_id ~= last_zone then
        last_zone = zone_id
    end
    check_and_correct_buff_status()
    return true
end

-- On addon load, check status immediately (handles user loading without buff or with wrong buff).
ashita.events.register('load', 'cb_load', function()
    ashita.tasks.once(COMMAND_DELAY, function()
        local buffs = get_buffs()
        last_buffs = buffs or {}
        update_zone_and_check()
    end)
end)

ashita.events.register('packet_in', 'cb_packet_in', function(e)
    if e.id == PKT_ZONE_IN then
        local moghouse = struct.unpack('b', e.data, 0x80 + 1)
        if moghouse ~= 1 then
            -- Delay zone check to allow zone data to fully load
            ashita.tasks.once(COMMAND_DELAY, function()
                update_zone_and_check()
            end)
        end
    elseif e.id == PKT_BUFF_UPDATE then
        local buffs = get_buffs()
        if not buffs then
            return
        end
        if buffs_changed(buffs, last_buffs) then
            last_buffs = buffs
            
            -- Add delay to allow buff data to fully update
            ashita.tasks.once(BUFF_UPDATE_DELAY, function()
                local buffs_delayed = get_buffs()
                if not buffs_delayed then
                    return
                end
                
                local current_buff = get_current_buff(buffs_delayed)
                local zone_id = get_zone()
                if not zone_id then
                    return
                end
                
                -- Skip non-combat zones and zones without required buffs
                if zone_buffs.non_combat_zones[zone_id] then
                    return
                end
                
                local required_buff = get_required_buff(zone_id)
                if not required_buff then
                    return
                end
                
                if is_world_ready() and (not current_buff or current_buff ~= required_buff) then
                    check_and_correct_buff_status()
                end
            end)
        end
    end
end)

-- Command handler for debug toggle and info
ashita.events.register('command', 'cb_command', function(e)
    local args = e.command:args()
    if #args == 0 or args[1]:lower() ~= '/crystalbuff' then return end
    
    e.blocked = true
    
    if #args >= 2 and args[2]:lower() == 'debug' then
        debug_mode = not debug_mode
        printf('Debug mode %s', debug_mode and 'enabled' or 'disabled')
    elseif #args >= 2 and args[2]:lower() == 'zoneid' then
        local zone_id = get_zone()
        if zone_id then
            local zone_name = get_zone_name(zone_id)
            printf('Current Zone: %s (%u)', zone_name, zone_id)
        end
    else
        printf('Commands:')
        printf('  /crystalbuff debug  - Toggle debug output')
        printf('  /crystalbuff zoneid - Print current zone name and ID')
    end
end)