--[[
* Zone Buff Lookup Table
* Maps zone IDs to their appropriate buff types
* 
* Buff Types:
* - Signet: Original FFXI zones (Final Fantasy XI Vanilla, Rise of the Zilart, Chains of Promathia)
* - Sanction: Treasures of Aht Urhgan zones
* - Sigil: Wings of the Goddess zones

--]]

local zone_buffs = {}
local non_combat_zones = {}

local non_combat_zone_ids = {
    230, 231, 232, 233, -- San d'Oria
    234, 235, 236, 237, -- Bastok
    238, 239, 240, 241, 242, -- Windurst
    243, 244, 245, 246, -- Jeuno
    80, 87, 94, -- WotG Cities of the past (San d'Oria [S], Bastok [S], Windurst [S]
    48, 50, 53, -- Aht Urhgan cities/towns (Al Zahbi, Aht Urhgan Whitegate, Nashmau)
    26, 247, 248, 249, 250, 252, -- Other Towns (Tavnazian Safehold, Rabao, Selbina, Mhaura, Kazham, Norg)
    256, 257, -- Adoulin
    280, -- Mog Garden
    46, 47, -- Open sea routes
    220, 221, -- Ships bound for Selbina/Mhaura
    223, 224, 225, 226, -- Airships
    227, 228, -- Ships with Pirates (still safe zones)
    70, -- Chocobo Circuit
    251, -- Hall of the Gods
    284, -- Celennia Memorial Library
}

-- Signet zones (Original FFXI, Rise of the Zilart, Chains of Promathia)
local signet_zones = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44,
    100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131,
    134, 135, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 157, 158, 159, 160, 161, 162, 163, 165, 166, 167, 168, 169, 170,
    172, 173, 174, 176, 177, 178, 179, 180, 181, 184, 185, 186, 187, 188, 190, 191, 192, 193, 194, 195, 196, 197, 198, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 211, 212, 213,
    220, 221, 223, 224, 225, 226, 227, 228, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252
}

-- Sanction zones (Treasures of Aht Urhgan)
local sanction_zones = {
    46, 47, 48, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79
}

-- Sigil zones (Wings of the Goddess)
local sigil_zones = {
    80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 136, 137, 138, 155, 156, 164, 171, 175, 182, 279, 298
}

-- Initialize the lookup table
for _, zone_id in ipairs(signet_zones) do
    zone_buffs[zone_id] = "Signet"
end

for _, zone_id in ipairs(sanction_zones) do
    zone_buffs[zone_id] = "Sanction"
end

for _, zone_id in ipairs(sigil_zones) do
    zone_buffs[zone_id] = "Sigil"
end

for _, zone_id in ipairs(non_combat_zone_ids) do
    non_combat_zones[zone_id] = true
end

-- Function to get the buff type for a given zone ID (returns nil for ignored zones)
function GetZoneBuff(zone_id)
    return zone_buffs[zone_id]
end

-- Function to check if a zone has buff tracking (not ignored)
function ZoneHasBuff(zone_id)
    return zone_buffs[zone_id] ~= nil
end

-- Function to check if a zone supports a specific buff
function ZoneSupports(zone_id, buff_type)
    return GetZoneBuff(zone_id) == buff_type
end

-- Function to get all zones that support a specific buff type
function GetZonesByBuff(buff_type)
    local zones = {}
    for zone_id, buff in pairs(zone_buffs) do
        if buff == buff_type then
            table.insert(zones, zone_id)
        end
    end
    table.sort(zones)
    return zones
end

-- Export the module
return {
    GetZoneBuff = GetZoneBuff,
    ZoneHasBuff = ZoneHasBuff,
    ZoneSupports = ZoneSupports,
    GetZonesByBuff = GetZonesByBuff,
    zone_buffs = zone_buffs,
    non_combat_zones = non_combat_zones
}
