_addon.name = 'hovertracker'
_addon.author = 'Kunel (Keramas)'
_addon.version = '1.1'
_addon.commands = {'hovertracker', 'ht'}

require('logger')
texts = require('texts')
config = require('config')
local res = require('resources')

------------------------------------------------------------------------------------
-- Variable defining and table initialization
------------------------------------------------------------------------------------
local debug = false

local hovershotJAID = res.job_abilities:with('en','Hover Shot').id
local hovershotBuffID = res.buffs:with('en','Hover Shot').id

local hover_shot = {
    stacks = 0,
    last_pos = nil,
    reference_pos = nil, 
    last_target_id = nil,
    max_stacks = 25,
    active = false,
    moved_last_check = nil
}

local settings = config.load({
    display = {
        pos = {x = 100, y = 200},
        bg = {alpha = 200, red = 0, green = 0, blue = 0},
        text = {size = 12, font = 'Arial', red = 255, green = 255, blue = 255},
        visible = true
    }
})

local display = texts.new(settings.display)

local last_position_check_time = 0
local last_known_pos = {x=0, y=0}

local MOVEMENT_THRESHOLD = 0.9 -- Grace buffer. Can be modified as needed for latency compensation.

------------------------------------------------------------------------------------
-- Core functions
------------------------------------------------------------------------------------
function get_player_pos()
    local me = windower.ffxi.get_mob_by_index(windower.ffxi.get_player().index)
    if me and me.x and me.y then
        return {x = me.x, y = me.y}
    end
    return {x = 0, y = 0}
end

function get_distance(p1, p2)
    if not p1 or not p2 then return 999 end
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    return math.sqrt(dx * dx + dy * dy)
end

function reset_hover()
    hover_shot.stacks = 0
    hover_shot.last_pos = nil
    hover_shot.reference_pos = nil
    hover_shot.last_target_id = nil
    hover_shot.moved_last_check = nil
    update_display()
end

function update_display()
    if not hover_shot.active then
        display:hide()
        return
    end

    -- Set text color based on movement
    if hover_shot.moved_last_check == true then
        display:bg_color(0, 0, 0)
        display:color(0, 255, 0) -- Green if distance moved is proper to gain a stack
    elseif hover_shot.moved_last_check == false then
        display:bg_color(0, 0, 0)
        display:color(255, 0, 0) -- Red if distance moved will reset stacks 
    else
        display:bg_color(0, 0, 0)
        display:color(255, 255, 255) -- White (default)
    end

    display:text(string.format('Hover Shot: %d/%d', hover_shot.stacks, hover_shot.max_stacks))
    display:show()
end

function initialize()
    if not windower.ffxi.get_info().logged_in then
        return
    end
    hovershotBuff = S(windower.ffxi.get_player().buffs):contains(hovershotBuffID)

    last_known_pos = get_player_pos()
end

--------------------------------------------------------------------------------
-- Windower Event Hooks
--------------------------------------------------------------------------------
windower.register_event('login', initialize)
windower.register_event('logout', function()
    hovershotBuff = false
    lastReportedPosition = nil
    stacks = 0
    display:hide()
end)

windower.register_event('gain buff', function(buff_id)
    if buff_id == hovershotBuffID then
        hovershotBuff = true
        lastReportedPosition = nil
        stacks = 0
        display:hide()
    end
end)

windower.register_event('lose buff', function(buff_id)
    if buff_id == hovershotBuffID then
        hovershotBuff = false
        lastReportedPosition = nil
        stacks = 0
        display:hide()
    end
end)

windower.register_event('zone change', function(buff_id)
    hovershotBuff = false
    lastReportedPosition = nil
    stacks = 0
    display:hide()
end)

windower.register_event('action', function(act)
    local player = windower.ffxi.get_player()
    if not player then return end

    -- Ensure the action was performed by the player
    if act.actor_id == player.id then
        local cat = act.category or 'nil'
        local msg = tonumber((act.targets and act.targets[1] and act.targets[1].actions and act.targets[1].actions[1].message) or 0)

    end
    
    -- Ranged Attack (2) or Weaponskill (3)
    if act.category ~= 2 and act.category ~= 3 then return end

    -- Confirm Hover Shot is active
    if not hovershotBuff then 
        if hover_shot.stacks > 0 then
            if debug then 
                windower.add_to_chat(207,'[HoverTrack] Hover Shot expired. Resetting stacks.')
            end
            reset_hover()
        end
        hover_shot.active = false
        update_display()
        return
    end

    hover_shot.active = true

    local target = act.targets and act.targets[1]
    local action = target and target.actions and target.actions[1]
    if not action then return end

    local msg_id = action.message

    local hit_messages = S{
        185, 187,        -- Ranged attack hit / crit
        234, 236,        -- WS normal hit
        352, 353,        -- WS crits
        206, 209,        -- Magic WS hits
        264, 265,        -- Additional WS hits
        576, 577         -- Square and true shot hits
    }

    if not hit_messages:contains(action.message) then
        if debug then
            windower.add_to_chat(207,'[HoverTrack] Shot missed! No stack granted. Do not move back to original position!')
        end
        return
    end

    -- Check for target switch
    if hover_shot.last_target_id and hover_shot.last_target_id ~= target.id then
        reset_hover()
    end
    hover_shot.last_target_id = target.id

    -- Check player movement
    local current_pos = get_player_pos()
    local moved = get_distance(hover_shot.last_pos, current_pos)

    if not hover_shot.last_pos or moved >= MOVEMENT_THRESHOLD then
        hover_shot.moved_last_check = true
        if hover_shot.stacks < hover_shot.max_stacks then
            hover_shot.stacks = hover_shot.stacks + 1
            if debug then
                windower.add_to_chat(207,'[HoverTrack] Hover Shot stack increased to: ' .. hover_shot.stacks)
            end
        end
    else
        hover_shot.moved_last_check = false
        hover_shot.stacks = 1
        if debug then
            windower.add_to_chat(207,'[HoverTrack] Only moved ' .. string.format('%.2f', moved) .. ' yalms. Stacks reset!')
        end
    end

    hover_shot.last_pos = current_pos
    hover_shot.reference_pos = current_pos
    
    update_display()
end)



windower.register_event('prerender', function()
    if not hover_shot.active or not hover_shot.reference_pos then return end

    local current_pos = get_player_pos()
    local moved = get_distance(hover_shot.reference_pos, current_pos)

    local previous_movement_state = hover_shot.moved_last_check

    if moved >= 1 then
        hover_shot.moved_last_check = true
    else
        hover_shot.moved_last_check = false
    end

    -- Only update display if movement state changed
    if hover_shot.moved_last_check ~= previous_movement_state then
        update_display()
    end
end)

windower.register_event('prerender', function()

    local now = os.clock()
    if now - last_position_check_time > 0.1 then
        last_known_pos - get_player_pos()
        last_position_check_time = now
    end
end)



windower.register_event('addon command', function(cmd)
    cmd = cmd and cmd:lower()
    if cmd == 'reset' then
        log('Manual reset.')
        reset_hover()
    elseif cmd == 'show' then
        hover_shot.active = true
        update_display()
    elseif cmd == 'hide' then
        hover_shot.active = false
        update_display()
    elseif cmd == 'debug' then
        debug = true
    else
        log('Commands: reset | show | hide | debug')
    end
end)
----------------------------------------------------------------------------------

initialize()