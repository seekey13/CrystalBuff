--[[
CrystalBuff
Automatically tracks and corrects your current crystal buff (Signet, Sanction, Sigil) based on your zone.
Copyright (c) 2025 Seekey
https://github.com/seekey13/CrystalBuff

This addon is designed for Ashita v4 and the CatsEyeXI private server.
]]

addon.name      = 'CrystalBuff';
addon.author    = 'Seekey';
addon.version   = '0.7';
addon.desc      = 'Tracks and corrects crystal buff (Signet, Sanction, Sigil) based on current zone.';
addon.link      = 'https://github.com/seekey13/CrystalBuff';

require('common');

local last_zone = nil
local last_buffs = {}
local last_command_time = 0
local COMMAND_COOLDOWN = 10 -- seconds; rate limit for issuing correction commands

-- Buff IDs for Signet, Sanction, and Sigil.
local tracked_buffs = {
    [118] = 'Signet',
    [119] = 'Sanction',
    [120] = 'Sigil'
}

-- Chat command mapping for each buff type.
local required_buff_commands = {
    ['Signet'] = '!signet',
    ['Sanction'] = '!sanction',
    ['Sigil'] = '!sigil'
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
    for _, buff_id in ipairs(buffs) do
        if tracked_buffs[buff_id] then
            return tracked_buffs[buff_id]
        end
    end
    return nil
end

-- Compare two buff tables for any difference.
local function buffs_changed(new, old)
    if #new ~= #old then return true end
    for i = 1, #new do
        if new[i] ~= old[i] then
            return true
        end
    end
    return false
end

local function print_status_and_correct()
    local zone_id = AshitaCore:GetMemoryManager():GetZone():GetZoneId()
    local zone_name = get_zone_name(zone_id)
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

-- On addon load, check status immediately (handles user loading without buff or with wrong buff).
ashita.events.register('load', 'cb_load', function()
    -- Initialize last_buffs to current buff list so first packet_in isn't double-triggered.
    local ok, buffs = pcall(function()
        return AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    end)
    if ok and type(buffs) == "table" then
        last_buffs = {table.unpack(buffs)}
    end
    print_status_and_correct()
end)

ashita.events.register('packet_in', 'cb_packet_in', function(e)
    -- Use 0x01B for "zone finished loading" instead of 0x0A which was zone changed.
    if (e.id == 0x01B) then
        local zone_id = AshitaCore:GetMemoryManager():GetZone():GetZoneId()
        if zone_id ~= last_zone then
            last_zone = zone_id
            print_status_and_correct()
        end
    elseif (e.id == 0x063 or e.id == 0x037) then
        local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
        if buffs_changed(buffs, last_buffs) then
            last_buffs = {table.unpack(buffs)}
            print_status_and_correct()
        end
    end
end)
