local entity = require "gamesense/entity"
local ui = require "pui"
local bit = require "bit"

local enable = ui.checkbox("RAGE", "Other", "Resolver")

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

client.color_log(0, 255, 150, "[resolver] HVH RIP by HELLPINE.XYZ")
