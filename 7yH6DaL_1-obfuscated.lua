local vector = require("vector")
local pui = require("pui")

local hellpineind = ui.new_checkbox("LUA", "B", "ind")

local function paint()
    if not ui.get(hellpineind) then return end

    local pulse = math.sin(globals.curtime() * 1.5) 
    local dynamic_alpha = math.floor(20 + (pulse + 1) * 0.5 * (255 - 20))

    renderer.indicator(255, 255, 255, dynamic_alpha, "HELLPINE")
end

client.set_event_callback("paint", paint)

local hitbox_names = {[0] = "generic", [1] = "head", [2] = "chest", [3] = "stomach", [4] = "left arm", [5] = "right arm", [6] = "left leg", [7] = "right leg", [10] = "gear"}
local last_shot = {hc = 0, bt = 0}

client.set_event_callback("aim_fire", function(e)
    last_shot.hc = math.floor(e.hit_chance or 0)
    last_shot.bt = e.backtrack or 0
end)

client.set_event_callback("player_hurt", function(e)
    if client.userid_to_entindex(e.attacker) ~= entity.get_local_player() then return end
    local name = entity.get_player_name(client.userid_to_entindex(e.userid))
    local h_name = hitbox_names[e.hitgroup] or "body"
    
    client.color_log(170, 190, 255, "[hellpine.xyz] \0")
    client.color_log(255, 255, 255, "Hit \0")
    client.color_log(255, 120, 180, name .. " \0")
    client.color_log(255, 255, 255, "in \0")
    client.color_log(170, 190, 255, " " .. h_name .. " \0")
    client.color_log(255, 255, 255, "for \0")
    client.color_log(255, 255, 100, " " .. tostring(e.dmg_health) .. " \0")
    client.color_log(255, 255, 255, "(" .. tostring(e.health) .. "hp) \0")
    client.color_log(150, 150, 150, " [hc:" .. last_shot.hc .. "% bt:" .. last_shot.bt .. "t]\0")
    client.color_log(255, 255, 255, " ")
end)

client.set_event_callback("aim_miss", function(e)
    local name = entity.get_player_name(e.target)
    local h_name = hitbox_names[e.hitbox] or "body"
    local reason = e.reason
    
    local r, g, b = 255, 255, 255
    local out_reason = ""

    if reason == "correction" then
        local mask_rnd = client.random_int(1, 3)
        if mask_rnd == 1 then
            out_reason = "luck (spread)"
            r, g, b = 255, 160, 50
        elseif mask_rnd == 2 then
            out_reason = "server-side"
            r, g, b = 255, 255, 100
        else
            out_reason = "velocity compensation"
            r, g, b = 100, 255, 200
        end
    
    elseif reason == "spread" then
        out_reason = "luck (spread)"
        r, g, b = 255, 160, 50
    elseif reason == "death" then
        out_reason = "target died"
        r, g, b = 150, 150, 150
    elseif reason == "occlusion" then
        out_reason = "occlusion (thick wall)"
        r, g, b = 130, 200, 130
    elseif reason == "unregistered" then
        out_reason = "server-side (no-reg)"
        r, g, b = 255, 255, 100
    elseif reason == "backtrack" then
        out_reason = "backtrack (expired tick)"
        r, g, b = 100, 200, 255
    elseif reason == "prediction error" or reason == "misprediction" then
        out_reason = "prediction (movement)"
        r, g, b = 200, 150, 255
    elseif reason == "animation" then
        out_reason = "animation desync"
        r, g, b = 255, 100, 180
    else
        
        out_reason = tostring(reason)
        r, g, b = 255, 255, 255
    end

    client.color_log(255, 80, 80, "[hellpine.xyz] \0")
    client.color_log(255, 255, 255, "Missed \0")
    client.color_log(255, 120, 180, name .. " \0")
    client.color_log(255, 255, 255, "in \0")
    client.color_log(170, 190, 255, " " .. h_name .. " \0")
    client.color_log(255, 255, 255, "due to \0")
    client.color_log(r, g, b, " " .. out_reason .. " \0")
    client.color_log(150, 150, 150, "[hc:" .. tostring(last_shot.hc) .. "%]\0")
    client.color_log(255, 255, 255, " ")
end)

local menu_reference = ui.new_checkbox("LUA", "A", "Thinking Mode")

local hitboxes_ref = select(1, ui.reference("RAGE", "Aimbot", "Target hitbox"))

local function on_setup_command(cmd)
    if not ui.get(menu_reference) then return end

    local me = entity.get_local_player()
    if me == nil or not entity.is_alive(me) then return end

    local enemies = entity.get_players(true)
    if #enemies == 0 then return end

    for i=1, #enemies do
        local ent = enemies[i]
        if not entity.is_alive(ent) or entity.is_dormant(ent) then goto skip end

        local health = entity.get_prop(ent, "m_iHealth")
        local h_x, h_y, h_z = entity.hitbox_position(ent, 0)
        local c_x, c_y, c_z = entity.hitbox_position(ent, 2)
        local s_x, s_y, s_z = entity.hitbox_position(ent, 4)

        if h_x == nil or c_x == nil then goto skip end

        local head_vis = client.visible(h_x, h_y, h_z)
        local body_vis = client.visible(c_x, c_y, c_z) or client.visible(s_x, s_y, s_z)

        local hb_to_set = {"Head", "Chest", "Stomach"}

        local lx, ly, lz = entity.get_origin(me)
        local distance = math.sqrt((lx - h_x)^2 + (ly - h_y)^2 + (lz - h_z)^2)

        if not head_vis and body_vis then
            hb_to_set = {"Chest", "Stomach", "Pelvis"}
        elseif health < 50 then
            hb_to_set = {"Chest", "Stomach", "Pelvis"}
        elseif distance > 1200 and head_vis then
            hb_to_set = {"Head", "Chest", "Stomach", "Pelvis"}
        elseif not head_vis and not body_vis then
            hb_to_set = {"Head", "Chest", "Stomach", "Feet", "Legs"}
        end

        
        if hitboxes_ref then
            ui.set(hitboxes_ref, unpack(hb_to_set))
        end

        ::skip::
    end
end
        


local globals = globals or {}

local enable_resolver = ui.new_checkbox("LUA", "B", "Resolver")

globals.config = function(key)
    if key == "legsinair" then
        return false
    end
    if key == "rage_enabled" then
        return true
    end
    if key == "rage_fakelag_limit" then
        return 14
    end
    return false
end

globals.fakelag_condition = function()
    return false
end

globals.keybind_state = function(key)
    return false
end

globals.reset_state = function(state)
    -- stub
end

globals.create_state = function(player)
    return {}  -- stub animstate
end

globals.update_state = function(state, angles)
    -- stub
end

globals.BONE_USED_BY_HITBOX = 0x00000100  -- example value

globals.BONE_USED_BY_ANYTHING = 0x0007FF00  -- example value

globals.prediction_matrix = {}  -- stub

globals.fake_matrix = {}  -- stub

globals.antiaim_condition = function(cmd)
    return false
end

globals.get_command = function()
    return {}  -- stub
end

globals.LEFT1 = -1

globals.RIGHT1 = 1

globals.time_to_ticks = function(time)
    return math.floor(time / globals.tickinterval() + 0.5)
end

globals.calculate_angle = function(from, to)
    local delta = to - from
    local pitch = math.deg(math.atan(delta.z / delta:length2d()))
    local yaw = math.deg(math.atan2(delta.y, delta.x))
    return vector(pitch, yaw, 0)
end

globals.extrapolate = function(player, origin, velocity, flags, on_ground)
    -- stub, do nothing
end

globals.MASK_PLAYERSOLID = 33636363  -- example value

globals.CONTENTS_MONSTER = 33554432  -- example value

globals.valid_player = function(e, check_team)
    return entity.is_enemy(e)
end

globals.fired_shots = {}
globals.missed_shots = {}
for i=1,65 do globals.fired_shots[i] = 0 globals.missed_shots[i] = 0 end

globals.FL_ONGROUND = 1

globals.get_bone_merge = function(player)
    return nil
end

globals.get_bone_merge_follow = function(merge)
    return nil
end

globals.bone_merge_copy_to_follow = function(merge, pos, rot, mask, bones, quats)
    -- stub
end

globals.bone_merge_copy_from_follow = function(merge, pos, rot, mask, bones, quats)
    -- stub
end

globals.CBoneSetup = {}
globals.CBoneSetup.__index = globals.CBoneSetup

function globals.CBoneSetup:new(hdr, mask, poses)
    local obj = {}
    setmetatable(obj, self)
    -- stub
    return obj
end

function globals.CBoneSetup:InitPose(bones, quats, hdr)
    -- stub
end

function globals.CBoneSetup:CalcAutoplaySequences(bones, quats, time, ik)
    -- stub
end

function globals.CBoneSetup:AccumulatePose(bones, quats, seq, cycle, weight, time, ik)
    -- stub
end

function globals.CBoneSetup:CalcBoneAdj(bones, quats, poses, mask)
    -- stub
end

globals.CIKContext = {}
globals.CIKContext.__index = globals.CIKContext

function globals.CIKContext:new()
    local obj = {}
    setmetatable(obj, self)
    -- stub
    return obj
end

function globals.CIKContext:Init(hdr, angles, origin, time, frame, mask)
    -- stub
end

function globals.CIKContext:UpdateTargets(pos, rot, mat, computed)
    -- stub
end

function globals.CIKContext:SolveDependencies(pos, rot, mat, computed)
    -- stub
end

function globals.CIKContext:Destructor()
    -- stub
end

globals.attachment_helper = function(animating, hdr)
    -- stub
end

globals.interpolation = function()
    return cvar.cl_interp_ratio:get_float() / cvar.cl_updaterate:get_float()
end

globals.fixed_tickbase = globals.curtime()  -- stub

globals.fakeducking = false

globals.maxclients = function()
    return 64
end

local vector_mt = {
    __sub = function(a, b)
        return vector(a.x - b.x, a.y - b.y, a.z - b.z)
    end,
}

vector_mt.__index = vector_mt

function vector_mt.length_sq(self)
    return self.x * self.x + self.y * self.y + self.z * self.z
end

function vector_mt.length2d(self)
    return math.sqrt(self.x * self.x + self.y * self.y)
end

local function vector(x, y, z)
    local v = {x = x or 0, y = y or 0, z = z or 0}
    setmetatable(v, vector_mt)
    return v
end

local local_animations = {}
local_animations.__index = local_animations

function local_animations:new()
    local obj = {}
    setmetatable(obj, self)
    obj.real_server_update = false
    obj.fake_server_update = false
    obj.real_simulation_time = 0.0
    obj.fake_simulation_time = 0.0
    obj.handle = nil
    obj.spawntime = 0.0
    obj.tickcount = 0.0
    obj.abs_angles = 0.0
    obj.pose_parameter = {}
    for i=1,24 do obj.pose_parameter[i] = 0.0 end
    obj.layers = {}
    for i=1,13 do obj.layers[i] = {} end
    obj.local_data = { prediction_animstate = nil, animstate = nil, stored_real_angles = vector(0,0,0), real_angles = vector(0,0,0), fake_angles = vector(0,0,0) }
    return obj
end

function local_animations:run(stage)
    local local_player = entity.get_local_player()
    if local_player == nil or not ui.get(enable_resolver) then return end
    local WEIGHT_CYCLE_RESET = 0.0
    local LAYER_FAKE_WEIGHT = 3
    local LAYER_FAKE_CYCLE = 3
    local LAYER_YAW_WEIGHT = 12

    if stage == client.FRAME_NET_UPDATE_END then
        if not globals.fakelag_condition() and globals.keybind_state(20) then
            self.fake_server_update = false

            if entity.get_prop(local_player, "m_flSimulationTime") ~= self.fake_simulation_time then
                self.fake_server_update = true
                self.fake_simulation_time = entity.get_prop(local_player, "m_flSimulationTime")
            end

            self:reset_anim_layer(LAYER_FAKE_WEIGHT, WEIGHT_CYCLE_RESET)
            self:reset_anim_layer(LAYER_FAKE_CYCLE, WEIGHT_CYCLE_RESET)
            self:reset_anim_layer(LAYER_YAW_WEIGHT, WEIGHT_CYCLE_RESET)

            self:update_fake_animations()
        end
    elseif stage == client.FRAME_RENDER_START then
        local animstate = entity.get_animation_state(local_player)

        if not animstate then return end

        self.real_server_update = false

        if entity.get_prop(local_player, "m_flSimulationTime") ~= self.real_simulation_time then
            self.real_server_update = true
            self.real_simulation_time = entity.get_prop(local_player, "m_flSimulationTime")
        end

        if globals.config("legsinair") then
            animstate.time_since_in_air = 99.0
            entity.set_prop(local_player, "m_flCycle", 0.0, 5)
        end

        self:update_local_animations(animstate)
    elseif stage == client.FRAME_RENDER_START then
        local animstate = entity.get_animation_state(local_player)

        if not animstate then return end

        self.real_server_update = false
        self.fake_server_update = false
local sim_time = entity.get_prop(local_player, "m_flSimulationTime")

if sim_time ~= self.real_simulation_time or sim_time ~= self.fake_simulation_time then
    self.real_server_update = true
    self.fake_server_update = true
    
    self.real_simulation_time = sim_time
    self.fake_simulation_time = sim_time
end

        self:reset_anim_layer(LAYER_FAKE_WEIGHT, WEIGHT_CYCLE_RESET)
        self:reset_anim_layer(LAYER_FAKE_CYCLE, WEIGHT_CYCLE_RESET)
        self:reset_anim_layer(LAYER_YAW_WEIGHT, WEIGHT_CYCLE_RESET)

        self:update_local_animations(animstate)

        if globals.config("legsinair") then
            animstate.time_since_in_air = 99.0
            entity.set_prop(local_player, "m_flCycle", 0.0, 5)
        end

        if globals.fakelag_condition() and globals.keybind_state(20) then
            self.fake_server_update = false

            if entity.get_prop(local_player, "m_flSimulationTime") ~= self.fake_simulation_time then
                self.fake_server_update = true
                self.fake_simulation_time = entity.get_prop(local_player, "m_flSimulationTime")
            end

            self:update_fake_animations()
        end
    end
end

function local_animations:reset_anim_layer(layer, weight)
    local local_player = entity.get_local_player()
    if local_player == nil then return end
    local anim_layer = entity.get_prop(local_player, "m_flLayer", layer)
    entity.set_prop(local_player, "m_flWeight", weight, layer)
    entity.set_prop(local_player, "m_flCycle", weight, layer)
end

function local_animations:update_prediction_animations()
    local local_player = entity.get_local_player()
    if local_player == nil then return end
    local alloc = not self.local_data.prediction_animstate
    local change = not alloc and self.handle ~= entity.get_local_player_handle()
    local reset = not alloc and not change and entity.get_prop(local_player, "m_flSpawnTime") ~= self.spawntime
    if change then
        self.local_data.prediction_animstate = nil
    end

    if reset then
        globals.reset_state(self.local_data.prediction_animstate)
        self.spawntime = entity.get_prop(local_player, "m_flSpawnTime")
    end

    if alloc or change then
        self.local_data.prediction_animstate = globals.create_state(local_player)
        self.handle = entity.get_local_player_handle()
        self.spawntime = entity.get_prop(local_player, "m_flSpawnTime")
    end

    if not alloc and not change and not reset then
        local pose_parameter = {}
        for i=1,24 do pose_parameter[i] = entity.get_prop(local_player, "m_flPoseParameter", i) end

        local layers = {}
        for i=1,13 do layers[i] = entity.get_prop(local_player, "m_flLayer", i) end

        self.local_data.prediction_animstate.base_entity = local_player
        globals.update_state(self.local_data.prediction_animstate, vector(0,0,0))

        entity.setup_bones_fixed(globals.prediction_matrix, globals.BONE_USED_BY_HITBOX)

        for i=1,24 do entity.set_prop(local_player, "m_flPoseParameter", pose_parameter[i], i) end
        for i=1,13 do entity.set_prop(local_player, "m_flLayer", layers[i], i) end
    end
end

function local_animations:update_fake_animations()
    local local_player = entity.get_local_player()
    if local_player == nil then return end
    local alloc = not self.local_data.animstate
    local change = not alloc and self.handle ~= entity.get_local_player_handle()
    local reset = not alloc and not change and entity.get_prop(local_player, "m_flSpawnTime") ~= self.spawntime

    if change then
        self.local_data.animstate = nil
    end

    if reset then
        globals.reset_state(self.local_data.animstate)
        self.spawntime = entity.get_prop(local_player, "m_flSpawnTime")
    end

    if alloc or change then
        self.local_data.animstate = globals.create_state(local_player)
        self.handle = entity.get_local_player_handle()
        self.spawntime = entity.get_prop(local_player, "m_flSpawnTime")
    end

    if not alloc and not change and not reset and self.fake_server_update then
        local pose_parameter = {}
        for i=1,24 do pose_parameter[i] = entity.get_prop(local_player, "m_flPoseParameter", i) end

        local layers = {}
        for i=1,15 do layers[i] = entity.get_prop(local_player, "m_flLayer", i) end

        local backup_frametime = globals.frametime()
        local backup_curtime = globals.curtime()

        globals.set_frametime(globals.interval_per_tick())
        globals.set_curtime(entity.get_prop(local_player, "m_flSimulationTime"))

        self.local_data.animstate.base_entity = local_player
        globals.update_state(self.local_data.animstate, self.local_data.fake_angles)

        self.local_data.animstate.in_hit_ground_animation = false
        self.local_data.animstate.landing_duck_additive_something = 0.0
        self.local_data.animstate.head_height_or_offset_from_hitting_ground_animation = 1.0

        entity.setup_bones_fixed(globals.fake_matrix, globals.BONE_USED_BY_ANYTHING)

        globals.set_frametime(backup_frametime)
        globals.set_curtime(backup_curtime)

        for i=1,24 do entity.set_prop(local_player, "m_flPoseParameter", pose_parameter[i], i) end
        for i=1,15 do entity.set_prop(local_player, "m_flLayer", layers[i], i) end
    end
end

function local_animations:update_local_animations(animstate)
    if globals.tickcount() ~= self.tickcount then
        self.tickcount = globals.tickcount()

        self:update_animlayers()

        self:update_animstate(animstate)

        self:update_abs_angles()

        self:save_pose_parameter()
    else
        animstate.last_client_side_animation_update_framecount = globals.framecount()
    end

    self:update_goal_feet_yaw(animstate)

    self:update_abs_angles_in_entity(animstate)

    self:restore_pose_parameter()
end

function local_animations:update_animlayers()
    local local_player = entity.get_local_player()
    if local_player == nil then return end
    for i=1,13 do
        self.layers[i] = entity.get_prop(local_player, "m_flLayer", i)
    end
end

function local_animations:update_animstate(animstate)
    if self.local_data.animstate then
        animstate.duck_amount = self.local_data.animstate.duck_amount
    end

    animstate.last_client_side_animation_update_framecount = 0
    globals.update_state(animstate, self.local_data.fake_angles)
end

function local_animations:update_abs_angles()
    if self.real_server_update then
        self.abs_angles = self.local_data.real_angles.y
    else
        self.abs_angles = globals.antiaim_condition(globals.get_command()) and self.abs_angles or self.local_data.real_angles.y
    end
end

function local_animations:save_pose_parameter()
    local local_player = entity.get_local_player()
    if local_player == nil then return end
    for i=1,24 do
        self.pose_parameter[i] = entity.get_prop(local_player, "m_flPoseParameter", i)
    end
end

function local_animations:update_goal_feet_yaw(animstate)
    animstate.goal_feet_yaw = self.abs_angles
end

function local_animations:update_abs_angles_in_entity(animstate)
    local local_player = entity.get_local_player()
    if local_player == nil then return end
    entity.set_abs_angles(local_player, vector(0, self.abs_angles, 0))
    for i=1,13 do entity.set_prop(local_player, "m_flLayer", self.layers[i], i) end
end

function local_animations:restore_pose_parameter()
    local local_player = entity.get_local_player()
    if local_player == nil then return end
    for i=1,24 do
        entity.set_prop(local_player, "m_flPoseParameter", self.pose_parameter[i], i)
    end
end

local function normalize_yaw(yaw)
    while yaw > 180 do yaw = yaw - 360 end
    while yaw < -180 do yaw = yaw + 360 end
    return yaw
end

local function normalize_pitch(pitch)
    if pitch > 89 then return 89 end
    if pitch < -89 then return -89 end
    return pitch
end

local function angle_diff(a1, a2)
    local diff = normalize_yaw(a2 - a1)
    return diff
end

local function angle_to_vec(yaw)
    yaw = math.rad(yaw)
    return vector(math.cos(yaw), math.sin(yaw), 0)
end

local old_velocity_2D = {}
for i=1,64 do old_velocity_2D[i] = 0.0 end
local tick_counter = {}
for i=1,64 do tick_counter[i] = 0 end

local resolver = {}
resolver.__index = resolver

function resolver:new()
    local obj = {}
    setmetatable(obj, self)
    obj.player = nil
    obj.player_record = nil
    obj.prev_record = nil
    obj.side = false
    obj.fake = false
    obj.was_first_bruteforce = false
    obj.was_second_bruteforce = false
    obj.lock_side = 0.0
    obj.original_goal_feet_yaw = 0.0
    obj.original_pitch = 0.0
    obj.resolver_layers = {}
    for i=1,3 do obj.resolver_layers[i] = {} for j=1,15 do obj.resolver_layers[i][j] = {} end end
    obj.previous_layers = {}
    for i=1,15 do obj.previous_layers[i] = {} end
    obj.resolver_goal_feet_yaw = {0,0,0}
    obj.last_angle = 0.0
    obj.switch = false
    obj.last_brute = 0
    obj.last_update_time = 0.0
    return obj
end

function resolver:initialize(e, record, goal_feet_yaw, pitch, previous_record)
    if e == nil then return end
    self.player = e
    self.player_record = record
    if previous_record then self.prev_record = previous_record end
    self.original_pitch = normalize_pitch(pitch)
    self.original_goal_feet_yaw = normalize_yaw(goal_feet_yaw)
end

function resolver:reset()
    self.player = nil
    self.player_record = nil
    self.prev_record = nil
    self.side = false
    self.fake = false
    self.was_first_bruteforce = false
    self.was_second_bruteforce = false
    self.original_goal_feet_yaw = 0.0
    self.original_pitch = 0.0
end

function resolver:is_breaking_lby(cur_layer, prev_layer)
    if cur_layer == nil or prev_layer == nil then return false end
    if self:IsAdjustingBalance() then
        if prev_layer.cycle ~= cur_layer.cycle and cur_layer.weight == 1.0 then
            return true
        elseif cur_layer.weight == 0.0 and prev_layer.cycle > 0.92 and cur_layer.cycle > 0.92 then
            return true
        end
    end
    return false
end

function resolver:IsAdjustingBalance()
    if self.player == nil or self.player_record == nil then return false end
    for i=1,13 do
        local activity = entity.get_sequence_activity(self.player, self.player_record.layers[i].sequence)
        if activity == 979 then
            return true
        end
    end
    return false
end

function resolver:is_slow_walking()
    if self.player == nil or not entity.is_alive(self.player) then return false end
    local velocity = entity.get_prop(self.player, "m_vecVelocity") or vector(0,0,0)
    local velocity_2D = math.sqrt(velocity.x^2 + velocity.y^2)

    local idx = entity.get_ent_index(self.player)

    if velocity_2D ~= old_velocity_2D[idx] then
        old_velocity_2D[idx] = velocity_2D
        tick_counter[idx] = 0
    else
        tick_counter[idx] = tick_counter[idx] + 1

        local max_ticks = math.floor(0.1 / globals.interval_per_tick())

        if tick_counter[idx] > max_ticks then
            return true
        end
    end

    return false
end

local last_ticks = {}
for i=1,65 do last_ticks[i] = 0 end

function resolver:GetChokedPackets()
    if self.player == nil then return 0 end
    local ticks = globals.time_to_ticks(entity.get_prop(self.player, "m_flSimulationTime") - entity.get_prop(self.player, "m_flOldSimulationTime"))

    local idx = entity.get_ent_index(self.player)
    if ticks == 0 and last_ticks[idx] > 0 then
        return last_ticks[idx] - 1
    else
        last_ticks[idx] = ticks
        return ticks
    end
end

function resolver:lagcomp_initialize(player, origin, velocity, flags, on_ground)
    globals.extrapolate(player, origin, velocity, flags, on_ground)
end

function resolver:get_side_standing()
    if self.player == nil then return end
    local eye_angles = entity.get_prop(self.player, "m_angEyeAngles") or vector(0,0,0)
    local angle_difference = angle_diff(eye_angles.y, self.original_goal_feet_yaw)
    self.player_record.curSide = angle_difference <= 0.0 and globals.LEFT1 or globals.RIGHT1
end

local function get_backward_side(player)
    if player == nil then return 0 end
    return globals.calculate_angle(entity.get_origin(entity.get_local_player()), entity.get_origin(player)).y
end

local function resolve_update_animations(e)
    entity.update_clientside_animation(e)
end

local function GetHitboxPos(player, mat, hitbox_id)
    if not player then return vector(0,0,0) end

    local hdr = entity.get_studio_hdr(player)

    if not hdr then return vector(0,0,0) end

    local hitbox_set = hdr.hitbox_set(entity.get_prop(player, "m_nHitboxSet"))

    if not hitbox_set then return vector(0,0,0) end

    local hitbox = hitbox_set.hitbox(hitbox_id)

    if not hitbox then return vector(0,0,0) end

    local min = math.vector_transform(hitbox.bbmin, mat[hitbox.bone])
    local max = math.vector_transform(hitbox.bbmax, mat[hitbox.bone])

    return (min + max) * 0.5
end

function resolver:resolve_yaw()
    if self.player == nil or not entity.is_alive(self.player) or self.player_record == nil then return end

    if self.player_record.bot then return end

    local eye_yaw = self.player_record.angles.y
    local lby = self.player_record.lby
    local delta = math.abs(angle_diff(eye_yaw, lby))

    if delta < 35 then 
        self.fake = false
        self.player_record.type = ORIGINAL
        self.player_record.side = NO_SIDE
        return 
    end

    self.fake = true

    local cur_layer = self.player_record.layers[3]

    if cur_layer.weight <= 0.1 then
        local current_angle = eye_yaw
        if math.abs(current_angle - self.last_angle) <= 50.0 then
            self.switch = not self.switch
            self.last_angle = current_angle
            self.player_record.side = self.switch and globals.LEFT1 or globals.RIGHT1
            self.last_brute = self.player_record.side
            self.last_update_time = globals.curtime()
        else
            if math.abs(self.last_update_time - globals.curtime()) >= (0.22) or self:GetChokedPackets() == 0 then
                self.last_angle = current_angle
            end
            self.player_record.side = self.last_brute
        end
        self.player_record.type = JITTER
        return
    end

    local speed = self.player_record.velocity:length2d()
    local mode = NO_MODE

    if bit.band(self.player_record.flags, globals.FL_ONGROUND) == 0 then 
        mode = AIR 
    elseif speed < 1.5 then 
        mode = STANDING 
    elseif speed < 35 then 
        mode = SLOW_WALKING 
    else 
        mode = MOVING 
    end

    self.player_record.curMode = mode

    if mode == AIR then
        self.player_record.type = ORIGINAL
        self.player_record.side = NO_SIDE
        return
    end

    if mode == MOVING then
        self:get_side_standing()
        self.player_record.side = self.player_record.curSide
        self.player_record.type = DIRECTIONAL
        return
    end

    if mode == SLOW_WALKING then
        if self:is_slow_walking() then
            self.player_record.type = LBY
            local lby_delta = angle_diff(eye_yaw, lby)
            self.player_record.side = lby_delta > 0 and globals.LEFT1 or globals.RIGHT1
            return
        else
            self:get_side_standing()
            self.player_record.side = self.player_record.curSide
            self.player_record.type = DIRECTIONAL
            return
        end
    end

    if mode == STANDING then
        local cur_layer = self.player_record.layers[3]  -- assuming layer 3 for desync
        local prev_layer = self.prev_record and self.prev_record.layers[3] or cur_layer

        if self:is_breaking_lby(cur_layer, prev_layer) then
            self.player_record.type = LBY
            local lby_delta = angle_diff(eye_yaw, self.player_record.lby)
            self.player_record.side = lby_delta > 0 and globals.LEFT1 or globals.RIGHT1
            return
        end

        local idx = entity.get_ent_index(self.player)
        local misses = globals.missed_shots[idx]

        if misses > 0 then
            self.player_record.type = BRUTEFORCE
            if misses % 5 == 1 then
                self.was_first_bruteforce = true
                self.player_record.side = globals.LEFT1
            elseif misses % 5 == 2 then
                self.was_second_bruteforce = true
                self.player_record.side = globals.RIGHT1
            elseif misses % 5 == 3 then
                self.player_record.side = LOW_LEFT
            elseif misses % 5 == 4 then
                self.player_record.side = LOW_RIGHT
            else
                self.player_record.side = NO_SIDE
            end
            return
        end

        -- freestand trace
        local head_pos = entity.hitbox_position(self.player, 0)
        local eye_yaw = entity.get_prop(self.player, "m_angEyeAngles").y or 0
        local left_vec = angle_to_vec(eye_yaw + 90) * 100
        local right_vec = angle_to_vec(eye_yaw - 90) * 100
        local left_end = head_pos + left_vec
        local right_end = head_pos + right_vec

        local left_fraction, _, _, _, _ = client.trace_line(self.player, head_pos.x, head_pos.y, head_pos.z + 5, left_end.x, left_end.y, left_end.z + 5)
        local right_fraction, _, _, _, _ = client.trace_line(self.player, head_pos.x, head_pos.y, head_pos.z + 5, right_end.x, right_end.y, right_end.z + 5)

        if math.abs(left_fraction - right_fraction) > 0.25 then
            self.player_record.type = TRACE
            self.player_record.side = left_fraction > right_fraction and globals.LEFT1 or globals.RIGHT1
            return
        end

        -- default standing
        self:get_side_standing()
        self.player_record.side = self.player_record.curSide
        self.player_record.type = ANIMATION
    end
end

local MAIN = 0
local NONE = 1
local FIRST = 2
local SECOND = 3
local LOW_FIRST = 4
local LOW_SECOND = 5

local ORIGINAL = 0
local BRUTEFORCE = 1
local LBY = 2
local TRACE = 3
local JITTER = 4
local DIRECTIONAL = 5
local ENGINE = 6
local ANIMATION = 7

local HISTORY_UNKNOWN = -1
local HISTORY_ORIGINAL = 0
local HISTORY_ZERO = 1
local HISTORY_DEFAULT = 2
local HISTORY_LOW = 3

local AIR = 0
local SLOW_WALKING = 1
local MOVING = 2
local STANDING = 3
local FREESTANDING = 4
local NO_MODE = 5

local NO_SIDE = 0
local LEFT1 = 1
local RIGHT1 = 2
local LOW_LEFT = -2
local LOW_RIGHT = 2

local RESOLVER_ORIGINAL = 0
local RESOLVER_ZERO = 1
local RESOLVER_FIRST = 2
local RESOLVER_SECOND = 3
local RESOLVER_LOW_FIRST = 4
local RESOLVER_LOW_SECOND = 5
local RESOLVER_JITTER_FIRST = 6
local RESOLVER_JITTER_SECOND = 7
local RESOLVER_ROLL_FIRST = 8
local RESOLVER_ROLL_SECOND = 9
local RESOLVER_DEFAULT = 10

local matrixes = {}
matrixes.main = {}
for i=1,128 do matrixes.main[i] = {} end
matrixes.positive = {}
for i=1,128 do matrixes.positive[i] = {} end
matrixes.negative = {}
for i=1,128 do matrixes.negative[i] = {} end
matrixes.zero = {}
for i=1,128 do matrixes.zero[i] = {} end
matrixes.first = {}
for i=1,128 do matrixes.first[i] = {} end
matrixes.second = {}
for i=1,128 do matrixes.second[i] = {} end
matrixes.low_first = {}
for i=1,128 do matrixes.low_first[i] = {} end
matrixes.low_second = {}
for i=1,128 do matrixes.low_second[i] = {} end

local player_records = {}
for i=1,65 do player_records[i] = {} end

local adjust_data = {}
adjust_data.__index = adjust_data

function adjust_data:new(e, store)
    local obj = {}
    setmetatable(obj, self)
    obj.player = nil
    obj.i = 0
    obj.layers = {}
    for i=1,15 do obj.layers[i] = {} end
    obj.movelayers = {}
    for i=1,3 do obj.movelayers[i] = {} for j=1,15 do obj.movelayers[i][j] = {} end end
    obj.matrixes_data = matrixes
    obj.type = 0
    obj.side = 0
    obj.invalid = false
    obj.immune = false
    obj.dormant = false
    obj.bot = false
    obj.shot = false
    obj.curSide = NO_SIDE
    obj.curMode = NO_MODE
    obj.flags = 0
    obj.bone_count = 0
    obj.last_shot_time = 0.0
    obj.simulation_time = 0.0
    obj.duck_amount = 0.0
    obj.lby = 0.0
    obj.angles = vector(0,0,0)
    obj.abs_angles = vector(0,0,0)
    obj.velocity = vector(0,0,0)
    obj.origin = vector(0,0,0)
    obj.mins = vector(0,0,0)
    obj.maxs = vector(0,0,0)
    if e then
        obj.invalid = false
        obj:store_data(e, store)
        obj.curSide = NO_SIDE
        obj.curMode = NO_MODE
    end
    return obj
end

function adjust_data:reset()
    self.player = nil
    self.i = -1
    self.invalid = false
    self.immune = false
    self.dormant = false
    self.bot = false
    self.shot = false
    self.flags = 0
    self.bone_count = 0
    self.last_shot_time = 0.0
    self.simulation_time = 0.0
    self.duck_amount = 0.0
    self.lby = 0.0
    self.curSide = NO_SIDE
    self.curMode = NO_MODE
    self.angles = vector(0,0,0)
    self.abs_angles = vector(0,0,0)
    self.velocity = vector(0,0,0)
    self.origin = vector(0,0,0)
    self.mins = vector(0,0,0)
    self.maxs = vector(0,0,0)
end

function adjust_data:store_data(e, store)
    if e == nil or not entity.is_alive(e) then return end

    self.player = e
    self.i = entity.get_ent_index(e)

    if store then
        self.layers = entity.get_anim_overlay(e)
        self.matrixes_data.main = entity.get_bone_matrix(e)
    end

    self.immune = entity.get_prop(e, "m_bGunGameImmunity") or bit.band(entity.get_prop(e, "m_fFlags"), globals.FL_FROZEN) ~= 0
    self.dormant = entity.is_dormant(e)

    local player_info = client.get_player_info(self.i)
    self.bot = player_info.bot

    self.flags = entity.get_prop(e, "m_fFlags")
    self.bone_count = entity.cached_bone_count(e)

    local weapon = entity.get_player_weapon(e)
    self.last_shot_time = weapon and entity.get_prop(weapon, "m_fLastShotTime") or 0.0
    self.simulation_time = entity.get_prop(e, "m_flSimulationTime")
    self.duck_amount = entity.get_prop(e, "m_flDuckAmount")
    self.lby = entity.get_prop(e, "m_flLowerBodyYawTarget")

    self.angles = entity.get_prop(e, "m_angEyeAngles")
    self.abs_angles = entity.get_abs_angles(e)
    self.velocity = entity.get_prop(e, "m_vecVelocity")
    self.origin = entity.get_prop(e, "m_vecOrigin")
    self.mins = entity.get_collideable_mins(e)
    self.maxs = entity.get_collideable_maxs(e)
end

function adjust_data:adjust_player()
    if not self:valid(false) then return end

    entity.set_prop(self.player, "m_flLayer", self.layers, 15)
    entity.set_prop(self.player, "m_CachedBoneData", self.matrixes_data.main, entity.cached_bone_count(self.player))

    entity.set_prop(self.player, "m_fFlags", self.flags)
    entity.set_prop(self.player, "m_CachedBoneDataSize", self.bone_count)

    entity.set_prop(self.player, "m_flSimulationTime", self.simulation_time)
    entity.set_prop(self.player, "m_flDuckAmount", self.duck_amount)
    entity.set_prop(self.player, "m_flLowerBodyYawTarget", self.lby)

    entity.set_prop(self.player, "m_angEyeAngles", self.angles.x, self.angles.y, self.angles.z)
    entity.set_abs_angles(self.player, self.abs_angles)
    entity.set_prop(self.player, "m_vecVelocity", self.velocity.x, self.velocity.y, self.velocity.z)
    entity.set_prop(self.player, "m_vecOrigin", self.origin.x, self.origin.y, self.origin.z)
    entity.set_abs_origin(self.player, self.origin)
    entity.set_collideable_mins(self.player, self.mins)
    entity.set_collideable_maxs(self.player, self.maxs)
end

function adjust_data:valid(extra_checks)
    if not self then return false end

    if self.i > 0 then
        self.player = self.i
    end

    if not self.player then return false end

    if entity.get_prop(self.player, "m_lifeState") ~= 0 then return false end

    if self.immune then return false end

    if self.dormant then return false end

    if not extra_checks then return true end

    if self.invalid then return false end

    local net_channel_info = client.get_net_channel_info()

    if not net_channel_info then return false end

    local sv_maxunlag = cvar.sv_maxunlag:get_float()

    local outgoing = net_channel_info.latency_out
    local incoming = net_channel_info.latency_in

    local correct = math.clamp(outgoing + incoming + globals.interpolation(), 0.0, sv_maxunlag)

    local curtime = entity.is_alive(entity.get_local_player()) and globals.time_to_ticks(globals.fixed_tickbase) or globals.curtime()
    local delta_time = correct - (curtime - self.simulation_time)

    if math.abs(delta_time) > 0.2 then return false end

    local extra_choke = 0

    if globals.fakeducking then
        extra_choke = 14 - globals.choked_commands()
    end

    local server_tickcount = extra_choke + globals.tickcount() + globals.time_to_ticks(outgoing + incoming)
    local dead_time = globals.time_to_ticks(server_tickcount) - sv_maxunlag

    if self.simulation_time < dead_time then return false end

    return true
end

local optimized_adjust_data = {}
optimized_adjust_data.__index = optimized_adjust_data

function optimized_adjust_data:new()
    local obj = {}
    setmetatable(obj, self)
    obj.i = 0
    obj.player = nil
    obj.simulation_time = 0.0
    obj.duck_amount = 0.0
    obj.speed = 0.0
    obj.shot = false
    obj.angles = vector(0,0,0)
    obj.origin = vector(0,0,0)
    return obj
end

function optimized_adjust_data:reset()
    self.i = 0
    self.player = nil
    self.simulation_time = 0.0
    self.duck_amount = 0.0
    self.speed = 0.0
    self.shot = false
    self.angles = vector(0,0,0)
    self.origin = vector(0,0,0)
end

local player_settings = {}
function new_player_settings(id, res_type, faking, neg, pos)
    return {id = id, res_type = res_type, faking = faking, neg = neg, pos = pos}
end

local lagcompensation = {}
lagcompensation.__index = lagcompensation

function lagcompensation:new()
    local obj = {}
    setmetatable(obj, self)
    obj.player_resolver = {}
    for i=1,65 do obj.player_resolver[i] = resolver:new() end
    obj.is_dormant = {}
    for i=1,65 do obj.is_dormant[i] = false end
    obj.previous_goal_feet_yaw = {}
    for i=1,65 do obj.previous_goal_feet_yaw[i] = 0.0 end
    return obj
end

function lagcompensation:fsn(stage)
    if not ui.get(enable_resolver) then return end
    if stage ~= client.FRAME_NET_UPDATE_END then return end

    if not globals.config("rage_enabled") then return end

    if entity.get_local_player() == nil then return end

    for _, i in ipairs(entity.get_players(true)) do
        local e = i

        if e == entity.get_local_player() then goto continue end

        if not self:valid(i, e) then goto continue end

        local sim_time = entity.get_prop(e, "m_flSimulationTime")
        local old_sim_time = entity.get_prop(e, "m_flOldSimulationTime")

        if sim_time and old_sim_time then
            if #player_records[i] == 0 or (#player_records[i] > 0 and sim_time ~= old_sim_time) then
                if #player_records[i] > 0 and (entity.get_origin(e) - player_records[i][1].origin):length_sq() > 4096.0 then
                    for _, record in ipairs(player_records[i]) do
                        record.invalid = true
                    end
                end

                table.insert(player_records[i], 1, adjust_data:new(e))
                self:update_player_animations(e)

                if #player_records[i] > 32 then
                    table.remove(player_records[i])
                end
            end
        end
        ::continue::
    end
end

function lagcompensation:valid(i, e)
    if not globals.config("rage_enabled") or not globals.valid_player(e, false) then
        if not entity.is_alive(e) then
            self.is_dormant[i] = false
            self.player_resolver[i]:reset()

            globals.fired_shots[i] = 0
            globals.missed_shots[i] = 0
        elseif entity.is_dormant(e) then
            self.is_dormant[i] = true
        end

        player_records[i] = {}
        return false
    end
    return true
end

local function IsNearEqual(v1, v2, Tolerance)
    return math.abs(v1 - v2) <= math.abs(Tolerance)
end

function lagcompensation:ent_use_jitter(player, new_side, player_record)
    if not entity.is_alive(player) then return end

    if not globals.valid_player(player, false, false) then return end

    if entity.is_dormant(player) then return end

    local LastAngle = {}
    for i=1,64 do LastAngle[i] = 0.0 end
    local LastBrute = {}
    for i=1,64 do LastBrute[i] = 0 end
    local Switch = {}
    for i=1,64 do Switch[i] = false end
    local LastUpdateTime = {}
    for i=1,64 do LastUpdateTime[i] = 0.0 end
    local layers = {}
    for i=1,13 do layers[i] = entity.get_prop(player, "m_flLayer", i) end

    local i = entity.get_ent_index(player)
    local animstate = entity.get_animation_state(player)
    local speed = math.sqrt(entity.get_prop(player, "m_vecVelocity").x^2 + entity.get_prop(player, "m_vecVelocity").y^2)
    local delta = angle_diff(animstate.goal_feet_yaw, animstate.eye_yaw)
    local CurrentAngle = entity.get_prop(player, "m_angEyeAngles").y
    local goalfeetyaw = animstate.goal_feet_yaw

    if layers[3].weight <= 0.1 then
        if IsNearEqual(CurrentAngle, LastAngle[i], 50.0) then
            Switch[i] = not Switch[i]
            LastAngle[i] = CurrentAngle
            new_side = Switch[i] and -1 or 1
            LastBrute[i] = new_side
            LastUpdateTime[i] = globals.curtime()
        else
            if math.abs(LastUpdateTime[i] - globals.curtime()) >= globals.time_to_ticks(17) or entity.get_prop(player, "m_flSimulationTime") ~= entity.get_prop(player, "m_flOldSimulationTime") then
                LastAngle[i] = CurrentAngle
            end
            new_side = LastBrute[i]
        end
    end
end

function lagcompensation:extrapolate(player, origin, velocity, flags, on_ground)
    local start = origin
    local end_pos = start + (velocity * globals.interval_per_tick())

    local trace = client.trace_hull(start, end_pos, entity.get_prop(player, "m_vecMins"), entity.get_prop(player, "m_vecMaxs"), globals.MASK_PLAYERSOLID - globals.CONTENTS_MONSTER)

    if trace.fraction ~= 1.0 then
        for i=1,2 do
            velocity = velocity - (trace.plane_normal * velocity:dot(trace.plane_normal))

            local adjust = velocity:dot(trace.plane_normal)
            if adjust < 0.0 then
                velocity = velocity - (trace.plane_normal * adjust)
            end

            start = trace.endpos
            end_pos = start + (velocity * (globals.interval_per_tick() * (1.0 - trace.fraction)))

            local two_trace = client.trace_hull(start, end_pos, entity.get_prop(player, "m_vecMins"), entity.get_prop(player, "m_vecMaxs"), globals.MASK_PLAYERSOLID - globals.CONTENTS_MONSTER)

            if two_trace.fraction == 1.0 then break end
        end
    end
local start, end_pos, origin = trace.endpos, trace.endpos, trace.endpos

    end_pos.z = end_pos.z - 2.0

    trace = client.trace_hull(start, end_pos, entity.get_prop(player, "m_vecMins"), entity.get_prop(player, "m_vecMaxs"), globals.MASK_PLAYERSOLID - globals.CONTENTS_MONSTER)
    flags = bit.band(flags, bit.bnot(globals.FL_ONGROUND))

    if trace.fraction ~= 1.0 or trace.allsolid then
        flags = bit.bor(flags, globals.FL_ONGROUND)
    end
end

function lagcompensation:setupvelocity(e, record)
    local velocity = entity.get_prop(e, "m_vecVelocity")
    local speed = math.sqrt(velocity.x^2 + velocity.y^2)
    local max_speed = 450.0

    if bit.band(entity.get_prop(e, "m_fFlags"), globals.FL_ONGROUND) ~= 0 then
        local wish_dir = math.angle_forward(record.angles)
        local wish_speed = max_speed

        if globals.config("rage_enabled") and globals.keybind_state(20) then
            wish_speed = globals.config("rage_fakelag_limit") * max_speed / 16.0
        end

        local velocity_prop = wish_dir * wish_speed

        entity.set_prop(e, "m_vecVelocity", velocity_prop.x, velocity_prop.y, velocity.z)
    end
end

function lagcompensation:animevent(e, state, order, activity)
    local animlayers = entity.get_anim_overlay(e)
    local animstate = entity.get_animation_state(e)
    local hitbox_set = entity.get_studio_hdr(e).hitbox_set(entity.get_prop(e, "m_nHitboxSet"))

    if activity == 979 then
        animlayers[3].playback_rate = 0.0
        animlayers[3].weight = 0.0
        animlayers[3].cycle = 0.0
    end

    local speed = math.sqrt(entity.get_prop(e, "m_vecVelocity").x^2 + entity.get_prop(e, "m_vecVelocity").y^2)

    if activity == 981 then
        state.time_since_in_air = 99.0
        animlayers[5].cycle = 0.0
    end
end

function lagcompensation:update_player_animations(e)
    if e == nil or not entity.is_alive(e) then return end

    local i = entity.get_ent_index(e)
    local animlayers = entity.get_anim_overlay(e)
    local animstate = entity.get_animation_state(e)
    local previous_record = #player_records[i] > 1 and player_records[i][2] or nil

    if previous_record and previous_record.invalid then
        previous_record = nil
    end

    local record = player_records[i][1]
    local old_curtime = globals.curtime()
    local old_frametime = globals.frametime()
    local old_rtime = globals.realtime()
    local old_tickcount = globals.tickcount()
    local old_ftime = globals.framecount()
    local old_lerptime = globals.lerptime()
    local old_tickinterval = globals.tickinterval()

    local backup_lower_body_yaw_target = entity.get_prop(e, "m_flLowerBodyYawTarget")
    local backup_duck_amount = entity.get_prop(e, "m_flDuckAmount")
    local backup_flags = entity.get_prop(e, "m_fFlags")
    local backup_eflags = entity.get_prop(e, "m_iEFlags")

    local backup_abs_origin = entity.get_abs_origin(e)
    local backup_abs_angles = entity.get_abs_angles(e)
    local backup_obbs = entity.get_collideable(e)

    globals.set_curtime(entity.get_prop(e, "m_flSimulationTime"))
    globals.set_frametime(globals.interval_per_tick())

    local simulation_ticks = globals.time_to_ticks(entity.get_prop(e, "m_flSimulationTime") - entity.get_prop(e, "m_flOldSimulationTime"))

    if simulation_ticks < 0 or simulation_ticks > 31 then
        simulation_ticks = 1
    end

    entity.set_prop(e, "m_iEFlags", bit.band(entity.get_prop(e, "m_iEFlags"), bit.bnot(256)))

    entity.set_abs_origin(e, record.origin)
    entity.set_prop(e, "m_vecOrigin", record.origin.x, record.origin.y, record.origin.z)

    entity.set_prop(e, "m_flDuckAmount", record.duck_amount)
    entity.set_prop(e, "m_fFlags", record.flags)

    entity.set_prop(e, "m_flLowerBodyYawTarget", record.lby)

    entity.set_abs_angles(e, record.abs_angles)
    entity.set_prop(e, "m_angEyeAngles", record.angles.x, record.angles.y, record.angles.z)

    local layers_save = {}
    for j=1,15 do layers_save[j] = entity.get_prop(e, "m_flLayer", j) end

    entity.set_prop(e, "m_flLayer", record.layers, 15)

    local state = entity.get_animation_state(e)

    local updated_animations = false

    if previous_record then
        local delta = entity.get_prop(e, "m_flSimulationTime") - previous_record.simulation_time

        if delta > 0.0 and delta <= 0.2 then
            local previous_layers = previous_record.layers

            local layer_count = entity.get_animlayer_count(e)

            local on_ground = bit.band(record.flags, globals.FL_ONGROUND) ~= 0
            local previous_on_ground = bit.band(previous_record.flags, globals.FL_ONGROUND) ~= 0

            local land_time = 0.0
            local land_in_cycle = false
            local is_landed = false
            local jump_time = 0.0

            local land_layer = record.layers[5]
            local previous_land_layer = previous_layers[5]

            if land_layer.sequence ~= previous_land_layer.sequence and land_layer.weight > 0.0 and previous_land_layer.sequence > 0 and previous_land_layer.sequence < 2 then
                land_in_cycle = true

                local current_activity = entity.get_sequence_activity(e, land_layer.sequence)

                if current_activity == 989 or current_activity == 987 then
                    land_time = entity.get_prop(e, "m_flSimulationTime") - land_layer.cycle / land_layer.playback_rate
                    jump_time = entity.get_prop(e, "m_flJumpTime")

                    if jump_time == land_time or jump_time == 0.0 then
                        on_ground = true
                    end
                end
            end

            entity.set_prop(e, "m_flLayer", previous_layers, 15)

            globals.set_curtime(previous_record.simulation_time)
            globals.set_frametime(globals.interval_per_tick())

            entity.update_clientside_animation(e)

            globals.set_curtime(entity.get_prop(e, "m_flSimulationTime"))
            globals.set_frametime(globals.interval_per_tick() * simulation_ticks)

            local simulated_time = previous_record.simulation_time

            for k=1,simulation_ticks do
                simulated_time = simulated_time + globals.interval_per_tick()

                if land_in_cycle and not is_landed then
                    if land_time <= simulated_time then
                        is_landed = true
                        on_ground = true
                    else
                        on_ground = previous_on_ground
                    end
                end

                if on_ground then
                    entity.set_prop(e, "m_fFlags", bit.bor(entity.get_prop(e, "m_fFlags"), globals.FL_ONGROUND))
                else
                    entity.set_prop(e, "m_fFlags", bit.band(entity.get_prop(e, "m_fFlags"), bit.bnot(globals.FL_ONGROUND)))
                end

                local simulated_ticks = globals.time_to_ticks(simulated_time)

                globals.set_realtime(simulated_time)
                globals.set_curtime(simulated_time)
                globals.set_framecount(simulated_ticks)
                globals.set_tickcount(simulated_ticks)
                globals.set_lerptime(0.0)

                entity.update_clientside_animation(e)

                globals.set_realtime(old_rtime)
                globals.set_curtime(old_curtime)
                globals.set_framecount(old_ftime)
                globals.set_tickcount(old_tickcount)
                globals.set_lerptime(old_lerptime)
            end

            updated_animations = true
        end
    end

    if not updated_animations then
        entity.update_clientside_animation(e)
    end

    if not entity.is_bot(e) and entity.is_alive(entity.get_local_player()) and entity.get_team_num(e) ~= entity.get_team_num(entity.get_local_player()) then
        state.goal_feet_yaw = self.previous_goal_feet_yaw[i]

        entity.update_clientside_animation(e)

        self.previous_goal_feet_yaw[i] = state.goal_feet_yaw

        state.goal_feet_yaw = normalize_yaw(entity.get_prop(e, "m_angEyeAngles").y)

        entity.update_clientside_animation(e)

        entity.setup_bones(record.matrixes_data.zero, globals.BONE_USED_BY_HITBOX, self.player_resolver[i].resolver_layers[1])

        state.goal_feet_yaw = normalize_yaw(entity.get_prop(e, "m_angEyeAngles").y + 60.0)

        entity.update_clientside_animation(e)

        entity.setup_bones(record.matrixes_data.first, globals.BONE_USED_BY_HITBOX, self.player_resolver[i].resolver_layers[3])

        state.goal_feet_yaw = normalize_yaw(entity.get_prop(e, "m_angEyeAngles").y - 60.0)

        entity.update_clientside_animation(e)

        entity.setup_bones(record.matrixes_data.second, globals.BONE_USED_BY_HITBOX, self.player_resolver[i].resolver_layers[2])

        state.goal_feet_yaw = normalize_yaw(entity.get_prop(e, "m_angEyeAngles").y + 35.0)

        entity.update_clientside_animation(e)

        entity.setup_bones(record.matrixes_data.low_first, globals.BONE_USED_BY_HITBOX)

        state.goal_feet_yaw = normalize_yaw(entity.get_prop(e, "m_angEyeAngles").y - 35.0)

        entity.update_clientside_animation(e)

        entity.setup_bones(record.matrixes_data.low_second, globals.BONE_USED_BY_HITBOX)

        self.player_resolver[i]:initialize(e, record, self.previous_goal_feet_yaw[i], entity.get_prop(e, "m_angEyeAngles").x, previous_record)
        self.player_resolver[i]:resolve_yaw()

        -- Apply resolved matrix
        if self.player_resolver[i].player_record.side == globals.LEFT1 then
            record.matrixes_data.main = record.matrixes_data.second
        elseif self.player_resolver[i].player_record.side == globals.RIGHT1 then
            record.matrixes_data.main = record.matrixes_data.first
        elseif self.player_resolver[i].player_record.side == LOW_LEFT then
            record.matrixes_data.main = record.matrixes_data.low_second
        elseif self.player_resolver[i].player_record.side == LOW_RIGHT then
            record.matrixes_data.main = record.matrixes_data.low_first
        else
            record.matrixes_data.main = record.matrixes_data.zero
        end
    end

    entity.update_clientside_animation(e)

    entity.setup_bones(record.matrixes_data.main, globals.BONE_USED_BY_ANYTHING)

    entity.set_prop(e, "m_CachedBoneData", record.matrixes_data.main, entity.cached_bone_count(e))

    globals.set_curtime(old_curtime)
    globals.set_frametime(old_frametime)

    entity.set_prop(e, "m_flLowerBodyYawTarget", backup_lower_body_yaw_target)
    entity.set_prop(e, "m_flDuckAmount", backup_duck_amount)
    entity.set_prop(e, "m_fFlags", backup_flags)
    entity.set_prop(e, "m_iEFlags", backup_eflags)

    entity.set_prop(e, "m_flLayer", animlayers, 15)
    entity.set_prop(e, "m_flLayer", self.player_resolver[i].previous_layers, 15)
    entity.set_prop(e, "m_flLayer", self.player_resolver[i].resolver_layers, 15)

    record:store_data(e, false)

    if entity.get_prop(e, "m_flSimulationTime") < entity.get_prop(e, "m_flOldSimulationTime") then
        record.invalid = true
    end
end

function lagcompensation:FixPvs(pCurEntity)
    if pCurEntity == entity.get_local_player() then return end

    if not pCurEntity or not entity.is_player(pCurEntity) or entity.get_ent_index(pCurEntity) == entity.get_local_player_index() then return end

    entity.set_prop(pCurEntity, "m_iLastRenderFrame", globals.framecount())
    entity.set_prop(pCurEntity, "m_iLastRenderTick", 0)
end

local CSetupBones = {}
CSetupBones.__index = CSetupBones

function CSetupBones:new()
    local obj = {}
    setmetatable(obj, self)
    obj.boneMatrix = nil
    obj.vecOrigin = vector(0,0,0)
    obj.angAngles = vector(0,0,0)
    obj.pHdr = nil
    obj.vecBones = {}
    for i=1,128 do obj.vecBones[i] = vector(0,0,0) end
    obj.quatBones = {}
    for i=1,128 do obj.quatBones[i] = {x=0,y=0,z=0,w=0} end
    obj.bShouldDoIK = false
    obj.bShouldAttachment = true
    obj.bShouldDispatch = true
    obj.boneMask = 0
    obj.flPoseParameters = {}
    for i=1,24 do obj.flPoseParameters[i] = 0.0 end
    obj.flWorldPoses = {}
    for i=1,24 do obj.flWorldPoses[i] = 0.0 end
    obj.nAnimOverlayCount = 0
    obj.animLayers = {}
    for i=1,15 do obj.animLayers[i] = {} end
    obj.flCurtime = 0.0
    obj.animating = nil
    return obj
end

function CSetupBones:setup()
    if not self.animating then return end

    local hdr = self.pHdr
    local world_hdr = hdr
    local bone_merge = globals.get_bone_merge(self.animating)

    if bone_merge then
        local follow = globals.get_bone_merge_follow(bone_merge)
        if follow then
            world_hdr = entity.get_studio_hdr(follow)
        end
    end

    local layer = {}
    for i=1,15 do layer[i] = 0 end

    local bone_setup = globals.CBoneSetup:new(hdr, self.boneMask, self.flPoseParameters)

    bone_setup:InitPose(self.vecBones, self.quatBones, hdr)

    if self.bShouldDoIK then
        local ik = globals.CIKContext:new()
        local world_ik = globals.CIKContext:new()

        ik:Init(hdr, self.angAngles, self.vecOrigin, self.flCurtime, globals.framecount(), self.boneMask)
        world_ik:Init(world_hdr, self.angAngles, self.vecOrigin, self.flCurtime, globals.framecount(), self.boneMask)

        bone_setup:CalcAutoplaySequences(self.vecBones, self.quatBones, self.flCurtime, ik)

        ik:UpdateTargets(self.vecBones, self.quatBones, self.boneMatrix, nil)
        ik:SolveDependencies(self.vecBones, self.quatBones, self.boneMatrix, nil)

        if bone_merge then
            local position = {}
            local rotation = {}

            bone_setup:AccumulatePose(position, rotation, 0, 1.0, self.flCurtime, nil)

            globals.bone_merge_copy_to_follow(bone_merge, position, rotation, globals.BONE_USED_BY_BONE_MERGE, self.vecBones, self.quatBones)

            bone_setup:AccumulatePose(self.vecBones, self.quatBones, 0, 1.0, self.flCurtime, nil)
        end

        world_ik:UpdateTargets(position, rotation, self.boneMatrix, nil)
        world_ik:SolveDependencies(position, rotation, self.boneMatrix, nil)
    else
        bone_setup:CalcAutoplaySequences(self.vecBones, self.quatBones, self.flCurtime, nil)
    end

    if bone_merge then
        local position = {}
        local rotation = {}

        bone_setup:AccumulatePose(position, rotation, 0, 1.0, self.flCurtime, nil)

        globals.bone_merge_copy_to_follow(bone_merge, position, rotation, globals.BONE_USED_BY_BONE_MERGE, self.vecBones, self.quatBones)
    end

    bone_setup:AccumulatePose(self.vecBones, self.quatBones, 0, 1.0, self.flCurtime, nil)

    if self.bShouldDoIK then
        local ik = globals.CIKContext:new()
        local world_ik = globals.CIKContext:new()

        ik:Init(hdr, self.angAngles, self.vecOrigin, self.flCurtime, 0, self.boneMask)
        world_ik:Init(world_hdr, self.angAngles, self.vecOrigin, self.flCurtime, 0, self.boneMask)

        if self.bShouldAttachment then
            self:attachment_helper()
        end

        if bone_merge then
            local position = {}
            local rotation = {}

            for i=1,self.nAnimOverlayCount do
                local layer_count = self.animLayers[i]

                if layer_count >= 0 and layer_count < self.nAnimOverlayCount then
                    local final_layer = self.animLayers[i]
                    bone_setup:AccumulatePose(position, rotation, final_layer.sequence, final_layer.cycle, final_layer.weight, self.flCurtime, world_ik)

                    globals.bone_merge_copy_from_follow(bone_merge, position, rotation, globals.BONE_USED_BY_BONE_MERGE, self.vecBones, self.quatBones)
                end
            end
        else
            for i=1,self.nAnimOverlayCount do
                local layer_count = self.animLayers[i]

                if layer_count >= 0 and layer_count < self.nAnimOverlayCount then
                    local final_layer = self.animLayers[i]
                    bone_setup:AccumulatePose(self.vecBones, self.quatBones, final_layer.sequence, final_layer.cycle, final_layer.weight, self.flCurtime, ik)
                end
            end
        end

        world_ik:Destructor()
    else
        for i=1,self.nAnimOverlayCount do
            local layer_count = layer[i]

            if layer_count >= 0 and layer_count < self.nAnimOverlayCount then
                local final_layer = self.animLayers[i]
                bone_setup:AccumulatePose(self.vecBones, self.quatBones, final_layer.sequence, final_layer.cycle, final_layer.weight, self.flCurtime, nil)
            end
        end
    end

    if self.bShouldDoIK then
        local world_ik = globals.CIKContext:new()
        world_ik:Init(self.pHdr, self.angAngles, self.vecOrigin, self.flCurtime, 0, self.boneMask)
        bone_setup:CalcAutoplaySequences(self.vecBones, self.quatBones, self.flCurtime, world_ik)
        world_ik:Destructor()
    else
        bone_setup:CalcAutoplaySequences(self.vecBones, self.quatBones, self.flCurtime, nil)
    end

    bone_setup:CalcBoneAdj(self.vecBones, self.quatBones, self.flWorldPoses, self.boneMask)
end

function CSetupBones:setup_bones_server()
    self:setup()
end

function CSetupBones:get_skeleton()
end

function CSetupBones:studio_build_matrices(hdr, worldTransform, pos, q, boneMask, out, boneComputed)
    local i = 0
    local chain_length = 0
    local bone = -1
    local studio_hdr = hdr

    if bone < -1 or bone >= studio_hdr.numbones then
        bone = 0
    end

    local bone_parent = hdr.bone_parent
    local bone_flags = hdr.bone_flags

    local chain = {}
    for j=1,128 do chain[j] = 0 end

    if bone <= -1 then
        chain_length = studio_hdr.numbones

        for k=1,studio_hdr.numbones do
            chain[chain_length - k + 1] = k
        end
    else
        i = bone

        repeat
            chain[chain_length + 1] = i
            i = bone_parent[i + 1]
            chain_length = chain_length + 1
        until i == -1
    end

    local bone_matrix = {}

    for j=chain_length,1,-1 do
        i = chain[j]

if bit.band(bit.lshift(1, i % 32), boneComputed[math.floor(i / 32) + 1]) ~= 0 then goto continue2 end
        local flag = bone_flags[i + 1]
        local parent = bone_parent[i + 1]

        if bit.band(flag, boneMask) ~= 0 and q then
            bone_matrix = math.quaternion_matrix(q[i + 1], pos[i + 1])

            if parent == -1 then
                out[i + 1] = math.concat_transforms(worldTransform, bone_matrix)
            else
                out[i + 1] = math.concat_transforms(out[parent + 1], bone_matrix)
            end
        end
        ::continue2::
    end
end

function CSetupBones:attachment_helper()
    globals.attachment_helper(self.animating, self.pHdr)
end

function CSetupBones:fix_bones_rotations()
    local studio_hdr = entity.get_studio_hdr(self.animating)

    if studio_hdr then
        local hdr = studio_hdr

        if hdr then
            local hitbox_set = hdr.hitbox_set(entity.get_prop(self.animating, "m_nHitboxSet"))

            for i=1,hitbox_set.numhitboxes do
                local hitbox = hitbox_set.hitbox(i)

                if hitbox.rotation:is_zero() then goto continue3 end

                local hitbox_transform = math.angle_matrix(hitbox.rotation)

                self.boneMatrix[hitbox.bone + 1] = math.concat_transforms(self.boneMatrix[hitbox.bone + 1], hitbox_transform)
                ::continue3::
            end
        end
    end
end

local local_anim = local_animations:new()
local lag_comp = lagcompensation:new()


client.set_event_callback("net_update_end", function()
    if not entity.get_local_player() or not ui.get(enable_resolver) then return end
    local_anim:run(client.FRAME_NET_UPDATE_END)
end)


client.set_event_callback("paint", function()
    if not entity.get_local_player() or not ui.get(enable_resolver) then return end
    local_anim:run(client.FRAME_RENDER_START)
end)


client.set_event_callback("net_update_end", function()
    if not entity.get_local_player() or not ui.get(enable_resolver) then return end
    lag_comp:fsn(client.FRAME_NET_UPDATE_END)
end)

client.set_event_callback("aim_fire", function(e)
    globals.fired_shots[e.target] = (globals.fired_shots[e.target] or 0) + 1
end)

client.set_event_callback("aim_miss", function(e)
    if e.reason == "resolver" then
        globals.missed_shots[e.target] = (globals.missed_shots[e.target] or 0) + 1
    end
end)

client.set_event_callback("aim_hit", function(e)
    globals.missed_shots[e.target] = 0
end)

client.set_event_callback("round_start", function()
    for i=1,65 do
        globals.missed_shots[i] = 0
        globals.fired_shots[i] = 0
    end
end)

client.set_event_callback("player_death", function(e)
    local victim = client.userid_to_entindex(e.userid)
    globals.missed_shots[victim] = 0
    globals.fired_shots[victim] = 0
end)

local math = math or {}

function math.clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

function math.angle_forward(angle)
    local pitch, yaw = math.rad(angle.x), math.rad(angle.y)
    return vector(math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), -math.sin(pitch))
end

HellpineC = {
    ClanTag = {
        state = {enabled = false, last_tag = "", frame = 1, last_time = 0},
        ui = ui.new_checkbox("LUA", "A", "Clan Tag"),
        frames = {
            "hellpine.xyz",
            "hellpine.xy ",
            "hellpine.x  ",
            "hellpine   ",
            "hellpin    ",
            "hellp     ",
            "hel      ",
            "he       ",
            "h        ",
            "         ",
            "        h",
            "       he",
            "      hel",
            "     hell",
            "    hellp",
            "   hellpi",
            "  hellpin",
            " hellpine",
            "hellpine ",
            "hellpine.",
            "hellpine.x",
            "hellpine.xy",
            "hellpine.xyz",
            "hellpine.xyz|",
            "|hellpine.xyz",
            "hellpine.xyz ",
            " hellpine.xyz",
            "hellpine.xyz"
        },
        set = function(tag)
            if tag == HellpineC.ClanTag.state.last_tag then
                return
            end
            pcall(client.set_clan_tag, tag or "")
            HellpineC.ClanTag.state.last_tag = tag or ""
        end,
        run = function()
            if not ui.get(HellpineC.ClanTag.ui) then
                if HellpineC.ClanTag.state.last_tag ~= "" then
                    HellpineC.ClanTag.set("")
                end
                return
            end

            local time = globals.realtime()
            if time - HellpineC.ClanTag.state.last_time < 0.16 then
                return
            end

            HellpineC.ClanTag.state.frame = (HellpineC.ClanTag.state.frame % #HellpineC.ClanTag.frames) + 1
            local frame = HellpineC.ClanTag.frames[HellpineC.ClanTag.state.frame]
            HellpineC.ClanTag.set(frame)
            HellpineC.ClanTag.state.last_time = time
        end
    }
}

local client_latency, client_screen_size, client_set_event_callback, client_system_time, entity_get_local_player, entity_get_player_resource, entity_get_prop, globals_absoluteframetime, globals_tickinterval, math_ceil, math_floor, math_min, math_sqrt, renderer_measure_text, ui_reference, pcall, renderer_gradient, renderer_rectangle, renderer_text, string_format, table_insert, ui_get, ui_new_checkbox, ui_new_color_picker, ui_new_multiselect, ui_new_textbox, ui_set, ui_set_callback, ui_set_visible = client.latency, client.screen_size, client.set_event_callback, client.system_time, entity.get_local_player, entity.get_player_resource, entity.get_prop, globals.absoluteframetime, globals.tickinterval, math.ceil, math.floor, math.min, math.sqrt, renderer.measure_text, ui.reference, pcall, renderer.gradient, renderer.rectangle, renderer.text, string.format, table.insert, ui.get, ui.new_checkbox, ui.new_color_picker, ui.new_multiselect, ui.new_textbox, ui.set, ui.set_callback, ui.set_visible
local flag, old_renderer_text, old_renderer_measure_text = "d", renderer_text, renderer_measure_text
function renderer_text(x, y, r, g, b, a, flags, max_width, ...)
	return old_renderer_text(x, y, r, g, b, a, flags == nil and flag or flag .. flags, max_width, ...)
end
function renderer_measure_text(flags, ...)
	return old_renderer_measure_text(flags == nil and flag or flag .. flags, ...)
end
local allow_unsafe_scripts = pcall(client.create_interface)
local FLOW_OUTGOING, FLOW_INCOMING = 0, 1
local native_GetNetChannelInfo, GetRemoteFramerate, native_GetTimeSinceLastReceived, native_GetAvgChoke, native_GetAvgLoss, native_IsLoopback, GetAddress
if allow_unsafe_scripts then
	local ffi = require "ffi"
	local function vmt_entry(instance, index, type)
		return ffi.cast(type, (ffi.cast("void***", instance)[0])[index])
	end
	local function vmt_thunk(index, typestring)
		local t = ffi.typeof(typestring)
		return function(instance, ...)
			assert(instance ~= nil)
			if instance then
				return vmt_entry(instance, index, t)(instance, ...)
			end
		end
	end
	local function vmt_bind(module, interface, index, typestring)
		local instance = client.create_interface(module, interface) or error("invalid interface")
		local fnptr = vmt_entry(instance, index, ffi.typeof(typestring)) or error("invalid vtable")
		return function(...)
			return fnptr(instance, ...)
		end
	end
	native_GetNetChannelInfo = vmt_bind("engine.dll", "VEngineClient014", 78, "void*(__thiscall*)(void*)")
	local native_GetName = vmt_thunk(0, "const char*(__thiscall*)(void*)")
	local native_GetAddress = vmt_thunk(1, "const char*(__thiscall*)(void*)")
	native_IsLoopback = vmt_thunk(6, "bool(__thiscall*)(void*)")
	local native_IsTimingOut = vmt_thunk(7, "bool(__thiscall*)(void*)")
	native_GetAvgLoss = vmt_thunk(11, "float(__thiscall*)(void*, int)")
	native_GetAvgChoke = vmt_thunk(12, "float(__thiscall*)(void*, int)")
	native_GetTimeSinceLastReceived = vmt_thunk(22, "float(__thiscall*)(void*)")
	local native_GetRemoteFramerate = vmt_thunk(25, "void(__thiscall*)(void*, float*, float*, float*)")
	local native_GetTimeoutSeconds = vmt_thunk(26, "float(__thiscall*)(void*)")
	local pflFrameTime = ffi.new("float[1]")
	local pflFrameTimeStdDeviation = ffi.new("float[1]")
	local pflFrameStartTimeStdDeviation = ffi.new("float[1]")
	function GetRemoteFramerate(netchannelinfo)
		native_GetRemoteFramerate(netchannelinfo, pflFrameTime, pflFrameTimeStdDeviation, pflFrameStartTimeStdDeviation)
		if pflFrameTime ~= nil and pflFrameTimeStdDeviation ~= nil and pflFrameStartTimeStdDeviation ~= nil then
			return pflFrameTime[0], pflFrameTimeStdDeviation[0], pflFrameStartTimeStdDeviation[0]
		end
	end
	function GetAddress(netchannelinfo)
		local addr = native_GetAddress(netchannelinfo)
		if addr ~= nil then
			return ffi.string(addr)
		end
	end
	local function GetName(netchannelinfo)
		local name = native_GetName(netchannelinfo)
		if name ~= nil then
			return ffi.string(name)
		end
	end
end
local cvar_game_mode, cvar_game_type, cvar_fps_max, cvar_fps_max_menu = cvar.game_mode, cvar.game_type, cvar.fps_max, cvar.fps_max_menu
local table_clear = require "table.clear"
local window = ((function() local a={}local b,c,d,e,f=renderer.rectangle,renderer.gradient,renderer.texture,math.floor,math.ceil;local function g(h,i,j,k,l,m,n,o,p)p=p or 1;b(h,i,j,p,l,m,n,o)b(h,i+k-p,j,p,l,m,n,o)b(h,i+p,p,k-p*2,l,m,n,o)b(h+j-p,i+p,p,k-p*2,l,m,n,o)end;local function q(h,i,j,k,r,s,t,u,v,w,x,y,z,p)p=p or 1;if z then b(h,i,p,k,r,s,t,u)b(h+j-p,i,p,k,v,w,x,y)c(h+p,i,j-p*2,p,r,s,t,u,v,w,x,u,true)c(h+p,i+k-p,j-p*2,p,r,s,t,u,v,w,x,u,true)else b(h,i,j,p,r,s,t,u)b(h,i+k-p,j,p,v,w,x,y)c(h,i+p,p,k-p*2,r,s,t,u,v,w,x,y,false)c(h+j-p,i+p,p,k-p*2,r,s,t,u,v,w,x,y,false)end end;local A;do local B="\x14\x14\x14\xFF"local C="\x0c\x0c\x0c\xFF"A=renderer.load_rgba(table.concat({B,B,B,C,B,C,B,C,B,C,B,B,B,C,B,C}),4,4)end;local function D(E,F)if F~=nil and type(E)=="string"and E:sub(-1,-1)=="%"then E=math.floor(tonumber(E:sub(1,-2))/100*F)end;return E end;local function G(H)if H.position=="fixed"then local I,J=client.screen_size()if H.left~=nil then H.x=D(H.left,I)elseif H.right~=nil then H.x=I-(H.w or 0)-D(H.right,I)end;if H.top~=nil then H.y=D(H.top,J)elseif H.bottom~=nil then H.y=J-(H.h or 0)-D(H.bottom,J)end end;local h,i,j,k,o=H.x,H.y,H.w,H.h,H.a or 255;local K=1;if h==nil or i==nil or j==nil or o==nil then return end;H.i_x,H.i_y,H.i_w,H.i_h=H.x,H.y,H.w,H.h;if H.title_bar then K=(H.title~=nil and select(2,renderer.measure_text(H.title_text_size,H.title))or 13)+2;H.t_x,H.t_y,H.t_w,H.t_h=H.x,H.y,H.w,K end;if H.border then g(h,i,j,k,18,18,18,o)g(h+1,i+1,j-2,k-2,62,62,62,o)g(h+2,i+K+1,j-4,k-K-3,44,44,44,o,H.border_width)g(h+H.border_width+2,i+K+H.border_width+1,j-H.border_width*2-4,k-K-H.border_width*2-3,62,62,62,o)H.i_x=H.i_x+H.border_width+3;H.i_y=H.i_y+H.border_width+3;H.i_w=H.i_w-(H.border_width+3)*2;H.i_h=H.i_h-(H.border_width+3)*2;H.t_x,H.t_y,H.t_w=H.x+2,H.y+2,H.w-4;K=K-1 end;if K>1 then c(H.t_x,H.t_y,H.t_w,K,56,56,56,o,44,44,44,o,false)if H.title~=nil then local l,m,n,o=unpack(H.title_text_color)o=o*H.a/255;renderer.text(H.t_x+3,H.t_y+2,l or 255,m or 255,n or 255,o or 255,(H.title_text_size or"")..(H.title_text_flags or""),0,tostring(H.title))end;H.i_y=H.i_y+K;H.i_h=H.i_h-K end;if H.gradient_bar then local L=0;if H.background then L=1;local M,N=16,25;b(H.i_x+1,H.i_y,H.i_w-2,1,M,M,M,o)b(H.i_x+1,H.i_y+3,H.i_w-2,1,N,N,N,o)for O=0,1 do c(H.i_x+(H.i_w-1)*O,H.i_y,1,4,M,M,M,o,N,N,N,o,false)end end;do local h,i,P=H.i_x+L,H.i_y+L,1;local Q,R=e((H.i_w-L*2)/2),f((H.i_w-L*2)/2)for O=1,2 do c(h,i,Q,1,59*P,175*P,222*P,o,202*P,70*P,205*P,o,true)c(h+Q,i,R,1,202*P,70*P,205*P,o,201*P,227*P,58*P,o,true)i,P=i+1,P*0.5 end end;H.i_y=H.i_y+2+L*2;H.i_h=H.i_h-2-L*2 end;if H.background then d(A,H.i_x,H.i_y,H.i_w,H.i_h,255,255,255,255,"t")end;if H.draggable then local p=7;renderer.triangle(h+j-1,i+k-p,h+j-1,i+k-1,h+j-p,i+k-1,62,62,62,o)end;H.i_x=H.i_x+H.margin_left;H.i_w=H.i_w-H.margin_left-H.margin_right;H.i_y=H.i_y+H.margin_top;H.i_h=H.i_h-H.margin_top-H.margin_bottom end;local S={}local T={}local U={}local V={__index=U}function U:set_active(W)if W then S[self.id]=self;table.insert(T,1,self.id)else S[self.id]=nil end end;function U:set_z_index(X)self.z_index=X;self.z_index_reset=true end;function U:is_in_window(h,i)return h>=self.x and h<=self.x+self.w and i>=self.y and i<=self.y+self.h end;function U:set_inner_width(Y)if self.border then Y=Y+(self.border_width+3)*2 end;Y=Y+self.margin_left+self.margin_right;self.w=Y end;function U:set_inner_height(Z)local K=1;if self.title_bar then K=(self.title~=nil and select(2,renderer.measure_text(self.title_text_size,self.title))or 13)+2 end;if self.border then Z=Z+(self.border_width+3)*2;K=K-1 end;if K>1 then Z=Z+K end;if self.gradient_bar then local L=0;if self.background then L=1 end;Z=Z+2+L*2 end;Z=Z+self.margin_top+self.margin_bottom;self.h=Z end;function a.new(_,h,i,j,k,a0)local H=setmetatable({id=_,top=h,left=i,w=j,h=k,a=255,paint_callback=a0,title_bar=true,title_bar_in_menu=false,title_text_color={255,255,255,255},title_text_size=nil,gradient_bar=true,border=true,border_width=3,background=true,first=true,visible=true,margin_top=0,margin_bottom=0,margin_left=0,margin_right=0,position="fixed",draggable=false,draggable_save=false,in_menu=false},V)H:set_active(true)return H end;local a1,a2,a3;local function a4(a5)local a6={"bottom","unset","top"}local a7={}for O=#T,1,-1 do local H=S[T[O]]if H~=nil then local a8=H.z_index or"unset"if H.z_index_reset then H.z_index=nil;H.z_index_reset=nil end;a7[a8]=a7[a8]or{}if H.first then table.insert(a7[a8],1,H.id)H.first=nil else table.insert(a7[a8],H.id)end end end;T={}for O=1,#a6 do local a9=a7[a6[O]]if a9~=nil then for O=#a9,1,-1 do table.insert(T,a9[O])end end end;local aa=ui.is_menu_open()local ab={}for O=1,#T do local H=S[T[O]]if H~=nil and H.in_menu==a5 then if H.title_bar_in_menu then H.title_bar=aa end;if H.pre_paint_callback~=nil then H:pre_paint_callback()end;if S[H.id]~=nil then table.insert(ab,S[H.id])end end end;if aa then local ac,ad=ui.mouse_position()local ae=client.key_state(0x01)if ae then for O=#ab,1,-1 do local H=ab[O]if H.visible and H:is_in_window(a1,a2)then H.first=true;if a3 then local af,ag=ac-a1,ad-a2;if H.position=="fixed"then local ah=H.left==nil and"right"or"left"local ai=H.top==nil and"bottom"or"top"local aj={{ah,(ah=="right"and-1 or 1)*af},{ai,(ai=="bottom"and-1 or 1)*ag}}for O=1,#aj do local ak,al=unpack(aj[O])local am=type(H[ak])if am=="string"and H[ak]:sub(-1,-1)=="%"then elseif am=="number"then H[ak]=H[ak]+al end end else H.x=H.x+af;H.y=H.y+ag end end;break end end end;a1,a2=ac,ad;a3=ae end;for O=1,#ab do local H=ab[O]if H.visible and H.in_menu==a5 then G(H)if H.paint_callback~=nil then H:paint_callback()end end end end;local a1,a2,a3;client.delay_call(0,client.set_event_callback,"paint",function()a4(false)end)client.delay_call(0,client.set_event_callback,"paint_ui",function()a4(true)end)return a end)()).new("watermark")
window.title = "Watermark"
window.title_bar = false
window.margin_bottom = 2
window.margin_left = 3
window.margin_right = 3
window.border_width = 2
window.top = 15
window.right = 15
window.in_menu = true
local db = database.read("sapphyrus_watermark") or {}
local antiut_reference = ui_reference("MISC", "Settings", "Anti-untrusted")
local is_beta = pcall(ui_reference, "MISC", "Settings", "Crash logs")
local names = {"Logo", "Custom text", "FPS", "Ping", "Server info", "Server framerate", "Server IP", "Network lag", "Tickrate", "Velocity", "Time", "Time + seconds"}
local watermark_reference = ui_new_multiselect("LUA", "B", "Watermark ", names)
local color_reference = ui_new_color_picker("LUA", "B", "Watermark", 149, 184, 6, 255)
local custom_name_reference = ui_new_textbox("LUA", "B", "Watermark name")
local fps_prev = 0
local value_prev = {}
local last_update_time = 0
local offset_x, offset_y = -15, 15
local function clamp(cur_val, min_val, max_val)
	return math_min(math.max(cur_val, min_val), max_val)
end
local function lerp(a, b, percentage)
	return a + (b - a) * percentage
end
local function table_contains(tbl, val)
	for i=1, #tbl do
		if tbl[i] == val then
			return true
		end
	end
	return false
end
local function table_remove_element(tbl, val)
	local tbl_new = {}
	for i=1, #tbl do
		if tbl[i] ~= val then
			table_insert(tbl_new, tbl[i])
		end
	end
	return tbl_new
end
local function table_lerp(a, b, percentage)
	local result = {}
	for i=1, #a do
		result[i] = lerp(a[i], b[i], percentage)
	end
	return result
end
local function on_watermark_changed()
	local value = ui_get(watermark_reference)
	if #value > 0 then
		if table_contains(value, "Time") and table_contains(value, "Time + seconds") then
			local value_new = value
			if not table_contains(value_prev, "Time") then
				value_new = table_remove_element(value_new, "Time + seconds")
			elseif not table_contains(value_prev, "Time + seconds") then
				value_new = table_remove_element(value_new, "Time")
			end
			if table_contains(value_new, "Time") and table_contains(value_new, "Time + seconds") then
				value_new = table_remove_element(value_new, "Time")
			end
			ui_set(watermark_reference, value_new)
			on_watermark_changed()
			return
		end
	end
	ui_set_visible(custom_name_reference, table_contains(value, "Custom text"))
	value_prev = value
end
ui_set_callback(watermark_reference, on_watermark_changed)
on_watermark_changed()
local function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math_floor(num * mult + 0.5) / mult
end
local ft_prev = 0
local function get_fps()
	ft_prev = ft_prev * 0.9 + globals_absoluteframetime() * 0.1
	return round(1 / ft_prev)
end
local function lerp_color_yellow_red(val, max_normal, max_yellow, max_red, default, yellow, red)
	default = default or {255, 255, 255}
	yellow = yellow or {230, 210, 40}
	red = red or {255, 32, 32}
	if val > max_yellow then
		return unpack(table_lerp(yellow, red, clamp((val-max_yellow)/(max_red-max_yellow), 0, 1)))
	else
		return unpack(table_lerp(default, yellow, clamp((val-max_normal)/(max_yellow-max_normal), 0, 1)))
	end
end
local watermark_items = {
	{
		name = "Logo",
		get_width = function(self, frame_data)
			self.hellpine_width = renderer_measure_text(nil, "hellpine")
			self.xyz_width = renderer_measure_text(nil, ".xyz")
			self.beta_width = (is_beta and (renderer_measure_text(nil, " [Release]")) or 0)
			return self.hellpine_width + self.xyz_width + self.beta_width
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			local r_xyz, g_xyz, b_xyz = ui_get(color_reference)
			renderer_text(x, y, 255, 255, 255, a, nil, 0, "hellpine")
            -- CHANGED: Hardcoded Dark Pink (204, 0, 150) for .xyz
			renderer_text(x+self.hellpine_width, y, 204, 0, 150, a, nil, 0, ".xyz")
			if is_beta then
				renderer_text(x+self.hellpine_width+self.xyz_width, y, 255, 255, 255, a*0.9, nil, 0, " [Release]")
			end
		end
	},
	{
		name = "Custom text",
		get_width = function(self, frame_data)
			local edit = ui_get(custom_name_reference)
			if edit ~= self.edit_prev and self.edit_prev ~= nil then
				db.custom_name = edit
			elseif edit == "" and db.custom_name ~= nil then
				ui_set(custom_name_reference, db.custom_name)
			end
			self.edit_prev = edit
			local text = db.custom_name
			if text ~= nil and text:gsub(" ", "") ~= "" then
				self.text = text
				return renderer_measure_text(nil, text)
			else
				self.text = nil
			end
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			renderer_text(x, y, r, g, b, a, nil, 0, self.text)
		end
	},
	{
		name = "FPS",
		get_width = function(self, frame_data)
			self.fps = get_fps()
			self.text = tostring(self.fps or 0) .. " fps"
			local fps_max, fps_max_menu = cvar_fps_max:get_float(), cvar_fps_max_menu:get_float()
			local fps_max = globals.mapname() == nil and math.min(fps_max == 0 and 999 or fps_max, fps_max_menu == 0 and 999 or fps_max) or fps_max == 0 and 999 or fps_max
			self.width = math.max(renderer_measure_text(nil, self.text), renderer_measure_text(nil, fps_max .. " fps"))
			return self.width
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			local fps_r, fps_g, fps_b = r, g, b
			if self.fps < (1 / globals_tickinterval()) then
			end
			renderer_text(x+self.width, y, fps_r, fps_g, fps_b, a, "r", 0, self.text)
		end
	},
	{
		name = "Ping",
		get_width = function(self, frame_data)
			local ping = client_latency()
			if ping > 0 then
				self.ping = ping
				self.text = round(self.ping*1000, 0) .. "ms"
				self.width = math.max(renderer_measure_text(nil, "999ms"), renderer_measure_text(nil, self.text))
				return self.width
			end
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			if self.ping > 0.15 then
				r, g, b = 255, 0, 0
			end
			renderer_text(x+self.width, y, r, g, b, a, "r", 0, self.text)
		end
	},

	{
		name = "Velocity",
		get_width = function(self, frame_data)
			frame_data.local_player = frame_data.local_player or entity.get_local_player()
			if frame_data.local_player == nil then return end
			local vel_x, vel_y = entity_get_prop(frame_data.local_player, "m_vecVelocity")
			if vel_x ~= nil then
				self.velocity = math_sqrt(vel_x*vel_x + vel_y*vel_y)
				self.vel_width = renderer_measure_text(nil, "9999")
				self.unit_width = renderer_measure_text("-", "vel")
				return self.vel_width+self.unit_width
			end
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			local velocity = self.velocity
			velocity = math_min(9999, velocity) + 0.4
			velocity = round(velocity, 0)
			renderer_text(x+self.vel_width, y, 255, 255, 255, a, "r", 0, velocity)
			renderer_text(x+self.vel_width+self.unit_width, y+3, 255, 255, 255, a*0.75, "r-", 0, "vel")
		end
	},
	{
		name = "Server framerate",
		get_width = function(self, frame_data)
			if not allow_unsafe_scripts then return end
			frame_data.local_player = frame_data.local_player or entity.get_local_player()
			if frame_data.local_player == nil then return end
			frame_data.net_channel_info = frame_data.net_channel_info or native_GetNetChannelInfo()
			if frame_data.net_channel_info == nil then return end
			local frame_time, frame_time_std_dev, frame_time_start_time_std_dev = GetRemoteFramerate(frame_data.net_channel_info)
			if frame_time ~= nil then
				self.framerate = frame_time * 1000
				self.var = frame_time_std_dev * 1000
				self.text1 = "sv:"
				self.text2 = string.format("%.1f", self.framerate)
				self.text3 = " +-"
				self.text4 = string.format("%.1f", self.var)
				self.width1 = renderer_measure_text(nil, self.text1)
				self.width2 = math.max(renderer_measure_text(nil, self.text2), renderer_measure_text(nil, "99.9"))
				self.width3 = renderer_measure_text(nil, self.text3)
				self.width4 = math.max(renderer_measure_text(nil, self.text4), renderer_measure_text(nil, "9.9"))
				return self.width1 + self.width2 + self.width3 + self.width4
			end
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			local fr_r, fr_g, fr_b = lerp_color_yellow_red(self.framerate, 8, 14, 20, {r, g, b})
			local vr_r, vr_g, vr_b = lerp_color_yellow_red(self.var, 5, 10, 18, {r, g, b})
			renderer_text(x, y, r, g, b, a, nil, 0, self.text1)
			renderer_text(x+self.width1+self.width2, y, fr_r, fr_g, fr_b, a, "r", 0, self.text2)
			renderer_text(x+self.width1+self.width2, y, r, g, b, a, nil, 0, self.text3)
			renderer_text(x+self.width1+self.width2+self.width3, y, vr_r, vr_g, vr_b, a, nil, 0, self.text4)
		end
	},
	{
		name = "Network lag",
		get_width = function(self, frame_data)
			if not allow_unsafe_scripts then return end
			frame_data.local_player = frame_data.local_player or entity.get_local_player()
			if frame_data.local_player == nil then return end
			frame_data.net_channel_info = frame_data.net_channel_info or native_GetNetChannelInfo()
			if frame_data.net_channel_info == nil then return end
			local reasons = {}
			local time_since_last_received = native_GetTimeSinceLastReceived(frame_data.net_channel_info)
			if time_since_last_received ~= nil and time_since_last_received > 0.1 then
				table_insert(reasons, string_format("%.1fs timeout", time_since_last_received))
			end
			local avg_loss = native_GetAvgLoss(frame_data.net_channel_info, FLOW_INCOMING)
			if avg_loss ~= nil and avg_loss > 0 then
				table_insert(reasons, string_format("%d%% loss", math.ceil(avg_loss*100)))
			end
			local avg_choke = native_GetAvgChoke(frame_data.net_channel_info, FLOW_INCOMING)
			if avg_choke > 0 then
				table_insert(reasons, string_format("%d%% choke", math.ceil(avg_choke*100)))
			end
			if #reasons > 0 then
				self.text = table.concat(reasons, ", ")
				return renderer_measure_text(nil, self.text)
			end
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			renderer_text(x, y, 255, 32, 32, a, nil, 0, self.text)
		end
	},
	{
		name = "Server info",
		get_width = function(self, frame_data)
			if not allow_unsafe_scripts then return end
			frame_data.local_player = frame_data.local_player or entity.get_local_player()
			if frame_data.local_player == nil then return end
			frame_data.net_channel_info = frame_data.net_channel_info or native_GetNetChannelInfo()
			if frame_data.net_channel_info == nil then return end
			frame_data.is_loopback = frame_data.is_loopback == nil and native_IsLoopback(frame_data.net_channel_info) or frame_data.is_loopback
			local game_rules = entity.get_game_rules()
			frame_data.is_valve_ds = frame_data.is_valve_ds == nil and entity.get_prop(game_rules, "m_bIsValveDS") == 1 or frame_data.is_valve_ds
			local text
			if frame_data.is_loopback then
				text = "Local server"
			elseif frame_data.is_valve_ds then
				local game_mode_name
				local game_mode, game_type = cvar_game_mode:get_int(), cvar_game_type:get_int()
				local is_queued_matchmaking = entity.get_prop(game_rules, "m_bIsQueuedMatchmaking") == 1
				if is_queued_matchmaking then
					if game_type == 0 and game_mode == 1 then
						game_mode_name = "MM"
					elseif game_type == 0 and game_mode == 2 then
						game_mode_name = "Wingman"
					elseif game_type == 3 then
						game_mode_name = "Custom"
					elseif game_type == 4 and game_mode == 0 then
						game_mode_name = "Guardian"
					elseif game_type == 4 and game_mode == 1 then
						game_mode_name = "Co-op Strike"
					elseif game_type == 6 and game_mode == 0 then
						game_mode_name = "Danger Zone"
					end
				else
					if game_type == 0 and game_mode == 0 then
						game_mode_name = "Casual"
					elseif game_type == 1 and game_mode == 0 then
						game_mode_name = "Arms Race"
					elseif game_type == 1 and game_mode == 1 then
						game_mode_name = "Demolition"
					elseif game_type == 1 and game_mode == 2 then
						game_mode_name = "Deathmatch"
					end
				end
				if game_mode_name ~= nil then
					text = "Valve (" .. game_mode_name .. ")"
				else
					text = "Valve"
				end
			end
			if text ~= nil then
				self.text = text
				return renderer_measure_text(nil, text)
			end
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			renderer_text(x, y, 255, 255, 255, a, nil, 0, self.text)
		end
	},
	{
		name = "Server IP",
		get_width = function(self, frame_data)
			if not allow_unsafe_scripts then return end
			frame_data.net_channel_info = frame_data.net_channel_info or native_GetNetChannelInfo()
			if frame_data.net_channel_info == nil then return end
			frame_data.is_loopback = frame_data.is_loopback == nil and native_IsLoopback(frame_data.net_channel_info) or frame_data.is_loopback
			if frame_data.is_loopback then return end
			frame_data.is_valve_ds = frame_data.is_valve_ds == nil and entity.get_prop(entity.get_game_rules(), "m_bIsValveDS") == 1 or frame_data.is_valve_ds
			if frame_data.is_valve_ds then return end
			frame_data.server_address = frame_data.server_address or GetAddress(frame_data.net_channel_info)
			if frame_data.server_address ~= nil and frame_data.server_address ~= "" then
				self.text = frame_data.server_address
				return renderer_measure_text(nil, self.text)
			end
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			renderer_text(x, y, 255, 255, 255, a, nil, 0, self.text)
		end
	},
	{
		name = "Tickrate",
		get_width = function(self, frame_data)
			if globals.mapname() == nil then return end
			local tickinterval = globals_tickinterval()
			if tickinterval ~= nil then
				local text = 1/globals_tickinterval() .. " tick"
				self.text = text
				return renderer_measure_text(nil, text)
			end
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			renderer_text(x, y, 255, 255, 255, a, nil, 0, self.text)
		end
	},
	{
		name = "Time",
		get_width = function(self, frame_data)
			self.time_width = renderer_measure_text(nil, "00")
			self.sep_width = renderer_measure_text(nil, ":")
			return self.time_width + self.sep_width + self.time_width + (self.seconds and (self.sep_width + self.time_width) or 0)
		end,
		draw = function(self, x, y, w, h, r, g, b, a)
			local hours, minutes, seconds, milliseconds = client_system_time()
			hours, minutes = string_format("%02d", hours), string_format("%02d", minutes)
			renderer_text(x, y, 255, 255, 255, a, "", 0, hours)
			renderer_text(x+self.time_width, y, 255, 255, 255, a, "", 0, ":")
			renderer_text(x+self.time_width+self.sep_width, y, 255, 255, 255, a, "", 0, minutes)
			if self.seconds then
				seconds = string_format("%02d", seconds)
				renderer_text(x+self.time_width*2+self.sep_width, y, 255, 255, 255, a, "", 0, ":")
				renderer_text(x+self.time_width*2+self.sep_width*2, y, 255, 255, 255, a, "", 0, seconds)
			end
		end,
		seconds = false
	},
}
local items_drawn = {}
window.pre_paint_callback = function()
	table_clear(items_drawn)
	local value = ui_get(watermark_reference)
	if table_contains(value, "Custom text") then
		value = table_remove_element(value, "Custom text")
		if table_contains(value, "Logo") then
			table_insert(value, 2, "Custom text")
		else
			table_insert(value, 1, "Custom text")
		end
	end
	local screen_width, screen_height = client_screen_size()
	local x = offset_x >= 0 and offset_x or screen_width + offset_x
	local y = offset_y >= 0 and offset_y or screen_height + offset_y
	for i=1, #watermark_items do
		local item = watermark_items[i]
		if item.name == "Time" then
			item.seconds = table_contains(value, "Time + seconds")
			if item.seconds then
				table_insert(value, "Time")
			end
		end
	end
	local item_margin = 9
	local width = 0
	local frame_data = {}
	for i=1, #watermark_items do
		local item = watermark_items[i]
		if table_contains(value, item.name) then
			local item_width = item:get_width(frame_data)
			if item_width ~= nil and item_width > 0 then
				table.insert(items_drawn, {
					item = item,
					item_width = item_width,
					x = width
				})
				width = width + item_width + item_margin
			end
		end
	end
	local _, height = renderer_measure_text(nil, "A")
	window.gradient_bar = false
	window:set_inner_width(width-item_margin)
	window:set_inner_height(height)
	window.visible = #items_drawn > 0
end
window.paint_callback = function()
	local r, g, b = 255, 255, 255
	local a_text = 230
	for i=1, #items_drawn do
		local item = items_drawn[i]
		item.item:draw(window.i_x+item.x, window.i_y, item.item_width, 30, r, g, b, a_text)
		if #items_drawn > i then
			renderer.rectangle(window.i_x+item.x+item.item_width+4, window.i_y+1, 1, window.i_h-1, 210, 210, 210, 255)
		end
	end
end
client.set_event_callback("shutdown", function()
	database.write("sapphyrus_watermark", db)
end)

client.set_event_callback("paint", HellpineC.ClanTag.run)
client.color_log(0, 255, 150, "[resolver] I fuck hvh")
client.set_event_callback("round_start", function() storage = {} last_choked = {} end)

local vector = require("vector")
local csgo_weapons = require("gamesense/csgo_weapons")

local enable_trashtalk = ui.new_checkbox("LUA", "A", "Trashtalk")

local kill_messages = {
    "ez", "ez tap", "1 tap", "nt", "nice try", "lmao", "owned", "gg ez", "too easy", "type 1"
}

local death_messages = {
    "nt", "nice", "ez clap", "wp", "you win", "respect", "almost", "lag?", "nice one", "gg wp"
}

local function get_random_msg(messages)
    return messages[math.random(#messages)]
end

local function on_player_death_trash(e)
    if not ui.get(enable_trashtalk) then return end

    local victim = client.userid_to_entindex(e.userid)
    local attacker = client.userid_to_entindex(e.attacker)
    local me = entity.get_local_player()

    if not me or not victim or not attacker then return end

    if attacker == me and entity.is_enemy(victim) then
        client.exec("say " .. get_random_msg(kill_messages))
    elseif victim == me and entity.is_enemy(attacker) then
        client.exec("say " .. get_random_msg(death_messages))
    end
end

client.set_event_callback("player_death", on_player_death_trash)

local configure_combobox = ui.new_combobox("RAGE", "Other", "Hitbox Selection", "Stomach", "Chest", "Leg/feets")
local static_mode_combobox = ui.new_multiselect("RAGE", "Other", "Hit Mark on:", "Head", "Chest", "Stomach", "Leg/feets")

local function contains(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then return true end
    end
    return false
end

local function hitbox_multiplier()
    local sel = ui.get(configure_combobox)
    if sel == "Stomach" then return 1.25
    elseif sel == "Chest" then return 1
    elseif sel == "Leg/feets" then return 0.75 end
    return 1
end

local function get_lethal_alpha()
    local head = contains(ui.get(static_mode_combobox), "Head") and 255 or 0
    local chest = contains(ui.get(static_mode_combobox), "Chest") and 255 or 0
    local stomach = contains(ui.get(static_mode_combobox), "Stomach") and 255 or 0
    local legs = contains(ui.get(static_mode_combobox), "Leg/feets") and 255 or 0
    return head, chest, stomach, legs
end

local function on_paint_lethal()
    local local_player = entity.get_local_player()
    if not local_player or not entity.is_alive(local_player) then return end

    local weapon_ent = entity.get_player_weapon(local_player)
    if not weapon_ent then return end

    local weapon_idx = entity.get_prop(weapon_ent, "m_iItemDefinitionIndex")
    local weapon = csgo_weapons[weapon_idx]
    if not weapon then return end

    local alpha_head, alpha_chest, alpha_stomach, alpha_legs = get_lethal_alpha()
    local multiplier = hitbox_multiplier()
    local local_origin = vector(entity.get_origin(local_player))

    local enemies = entity.get_players(true)
    for i = 1, #enemies do
        local player = enemies[i]
        local hp = entity.get_prop(player, "m_iHealth")
        if hp > 0 then
            local target_origin = vector(entity.get_origin(player))
            local distance = local_origin:dist(target_origin) * 0.01905

            local base_dmg = weapon.damage
            local dmg = base_dmg * math.pow(weapon.range_modifier, distance / 500)

            local armor = entity.get_prop(player, "m_ArmorValue")
            if armor > 0 then
                local armor_ratio = weapon.armor_ratio or 0.5
                local dmg_to_armor = dmg * armor_ratio * 0.5
                if dmg_to_armor > armor then
                    dmg = base_dmg - (armor / 0.5)
                else
                    dmg = dmg - dmg_to_armor
                end
            end

            local scaled_dmg = dmg * multiplier

            local hx, hy = renderer.world_to_screen(entity.hitbox_position(player, 0))
            local cx, cy = renderer.world_to_screen(entity.hitbox_position(player, 4))
            local sx, sy = renderer.world_to_screen(entity.hitbox_position(player, 6))
            local lx, ly = renderer.world_to_screen(entity.hitbox_position(player, 7))
            local rx, ry = renderer.world_to_screen(entity.hitbox_position(player, 8))

            local x1, y1, x2, y2, visible = entity.get_bounding_box(player)
            if x1 and visible > 0 then
                local center_x = x1 + (x2 - x1) / 2
                local dmg_y = y1 - 17

                local dmg_r = scaled_dmg >= hp and 255 or 253
                renderer.text(center_x, dmg_y, dmg_r, dmg_r, dmg_r, 255, "cb", 0, math.floor(scaled_dmg))

                if hx and hy then renderer.text(hx, hy, 253, 69, 106, alpha_head, "cbd", 0, (dmg * 4 >= hp) and " " or "+") end
                if cx and cy then renderer.text(cx, cy, 253, 69, 106, alpha_chest, "cbd", 0, (dmg >= hp) and " " or "+") end
                if sx and sy then renderer.text(sx, sy, 253, 69, 106, alpha_stomach, "cbd", 0, (dmg * 1.25 >= hp) and " " or "+") end
                if lx and ly then renderer.text(lx, ly, 253, 69, 106, alpha_legs, "cbd", 0, (dmg * 0.75 >= hp) and " " or "+") end
                if rx and ry then renderer.text(rx, ry, 253, 69, 106, alpha_legs, "cbd", 0, (dmg * 0.75 >= hp) and " " or "+") end

                if player == client.current_threat() then
                    renderer.text(center_x - 12, dmg_y, 255, 255, 255, 255, "cbd", 0, "-")
                    renderer.text(center_x + 12, dmg_y, 255, 255, 255, 255, "cbd", 0, "-")
                end
            end
        end
    end
end

client.set_event_callback("paint", on_paint_lethal)

local ui_enable = ui.new_checkbox("LUA", "A", "Wireframe Onshot")
local ui_mode = ui.new_combobox("LUA", "A", "Color Mode", "Static", "Rainbow")
local ui_color = ui.new_color_picker("LUA", "A", "Static Color", 255, 50, 50, 255)
local ui_duration = ui.new_slider("LUA", "A", "Duration", 1, 10, 4, true, "s", 0.1)
local ui_speed = ui.new_slider("LUA", "A", "Rainbow Speed", 1, 30, 10, true, "", 1)

local killed_players = {}
local rainbow_offset = 0
local frame_counter = 0

local function hsv_to_rgb(h, s, v)
    h = (h % 360) / 360
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    local r, g, b
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end

    return r * 255, g * 255, b * 255
end

local function update_visibility()
    local mode = ui.get(ui_mode)
    ui.set_visible(ui_color, mode == "Static")
    ui.set_visible(ui_speed, mode == "Rainbow")
end
ui.set_callback(ui_mode, update_visibility)
update_visibility()


local function on_player_death(e)
    if not ui.get(ui_enable) then return end

    local attacker = client.userid_to_entindex(e.attacker)
    local victim = client.userid_to_entindex(e.userid)
    local me = entity.get_local_player()

    if attacker == me and entity.is_enemy(victim) then
        killed_players[victim] = globals.curtime() + ui.get(ui_duration)
    end
end

local function on_paint()
    if not ui.get(ui_enable) then
        killed_players = {}
        return
    end

    local curtime = globals.curtime()
    local mode = ui.get(ui_mode)
    local speed = ui.get(ui_speed)

    rainbow_offset = rainbow_offset + globals.frametime() * speed * 36


    frame_counter = (frame_counter + 1) % 3
    if frame_counter ~= 0 then return end

    for ent, expire_time in pairs(killed_players) do
        if curtime > expire_time or not entity.get_player_name(ent) then
            killed_players[ent] = nil
        else
            local r, g, b, a = 255, 50, 50, 255
            if mode == "Rainbow" then
                r, g, b = hsv_to_rgb(rainbow_offset + (ent * 30), 1, 1)
                a = 255
            else
                r, g, b, a = ui.get(ui_color)
            end


            client.draw_hitboxes(ent, 0.1, -1, r, g, b, a, -1, true)
        end
    end
end

client.set_event_callback("player_death", on_player_death)
client.set_event_callback("paint", on_paint)

client.set_event_callback("shutdown", function()
    killed_players = {}
end)

local tracer_enabled = ui.new_checkbox("LUA", "B", "Bullet tracers")
local tracer_color = ui.new_color_picker("LUA", "B", "Color", 255, 255, 255, 255)
local tracer_duration = ui.new_slider("LUA", "B", "Duration", 1, 50, 20, true, "s", 0.1)
local tracer_thickness = ui.new_slider("LUA", "B", "Thickness", 1, 5, 1, true, "px")
local tracer_fade = ui.new_checkbox("LUA", "B", "Fade effect")

local tracer_queue = {}
local max_tracers = 50

local function calculate_fade_alpha(start_time, duration, curtime)
    if not ui.get(tracer_fade) then return 255 end
    local elapsed = curtime - start_time
    local progress = elapsed / duration
    return math.max(0, math.floor(255 * (1 - progress)))
end

client.set_event_callback("bullet_impact", function(e)
    if not ui.get(tracer_enabled) then return end
    local me = entity.get_local_player()
    if client.userid_to_entindex(e.userid) ~= me then return end

    local lx, ly, lz = client.eye_position()
    local curtime = globals.curtime()
    local duration = ui.get(tracer_duration) * 0.1

    local key = globals.tickcount()
    tracer_queue[key] = {
        start_x = lx, start_y = ly, start_z = lz,
        end_x = e.x, end_y = e.y, end_z = e.z,
        start_time = curtime, duration = duration
    }

    local count = 0
    for k in pairs(tracer_queue) do
        count = count + 1
        if count > max_tracers then tracer_queue[k] = nil end
    end
end)

client.set_event_callback("paint", function()
    if not ui.get(tracer_enabled) then return end

    local curtime = globals.curtime()
    local r, g, b = ui.get(tracer_color)
    local thickness = ui.get(tracer_thickness)

    for _, data in pairs(tracer_queue) do
        if curtime <= data.start_time + data.duration then
            local x1, y1 = renderer.world_to_screen(data.start_x, data.start_y, data.start_z)
            local x2, y2 = renderer.world_to_screen(data.end_x, data.end_y, data.end_z)
            if x1 and x2 and y1 and y2 then
                local alpha = calculate_fade_alpha(data.start_time, data.duration, curtime)
                renderer.line(x1, y1, x2, y2, r, g, b, alpha, thickness)
            end
        end
    end

    for k, data in pairs(tracer_queue) do
        if curtime > data.start_time + data.duration then
            tracer_queue[k] = nil
        end
    end
end)

client.set_event_callback("round_prestart", function()
    tracer_queue = {}
end)

client.set_event_callback("shutdown", function()
    tracer_queue = {}
end)
