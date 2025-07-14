addon.name      = 'CrystalBuff';
addon.author    = 'Seekey';
addon.version   = '0.3';
addon.desc      = 'Tracks correct crystal buff (Signet, Sanction, Sigil) based on current zone.';
addon.link      = 'https://github.com/seekey13/CrystalBuff';

require('common');

local last_zone = nil
local last_buffs = {}

-- IDs for Signet, Sanction, and Sigil
local tracked_buffs = {
    [118] = 'Signet',
    [119] = 'Sanction',
    [120] = 'Sigil'
}

-- Returns which buff should be active in this zone
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
    return AshitaCore:GetResourceManager():GetString('zones.names', zone_id) or ('Unknown Zone [' .. tostring(zone_id) .. ']')
end

-- Print zone and tracked buff info, and what should be active
local function print_status()
    local zone_id = AshitaCore:GetMemoryManager():GetZone():GetZoneId()
    local zone_name = get_zone_name(zone_id)
    local required_buff = get_required_buff(zone_id)

    print(('[CrystalBuff] Current Zone: %s (%u)'):format(zone_name, zone_id))
    print(('[CrystalBuff] Required Buff: %s'):format(required_buff))

    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    local found_buff = nil
    for _, buff_id in ipairs(buffs) do
        if tracked_buffs[buff_id] then
            found_buff = tracked_buffs[buff_id]
            break
        end
    end
    print('[CrystalBuff] Current Crystal Buff: ' .. (found_buff or 'None'))
end

ashita.events.register('packet_in', 'cb_packet_in', function(e)
    if (e.id == 0x0A) then
        local zone_id = AshitaCore:GetMemoryManager():GetZone():GetZoneId()
        if zone_id ~= last_zone then
            last_zone = zone_id
            print_status()
        end
    end
end)

ashita.tasks.repeating(2, 0, 2, function()
    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    local changed = false
    for i = 1, #buffs do
        if last_buffs[i] ~= buffs[i] then
            changed = true
            break
        end
    end
    if changed then
        last_buffs = {table.unpack(buffs)}
        print_status()
    end
end)
