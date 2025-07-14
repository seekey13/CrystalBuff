addon.name      = 'CrystalBuff';
addon.author    = 'Seekey';
addon.version   = '0.5';
addon.desc      = 'Tracks and corrects crystal buff (Signet, Sanction, Sigil) based on current zone.';
addon.link      = 'https://github.com/seekey13/CrystalBuff';

require('common');

local last_zone = nil
local last_buffs = {}

local tracked_buffs = {
    [118] = 'Signet',
    [119] = 'Sanction',
    [120] = 'Sigil'
}

local required_buff_commands = {
    ['Signet'] = '!signet',
    ['Sanction'] = '!sanction',
    ['Sigil'] = '!sigil'
}

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

local function get_current_buff(buffs)
    for _, buff_id in ipairs(buffs) do
        if tracked_buffs[buff_id] then
            return tracked_buffs[buff_id]
        end
    end
    return nil
end

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
        local cmd = required_buff_commands[required_buff]
        print(('[CrystalBuff] Mismatch detected, issuing command: %s'):format(cmd))
        AshitaCore:GetChatManager():QueueCommand(-1, cmd)
    end
end

ashita.events.register('packet_in', 'cb_packet_in', function(e)
    if (e.id == 0x0A) then
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
