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
local last_known_pos = {x = 0, y = 0}

local MOVEMENT_THRESHOLD = 0.9 -- Grace buffer. Can be modified as needed for latency compensation.

------------------------------------------------------------------------------------
-- Core functions
------------------------------------------------------------------------------------
function get_player_pos()
    local info = windower.ffxi.get_info()
    if not info.logged_in or info.loading then
        return nil
    end
    local player = windower.ffxi.get_player()
    if not player then return nil end
    local me = windower.ffxi.get_mob_by_index(player.index)
    if me and me.x and me.y then
        return {x = me.x, y = me.y}
    end
    return nil
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
    if hover_shot.moved_last_check == true then
        display:bg_color(0, 0, 0)
        display:color(0, 255, 0)
    elseif hover_shot.moved_last_check == false then
        display:bg_color(0, 0, 0)
        display:color(255, 0, 0)
    else
        display:bg_color(0, 0, 0)
        display:color(255, 255, 255)
    end
    display:text(string.format('Hover Shot: %d/%d', hover_shot.stacks, hover_shot.max_stacks))
    display:show()
end

function initialize()
    if not windower.ffxi.get_info().logged_in then return end
    hovershotBuff = S(windower.ffxi.get_player().buffs):contains(hovershotBuffID)
    local pos = get_player_pos()
    if pos then
        last_known_pos = pos
    end
end

------------------------------------------------------------------------------------
-- Windower Event Hooks
------------------------------------------------------------------------------------
windower.register_event('login', initialize)

windower.register_event('logout', function()
    hovershotBuff = false
    hover_shot.stacks = 0
    hover_shot.last_pos = nil
    hover_shot.reference_pos = nil
    hover_shot.last_target_id = nil
    hover_shot.active = false
    display:hide()
end)

windower.register_event('gain buff', function(buff_id)
    if buff_id == hovershotBuffID then
        hovershotBuff = true
        reset_hover()
        display:hide()
    end
end)

windower.register_event('lose buff', function(buff_id)
    if buff_id == hovershotBuffID then
        hovershotBuff = false
        reset_hover()
        display:hide()
    end
end)

windower.register_event('zone change', function()
    hovershotBuff = false
    reset_hover()
    display:hide()
end)

windower.register_event('action', function(act)
    local player = windower.ffxi.get_player()
    if not player then return end
    if act.actor_id ~= player.id then return end
    if act.category ~= 2 and act.category ~= 3 then return end
    if not hovershotBuff then
        if hover_shot.stacks > 0 then reset_hover() end
        hover_shot.active = false
        update_display()
        return
    end

    hover_shot.active = true

    local target = act.targets and act.targets[1]
    local action = target and target.actions and target.actions[1]
    if not action then return end

    local hit_messages = S{185,187,234,236,352,353,206,209,264,265,576,577}
    if not hit_messages:contains(action.message) then return end

    if hover_shot.last_target_id and hover_shot.last_target_id ~= target.id then
        reset_hover()
    end
    hover_shot.last_target_id = target.id

    local current_pos = get_player_pos()
    if not current_pos then return end

    local moved = get_distance(hover_shot.last_pos, current_pos)
    if not hover_shot.last_pos or moved >= MOVEMENT_THRESHOLD then
        hover_shot.moved_last_check = true
        if hover_shot.stacks < hover_shot.max_stacks then
            hover_shot.stacks = hover_shot.stacks + 1
        end
    else
        hover_shot.moved_last_check = false
        hover_shot.stacks = 1
    end

    hover_shot.last_pos = current_pos
    hover_shot.reference_pos = current_pos
    update_display()
end)

windower.register_event('prerender', function()
    if not hover_shot.active or not hover_shot.reference_pos then return end
    local current_pos = get_player_pos()
    if not current_pos then return end
    local moved = get_distance(hover_shot.reference_pos, current_pos)
    local previous_movement_state = hover_shot.moved_last_check
    hover_shot.moved_last_check = (moved >= 1)
    if hover_shot.moved_last_check ~= previous_movement_state then
        update_display()
    end
end)

windower.register_event('prerender', function()
    local now = os.clock()
    if now - last_position_check_time > 0.1 then
        local pos = get_player_pos()
        if pos then
            last_known_pos = pos
        end
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
    else
        log('Commands: reset | show | hide')
    end
end)

initialize()