
local ui = require("gamesense/pui")
local vector = require("vector")

local menu_reference = ui.new_checkbox("RAGE", "Other", "Thinking Mode")
local hitboxes_ref = ui.reference("RAGE", "Aimbot", "Target hitbox")
local accuracy_boost_ref = ui.reference("RAGE", "Other", "Accuracy boost")
local slow_walk_ref, slow_walk_key = ui.reference("AA", "Other", "Slow motion")

local function on_setup_command(cmd)
    if not ui.get(menu_reference) then return end

    local me = entity.get_local_player()
    local enemies = entity.get_players(true)
    local weapon = entity.get_player_weapon(me)
    if weapon == nil then return end
    
    local weapon_id = entity.get_prop(weapon, "m_iItemDefinitionIndex")

    for i=1, #enemies do
        local ent = enemies[i]
        local health = entity.get_prop(ent, "m_iHealth")
        
        local head_pos = {entity.hitbox_position(ent, 0)}
        local chest_pos = {entity.hitbox_position(ent, 2)}
        local pelvis_pos = {entity.hitbox_position(ent, 3)}

        local head_visible = client.visible(head_pos[1], head_pos[2], head_pos[3])
        local chest_visible = client.visible(chest_pos[1], chest_pos[2], chest_pos[3])
        local pelvis_visible = client.visible(pelvis_pos[1], pelvis_pos[2], pelvis_pos[3])

        if ui.get(slow_walk_ref) and ui.get(slow_walk_key) then
            ui.set(accuracy_boost_ref, "Maximum")
        else
            ui.set(accuracy_boost_ref, "Medium")
        end

        local should_baim = false

        if not head_visible and (chest_visible or pelvis_visible) then
            should_baim = true
        elseif health < 45 then
            should_baim = true
        elseif head_visible and chest_visible then
            if health < 70 and (weapon_id == 9 or weapon_id == 40) then
                should_baim = true
            end
        end

        if should_baim then
            ui.set(hitboxes_ref, {"Chest", "Stomach", "Pelvis"})
        else
            if not head_visible and not chest_visible and not pelvis_visible then
                ui.set(hitboxes_ref, {"Head", "Chest", "Stomach", "Feet", "Legs"})
            else
                ui.set(hitboxes_ref, {"Head", "Chest", "Stomach"})
            end
        end

        if (weapon_id == 1 or weapon_id == 64) and head_visible then
            ui.set(accuracy_boost_ref, "Maximum")
        end
    end
end

client.set_event_callback("setup_command", on_setup_command)

local enable_resolver = ui.new_checkbox("LUA", "B", "Anti-Aim correction")


local function normalize_yaw(yaw)
    while yaw > 180 do yaw = yaw - 360 end
    while yaw < -180 do yaw = yaw + 360 end
    return yaw
end

local function normalize_pitch(pitch)
    return math.clamp(pitch, -89, 89)
end

local function angle_diff(a1, a2)
    a1 = normalize_yaw(a1)
    a2 = normalize_yaw(a2)
    local diff = normalize_yaw(a2 - a1)
    return diff
end

local function calculate_angle(from, to)
    local diff = to - from
    local yaw = math.deg(math.atan2(diff.y, diff.x))
    local pitch = -math.deg(math.atan2(diff.z, diff:length2d()))
    return vector(pitch, yaw, 0)
end


local resolver = {}
resolver.__index = resolver

function resolver:new()
    local self = setmetatable({}, resolver)
    self.player = nil
    self.player_record = nil
    self.prev_record = nil
    self.side = false
    self.fake = false
    self.was_first_bruteforce = false
    self.was_second_bruteforce = false
    self.original_goal_feet_yaw = 0.0
    self.original_pitch = 0.0
    return self
end

function resolver:initialize(e, record, goal_feet_yaw, pitch, previous_record)
    self.player = e
    self.player_record = record
    if previous_record then
        self.prev_record = previous_record
    end
    self.original_pitch = normalize_pitch(pitch)
    self.original_goal_feet_yaw = normalize_yaw(goal_feet_yaw)
end

function resolver:lagcomp_initialize(player, origin, velocity, flags, on_ground)

    lagcompensation:extrapolate(player, origin, velocity, flags, on_ground)
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
    if self:IsAdjustingBalance() then
        if (prev_layer.cycle ~= cur_layer.cycle) and cur_layer.weight == 1.0 then
            return true
        elseif cur_layer.weight == 0.0 and (prev_layer.cycle > 0.92 and cur_layer.cycle > 0.92) then
            return true
        end
    end
    return false
end

function resolver:IsAdjustingBalance()
    for i = 0, 12 do
        local activity = self.player:sequence_activity(self.player_record.layers[i].sequence)
        if activity == 979 then
            return true
        end
    end
    return false
end

function resolver:is_slow_walking()
    local old_velocity_2D = {} 
    local tick_counter = {} 
    
    if not old_velocity_2D[self.player:get_prop("m_iIndex")] then old_velocity_2D[self.player:get_prop("m_iIndex")] = 0.0 end
    if not tick_counter[self.player:get_prop("m_iIndex")] then tick_counter[self.player:get_prop("m_iIndex")] = 0 end

    local velocity = self.player:get_prop("m_vecVelocity")
    local velocity_2D = velocity:length2d()
    if velocity_2D ~= old_velocity_2D[self.player:get_prop("m_iIndex")] then
        old_velocity_2D[self.player:get_prop("m_iIndex")] = velocity_2D
        tick_counter[self.player:get_prop("m_iIndex")] = 0
    else
        tick_counter[self.player:get_prop("m_iIndex")] = tick_counter[self.player:get_prop("m_iIndex")] + 1
        local max_ticks = math.floor(0.1 / globals.tickinterval())
        if tick_counter[self.player:get_prop("m_iIndex")] > max_ticks then
            return true
        end
    end
    return false
end

function resolver:GetChokedPackets()
    local last_ticks = {} 
    if not last_ticks[self.player:get_prop("m_iIndex")] then last_ticks[self.player:get_prop("m_iIndex")] = 0 end

    local ticks = globals.time_to_ticks(self.player:get_prop("m_flSimulationTime") - self.player:get_prop("m_flOldSimulationTime"))
    if ticks == 0 and last_ticks[self.player:get_prop("m_iIndex")] > 0 then
        return last_ticks[self.player:get_prop("m_iIndex")] - 1
    else
        last_ticks[self.player:get_prop("m_iIndex")] = ticks
        return ticks
    end
end

function resolver:get_side_standing()
    local angle_difference = angle_diff(self.player:get_prop("m_angEyeAngles").y, self.original_goal_feet_yaw)
    self.player_record.curSide = (angle_difference <= 0.0) and "LEFT1" or "RIGHT1"
end

local function get_backward_side(player)
    return calculate_angle(entity.get_local_player():get_prop("m_vecOrigin"), player:get_prop("m_vecOrigin")).y
end

local function resolve_update_animations(e)
    e:update_client_animations()
end

local function GetHitboxPos(player, mat, hitbox_id)
    if not player then return vector(0,0,0) end
    
    return entity.get_hitbox_position(player:get_prop("m_iIndex"), hitbox_id) or vector(0,0,0)
end

local function resolve_yaw()
    
end


local lagcompensation = {}
lagcompensation.__index = lagcompensation

function lagcompensation:new()
    local self = setmetatable({}, lagcompensation)
    self.player_records = {} 
    for i=1, 65 do self.player_records[i] = {} end
    return self
end

function lagcompensation:fsn(stage)
    if not ui.get(enable_resolver) then return end
    if stage ~= "FRAME_NET_UPDATE_END" then return end 
    if not ui.get("rage_enabled") then return end 

    for i = 1, globals.maxclients() do
        local e = entity.get_player_entity(i)
        if e == entity.get_local_player() then goto continue end
        if not self:valid(i, e) then goto continue end

        if #self.player_records[i] == 0 or (#self.player_records[i] > 0 and e:get_prop("m_flSimulationTime") ~= e:get_prop("m_flOldSimulationTime")) then
            if #self.player_records[i] > 0 and (e:get_prop("m_vecOrigin") - self.player_records[i][1].origin):lengthsq() > 4096.0 then
                for _, record in ipairs(self.player_records[i]) do
                    record.invalid = true
                end
            end
            table.insert(self.player_records[i], 1, { 
                layers = {}, 
               
            })
            self:update_player_animations(e)
            if #self.player_records[i] > 32 then
                table.remove(self.player_records[i])
            end
        end
        ::continue::
    end
end

function lagcompensation:valid(i, e)
    if not ui.get(enable_resolver) then return false end
    if not ui.get("rage_enabled") or not e:valid(false) then
        if not e:is_alive() then
            is_dormant[i] = false 
            player_resolver[i]:reset()
            globals.fired_shots[i] = 0
            globals.missed_shots[i] = 0
        elseif e:is_dormant() then
            is_dormant[i] = true
        end
        self.player_records[i] = {}
        return false
    end
    return true
end

local function IsNearEqual(v1, v2, Tolerance)
    return math.abs(v1 - v2) <= math.abs(Tolerance)
end

function lagcompensation:ent_use_jitter(player, new_side, player_record)
    if not ui.get(enable_resolver) then return end
    if not player:is_alive() then return end
    if not player:valid(false, false) then return end
    if player:is_dormant() then return end

    local LastAngle = {} 
    local LastBrute = {}
    local Switch = {}
    local LastUpdateTime = {}

    local i = player:get_prop("m_iIndex")
    if not LastAngle[i] then LastAngle[i] = 0 end
    

    local layers = player:get_anim_layers()
    local animstate = player:get_anim_state() 
    local speed = player:get_prop("m_vecVelocity"):length2d()
    local delta = angle_diff(animstate.goal_feet_yaw, animstate.eye_yaw)
    local CurrentAngle = player:get_prop("m_angEyeAngles").y
    local goalfeetyaw = animstate.goal_feet_yaw

    if layers[3].weight <= 0.1 then
        if IsNearEqual(CurrentAngle, LastAngle[i], 50.0) then
            Switch[i] = not Switch[i]
            LastAngle[i] = CurrentAngle
            new_side = Switch[i] and -1 or 1
            LastBrute[i] = new_side
            LastUpdateTime[i] = globals.curtime()
        else
            if math.abs(LastUpdateTime[i] - globals.curtime()) >= globals.ticks_to_time(17) or player:get_prop("m_flSimulationTime") ~= player:get_prop("m_flOldSimulationTime") then
                LastAngle[i] = CurrentAngle
            end
            new_side = LastBrute[i]
        end
    end
end

function lagcompensation:extrapolate(player, origin, velocity, flags, on_ground)
    if not ui.get(enable_resolver) then return end
    local start = origin
    local end_pos = start + (velocity * globals.tickinterval())
    local trace = client.trace_line(start, end_pos, player:get_prop("m_vecMins"), player:get_prop("m_vecMaxs"), "MASK_PLAYERSOLID & ~CONTENTS_MONSTER") -- Adapt to API

    if trace.fraction ~= 1.0 then
        for i=1, 2 do
            velocity = velocity - trace.plane.normal * velocity:dot(trace.plane.normal)
            local adjust = velocity:dot(trace.plane.normal)
            if adjust < 0 then
                velocity = velocity - (trace.plane.normal * adjust)
            end
            start = trace.endpos
            end_pos = start + (velocity * (globals.tickinterval() * (1.0 - trace.fraction)))
            trace = client.trace_line(start, end_pos, player:get_prop("m_vecMins"), player:get_prop("m_vecMaxs"), "MASK_PLAYERSOLID & ~CONTENTS_MONSTER")
            if trace.fraction == 1.0 then break end
        end
    end
    local temp_endpos = trace.endpos
    start = temp_endpos
    end_pos = temp_endpos
    origin = temp_endpos
    end_pos.z = end_pos.z - 2.0
    trace = client.trace_line(start, end_pos, player:get_prop("m_vecMins"), player:get_prop("m_vecMaxs"), "MASK_PLAYERSOLID & ~CONTENTS_MONSTER")
    flags = bit.band(flags, bit.bnot(1)) 
    if trace.fraction ~= 1.0 and trace.plane.normal.z > 0.7 then
        flags = bit.bor(flags, 1)
    end
end

-- // Approach
local function Approach(target, value, speed)
    local diff = target - value
    if diff > speed then
        value = value + speed
    elseif diff < -speed then
        value = value - speed
    else
        value = target
    end
    return value
end

local function ApproachVector(target, value, speed)
    local diff = target - value
    local delta = diff:length()
    if delta > speed then
        value = value + diff:normalized() * speed
    elseif delta < -speed then
        value = value - diff:normalized() * speed
    else
        value = target
    end
    return value
end


local aimmatrix_transition = {}
aimmatrix_transition.__index = aimmatrix_transition

function aimmatrix_transition:new()
    local self = setmetatable({}, aimmatrix_transition)
    self:Init()
    return self
end

function aimmatrix_transition:Init()
    self.duration_state_has_been_valid = 0
    self.duration_state_has_been_invalid = 0
    self.how_long_to_wait_until_transition_can_blend_in = 0.3
    self.how_long_to_wait_until_transition_can_blend_out = 0.3
    self.blend_value = 0
end

function aimmatrix_transition:UpdateTransitionState(bStateShouldBeValid, flTimeInterval, flSpeed)
    if bStateShouldBeValid then
        self.duration_state_has_been_invalid = 0
        self.duration_state_has_been_valid = self.duration_state_has_been_valid + flTimeInterval
        if self.duration_state_has_been_valid >= self.how_long_to_wait_until_transition_can_blend_in then
            self.blend_value = Approach(1, self.blend_value, flSpeed)
        end
    else
        self.duration_state_has_been_valid = 0
        self.duration_state_has_been_invalid = self.duration_state_has_been_invalid + flTimeInterval
        if self.duration_state_has_been_invalid >= self.how_long_to_wait_until_transition_can_blend_out then
            self.blend_value = Approach(0, self.blend_value, flSpeed)
        end
    end
end

function lagcompensation:OnRestore(e, player_record)
    if not ui.get(enable_resolver) then return end
    
end

function lagcompensation:SetUpAimMatrix(e)
    if not ui.get(enable_resolver) then return end
    local animstate = e:get_anim_state()
    local m_flLastUpdateIncrement = 0.0 
    local m_flSpeedAsPortionOfWalkTopSpeed = 0.0
    local m_flSpeedAsPortionOfRunTopSpeed = 0.0
    local m_tStandWalkAim = aimmatrix_transition:new()
    local m_tStandRunAim = aimmatrix_transition:new()
    local m_tCrouchWalkAim = aimmatrix_transition:new()
    local m_flSpeedAsPortionOfCrouchTopSpeed = 0.0

    if animstate.duck_amount <= 0 or animstate.duck_amount >= 1 then
        local bPlayerIsWalking = e:get_prop("m_bIsWalking")
        local bPlayerIsScoped = e:get_prop("m_bIsScoped")
        local flTransitionSpeed = m_flLastUpdateIncrement * (bPlayerIsScoped and 4.2 or 0.8)

        if bPlayerIsScoped then
            m_tStandWalkAim.duration_state_has_been_invalid = m_tStandWalkAim.how_long_to_wait_until_transition_can_blend_out
            m_tStandRunAim.duration_state_has_been_invalid = m_tStandRunAim.how_long_to_wait_until_transition_can_blend_out
            m_tCrouchWalkAim.duration_state_has_been_invalid = m_tCrouchWalkAim.how_long_to_wait_until_transition_can_blend_out
        end

        m_tStandWalkAim:UpdateTransitionState(bPlayerIsWalking and not bPlayerIsScoped and m_flSpeedAsPortionOfWalkTopSpeed > 0.7 and m_flSpeedAsPortionOfRunTopSpeed < 0.7, m_flLastUpdateIncrement, flTransitionSpeed)
        m_tStandRunAim:UpdateTransitionState(not bPlayerIsScoped and m_flSpeedAsPortionOfRunTopSpeed >= 0.7, m_flLastUpdateIncrement, flTransitionSpeed)
        m_tCrouchWalkAim:UpdateTransitionState(not bPlayerIsScoped and m_flSpeedAsPortionOfCrouchTopSpeed >= 0.5, m_flLastUpdateIncrement, flTransitionSpeed)
    end

    local flStandIdleWeight = 1
    local flStandWalkWeight = m_tStandWalkAim.blend_value
    local flStandRunWeight = m_tStandRunAim.blend_value
    local flCrouchIdleWeight = 1
    local flCrouchWalkWeight = m_tCrouchWalkAim.blend_value

    if flStandWalkWeight >= 1 then flStandIdleWeight = 0 end
    if flStandRunWeight >= 1 then
        flStandIdleWeight = 0
        flStandWalkWeight = 0
    end
    if flCrouchWalkWeight >= 1 then flCrouchIdleWeight = 0 end
    if animstate.duck_amount >= 1 then
        flStandIdleWeight = 0
        flStandWalkWeight = 0
        flStandRunWeight = 0
    elseif animstate.duck_amount <= 0 then
        flCrouchIdleWeight = 0
        flCrouchWalkWeight = 0
    end

    local flOneMinusDuckAmount = 1.0 - animstate.duck_amount
    flCrouchIdleWeight = flCrouchIdleWeight * animstate.duck_amount
    flCrouchWalkWeight = flCrouchWalkWeight * animstate.duck_amount
    flStandWalkWeight = flStandWalkWeight * flOneMinusDuckAmount
    flStandRunWeight = flStandRunWeight * flOneMinusDuckAmount

    if flCrouchIdleWeight < 1 and flCrouchWalkWeight < 1 and flStandWalkWeight < 1 and flStandRunWeight < 1 then
        flStandIdleWeight = 1
    end
    
end

function lagcompensation:setupvelocity(e, record)
    if not ui.get(enable_resolver) then return end
    local animstate = e:get_anim_state()
    local animlayers = e:get_anim_layers()
    local m_pState = animstate 

    local CS_PLAYER_SPEED_RUN = 260.0
    local m_flLastUpdateIncrement = m_pState.last_update_increment 
    local m_flFootYaw = m_pState.goal_feet_yaw
    local m_flMoveYaw = m_pState.current_torso_yaw
    local m_vecVelocityNormalizedNonZero = m_pState.velocity_normalized_non_zero
    local m_flInAirSmoothValue = m_pState.in_air_smooth_value
    local m_AnimationData 
    local m_szDestination = "move" 
    local m_nMoveSequence = e:get_attachment(m_szDestination) or e:get_attachment("move")

    local m_flYaw = angle_diff((m_pState.current_torso_yaw + m_pState.goal_feet_yaw), 180.0)
    local m_angAngle = vector(0, m_flYaw, 0)
    local m_vecDirection = m_angAngle:to_forward() 

    local m_flMovementSide = m_vecVelocityNormalizedNonZero:dot(m_vecDirection)
    if m_flMovementSide < 0.0 then m_flMovementSide = -m_flMovementSide end

    local m_flNewFeetWeight = math.angle_distance(m_flMovementSide, 0.2) * animlayers[1].weight 
    local m_flNewFeetWeightWithAirSmooth = m_flNewFeetWeight * m_flInAirSmoothValue
    local m_flLayer5_Weight = animlayers[5].weight
    local m_flNewWeight = 0.55
    if 1.0 - m_flLayer5_Weight > 0.55 then m_flNewWeight = 1.0 - m_flLayer5_Weight end

    local m_flNewFeetWeightLayerWeight = m_flNewWeight * m_flNewFeetWeightWithAirSmooth
    local m_flFeetCycleRate = 0.0
    local m_flSpeed = math.min(e:get_prop("m_vecVelocity"):length(), 260.0)
    animlayers[1].sequence = m_nMoveSequence
    animlayers[1].weight = math.clamp(m_flNewFeetWeightLayerWeight, 0.0, 1.0)

    if animstate.feet_speed_forwards_or_sideways >= 0.0 then
        animstate.feet_speed_forwards_or_sideways = math.min(animstate.feet_speed_forwards_or_sideways, 1.0)
    else
        animstate.feet_speed_forwards_or_sideways = 0.0
    end

    local v54 = animstate.duck_amount
    local v55 = (((animstate.some_field * -0.3) - 0.2) * animstate.feet_speed_forwards_or_sideways) + 1.0
    if v54 > 0.0 then
        if animstate.feet_speed_unknown_forward_or_sideways >= 0.0 then
            animstate.feet_speed_unknown_forward_or_sideways = math.min(animstate.feet_speed_unknown_forward_or_sideways, 1.0)
        else
            animstate.feet_speed_unknown_forward_or_sideways = 0.0
        end
    end

    local bWasMovingLastUpdate = false
    local bJustStartedMovingLastUpdate = false
    if e:get_prop("m_vecVelocity"):length2d() <= 0.0 then
        animstate.time_since_started_moving = 0.0
        bWasMovingLastUpdate = animstate.time_since_stopped_moving <= 0.0
        animstate.time_since_stopped_moving = animstate.time_since_stopped_moving + animstate.last_client_side_animation_update_time
    else
        animstate.time_since_stopped_moving = 0.0
        bJustStartedMovingLastUpdate = animstate.time_since_started_moving <= 0.0
        animstate.time_since_started_moving = animstate.last_client_side_animation_update_time + animstate.time_since_started_moving
    end

    if animstate.feet_speed_unknown_forward_or_sideways < 1.0 then
        if animstate.feet_speed_unknown_forward_or_sideways < 0.5 then
            local unknown_velocity = 0.0
            local velocity = unknown_velocity
            local delta = animstate.last_client_side_animation_update_time * 60.0
            local new_velocity
            if (80.0 - velocity) <= delta then
                if (-delta) <= (80.0 - velocity) then
                    new_velocity = 80.0
                else
                    new_velocity = velocity - delta
                end
            else
                new_velocity = velocity + delta
            end
            unknown_velocity = new_velocity
        end
    end
end

function lagcompensation:animevent(e, state, order, activity)
    if not ui.get(enable_resolver) then return end
    local v18 = state.duck_amount > 0.55
    local v15 = state.velocity > 0.25
    local sequence = 0
    local p_layer = e:get_anim_layers()[order]
    if activity == 985 then
        sequence = v15 and 18 or 17
        if not v18 then
            sequence = v15 and 16 or 15
        end
    elseif activity == 986 then
        sequence = 14
    elseif activity == 987 then
        sequence = 13
    elseif activity == 988 then
        sequence = v15 and 22 or 20
        if v18 then
            sequence = v15 and 21 or 19
        end
    elseif activity == 989 then
        sequence = 23
        if v18 then
            sequence = 24
        end
    else
        return
    end

    p_layer.sequence = sequence
    p_layer.weight = 0
    p_layer.cycle = 0
end

function lagcompensation:update_player_animations(e)
    if not ui.get(enable_resolver) then return end
    local animstate = e:get_anim_state()
    if not animstate then return end

    local player_info = client.get_player_info(e:get_prop("m_iIndex"))
    if not player_info then return end

    local records = self.player_records[e:get_prop("m_iIndex")]
    if #records == 0 then return end

    local previous_record = #records >= 2 and records[2] or nil
    local record = records[1]

    local animlayers = e:get_anim_layers()
    record.layers = animlayers -- Copy

    local backup_lower_body_yaw_target = e:get_prop("m_flLowerBodyYawTarget")
    local backup_duck_amount = e:get_prop("m_flDuckAmount")
    local backup_flags = e:get_prop("m_fFlags")
    local backup_eflags = e:get_prop("m_iEFlags")
    local backup_curtime = globals.curtime()
    local backup_frametime = globals.frametime()
    local backup_realtime = globals.realtime()
    local backup_framecount = globals.framecount()
    local backup_tickcount = globals.tickcount()
    local backup_interpolation_amount = globals.interpolation_amount()

    globals.set_curtime(e:get_prop("m_flSimulationTime"))
    globals.set_frametime(globals.tickinterval())

    local current_weapon = e:get_prop("m_hActiveWeapon")

    if previous_record then
        record.shot = record.last_shot_time > previous_record.simulation_time and record.last_shot_time <= record.simulation_time
        local velocity = e:get_prop("m_vecVelocity")
        local was_in_air = bit.band(e:get_prop("m_fFlags"), 1) and bit.band(previous_record.flags, 1)
        local time_difference = math.max(globals.tickinterval(), e:get_prop("m_flSimulationTime") - previous_record.simulation_time)
        local origin_delta = e:get_prop("m_vecOrigin") - previous_record.origin
        local animation_speed = 0.0

        if not origin_delta:is_zero() and globals.time_to_ticks(time_difference) > 0 then
            e:set_prop("m_vecVelocity", origin_delta * (1.0 / time_difference))
            if bit.band(e:get_prop("m_fFlags"), 1) and animlayers[11].weight > 0.0 and animlayers[11].weight < 1.0 and animlayers[11].cycle > previous_record.layers[11].cycle then
                local weapon = e:get_prop("m_hActiveWeapon")
                if weapon then
                    local max_speed = 260.0
                    local weapon_info = weapon:get_weapon_info()
                    if weapon_info then
                        max_speed = e:get_prop("m_bIsScoped") and weapon_info.max_player_speed_alt or weapon_info.max_player_speed
                    end
                    local modifier = 0.35 * (1.0 - animlayers[11].weight)
                    if modifier > 0.0 and modifier < 1.0 then
                        animation_speed = max_speed * (modifier + 0.55)
                    end
                end
            end

            if animation_speed > 0.0 then
                animation_speed = animation_speed / e:get_prop("m_vecVelocity"):length2d()
                local vel = e:get_prop("m_vecVelocity")
                vel.x = vel.x * animation_speed
                vel.y = vel.y * animation_speed
                e:set_prop("m_vecVelocity", vel)
            end

            if #records >= 3 and time_difference > globals.tickinterval() then
                local previous_velocity = (previous_record.origin - records[3].origin) * (1.0 / time_difference)
                if not previous_velocity:is_zero() and not was_in_air then
                    local current_direction = normalize_yaw(math.rad(math.atan2(e:get_prop("m_vecVelocity").y, e:get_prop("m_vecVelocity").x)))
                    local previous_direction = normalize_yaw(math.rad(math.atan2(previous_velocity.y, previous_velocity.x)))
                    local average_direction = current_direction - previous_direction
                    average_direction = math.deg(normalize_yaw(current_direction + average_direction * 0.5))
                    local direction_cos = math.cos(average_direction)
                    local direction_sin = math.sin(average_direction)
                    local velocity_speed = e:get_prop("m_vecVelocity"):length2d()
                    if animlayers[6].playback_rate == 0.0 then
                        e:set_prop("m_vecVelocity", vector(0,0,0))
                    else
                        local avg_speed = e:get_prop("m_vecVelocity"):length2d()
                        if avg_speed ~= 0.0 then
                            local weight = animlayers[11].weight
                            local speed_as_portion = 0.55 - (weight - 1.0) * 0.35
                            local avg_speed_modifier = speed_as_portion * (current_weapon and math.max(current_weapon:get_weapon_info().max_player_speed, 0.001) or 260.0)
                            if weight >= 1.0 and avg_speed > avg_speed_modifier or weight < 1.0 and (avg_speed_modifier > avg_speed or weight > 0.0) then
                                local vel = e:get_prop("m_vecVelocity")
                                vel.x = vel.x / avg_speed
                                vel.y = vel.y / avg_speed
                                vel = vel * avg_speed_modifier
                                e:set_prop("m_vecVelocity", vel * avg_speed_modifier)
                            end
                        end
                    end
                end
            end
        end

        if bit.band(e:get_prop("m_fFlags"), 1) == 0 then
            local sv_gravity = cvar.sv_gravity:get_float()
            local tick = math.clamp(globals.time_to_ticks(time_difference), 1, 16)
            local vel = e:get_prop("m_vecVelocity")
            vel.z = vel.z - (sv_gravity * globals.ticks_to_time(tick) * 0.5)
            e:set_prop("m_vecVelocity", vel)
        else
            local vel = e:get_prop("m_vecVelocity")
            vel.z = 0.0
            e:set_prop("m_vecVelocity", vel)
        end
    else
        record.shot = record.last_shot_time == record.simulation_time
    end

    if animlayers[6].weight == 0.0 or animlayers[6].playback_rate == 0.0 then
        e:set_prop("m_vecVelocity", vector(0,0,0))
    end

    e:set_prop("m_iEFlags", bit.band(e:get_prop("m_iEFlags"), bit.bnot(0x40))) 

    local activity = e:sequence_activity(animlayers[3].sequence)
    if animstate.time_since_stopped_moving > 0.1 and e:get_prop("m_vecVelocity"):length2d() < 0.1 or animlayers[6].weight <= 0.1 then
        activity = 980 
    end

    e:set_prop("m_vecAbsVelocity", e:get_prop("m_vecVelocity"))
    e:set_prop("m_bClientSideAnimation", true)

    if is_dormant[e:get_prop("m_iIndex")] then
        is_dormant[e:get_prop("m_iIndex")] = false
        if bit.band(e:get_prop("m_fFlags"), 1) then
            animstate.on_ground = true
            animstate.in_hit_ground_animation = false
        end
        animstate.time_since_in_air = 0.0
        animstate.goal_feet_yaw = normalize_yaw(e:get_prop("m_angEyeAngles").y)
    end

    local updated_animations = false
    local state = {} 
    for k,v in pairs(animstate) do state[k] = v end

    local old_onground = animstate.on_ground
    local new_onladder = not animstate.on_ground and e:get_move_type() == 9 
    local new_onground = bit.band(e:get_prop("m_fFlags"), 1)
    local just_landed = old_onground ~= new_onground and new_onground

    if animstate.on_ground then
        if not animstate.in_hit_ground_animation then
            if just_landed or new_onladder then
                local landing_activity = animstate.time_since_in_air > 1.0 and 988 or 987 
                record.layers[5].sequence = landing_activity
                record.layers[5].cycle = 0.0
                animstate.in_hit_ground_animation = true
            end
        end
    end

    if e:get_move_type() ~= 9 then
        if record.layers[5].weight > 0.0 then
            local v175 = (animstate.time_since_in_air - 0.2) * -5.0
            v175 = math.clamp(v175, 0.0, 1.0)
            local newlayer5_weight = ((3.0 - (v175 + v175)) * (v175 * v175)) * record.layers[5].weight
            record.layers[5].weight = newlayer5_weight
        end
    end

    if previous_record then
        local animlayers = e:get_anim_layers()
        e:set_anim_layers(previous_record.layers)
        local ticks_chocked = 1
        -- // local simulation_ticks = globals.time_to_ticks(e:get_prop("m_flSimulationTime") - previous_record.simulation_time)
        -- // if simulation_ticks > 0 and simulation_ticks < 17 then ticks_chocked = simulation_ticks end

        if ticks_chocked > 1 then
            local land_time = 0.0
            local land_in_cycle = false
            local is_landed = false
            local on_ground = false
            if animlayers[4].cycle < 0.5 and (bit.band(e:get_prop("m_fFlags"), 1) == 0 or bit.band(previous_record.flags, 1) == 0) then
                land_time = e:get_prop("m_flSimulationTime") - animlayers[4].playback_rate * animlayers[4].cycle
                land_in_cycle = land_time >= previous_record.simulation_time
            end

            local duck_amount_per_tick = (e:get_prop("m_flDuckAmount") - previous_record.duck_amount) / ticks_chocked

            for i=0, ticks_chocked-1 do
                local simulated_time = previous_record.simulation_time + globals.ticks_to_time(i)
                if duck_amount_per_tick then
                    local v208 = ((record.duck_amount - e:get_prop("m_flDuckAmount")) * duck_amount_per_tick) + e:get_prop("m_flDuckAmount")
                    e:set_prop("m_flDuckAmount", math.clamp(v208, 0.0, 1.0))
                end

                on_ground = bit.band(e:get_prop("m_fFlags"), 1) ~= 0
                if land_in_cycle and not is_landed then
                    if land_time <= simulated_time then
                        is_landed = true
                        on_ground = true
                    else
                        on_ground = bit.band(previous_record.flags, 1) ~= 0
                    end
                end

                if on_ground then
                    e:set_prop("m_fFlags", bit.bor(e:get_prop("m_fFlags"), 1))
                else
                    e:set_prop("m_fFlags", bit.band(e:get_prop("m_fFlags"), bit.bnot(1)))
                end

                local simulated_ticks = globals.time_to_ticks(simulated_time)
                globals.set_realtime(simulated_time)
                globals.set_curtime(simulated_time)
                globals.set_framecount(simulated_ticks)
                globals.set_tickcount(simulated_ticks)
                globals.set_interpolation_amount(0.0)

                e:update_client_animations()

                globals.set_realtime(backup_realtime)
                globals.set_curtime(backup_curtime)
                globals.set_framecount(backup_framecount)
                globals.set_tickcount(backup_tickcount)
                globals.set_interpolation_amount(backup_interpolation_amount)

                updated_animations = true
            end
        end
    end

    if not updated_animations then
        e:update_client_animations()
    end

    
    for k,v in pairs(state) do animstate[k] = v end

    local function setup_matrix(e, layers, matrix)
        e:invalidate_physics_recursive(8)
        local backup_layers = e:get_anim_layers()
        e:set_anim_layers(layers)

        if matrix == "MAIN" then
            e:setup_bones(record.matrixes_data.main, "BONE_USED_BY_ANYTHING") -- Assume API
        elseif matrix == "NONE" then
            e:setup_bones(record.matrixes_data.zero, "BONE_USED_BY_HITBOX")
        elseif matrix == "FIRST" then
            e:setup_bones(record.matrixes_data.first, "BONE_USED_BY_HITBOX")
        elseif matrix == "SECOND" then
            e:setup_bones(record.matrixes_data.second, "BONE_USED_BY_HITBOX")
        end

        e:set_anim_layers(backup_layers)
    end

    if not player_info.bot and entity.get_local_player():is_alive() and e:get_prop("m_iTeamNum") ~= entity.get_local_player():get_prop("m_iTeamNum") then
        animstate.goal_feet_yaw = previous_goal_feet_yaw[e:get_prop("m_iIndex")]
        e:update_client_animations()
        previous_goal_feet_yaw[e:get_prop("m_iIndex")] = animstate.goal_feet_yaw

        for k,v in pairs(state) do animstate[k] = v end
        animstate.goal_feet_yaw = normalize_yaw(e:get_prop("m_angEyeAngles").y)
        e:update_client_animations()
        setup_matrix(e, player_resolver[e:get_prop("m_iIndex")].resolver_layers[1], "NONE") -- Adjust indices

        for k,v in pairs(state) do animstate[k] = v end
        animstate.goal_feet_yaw = normalize_yaw(e:get_prop("m_angEyeAngles").y + 60.0)
        e:update_client_animations()
        setup_matrix(e, player_resolver[e:get_prop("m_iIndex")].resolver_layers[3], "FIRST")

        for k,v in pairs(state) do animstate[k] = v end
        animstate.goal_feet_yaw = normalize_yaw(e:get_prop("m_angEyeAngles").y - 60.0)
        e:update_client_animations()
        setup_matrix(e, player_resolver[e:get_prop("m_iIndex")].resolver_layers[2], "SECOND")

        for k,v in pairs(state) do animstate[k] = v end

        player_resolver[e:get_prop("m_iIndex")]:initialize(e, record, previous_goal_feet_yaw[e:get_prop("m_iIndex")], e:get_prop("m_angEyeAngles").x, previous_record)
    end

    e:update_client_animations()
    setup_matrix(e, animlayers, "MAIN")



    globals.set_curtime(backup_curtime)
    globals.set_frametime(backup_frametime)

    e:set_prop("m_flLowerBodyYawTarget", backup_lower_body_yaw_target)
    e:set_prop("m_flDuckAmount", backup_duck_amount)
    e:set_prop("m_fFlags", backup_flags)
    e:set_prop("m_iEFlags", backup_eflags)
    e:set_anim_layers(animlayers)
    player_resolver[e:get_prop("m_iIndex")].previous_layers = animlayers
    player_resolver[e:get_prop("m_iIndex")].resolver_layers = animlayers

    record:store_data(e, false)
    if e:get_prop("m_flSimulationTime") < e:get_prop("m_flOldSimulationTime") then
        record.invalid = true
    end
end

function lagcompensation:FixPvs(pCurEntity)
    if not ui.get(enable_resolver) then return end
    if pCurEntity == entity.get_local_player() then return end
    if not pCurEntity or not pCurEntity:is_player() or pCurEntity:get_prop("m_iIndex") == client.local_player_index() then return end

    pCurEntity:set_prop("m_iOcclusionFrame", globals.framecount())
    pCurEntity:set_prop("m_iOcclusionFlags", 0)
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
local ui_duration = ui.new_slider("LUA", "A", "Duration (sec)", 1, 10, 4, true, "s", 0.1)
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

local enable = ui.checkbox("LUA", "A", "Defensive Fix")

local sides = {}
local default_rates = {left = 0.6875, right = -0.6875, low_left = 0.34375, center = 0.0}
local resolved_side = {}

client.set_event_callback(
    "player_spawn",
    function(e)
        if not enable[2] then
            return
        end
        local ent = client.userid_to_entindex(e.userid)
        if not ent then
            return
        end

        local lp = entity.get_local_player()
        if not lp or ent == lp then
            return
        end
        if entity.get_prop(lp, "m_iTeamNum") == entity.get_prop(ent, "m_iTeamNum") then
            return
        end

        sides[ent] = sides[ent] or {}
        local layers = entity.get_anim_layers(ent)
        if not layers or layers[12].weight > 0.01 then
            return
        end

        local rate = layers[6].playback_rate
        if math.abs(rate - 0.6875) < 0.01 then
            sides[ent].left = rate
        elseif math.abs(rate + 0.6875) < 0.01 then
            sides[ent].right = rate
        elseif math.abs(rate - 0.34375) < 0.01 then
            sides[ent].low_left = rate
        elseif math.abs(rate) < 0.05 then
            sides[ent].center = rate
        end
    end
)

client.set_event_callback(
    "net_update_end",
    function()
        if not enable[2] then
            return
        end

        local lp = entity.get_local_player()
        if not lp then
            return
        end

        local enemies = entity.get_players(true)
        for i = 1, #enemies do
            local ent = enemies[i]
            if not ent or not entity.is_alive(ent) or entity.is_dormant(ent) then
                goto next
            end
            if bit.band(entity.get_prop(ent, "m_fFlags"), 1) == 0 then
                goto next
            end
            if (entity.get_prop(ent, "m_iShotsFired") or 0) > 0 then
                goto next
            end

            local vx = entity.get_prop(ent, "m_vecVelocity[0]") or 0
            local vy = entity.get_prop(ent, "m_vecVelocity[1]") or 0
            local speed = math.sqrt(vx * vx + vy * vy)

            local updated = false
            local side = 0

            if speed > 20 then
                local yaw = math.deg(math.atan2(vy, vx))
                if math.abs(yaw) < 1 or math.abs(math.abs(yaw) - 180) < 1 then
                    local layers = entity.get_anim_layers(ent)
                    if layers then
                        local can_solve = false
                        if layers[12].weight * 1000 > 0 then
                            local prev = entity.get_anim_layers(ent, true) or layers
                            can_solve = math.floor(layers[6].weight * 1000) == math.floor(prev[6].weight * 1000)
                        end

                        if can_solve then
                            local rate = layers[6].playback_rate
                            local s = sides[ent] or {}

                            local dl = math.abs(rate - (s.left or default_rates.left))
                            local dr = math.abs(rate - (s.right or default_rates.right))
                            local dlow = math.abs(rate - (s.low_left or default_rates.low_left))
                            local dc = math.abs(rate - (s.center or default_rates.center))

                            local best = dc
                            updated = true

                            if not (dlow * 1000 > 0 and dc < dlow) then
                                side = 3
                                best = dlow
                            end
                            if dl * 1000 == 0 and best >= dl then
                                side = 1
                                best = dl
                            end
                            if dr * 1000 == 0 and best >= dr then
                                resolved_side[ent] = "right"
                                client.exec("cl_yawspeed 0")
                                client.exec("cl_yawspeed 2100")
                                goto next
                            end
                        end
                    end
                end
            end

            if updated then
                if side == 1 or side == 3 then
                    resolved_side[ent] = (side == 1 and "left" or "low_left")
                    client.exec("cl_yawspeed 0")
                    client.exec("cl_yawspeed 2100")
                else
                    resolved_side[ent] = "center"
                    client.exec("cl_yawspeed 0")
                end
            else
                resolved_side[ent] = "center"
                client.exec("cl_yawspeed 0")
            end

            ::next::
        end
    end
)


