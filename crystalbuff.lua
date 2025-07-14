addon.name      = 'CrystalBuff';
addon.author    = 'Seekey';
addon.version   = '0.1';
addon.desc      = 'Tracks current zone and buff information.';
addon.link      = 'https://github.com/seekey13/CrystalBuff';

require('common');

local last_zone = nil
local last_buffs = {}

-- Helper to get zone name from ID
local function get_zone_name(zone_id)
    return AshitaCore:GetResourceManager():GetString('zones.names', zone_id) or ('Unknown Zone [' .. tostring(zone_id) .. ']')
end

-- Helper to get buff name from ID
local function get_buff_name(buff_id)
    return AshitaCore:GetResourceManager():GetString('buffs.names', buff_id) or ('BuffID: ' .. tostring(buff_id))
end

-- Print zone and buffs
local function print_status()
    local zone_id = AshitaCore:GetMemoryManager():GetZone():GetZoneId()
    local zone_name = get_zone_name(zone_id)
    print(('[CrystalBuff] Current Zone: %s (%u)'):format(zone_name, zone_id))

    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    local buff_names = {}
    for _, buff_id in ipairs(buffs) do
        if buff_id > 0 then
            table.insert(buff_names, get_buff_name(buff_id))
        end
    end
    print('[CrystalBuff] Current Buffs: ' .. (next(buff_names) and table.concat(buff_names, ', ') or 'None'))
end

-- Listen for zone change
ashita.events.register('packet_in', 'cb_packet_in', function(e)
    if (e.id == 0x0A) then
        local zone_id = AshitaCore:GetMemoryManager():GetZone():GetZoneId()
        if zone_id ~= last_zone then
            last_zone = zone_id
            print_status()
        end
    end
end)

-- Listen for buff changes (check every 2 seconds)
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
