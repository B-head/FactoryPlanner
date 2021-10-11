local M = {}

local gui = require("__flib__.gui")
local modal_dialog = require("ui.dialogs.modal_dialog")
local ui_util = require("ui.ui_util")

local function close_window(event)
    local window = M.get_window_element(event.element)
    M.exit(event.player_index, window)
end

local function recenter_window(event)
    -- No description of this feature.
    if event.button == defines.mouse_button_type.middle then
        local window = M.get_window_element(event.element)
        window.force_auto_center()
    end
end

function M.toggle_searchfield(element, set_visible)
    local window = M.get_window_element(element)
    local search_field = window.title_bar.search_field
    local search_button = window.title_bar.search_button

    search_field.visible = set_visible or not search_field.visible
    if search_field.visible then
        search_field.focus()

        search_button.style = "flib_selected_frame_action_button"
        search_button.sprite = "utility/search_black"
    else
        search_field.text = ""

        search_button.style = "frame_action_button"
        search_button.sprite = "utility/search_white"
    end
end

function M.create_window_defines(params)
    local actions = params.actions
    return ui_util.preprocess_gui_defines{
        type = "frame",
        name = params.name,
        direction = "vertical",
        tags = {
            __is_fp_window = true,
        },
        style_mods = {
            -- If there is a delete button present, we need to set a minimum dialog width for it to look good
            minimal_width = params.allow_delete and 340 or 240,
            -- maximal_height = (data_util.get("ui_state", player).main_dialog_dimensions.height - 80) * 0.95,
        },
        elem_mods = {
            auto_center = params.auto_center,
        },
        actions = table.shallow_merge{actions, {
            on_closed = close_window,
            fp_confirm_dialog = actions.on_confirm,

            fp_focus_searchfield = function(event)
                M.toggle_searchfield(event.element, true)
            end,
        }},

        {
            type = "flow",
            name = "title_bar",
            direction = "horizontal",
            visible = params.type ~= "compact",
            actions = {
                on_click = recenter_window,
            },

            {
                type = "label",
                name = "title",
                caption = params.title,
                ignored_by_interaction = true,
                style = "frame_title",
            },
            {
                type = "empty-widget",
                name = "drag_handle",
                ignored_by_interaction = true,
                visible = params.draggable or true,
                style = "flib_titlebar_drag_handle",
            },
            {
                type = "textfield",
                name = "search_field",
                visible = false,
                clear_and_focus_on_right_click = true,
                style = "search_popup_textfield",
                style_mods = {
                    width = 140,
                    top_margin = -3,
                },
                actions = {
                    on_text_changed = actions.on_search,
                },
            },
            {
                type = "sprite-button",
                name = "search_button",
                tooltip = {"fp.search_button_tt"},
                visible = params.allow_search or false,
                mouse_button_filter = {"left"},
                sprite = "utility/search_white",
                hovered_sprite = "utility/search_black",
                clicked_sprite = "utility/search_black",
                style = "frame_action_button",
                style_mods = {
                    left_margin = 4,
                },
                actions = {
                    on_click = function(event)
                        M.toggle_searchfield(event.element)
                    end,
                },
            },
            {
                type = "sprite-button",
                name = "close_button",
                tooltip = {"fp.close_button_tt"},
                visible = params.type == "standard",
                mouse_button_filter = {"left"},
                sprite = "utility/close_white",
                hovered_sprite = "utility/close_black",
                clicked_sprite = "utility/close_black",
                style = "frame_action_button",
                style_mods = {
                    left_margin = 4,
                    padding = 1,
                },
                actions = {
                    on_click = close_window,
                },
            },
        },
        
        params.content,
        
        {
            type = "flow",
            name = "button_bar",
            direction = "horizontal",
            visible = params.type == "dialog",
            style = "dialog_buttons_horizontal_flow",
            style_mods = {
                horizontal_spacing = 0,
            },
            
            {
                type = "button",
                name = "back_button",
                caption = {"fp.cancel"},
                tooltip = {"fp.cancel_dialog_tt"},
                mouse_button_filter = {"left"},
                style = "back_button",
                style_mods = {
                    minimal_width = 0,
                    padding = {1, 12, 0, 12},
                },
                actions = {
                    on_click = close_window,
                },
            },
            {
                type = "empty-widget",
                name = "left_drag_handle",
                visible = (params.draggable or true) and (params.allow_delete or false),
                style = "flib_dialog_footer_drag_handle",
            },
            {
                type = "button",
                name = "red_button",
                caption = {"fp.delete"},
                visible = params.allow_delete or false,
                mouse_button_filter = {"left"},
                style = "red_button",
                style_mods = {
                    font = "default-dialog-button",
                    height = 32,
                    minimal_width = 0,
                    padding = {0, 8},
                },
                actions = {
                    on_click = actions.on_delete,
                },
            },
            {
                type = "empty-widget",
                name = "right_drag_handle",
                visible = params.draggable or true,
                style = "flib_dialog_footer_drag_handle",
            },
            {
                type = "button",
                name = "confirm_button",
                caption = {"fp.submit"},
                tooltip = {"fp.confirm_dialog_tt"},
                mouse_button_filter = {"left"},
                style = "confirm_button",
                style_mods = {
                    minimal_width = 0,
                    padding = {1, 8, 0, 12},
                },
                actions = {
                    on_click = params.on_confirm,
                },
            },
        }
    }
end

function M.enter(player, window_defines, data)
    player = ui_util.get_player(player)
    modal_dialog.create_interface_dimmer(player, "redesign", false)
    
    local window = gui.add(player.gui.screen, table.deep_copy(window_defines))
    window.title_bar.drag_target = window
    window.button_bar.left_drag_handle.drag_target = window
    window.button_bar.right_drag_handle.drag_target = window

    ui_util.recursive_dispatch_gui_event{
        name = "on_build",
        player_index = player.index,
        element = window,
        data = data,
        tick = game.tick,
    }
    
    player.opened = window
    if window.auto_center then
        window.force_auto_center()
    end

    ui_util.recursive_dispatch_gui_event{
        name = "on_builded",
        player_index = player.index,
        element = window,
        data = data,
        tick = game.tick,
    }
end

function M.exit(player, window)
    assert(window and gui.get_tags(window).__is_fp_window, "Specify a window.")
    player = ui_util.get_player(player)
    window.destroy()
    modal_dialog.reset_ui_state(player, false)
end

function M.get_window_element(elemnet)
    local current = elemnet
    while current do
        if gui.get_tags(current).__is_fp_window then
            return current
        end
        current = current.parent
    end
    return nil
end

function M.get_window_tags(elemnet)
    local window = M.get_window_element(elemnet)
    return gui.get_tags(window)
end

function M.get_window_search_text(elemnet)
    local window = M.get_window_element(elemnet)
    return window.title_bar.search_field.text
end

function M.request_to_add_recipe_chain(player, item_proto, production_type, subfactory_id, floor_id, insert_index)
    local chainable_recipes = data_util.get_chainable_recipes(player, item_proto, production_type)

    -- Users may not even notice that filters are switched.
    -- That would be confusing.
    --
    -- -- Set filters to try and show at least one recipe, should one exist, incorporating user preferences
    -- -- (This logic is probably inefficient, but it's clear and way faster than the loop above anyways)
    -- if relevant_recipes_count - counts.disabled - counts.hidden - counts.disabled_hidden > 0 then
    --     show.filters.disabled = user_prefs.disabled or false
    --     show.filters.hidden = user_prefs.hidden or false
    -- elseif relevant_recipes_count - counts.hidden - counts.disabled_hidden > 0 then
    --     show.filters.disabled = true
    --     show.filters.hidden = user_prefs.hidden or false
    -- else
    --     show.filters.disabled = true
    --     show.filters.hidden = true
    -- end
    local relevant_recipes = table.filter(chainable_recipes, function(v) return not v.ignored end)
    if #relevant_recipes == 0 then
        local error = (#chainable_recipes == 0) and {"fp.error_no_enabled_recipe"} or {"fp.error_no_relevant_recipe"}
        title_bar.enqueue_message(player, error, "error", 1, false)
    elseif #relevant_recipes == 1 then
        local recipe_id = relevant_recipes[1].proto.id
        data_util.attempt_adding_line(player, recipe_id, production_type, subfactory_id, floor_id, insert_index)
    else -- 2+ relevant recipes
        local preferences = data_util.get("preferences", player)
        M.enter(player, GUI_DEFINES.recipe_dialog, {
            chainable_recipes = chainable_recipes,
            item_proto = item_proto,
            production_type = production_type,
            subfactory_id = subfactory_id,
            floor_id = floor_id,
            insert_index = insert_index,
            filters = table.deep_copy(preferences.recipe_filters)
        })
    end
end

return M
