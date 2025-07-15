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

-- RoE mask packet constants
local PKT_ROE_MASK = 0x112
local MASK_OFFSET_BYTE = 133

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

-- Table of city and non-combat zone IDs
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
    if type(buffs) == "userdata" then
        for i = 0, 31 do
            local buff_id = buffs[i]
            if buff_id and buff_id > 0 and tracked_buffs[buff_id] then
                return tracked_buffs[buff_id]
            end
        end
    else
        for _, buff_id in ipairs(buffs) do
            if tracked_buffs[buff_id] then
                return tracked_buffs[buff_id]
            end
        end
    end
    return nil
end

-- Returns true if the buff arrays differ.
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

-- Returns true if the world is ready (not zoning and player entity exists).
local function is_world_ready()
    local p = AshitaCore:GetMemoryManager():GetPlayer()
    local e = GetPlayerEntity and GetPlayerEntity()
    return p and not p.isZoning and e
end



-- Main logic: prints status and issues a buff command if needed.
local function print_status_and_correct()
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

-- Handles zone events, ensuring only one check per unique zone.
local function handle_zone_event()
    local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    if zone_id ~= last_zone then
        last_zone = zone_id
        print_status_and_correct()
    end
end

-- On addon load, check status immediately (handles user loading without buff or with wrong buff).
ashita.events.register('load', 'cb_load', function()
    local ok, buffs = pcall(function()
        return AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    end)
    if ok and buffs then
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
        -- Wait for naturally occurring RoE mask packets
        ashita.tasks.once(3, function()
            if is_world_ready() then
                print_status_and_correct()
            end
        end)
    else
        -- Wait until world is ready, then check
        ashita.tasks.once(5, function()
            if is_world_ready() then
                print_status_and_correct()
            end
        end)
    end
end)

-- Only listen for 0x0A (zone change) and match the unityroEZ/zonename pattern.
ashita.events.register('packet_in', 'cb_packet_in', function(e)
    if e.id == 0x0A then
        local moghouse = struct.unpack('b', e.data, 0x80 + 1)
        if moghouse ~= 1 then
            -- Wait a bit before checking, similar to load event
            ashita.tasks.once(3, function()
                if is_world_ready() then
                    handle_zone_event()
                end
            end)
        end
    elseif e.id == PKT_ROE_MASK then
        -- Check offset from RoE mask packet, only trigger on offset == 3
        local offset = struct.unpack('H', e.data, MASK_OFFSET_BYTE)
        if offset == 3 then
            handle_zone_event()
        end
    elseif e.id == 0x037 then
        local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
        if buffs_changed(buffs, last_buffs) then
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
            -- Only check if we don't have the correct buff or lost a crystal buff
            local current_buff = get_current_buff(buffs)
            local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
            local required_buff = get_required_buff(zone_id)
            
            if is_world_ready() and (not current_buff or current_buff ~= required_buff) then
                print_status_and_correct()
            end
        end
    end
end)