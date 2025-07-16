--[[
CrystalBuff
Automatically tracks and corrects your current crystal buff (Signet, Sanction, Sigil) based on your zone.
Copyright (c) 2025 Seekey
https://github.com/seekey13/CrystalBuff

This addon is designed for Ashita v4 and the CatsEyeXI private server.
]]

addon.name      = 'CrystalBuff';
addon.author    = 'Seekey';
addon.version   = '1.3';
addon.desc      = 'Tracks and corrects crystal buff (Signet, Sanction, Sigil) based on current zone (Optimized).';
addon.link      = 'https://github.com/seekey13/CrystalBuff';

require('common');
local chat = require('chat')
local zone_buffs = require('zone_buffs');

-- Main module encapsulation
local CrystalBuff = {
    -- Centralized constants
    PACKETS = {
        ZONE_CHANGE = 0x0A,
        ROE_MASK = 0x112,
        BUFF_UPDATE = 0x037,
        OFFSETS = {
            MOGHOUSE = 0x80,
            MASK_BYTE = 133
        }
    },
    
    CONFIG = {
        COMMAND_COOLDOWN = 10, -- seconds
        ZONE_NAME_CACHE_SIZE = 300, -- max cached zone names
        BUFF_CHECK_DEBOUNCE = 0.5, -- seconds
        ZONE_TRANSITION_DELAY = 0.3, -- seconds to wait after zone change before checking
        SUPPRESS_BUFF_CHECKS_DURING_ZONE_CHANGE = true -- skip buff update checks during zone transitions
    },
    
    -- Centralized state
    state = {
        cached_zone_id = nil,
        last_buffs = {},
        last_command_time = 0,
        zone_check_pending = false,
        debug_mode = false,
        last_buff_check = 0,
        zone_name_cache = {},
        buff_buffer = {}, -- reusable buffer for buff comparisons
        world_ready = false,
        initial_check_needed = false
    },
    
    -- Buff and zone data
    tracked_buffs = {
        [253] = 'Signet',
        [256] = 'Sanction', 
        [268] = 'Sigil'
    },
    
    required_buff_commands = {
        ['Signet'] = '!signet',
        ['Sanction'] = '!sanction',
        ['Sigil'] = '!sigil'
    },
    
    non_combat_zones = {
        [230]=true, [231]=true, [232]=true, [233]=true,  -- San d'Oria
        [234]=true, [235]=true, [236]=true, [237]=true,  -- Bastok
        [238]=true, [239]=true, [240]=true, [241]=true, [242]=true,  -- Windurst
        [243]=true, [244]=true, [245]=true, [246]=true,  -- Jeuno
        [80]=true, [87]=true, [94]=true,  -- WotG Cities
        [48]=true, [50]=true, [53]=true,  -- Aht Urhgan cities
        [26]=true, [247]=true, [248]=true, [249]=true, [250]=true, [252]=true,  -- Other Towns
        [256]=true, [257]=true,  -- Adoulin
        [280]=true, -- Mog Garden
        [46]=true, [47]=true, -- Open sea routes
        [220]=true, [221]=true, [223]=true, [224]=true, [225]=true, [226]=true,
        [227]=true, [228]=true, [70]=true, [251]=true, [284]=true,
    }
}

-- Optimized utility functions with error handling
local function printf(fmt, ...)  
    print(chat.header(addon.name) .. chat.message(fmt:format(...))) 
end

local function warnf(fmt, ...)   
    print(chat.header(addon.name) .. chat.warning(fmt:format(...))) 
end

local function errorf(fmt, ...)  
    print(chat.header(addon.name) .. chat.error(fmt:format(...))) 
end

-- Safe wrapper for AshitaCore calls
local function safe_call(func, operation_name)
    local ok, result = pcall(func)
    if not ok then
        errorf('Error: Failed to %s.', operation_name)
        return nil
    end
    return result
end

-- Optimized zone ID fetching with caching
local function get_current_zone()
    if not CrystalBuff.state.cached_zone_id then
        local zone_id = safe_call(function()
            return AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
        end, 'get current zone')
        
        if zone_id then
            CrystalBuff.state.cached_zone_id = zone_id
        end
    end
    return CrystalBuff.state.cached_zone_id
end

-- Clear cached zone when zone actually changes
local function invalidate_zone_cache()
    CrystalBuff.state.cached_zone_id = nil
end

-- Optimized zone name fetching with caching
local function get_zone_name(zone_id)
    if not zone_id then return 'Unknown Zone' end
    
    -- Check cache first
    if CrystalBuff.state.zone_name_cache[zone_id] then
        return CrystalBuff.state.zone_name_cache[zone_id]
    end
    
    -- Fetch and cache
    local name = safe_call(function()
        return AshitaCore:GetResourceManager():GetString('zones.names', zone_id)
    end, 'get zone name')
    
    local result = (name and #name > 0) and name or ('Unknown Zone [' .. tostring(zone_id) .. ']')
    
    -- Cache with size limit
    if table.length(CrystalBuff.state.zone_name_cache) < CrystalBuff.CONFIG.ZONE_NAME_CACHE_SIZE then
        CrystalBuff.state.zone_name_cache[zone_id] = result
    end
    
    return result
end

-- Optimized buff detection with early returns
local function get_current_buff(buffs)
    if not buffs then return nil end
    
    if type(buffs) == "userdata" then
        for i = 0, 31 do
            local buff_id = buffs[i]
            if buff_id and buff_id > 0 then
                local buff_name = CrystalBuff.tracked_buffs[buff_id]
                if buff_name then
                    return buff_name -- Early return
                end
            end
        end
    else
        for _, buff_id in ipairs(buffs) do
            if buff_id then
                local buff_name = CrystalBuff.tracked_buffs[buff_id]
                if buff_name then
                    return buff_name -- Early return
                end
            end
        end
    end
    return nil
end

-- Optimized buff comparison with buffer reuse
local function buffs_changed(new_buffs, old_buffs)
    if not new_buffs then 
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: new_buffs is nil, returning false')
        end
        return false 
    end
    
    if not old_buffs then 
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: old_buffs is nil, returning true')
        end
        return true 
    end
    
    -- Reuse buffer to avoid allocations
    local new_table = CrystalBuff.state.buff_buffer
    table.clear(new_table)
    
    if type(new_buffs) == "userdata" then
        for i = 0, 31 do
            local buff_id = new_buffs[i]
            if buff_id and buff_id > 0 then
                table.insert(new_table, buff_id)
            end
        end
    else
        for _, buff_id in ipairs(new_buffs) do
            if buff_id and buff_id > 0 then
                table.insert(new_table, buff_id)
            end
        end
    end
    
    if CrystalBuff.state.debug_mode then
        printf('DEBUG: New buff count: %d, Old buff count: %d', #new_table, #old_buffs)
    end
    
    -- Quick length check
    if #new_table ~= #old_buffs then 
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: Buff counts differ, change detected')
        end
        return true 
    end
    
    -- Content comparison
    for i = 1, #new_table do
        if new_table[i] ~= old_buffs[i] then
            if CrystalBuff.state.debug_mode then
                printf('DEBUG: Buff content differs at position %d: %d vs %d', i, new_table[i], old_buffs[i])
            end
            return true
        end
    end
    
    if CrystalBuff.state.debug_mode then
        printf('DEBUG: No buff changes detected')
    end
    return false
end

-- Safe buff fetching
local function get_player_buffs()
    return safe_call(function()
        return AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    end, 'get player buffs')
end

-- World readiness check
local function is_world_ready()
    local player = safe_call(function() 
        return AshitaCore:GetMemoryManager():GetPlayer() 
    end, 'access player object')
    
    if not player then return false end
    
    local entity = GetPlayerEntity and GetPlayerEntity()
    return player and not player.isZoning and entity
end

-- Zone buff requirement lookup
local function get_required_buff(zone_id)
    return zone_buffs.GetZoneBuff(zone_id)
end

-- Debounced buff checking to prevent spam
local function should_check_buffs()
    local now = os.clock()
    if (now - CrystalBuff.state.last_buff_check) < CrystalBuff.CONFIG.BUFF_CHECK_DEBOUNCE then
        return false
    end
    CrystalBuff.state.last_buff_check = now
    return true
end

-- Central buff checking and correction logic
local function check_and_correct_buff_status()
    if not should_check_buffs() then
        return
    end
    
    local zone_id = get_current_zone()
    if not zone_id then return end
    
    local zone_name = get_zone_name(zone_id)
    
    -- Non-combat zone filter (early return optimization)
    if CrystalBuff.non_combat_zones[zone_id] then
        if CrystalBuff.state.debug_mode then
            printf('Zone "%s" (%u) is a non-combat/city zone. No buff check needed.', zone_name, zone_id)
        end
        return
    end
    
    local required_buff = get_required_buff(zone_id)
    
    -- No buff needed (early return)
    if not required_buff then
        if CrystalBuff.state.debug_mode then
            printf('Zone "%s" (%u) requires no crystal buff.', zone_name, zone_id)
        end
        return
    end
    
    if CrystalBuff.state.debug_mode then
        printf('Current Zone: %s (%u)', zone_name, zone_id)
        printf('Required Buff: %s', required_buff)
    end
    
    local buffs = get_player_buffs()
    if not buffs then return end
    
    local found_buff = get_current_buff(buffs)
    if CrystalBuff.state.debug_mode then
        printf('Current Crystal Buff: %s', found_buff or 'None')
    end
    
    -- Issue command if needed
    if CrystalBuff.required_buff_commands[required_buff] and found_buff ~= required_buff then
        local now = os.time()
        if (now - CrystalBuff.state.last_command_time) >= CrystalBuff.CONFIG.COMMAND_COOLDOWN then
            local delay = 2 -- Fixed delay to avoid addon conflicts
            ashita.tasks.once(delay, function()
                local cmd = CrystalBuff.required_buff_commands[required_buff]
                printf('Mismatch detected, issuing command: %s', cmd)
                safe_call(function()
                    AshitaCore:GetChatManager():QueueCommand(-1, cmd)
                end, 'queue chat command')
            end)
            CrystalBuff.state.last_command_time = now
        else
            local remaining = CrystalBuff.CONFIG.COMMAND_COOLDOWN - (now - CrystalBuff.state.last_command_time)
            warnf('Command cooldown in effect, %d seconds remaining.', remaining)
        end
    end
end

-- Centralized zone change handling
local function handle_zone_change()
    invalidate_zone_cache()
    local zone_id = get_current_zone()
    if zone_id then
        CrystalBuff.state.zone_check_pending = false
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: Zone change handled, scheduling buff check in %.1fs', CrystalBuff.CONFIG.ZONE_TRANSITION_DELAY)
        end
        -- Delay to let zone transition settle and avoid redundant checks
        ashita.tasks.once(CrystalBuff.CONFIG.ZONE_TRANSITION_DELAY, function()
            check_and_correct_buff_status()
        end)
    end
end

-- Centralized buff change handling  
local function handle_buff_change()
    local buffs = get_player_buffs()
    if not buffs then 
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: Could not get player buffs in handle_buff_change')
        end
        return 
    end
    
    if CrystalBuff.state.debug_mode then
        local current_crystal_buff = get_current_buff(buffs)
        printf('DEBUG: Current crystal buff detected: %s', current_crystal_buff or 'None')
    end
    
    -- Always update our internal buff state first
    local buffs_have_changed = buffs_changed(buffs, CrystalBuff.state.last_buffs)
    
    if buffs_have_changed then
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: Buff change detected, updating internal state')
        end
        
        -- Update last_buffs efficiently
        table.clear(CrystalBuff.state.last_buffs)
        if type(buffs) == "userdata" then
            for i = 0, 31 do
                local buff_id = buffs[i]
                if buff_id and buff_id > 0 then
                    table.insert(CrystalBuff.state.last_buffs, buff_id)
                end
            end
        else
            for _, buff_id in ipairs(buffs) do
                if buff_id and buff_id > 0 then
                    table.insert(CrystalBuff.state.last_buffs, buff_id)
                end
            end
        end
    else
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: No buff changes detected, but still checking buff status')
        end
    end
    
    -- Always check if we have the correct buff for the zone (regardless of whether buffs changed)
    local zone_id = get_current_zone()
    if not zone_id then 
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: No zone ID available, skipping buff check')
        end
        return 
    end
    
    -- Skip if non-combat zone 
    if CrystalBuff.non_combat_zones[zone_id] then
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: In non-combat zone, skipping buff check')
        end
        return
    end
    
    -- Skip if no required buff
    if not get_required_buff(zone_id) then
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: No buff required for this zone, skipping check')
        end
        return
    end
    
    -- Skip if zone change is pending
    if CrystalBuff.state.zone_check_pending then
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: Zone change pending, skipping buff check')
        end
        return
    end
    
    -- Skip if world not ready
    if not is_world_ready() then
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: World not ready, skipping buff check')
        end
        return
    end
    
    if CrystalBuff.state.debug_mode then
        printf('DEBUG: All checks passed, proceeding with buff status check')
    end
    
    check_and_correct_buff_status()
end

-- Initialize last_buffs on load
local function initialize_buff_state()
    local buffs = get_player_buffs()
    if buffs then
        table.clear(CrystalBuff.state.last_buffs)
        if type(buffs) == "userdata" then
            for i = 0, 31 do
                local buff_id = buffs[i]
                if buff_id and buff_id > 0 then
                    table.insert(CrystalBuff.state.last_buffs, buff_id)
                end
            end
        else
            for _, buff_id in ipairs(buffs) do
                if buff_id and buff_id > 0 then
                    table.insert(CrystalBuff.state.last_buffs, buff_id)
                end
            end
        end
    end
end

-- Event Handlers

ashita.events.register('load', 'cb_load', function()
    initialize_buff_state()
    if CrystalBuff.state.debug_mode then
        printf('CrystalBuff loaded and optimized!')
    end
    
    -- Mark that we need an initial check once the world is ready
    CrystalBuff.state.initial_check_needed = true
    CrystalBuff.state.world_ready = false
    
    if CrystalBuff.state.debug_mode then
        printf('DEBUG: Initial buff check will be performed once world is ready (after RoE packet)')
    end
    
    -- Safety fallback: if world isn't ready after 10 seconds, perform check anyway
    ashita.tasks.once(10.0, function()
        if CrystalBuff.state.initial_check_needed then
            CrystalBuff.state.initial_check_needed = false
            if CrystalBuff.state.debug_mode then
                printf('DEBUG: Fallback - performing initial buff check after 10s timeout')
            end
            check_and_correct_buff_status()
        end
    end)
end)

-- Consolidated packet handling
ashita.events.register('packet_in', 'cb_packet_in', function(e)
    if e.id == CrystalBuff.PACKETS.ZONE_CHANGE then
        local moghouse = struct.unpack('b', e.data, CrystalBuff.PACKETS.OFFSETS.MOGHOUSE + 1)
        if moghouse ~= 1 then
            CrystalBuff.state.zone_check_pending = true
        end
        
    elseif e.id == CrystalBuff.PACKETS.ROE_MASK then
        local offset = struct.unpack('H', e.data, CrystalBuff.PACKETS.OFFSETS.MASK_BYTE)
        if offset == 3 then
            -- Mark the world as ready
            if not CrystalBuff.state.world_ready then
                CrystalBuff.state.world_ready = true
                if CrystalBuff.state.debug_mode then
                    printf('DEBUG: World is now ready (RoE packet received)')
                end
                
                -- Perform initial buff check if needed
                if CrystalBuff.state.initial_check_needed then
                    CrystalBuff.state.initial_check_needed = false
                    if CrystalBuff.state.debug_mode then
                        printf('DEBUG: Performing initial buff check now that world is ready')
                    end
                    -- Small delay to ensure all systems are fully initialized
                    ashita.tasks.once(0.5, function()
                        check_and_correct_buff_status()
                    end)
                end
            end
            
            -- Handle zone changes
            if CrystalBuff.state.zone_check_pending then
                handle_zone_change()
            elseif not get_current_zone() then
                handle_zone_change()
            end
        end
        
    elseif e.id == CrystalBuff.PACKETS.BUFF_UPDATE then
        -- Skip buff update checks if we're in the middle of a zone change (if configured)
        if CrystalBuff.CONFIG.SUPPRESS_BUFF_CHECKS_DURING_ZONE_CHANGE and CrystalBuff.state.zone_check_pending then
            if CrystalBuff.state.debug_mode then
                printf('DEBUG: Buff update packet received but zone change pending, skipping check')
            end
            return
        end
        
        if CrystalBuff.state.debug_mode then
            printf('DEBUG: Buff update packet received (0x037), scheduling delayed check')
        end
        -- Add small delay to allow buff data to update in memory
        ashita.tasks.once(0.1, function()
            -- Double-check that zone change isn't pending when the delayed check runs (if configured)
            if not (CrystalBuff.CONFIG.SUPPRESS_BUFF_CHECKS_DURING_ZONE_CHANGE and CrystalBuff.state.zone_check_pending) then
                handle_buff_change()
            elseif CrystalBuff.state.debug_mode then
                printf('DEBUG: Delayed buff check cancelled due to pending zone change')
            end
        end)
    end
end)

-- Enhanced command handler
ashita.events.register('command', 'cb_command', function(e)
    local args = e.command:args()
    if #args == 0 or args[1]:lower() ~= '/crystalbuff' then return end
    
    e.blocked = true
    
    if #args >= 2 then
        local cmd = args[2]:lower()
        
        if cmd == 'debug' then
            CrystalBuff.state.debug_mode = not CrystalBuff.state.debug_mode
            printf('Debug mode %s', CrystalBuff.state.debug_mode and 'enabled' or 'disabled')
            
        elseif cmd == 'zoneid' then
            local zone_id = get_current_zone()
            if zone_id then
                local zone_name = get_zone_name(zone_id)
                printf('Current Zone: %s (%u)', zone_name, zone_id)
            else
                warnf('Unable to determine current zone.')
            end
            
        elseif cmd == 'status' then
            local zone_id = get_current_zone()
            if zone_id then
                local zone_name = get_zone_name(zone_id)
                local required_buff = get_required_buff(zone_id)
                local buffs = get_player_buffs()
                local current_buff = buffs and get_current_buff(buffs)
                
                printf('=== CrystalBuff Status ===')
                printf('Zone: %s (%u)', zone_name, zone_id)
                printf('Required Buff: %s', required_buff or 'None')
                printf('Current Buff: %s', current_buff or 'None')
                printf('Debug Mode: %s', CrystalBuff.state.debug_mode and 'ON' or 'OFF')
                printf('World Ready: %s', CrystalBuff.state.world_ready and 'YES' or 'NO')
                printf('Initial Check Pending: %s', CrystalBuff.state.initial_check_needed and 'YES' or 'NO')
                printf('Zone Change Suppression: %s', CrystalBuff.CONFIG.SUPPRESS_BUFF_CHECKS_DURING_ZONE_CHANGE and 'ON' or 'OFF')
                printf('Cache Size: %d zones', table.length(CrystalBuff.state.zone_name_cache))
            end
            
        elseif cmd == 'check' then
            printf('Manually triggering buff check...')
            check_and_correct_buff_status()
            
        elseif cmd == 'suppress' then
            CrystalBuff.CONFIG.SUPPRESS_BUFF_CHECKS_DURING_ZONE_CHANGE = not CrystalBuff.CONFIG.SUPPRESS_BUFF_CHECKS_DURING_ZONE_CHANGE
            printf('Zone change buff suppression %s', 
                CrystalBuff.CONFIG.SUPPRESS_BUFF_CHECKS_DURING_ZONE_CHANGE and 'enabled' or 'disabled')
            
        elseif cmd == 'help' then
            printf('CrystalBuff Commands:')
            printf('  /crystalbuff debug    - Toggle debug output')
            printf('  /crystalbuff zoneid   - Print current zone info')
            printf('  /crystalbuff status   - Show addon status')
            printf('  /crystalbuff check    - Manually trigger buff check')
            printf('  /crystalbuff suppress - Toggle zone change buff suppression')
            printf('  /crystalbuff help     - Show this help')
        else
            printf('Unknown command. Use /crystalbuff help for available commands.')
        end
    else
        printf('Use /crystalbuff help for available commands.')
    end
end)