--[[
CrystalBuff
Automatically tracks and corrects your current crystal buff (Signet, Sanction, Sigil) based on your zone.
Copyright (c) 2025 Seekey
https://github.com/seekey13/CrystalBuff

This addon is designed for Ashita v4 and the CatsEyeXI private server.
]]

addon.name      = 'CrystalBuff';
addon.author    = 'Seekey';
addon.version   = '0.8';
addon.desc      = 'Tracks and corrects crystal buff (Signet, Sanction, Sigil) based on current zone.';
addon.link      = 'https://github.com/seekey13/CrystalBuff';

require('common');

local last_zone = nil
local last_buffs = {}
local last_command_time = 0
local COMMAND_COOLDOWN = 10 -- seconds; rate limit for issuing correction commands

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

local non_combat_zones = {
    [0]=true, [1]=true, [2]=true, -- San d'Oria
    [3]=true, [4]=true, [5]=true, -- Bastok
    [6]=true, [7]=true, [8]=true, [9]=true, -- Windurst
    [16]=true, [17]=true, [18]=true, [246]=true, -- Jeuno
    [50]=true, [53]=true, -- ToAU cities
    [25]=true, -- Tavnazian Safehold
    [32]=true, [40]=true, [41]=true, [47]=true, [56]=true, -- Small towns
    [256]=true, [257]=true, -- Adoulin
    [231]=true, [232]=true, [233]=true, [234]=true, [235]=true, [236]=true, [237]=true, [238]=true, [239]=true, -- Mog Houses
    [242]=true, -- Residential Area/Mog Garden
    [69]=true, -- Chocobo Circuit
    [285]=true, -- Celennia Memorial Library
}

--[[
get_required_buff:
Zone Ranges:
  0-184   : Signet    (Vanilla, Zilart, CoP, most city/outdoor)
  185-254 : Sanction  (Treasures of Aht Urhgan zones)
  255-294 : Sigil     (Wings of the Goddess past zones)
  Other   : No crystal buff expected
]]
local function get_required_buff(zone_id)
    if zone_id >= 0 and zone_id <= 184 then
        return 'Signet'
    elseif zone_id >= 185 and zone_id <= 254 then
        return 'Sanction'
    elseif zone_id >= 255 and zone_id <= 294 then
        return 'Sigil'
    else
        return 'Other'
    end
end

local function get_zone_name(zone_id)
    -- Use pcall for safe resource fetching in case AshitaCore is not fully ready.
    local ok, name = pcall(function()
        return AshitaCore:GetResourceManager():GetString('zones.names', zone_id)
    end)
    return (ok and name) or ('Unknown Zone [' .. tostring(zone_id) .. ']')
end

-- Returns the first found tracked buff (only one can be active at a time).
local function get_current_buff(buffs)
    if not buffs then return nil end
    
    -- Handle both userdata and table formats
    if type(buffs) == "userdata" then
        -- Iterate through userdata indices
        for i = 0, 31 do -- FFXI has max 32 buffs
            local buff_id = buffs[i]
            if buff_id and buff_id > 0 and tracked_buffs[buff_id] then
                return tracked_buffs[buff_id]
            end
        end
    else
        -- Handle as table
        for _, buff_id in ipairs(buffs) do
            if tracked_buffs[buff_id] then
                return tracked_buffs[buff_id]
            end
        end
    end
    return nil
end

-- Compare two buff tables for any difference.
local function buffs_changed(new, old)
    -- Convert userdata to table if needed
    local new_table = {}
    local old_table = old or {}
    
    if type(new) == "userdata" then
        for i = 0, 31 do
            local buff_id = new[i]
            if buff_id and buff_id > 0 then
                table.insert(new_table, buff_id)
            end
        end
    else
        new_table = new or {}
    end
    
    if #new_table ~= #old_table then return true end
    for i = 1, #new_table do
        if new_table[i] ~= old_table[i] then
            return true
        end
    end
    return false
end

-- Checks if the world is ready (not zoning, player entity exists)
local function is_world_ready()
    local p = AshitaCore:GetMemoryManager():GetPlayer()
    local e = GetPlayerEntity and GetPlayerEntity()
    return p and not p.isZoning and e
end

local function print_status_and_correct()
    -- Use the robust method from zonename/unityroEZ: Party->GetMemberZone(0)
    local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    local zone_name = get_zone_name(zone_id)

    -- Non-combat/city zone filter
    if non_combat_zones[zone_id] then
        print(('[CrystalBuff] Zone "%s" (%u) is a non-combat/city zone. No buff check needed.'):format(zone_name, zone_id))
        return
    end

    local required_buff = get_required_buff(zone_id)

    print(('[CrystalBuff] Current Zone: %s (%u)'):format(zone_name, zone_id))
    print(('[CrystalBuff] Required Buff: %s'):format(required_buff))

    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    
    -- Debug: Print buff information to see what we're actually getting
    if type(buffs) == "userdata" then
        print('[CrystalBuff] DEBUG: Buffs are userdata, checking indices...')
        local buff_list = {}
        for i = 0, 31 do
            local buff_id = buffs[i]
            if buff_id and buff_id > 0 then
                table.insert(buff_list, buff_id)
                -- Check specifically for crystal buffs
                if tracked_buffs[buff_id] then
                    print('[CrystalBuff] DEBUG: Found tracked buff ' .. buff_id .. ' (' .. tracked_buffs[buff_id] .. ')')
                end
            end
        end
        if #buff_list > 0 then
            print('[CrystalBuff] DEBUG: All active buffs: ' .. table.concat(buff_list, ', '))
        else
            print('[CrystalBuff] DEBUG: No active buffs found')
        end
    else
        print('[CrystalBuff] DEBUG: Buffs type: ' .. type(buffs))
        if buffs and #buffs > 0 then
            print('[CrystalBuff] DEBUG: Buff list: ' .. table.concat(buffs, ', '))
        end
    end
    
    local found_buff = get_current_buff(buffs)
    print('[CrystalBuff] Current Crystal Buff: ' .. (found_buff or 'None'))

    if required_buff_commands[required_buff] and found_buff ~= required_buff then
        local now = os.time()
        if (now - last_command_time) >= COMMAND_COOLDOWN then
            local cmd = required_buff_commands[required_buff]
            print(('[CrystalBuff] Mismatch detected, issuing command: %s'):format(cmd))
            AshitaCore:GetChatManager():QueueCommand(-1, cmd)
            last_command_time = now
        else
            print('[CrystalBuff] Mismatch detected, but command cooldown is active.')
        end
    end
end

-- On addon load, check status immediately (handles user loading without buff or with wrong buff).
ashita.events.register('load', 'cb_load', function()
    -- Initialize last_buffs to current buff list so first packet_in isn't double-triggered.
    local ok, buffs = pcall(function()
        return AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    end)
    if ok and buffs then
        -- Convert userdata to table if needed
        if type(buffs) == "userdata" then
            local buffs_table = {}
            for i = 0, 31 do
                local buff_id = buffs[i]
                if buff_id and buff_id > 0 then
                    table.insert(buffs_table, buff_id)
                end
            end
            last_buffs = buffs_table
        else
            last_buffs = buffs
        end
    else
        last_buffs = {}
    end
    if is_world_ready() then
        print_status_and_correct()
    else
        -- Wait until world is ready, then check
        ashita.tasks.once(2, function()
            if is_world_ready() then
                print_status_and_correct()
            end
        end)
    end
end)

-- Use "zone finished loading" (0x01B) or "zone changed" (0x0A) - with robust world ready check and delay
ashita.events.register('packet_in', 'cb_packet_in', function(e)
    if e.id == 0x0A then
        -- On zone change, wait a moment for memory to update and ensure world is ready, then check
        local moghouse = struct.unpack('b', e.data, 0x80 + 1)
        if moghouse ~= 1 then
            coroutine.sleep(1)
            if is_world_ready() then
                local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
                if zone_id ~= last_zone then
                    last_zone = zone_id
                    print_status_and_correct()
                end
            end
        end
    elseif e.id == 0x01B then
        -- Some servers fire this only after fully loaded; double check world ready
        coroutine.sleep(0.5)
        if is_world_ready() then
            local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
            if zone_id ~= last_zone then
                last_zone = zone_id
                print_status_and_correct()
            end
        end
    elseif (e.id == 0x063 or e.id == 0x037) then
        local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
        if buffs_changed(buffs, last_buffs) then
            -- Convert userdata to table for storage
            if type(buffs) == "userdata" then
                local buffs_table = {}
                for i = 0, 31 do
                    local buff_id = buffs[i]
                    if buff_id and buff_id > 0 then
                        table.insert(buffs_table, buff_id)
                    end
                end
                last_buffs = buffs_table
            else
                last_buffs = buffs
            end
            if is_world_ready() then
                print_status_and_correct()
            end
        end
    end
end)