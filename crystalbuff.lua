--[[
CrystalBuff
Automatically tracks and corrects your current crystal buff (Signet, Sanction, Sigil) based on your zone.
Copyright (c) 2025 Seekey
https://github.com/seekey13/CrystalBuff

This addon is designed for Ashita v4 and the CatsEyeXI private server.
]]

addon.name      = 'CrystalBuff'
addon.author    = 'Seekey'
addon.version   = '1.5'
addon.desc      = 'Tracks and corrects crystal buff (Signet, Sanction, Sigil) based on current zone.'
addon.link      = 'https://github.com/seekey13/CrystalBuff'

require('common')
local chat = require('chat')

-- Zone data: maps zone IDs to required buff type, and marks non-combat zones.
local buff_map = {}
local non_combat_zones = {}

local non_combat_zone_ids = {
    230, 231, 232, 233,          -- San d'Oria
    234, 235, 236, 237,          -- Bastok
    238, 239, 240, 241, 242,     -- Windurst
    243, 244, 245, 246,          -- Jeuno
    80, 87, 94,                  -- WotG Cities (San d'Oria [S], Bastok [S], Windurst [S])
    48, 50, 53,                  -- Aht Urhgan cities/towns (Al Zahbi, Whitegate, Nashmau)
    26, 247, 248, 249, 250, 252, -- Other Towns (Tavnazian Safehold, Rabao, Selbina, Mhaura, Kazham, Norg)
    256, 257,                    -- Adoulin
    280,                         -- Mog Garden
    46, 47,                      -- Open sea routes
    220, 221,                    -- Ships bound for Selbina/Mhaura
    223, 224, 225, 226,          -- Airships
    227, 228,                    -- Ships with Pirates (still safe zones)
    70,                          -- Chocobo Circuit
    251,                         -- Hall of the Gods
    284,                         -- Celennia Memorial Library
}

-- Signet zones (Original FFXI, Rise of the Zilart, Chains of Promathia)
local signet_zones = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 134, 135, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 157, 158, 159, 160, 161, 162, 163, 165, 166, 167, 168, 169, 170, 172, 173, 174, 176, 177, 178, 179, 180, 181, 184, 185, 186, 187, 188, 190, 191, 192, 193, 194, 195, 196, 197, 198, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 211, 212, 213
}

-- Sanction zones (Treasures of Aht Urhgan)
local sanction_zones = {
    51, 52, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 71, 72, 73, 74, 75, 76, 77, 78, 79
}

-- Sigil zones (Wings of the Goddess)
local sigil_zones = {
    81, 82, 83, 84, 85, 86, 88, 89, 90, 91, 92, 93, 95, 96, 97, 98, 99, 136, 137, 138, 155, 156, 164, 171, 175, 182, 279, 298
}

for buff_name, zones in pairs({ Signet = signet_zones, Sanction = sanction_zones, Sigil = sigil_zones }) do
    for _, zone_id in ipairs(zones) do buff_map[zone_id] = buff_name end
end

for _, zone_id in ipairs(non_combat_zone_ids) do non_combat_zones[zone_id] = true end
local last_buffs = {}
local pending_buff_check = false
local last_check_time = 0

-- Constants
local MAX_BUFF_SLOTS  = 31    -- Maximum buff slot index (0-31)
local INVALID_BUFF_ID = 255   -- Invalid/empty buff slot marker
local PKT_ZONE_IN     = 0x0A  -- Zone in packet
local CHECK_INTERVAL  = 1.0   -- Seconds between tick evaluations

-- Buff names mapped to ID and correction command (single source of truth).
local tracked_buffs = {
    Signet   = { id = 253, command = '!signet'   },
    Sanction = { id = 256, command = '!sanction' },
    Sigil    = { id = 268, command = '!sigil'    },
}

-- Reverse lookup: buff ID -> command (built once at load).
local buff_id_to_command = {}
for _, entry in pairs(tracked_buffs) do
    buff_id_to_command[entry.id] = entry.command
end

-- Safe pcall wrapper: returns value on success, nil on error.
local function safe_call(fn)
    local ok, result = pcall(fn)
    if ok then return result end
end

-- GetEventSystemActive Code From Thorny
local pEventSystem = ashita.memory.find('FFXiMain.dll', 0, "A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3", 0, 0);
local function is_event_system_active()
    if pEventSystem == 0 then return false end
    local ptr = ashita.memory.read_uint32(pEventSystem + 1)
    if ptr == 0 then return false end
    return ashita.memory.read_uint8(ptr) == 1
end

-- Returns the player object, or nil if unavailable.
local function get_player()
    return safe_call(function() return AshitaCore:GetMemoryManager():GetPlayer() end)
end

-- Returns true if the player data has not finished loading yet.
local function is_loading(player)
    local level = player:GetMainJobLevel()
    return not level or level == 0
end

-- Returns the current zone ID.
local function get_zone()
    return safe_call(function() return AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) end)
end

-- Queues a command to be executed by the chat manager.
local function queue_command(cmd)
    AshitaCore:GetChatManager():QueueCommand(-1, cmd)
end

-- Returns the player's current buffs as a filtered table.
local function get_buffs(player)
    local buffs = safe_call(function() return player:GetBuffs() end)
    if not buffs then return nil end

    local valid_buffs = {}
    for i = 0, MAX_BUFF_SLOTS do
        local buff_id = buffs[i]
        if buff_id and buff_id ~= INVALID_BUFF_ID and buff_id > 0 then
            table.insert(valid_buffs, buff_id)
        end
    end
    return valid_buffs
end

-- Finds the command for the first matching tracked buff in player's buffs.
local function get_current_buff(buffs)
    for _, buff_id in ipairs(buffs) do
        local cmd = buff_id_to_command[buff_id]
        if cmd then return cmd end
    end
end

-- Returns true if the buff arrays differ (order-insensitive).
local function buffs_changed(new, old)
    if #new ~= #old then return true end
    local set = {}
    for _, v in ipairs(old) do set[v] = true end
    for _, v in ipairs(new) do
        if not set[v] then return true end
    end
    return false
end

-- Main loop: throttled to once per second; checks and corrects buff when pending.
local function check_and_correct_buff()
    local now = os.clock()
    if now - last_check_time < CHECK_INTERVAL then return end
    last_check_time = now

    local player = get_player()
    if is_loading(player) then return end
    if is_event_system_active() then return end

    local buffs = get_buffs(player)
    if buffs and buffs_changed(buffs, last_buffs) then
        last_buffs = buffs
        pending_buff_check = true
    end

    if not pending_buff_check or not buffs then return end
    pending_buff_check = false

    local zone_id = get_zone()
    if not zone_id then return end

    if non_combat_zones[zone_id] then return end

    local required_buff = buff_map[zone_id]
    if not required_buff then return end

    local required_cmd = tracked_buffs[required_buff].command
    if get_current_buff(buffs) ~= required_cmd then
        print(chat.header(addon.name) .. chat.message(('Mismatch detected, issuing command: %s'):format(required_cmd)))
        queue_command(required_cmd)
    end
end

ashita.events.register('d3d_present', 'cb_present', check_and_correct_buff)

ashita.events.register('load', 'cb_load', function()
    pending_buff_check = true
end)

ashita.events.register('packet_in', 'cb_packet_in', function(e)
    if e.id == PKT_ZONE_IN then
        pending_buff_check = true
    end
end)