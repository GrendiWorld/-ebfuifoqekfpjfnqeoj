local enable = ui.new_checkbox("Lua", "B", "Anti-Aim Correction")

local storage = {}
local last_choked = {}

local function norm_yaw(y) 
    while y > 180 do y = y - 360 end
    while y <= -180 do y = y + 360 end
    return y
end

local function norm_pitch(p) 
    p = math.max(-89, math.min(89, p))
    return p
end

local function angle_diff(a1, a2)
    local d = a2 - a1
    while d > 180 do d = d - 360 end
    while d <= -180 do d = d + 360 end
    return d
end

local function is_adjusting_balance(player)
    for i = 0, 12 do
        local seq = entity.get_prop(player, "m_AnimOverlay", i, "m_nSequence") or 0
        if seq == 979 then
            return true
        end
    end
    return false
end

local function is_breaking_lby(player, cur, prev)
    if not is_adjusting_balance(player) then return false end

    if prev and cur then
        if prev.cycle ~= cur.cycle and cur.weight == 1.0 then
            return true
        end
        if cur.weight == 0.0 and prev.cycle > 0.92 and cur.cycle > 0.92 then
            return true
        end
    end
    return false
end

local function get_choked(player)
    local sim = entity.get_prop(player, "m_flSimulationTime") or 0
    local old = entity.get_prop(player, "m_flOldSimulationTime") or sim
    local ticks = math.floor((sim - old) / globals.tickinterval() + 0.5)

    local idx = entity.get_prop(player, "m_nTickBase")
    if ticks == 0 and last_choked[idx] and last_choked[idx] > 0 then
        return last_choked[idx] - 1
    end

    last_choked[idx] = ticks
    return ticks
end

local function get_backward_yaw(player)
    local lp = entity.get_local_player()
    if not lp then return 0 end
    local lorg = vector(entity.get_prop(lp, "m_vecOrigin"))
    local eorg = vector(entity.get_prop(player, "m_vecOrigin"))
    local delta = eorg - lorg
    return math.deg(math.atan2(delta.y, delta.x))
end

local function run()
    if not ui.get(enable) then
        storage = {}
        return
    end

    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then return end

    local enemies = entity.get_players(true)

    for i = 1, #enemies do
        local p = enemies[i]
        local idx = p

        if not storage[idx] then
            storage[idx] = {
                side = false,
                was_first_brute = false,
                was_second_brute = false,
                prev_layers = {}
            }
        end

        local data = storage[idx]

        local eye = { entity.get_prop(p, "m_angEyeAngles") }
        if #eye < 3 then goto next end

        local lby = entity.get_prop(p, "m_flLowerBodyYawTarget") or eye[2]
        local original_goal_feet_yaw = norm_yaw(lby)
        local original_pitch = norm_pitch(eye[1])

        local layer12 = {
            weight = entity.get_prop(p, "m_AnimOverlay", 12, "m_flWeight") or 0,
            cycle  = entity.get_prop(p, "m_AnimOverlay", 12, "m_flCycle") or 0
        }

        local prev_layer12 = data.prev_layers[12] or { cycle = 0, weight = 0 }
        data.prev_layers[12] = layer12

        local breaking_lby = is_breaking_lby(p, layer12, prev_layer12)

        local diff = angle_diff(eye[2], original_goal_feet_yaw)
        local side = diff <= 0

        local resolved_yaw = eye[2]

        if breaking_lby then
            resolved_yaw = original_goal_feet_yaw
            data.was_first_brute = false
            data.was_second_brute = false
        else
            if math.abs(diff) > 80 then
                resolved_yaw = original_goal_feet_yaw + (side and 120 or -120)
            else
                resolved_yaw = original_goal_feet_yaw + (side and 58 or -58)
            end
        end

        entity.set_prop(p, "m_angEyeAngles", original_pitch, norm_yaw(resolved_yaw), eye[3])

        ::next::
    end
end

client.set_event_callback("net_update_end", run)
client.set_event_callback("round_start", function() storage = {} last_choked = {} end)
