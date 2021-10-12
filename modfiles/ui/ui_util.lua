ui_util = {
    context = {},
    switch = {}
}

local gui = require("__flib__.gui")

-- ** GUI **
-- Properly centers the given frame (need width/height parameters cause no API-read exists)
function ui_util.properly_center_frame(player, frame, dimensions)
    local resolution, scale = player.display_resolution, player.display_scale
    local x_offset = ((resolution.width - (dimensions.width * scale)) / 2)
    local y_offset = ((resolution.height - (dimensions.height * scale)) / 2)
    frame.location = {x_offset, y_offset}
end

function ui_util.setup_textfield(textfield)
    textfield.lose_focus_on_confirm = true
    textfield.clear_and_focus_on_right_click = true
end

function ui_util.setup_numeric_textfield(textfield, decimal, negative)
    textfield.lose_focus_on_confirm = true
    textfield.clear_and_focus_on_right_click = true
    textfield.numeric = true
    textfield.allow_decimal = (decimal or false)
    textfield.allow_negative = (negative or false)
end

function ui_util.select_all(textfield)
    textfield.focus()
    textfield.select_all()
end

local mod_gui = require("mod-gui")

-- Toggles the visibility of the toggle-main-dialog-button
function ui_util.toggle_mod_gui(player)
    local enable = data_util.get("settings", player).show_gui_button

    local frame_flow = mod_gui.get_button_flow(player)
    local mod_gui_button = frame_flow["fp_button_toggle_interface"]

    if enable then
        if not mod_gui_button then
            frame_flow.add{type="button", name="fp_button_toggle_interface", caption={"fp.toggle_interface"},
              tooltip={"fp.toggle_interface_tt"}, tags={mod="fp", on_gui_click="mod_gui_toggle_interface"},
              style=mod_gui.button_style, mouse_button_filter={"left"}}
        end
    else
        if mod_gui_button then mod_gui_button.destroy() end
    end
end


-- ** MISC **
function ui_util.generate_tutorial_tooltip(player, element_type, has_alt_action, add_padding, avoid_archive)
    local player_table = data_util.get("table", player)

    local archive_check = (avoid_archive and player_table.ui_state.flags.archive_open)
    if player_table.preferences.tutorial_mode and not archive_check and element_type then
        local action_tooltip = {"fp.tut_mode_" .. element_type}

        local alt_action_name, alt_action_tooltip = player_table.settings.alt_action, ""
        if has_alt_action and alt_action_name ~= "none" then
            alt_action_tooltip = {"fp.tut_mode_alt_action", {"fp.alt_action_" .. alt_action_name}}
        end

        local padding = (add_padding) and {"fp.tut_mode_tooltip_padding"} or ""
        return {"fp.tut_mode_tooltip", padding, action_tooltip, alt_action_tooltip}
    else
        return ""
    end
end

function ui_util.check_archive_status(player)
    if data_util.get("flags", player).archive_open then
        title_bar.enqueue_message(player, {"fp.error_editing_archived_subfactory"}, "error", 1, true)
        return false
    else
        return true
    end
end


-- ** Number formatting **
-- Formats given number to given number of significant digits
function ui_util.format_number(number, precision)
    if number == nil then return nil end

    -- To avoid scientific notation, chop off the decimals points for big numbers
    if (number / (10 ^ precision)) >= 1 then
        return ("%d"):format(number)
    else
        -- Set very small numbers to 0
        if number < (0.1 ^ precision) then
            number = 0

        -- Decrease significant digits for every zero after the decimal point
        -- This keeps the number of digits after the decimal point constant
        elseif number < 1 then
            local n = number
            while n < 1 do
                precision = precision - 1
                n = n * 10
            end
        end

        -- Show the number in the shortest possible way
        return ("%." .. precision .. "g"):format(number)
    end
end

-- Returns string representing the given power
function ui_util.format_SI_value(value, unit, precision)
    local prefixes = {"", "kilo", "mega", "giga", "tera", "peta", "exa", "zetta", "yotta"}
    local units = {
        ["W"] = {"fp.unit_watt"},
        ["J"] = {"fp.unit_joule"},
        ["P/m"] = {"", {"fp.unit_pollution"}, "/", {"fp.unit_minute"}}
    }

    local sign = (value >= 0) and "" or "-"
    value = math.abs(value) or 0

    local scale_counter = 0
    -- Determine unit of the energy consumption, while keeping the result above 1 (ie no 0.1kW, but 100W)
    while scale_counter < #prefixes and value > (1000 ^ (scale_counter + 1)) do
        scale_counter = scale_counter + 1
    end

    -- Round up if energy consumption is close to the next tier
    if (value / (1000 ^ scale_counter)) > 999 then
        scale_counter = scale_counter + 1
    end

    value = value / (1000 ^ scale_counter)
    local prefix = (scale_counter == 0) and "" or {"fp.prefix_" .. prefixes[scale_counter + 1]}
    return {"", sign .. ui_util.format_number(value, precision) .. " ", prefix, units[unit]}
end



-- **** Context ****
-- Creates a blank context referencing which part of the Factory is currently displayed
function ui_util.context.create(player)
    return {
        factory = global.players[player.index].factory,
        subfactory = nil,
        floor = nil
    }
end

-- Updates the context to match the newly selected factory
function ui_util.context.set_factory(player, factory)
    local context = data_util.get("context", player)
    context.factory = factory
    local subfactory = factory.selected_subfactory or
      Factory.get_by_gui_position(factory, "Subfactory", 1)  -- might be nil
    ui_util.context.set_subfactory(player, subfactory)
end

-- Updates the context to match the newly selected subfactory
function ui_util.context.set_subfactory(player, subfactory)
    local context = data_util.get("context", player)
    context.factory.selected_subfactory = subfactory
    context.subfactory = subfactory
    context.floor = (subfactory ~= nil) and subfactory.selected_floor or nil
end

-- Updates the context to match the newly selected floor
function ui_util.context.set_floor(player, floor)
    local context = data_util.get("context", player)
    context.subfactory.selected_floor = floor
    context.floor = floor
end


-- **** Switch utility ****
-- Adds an on/off-switch including a label with tooltip to the given flow
-- Automatically converts boolean state to the appropriate switch_state
function ui_util.switch.add_on_off(parent_flow, action, additional_tags, state, caption, tooltip, label_first)
    if type(state) == "boolean" then state = ui_util.switch.convert_to_state(state) end

    local flow = parent_flow.add{type="flow", direction="horizontal"}
    flow.style.vertical_align = "center"
    local switch, label

    local function add_switch()
        local tags = {mod="fp", on_gui_switch_state_changed=action}
        for key, value in pairs(additional_tags) do tags[key] = value end
        switch = flow.add{type="switch", tags=tags, switch_state=state,
          left_label_caption={"fp.on"}, right_label_caption={"fp.off"}}
    end

    local function add_label()
        caption = (tooltip ~= nil) and {"", caption, " [img=info]"} or caption
        label = flow.add{type="label", caption=caption, tooltip=tooltip}
        label.style.font = "default-semibold"
    end

    if label_first then add_label(); add_switch(); label.style.right_margin = 8
    else add_switch(); add_label(); label.style.left_margin = 8 end

    return switch
end

function ui_util.switch.convert_to_boolean(state)
    return (state == "left") and true or false
end

function ui_util.switch.convert_to_state(boolean)
    return boolean and "left" or "right"
end

-- I want to use coroutine.
function ui_util.visit_gui_elements(context)
    local element_stack = {context}
    local index_stack = {1}
    function it()
        local top = #element_stack
        if top == 0 then
            return nil
        end

        local current = element_stack[top]
        local children = current.children
        local index = index_stack[top]
        index_stack[top] = index + 1

        if #children >= index then
            local n = children[index]
            if n.name == "" then
                table.insert(element_stack, n)
                table.insert(index_stack, 1)
            end
            return n.index, n
        else
            table.remove(element_stack)
            table.remove(index_stack)
            return it()
        end
    end
    return it
end

function ui_util.get_gui_element(context, find_name, ...)
    if not find_name then
        return context
    end

    for _, e in ui_util.visit_gui_elements(context) do
        if e.name == find_name then
            return ui_util.get_gui_element(e, ...)
        end
    end
    error(string.format("Can't find an element named %q.", find_name))
end

function ui_util.get_super_gui_element(context, find_name)
    local e = context
    while e do
        if e.name == find_name then
            return e
        end
        e = e.parent
    end
    error(string.format("Can't find an element named %q.", find_name))
end

-- function ui_util.create_gui_placeholder(key)
--     local meta = {__placeholder = key}
--     local ret = {}
--     setmetatable(ret, meta)
--     return ret
-- end

-- local function preprocess_gui_placeholder(defines)
--     local ret = {}
--     for k, v in pairs(defines) do
--         if type(k) == "string" then
--             local meta = getmetatable(v)
--             if meta and meta.__placeholder then
--                 ret[k] = meta.__placeholder
--                 defines[k] = nil
--             elseif type(v) == "table" then
--                 ret[k] = preprocess_gui_placeholder(v)
--             end
--         end
--     end
--     return (table_size(ret) > 0) and ret or nil
-- end

ui_util.gui_handlers = {}

function ui_util.register_handler(event_name, handler_id, handler)
    assert(game == nil, "register_handler() needs to be called during initialization stage.")
    assert(handler_id, "To register, either handler_id or name is required.")
    assert(type(handler) == "function", string.format("%s handler for id %q is not function.", event_name, handler_id))

    local actual_handlers_id = event_name.."@"..handler_id
    assert(not ui_util.gui_handlers[handler_id], string.format("Id %q has already been registered with %s handler.", handler_id, event_name))
    ui_util.gui_handlers[actual_handlers_id] = handler
    return actual_handlers_id
end

function ui_util.preprocess_gui_defines(handlers_id_prefix, defines)
    assert(game == nil, "preprocess_gui_defines() needs to be called during initialization stage.")

    if type(handlers_id_prefix) == "table" then
        defines = handlers_id_prefix
        handlers_id_prefix = nil
    end

    -- local placeholder_map = preprocess_gui_placeholder(defines)
    -- local tags = defines.tags or {}
    -- tags.__placeholder_map = placeholder_map
    -- defines.tags = tags

    local handlers_id = defines.handlers_id or defines.name
    if handlers_id_prefix then
        if handlers_id then
            handlers_id = handlers_id_prefix.."::"..handlers_id
        else            
            handlers_id = handlers_id_prefix
        end
    end

    local actions = defines.actions or {}
    for event_name, handler in pairs(actions) do
        actions[event_name] = ui_util.register_handler(event_name, handlers_id, handler)
    end

    for _, v in ipairs(defines) do
        ui_util.preprocess_gui_defines(handlers_id, v)
    end

    return defines
end

-- function ui_util.inject_value_into_gui_placeholder(preprocessd_defines, inject_map)
--     local function impl(current, placeholder_map)
--         placeholder_map = (current.tags or {}).__placeholder_map or placeholder_map or {}
--         for k, v in pairs(placeholder_map) do
--             if type(v) == "table" then
--                 impl(current[k], v)
--             elseif type(v) == "string" then
--                 current[k] = inject_map[v] or current[k]
--             else
--                 assert()
--             end
--         end
--     end

--     local ret = table.deep_copy(preprocessd_defines)
--     impl(ret)
--     return ret
-- end

function ui_util.dispatch_gui_event(event)
    local element = event.element or (ui_util.get_player(event.player_index) or {}).opened
    event.element = element
    if not element then return false end

    local event_name = event.input_name or event.name
    local handler_id = gui.read_action(event) or gui.get_action(element, event_name)
    if not handler_id then return false end

    local handler = ui_util.gui_handlers[handler_id]
    if not handler then return false end

    handler(event)
    return true
end

function ui_util.recursive_dispatch_gui_event(event)
    local element = event.element or (ui_util.get_player(event.player_index) or {}).opened
    assert(element)

    event.element = element
    ui_util.dispatch_gui_event(event)
    for _, next_element in ipairs(element.children) do
        event.element = next_element
        ui_util.recursive_dispatch_gui_event(event)
    end
end

function ui_util.reverse_recursive_dispatch_gui_event(event)
    local element = event.element or (ui_util.get_player(event.player_index) or {}).opened
    assert(element)

    for _, next_element in ipairs(element.children) do
        event.element = next_element
        ui_util.reverse_recursive_dispatch_gui_event(event)
    end
    event.element = element
    ui_util.dispatch_gui_event(event)
end

function ui_util.get_player(indicates_player)
    return (type(indicates_player) == "table") and indicates_player or game.get_player(indicates_player)
end

return ui_util