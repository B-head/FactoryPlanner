local gui = require("__flib__.gui")
local window_util = require("ui.window_util")
local ui_util = require("ui.ui_util")

local recipes_per_row = 6

local function apply_recipe_filter(player_index, element)
    ui_util.reverse_recursive_dispatch_gui_event{
        name = "on_refresh",
        player_index = player_index,
        element = window_util.get_window_element(element),
        tick = game.tick,
    }
end

local function create_filter_switch_defines(name, filter_name, caption)
    return {
        type = "flow",
        direction = "horizontal",
        
        {
            type = "switch",
            name = name,
            left_label_caption = {"fp.on"},
            right_label_caption = {"fp.off"},
            actions = {
                on_build = function(event)
                    local element, data = event.element, event.data
                    element.switch_state = (data.filters[filter_name] and "right" or "left")
                end,

                on_switch_state_changed = function(event)
                    local element, window = event.element, window_util.get_window_element(event.element)
                    local boolean_state = element.switch_state == "right"

                    local tags = gui.get_tags(window)
                    tags.filters[filter_name] = boolean_state
                    gui.set_tags(window, tags)

                    data_util.get("preferences", event.player_index).recipe_filters[filter_name] = boolean_state
                    apply_recipe_filter(event.player_index, element)
                end,
            },
        },
        {
            type = "label",
            caption = caption,
            style_mods = {
                font = "default-semibold",
                left_margin = 8,
            },
        },
    }
end

local function pick_recipe(event)
    local element, player = event.element, ui_util.get_player(event.player_index)
    local window = window_util.get_window_element(element)
    local recipe_id, state = gui.get_tags(element).recipe_id, gui.get_tags(window)
    
    data_util.attempt_adding_line(player, recipe_id, state.production_type, state.subfactory_id, state.floor_id, state.insert_index)
    window_util.exit(player, window)
end
local pick_recipe_handler_id = ui_util.register_handler("on_click", "pick_recipe", pick_recipe)

local recipe_group_box = ui_util.preprocess_gui_defines{
    type = "frame",
    handlers_id = "recipe_group_box",
    style = "fp_frame_bordered_stretch",
    direction = "horizontal",
    style_mods = {
        padding = 8,
    },
    actions = {
        on_build = function(event)
            local element, data = event.element, event.data
            local group_name = gui.get_tags(element).group_name
            local recipe_group = data.recipe_groups[group_name]

            local group_sprite = ui_util.get_gui_element(element, "group_sprite")
            group_sprite.sprite = "item-group/"..group_name
            group_sprite.tooltip = recipe_group.proto.localised_name
        end,

        on_refresh = function(event)
            local element = event.element
            local recipes_table = ui_util.get_gui_element(element, "recipes_table")

            for _, e in ipairs(recipes_table.children) do
                if e.visible then
                    element.visible = true
                    return
                end
            end
            element.visible = false
        end
    },

    {
        type = "flow",
        direction = "horizontal",
        style_mods = {
            vertical_align = "center",
        },

        {
            type = "sprite-button",
            name = "group_sprite",
            style = "transparent_slot",
            style_mods = {
                size = 64,
                right_margin = 12,
            },
        },
        {
            type = "frame",
            direction = "horizontal",
            style = "fp_frame_deep_slots_small",
            
            {
                type = "table",
                name = "recipes_table",
                column_count = recipes_per_row,
                style = "filter_slot_table",
                actions = {
                    on_build = function(event)
                        local element, data = event.element, event.data
                        local group_name = gui.get_tags(element).group_name
                        local recipe_group = data.recipe_groups[group_name]

                        for _, recipe in pairs(recipe_group.recipes) do
                            local style
                            if recipe.hidden then 
                                style = "flib_slot_button_default_small"
                            elseif recipe.disabled then 
                                style = "flib_slot_button_yellow_small"
                            else
                                style = "flib_slot_button_green_small"
                            end

                            local recipe_proto = recipe.proto
                            local tags = table.shallow_copy(recipe)
                            tags.proto = nil
                            tags.recipe_id = recipe_proto.id
                            tags.recipe_name = recipe_proto.name -- todo: Support for translation.

                            if recipe_proto.custom then -- can't use choose-elem-buttons for custom recipes
                                gui.add(element, {
                                    type = "sprite-button",
                                    sprite = recipe_proto.sprite,
                                    tooltip = recipe_proto.tooltip,
                                    mouse_button_filter = {"left"},
                                    style = style,
                                    tags = tags,
                                    actions = {
                                        on_click = pick_recipe_handler_id,
                                    },
                                })
                            else
                                gui.add(element, {
                                    type = "choose-elem-button",
                                    elem_type = "recipe",
                                    recipe = recipe_proto.name,
                                    mouse_button_filter = {"left"},
                                    style = style,
                                    elem_mods = {
                                        locked = true,
                                    },
                                    tags = tags,
                                    actions = {
                                        on_click = pick_recipe_handler_id,
                                    },
                                })
                            end
                        end
                    end,

                    on_refresh = function(event)
                        local element, state = event.element, window_util.get_window_tags(event.element)
                        local disabled, hidden, ignore = state.filters.disabled, state.filters.hidden, state.filters.ignore
                        local search_term = window_util.get_window_search_text(element)

                        for _, recipe_button in ipairs(element.children) do
                            local tags = gui.get_tags(recipe_button)
                            local found = string.find(tags.recipe_name, search_term, 1, true)
                            local visible = not (
                                (not found)
                                or (disabled and tags.disabled)
                                or (hidden and tags.hidden)
                                or (ignore and tags.ignored)
                            )
                            recipe_button.visible = visible
                        end
                    end,
                },
            },
        },
    },
}

local recipe_dialog = window_util.create_window_defines{
    type = "standard",
    name = "fp_recipe_dialog",
    title = {"fp.two_word_title", {"fp.add"}, {"fp.pl_recipe", 1}},
    auto_center = true,
    allow_search = true,
    actions = {
        on_build = function(event)
            local element, data = event.element, event.data

            local state = table.shallow_copy(data)
            state.chainable_recipes = nil
            state.item_proto = nil
            gui.update_tags(element, state)

            -- At this point, we're sure the dialog should be opened
            local recipe_groups = {}
            for _, recipe in pairs(data.chainable_recipes) do
                local group_name = recipe.proto.group.name
                recipe_groups[group_name] = recipe_groups[group_name] or {proto = recipe.proto.group, recipes = {}}
                recipe_groups[group_name].recipes[recipe.proto.name] = recipe
            end
            data.recipe_groups = recipe_groups
        end,

        on_builded = function(event)
            apply_recipe_filter(event.player_index, event.element)
        end,

        on_search = function(event)
            apply_recipe_filter(event.player_index, event.element)
        end,
    },
    
    content = {
        type = "frame",
        name = "content_frame",
        direction = "vertical",
        style = "inside_shallow_frame",
        style_mods = {
            width = 380,
            maximal_height = 570,
            vertically_stretchable = true,
        },
        
        {
            type = "frame",
            name = "sub_title_frame",
            direction = "horizontal",
            style = "subheader_frame",
            style_mods = {
                horizontally_stretchable = true,
                padding = {12, 24, 12, 12},
            },
            
            {
                type = "label",
                name = "sub_title",
                style_mods = {
                    font = "default-semibold",
                },
                actions = {
                    on_build = function(event)
                        local element, data = event.element, event.data
                        element.caption = {"fp.recipe_instruction", {"fp." .. data.production_type}, data.item_proto.localised_name}
                    end,
                },
            },
        },
        {
            type = "scroll-pane",
            name = "content",
            direction = "vertical",
            style = "flib_naked_scroll_pane",
            
            {
                type = "frame",
                style = "fp_frame_bordered_stretch",
                
                {
                    type = "table",
                    column_count = 2,
                    style_mods = {
                        horizontal_spacing = 16,
                    },
                    
                    {
                        type = "label",
                        caption = {"fp.show"},
                        style_mods = {
                            top_margin = 2,
                            left_margin = 4,
                        },
                    },
                    {
                        type = "flow",
                        direction = "vertical",
                        
                        create_filter_switch_defines("unresearched_switch", "disabled", {"fp.unresearched_recipes"}),
                        create_filter_switch_defines("hidden_switch", "hidden", {"fp.hidden_recipes"}),
                    },
                },
            },
            {
                type = "flow",
                name = "recipe_groups",
                direction = "vertical",
                actions = {
                    on_build = function(event)
                        local element, data = event.element, event.data
                        for _, group in ipairs(ORDERED_RECIPE_GROUPS) do
                            local group_name = group.name
                            local recipe_group = data.recipe_groups[group_name]

                            -- Only actually create this group if it contains any relevant recipes
                            if recipe_group ~= nil then
                                local added = gui.add(element, table.deep_copy(recipe_group_box))
                                added.name = group_name
                                gui.update_tags(added, {
                                    group_name = group_name,
                                })

                                local recipes_table = ui_util.get_gui_element(added, "recipes_table")
                                gui.update_tags(recipes_table, {
                                    group_name = group_name,
                                })
                            end
                        end
                    end,
                },
            },
            {
                type = "label",
                name = "warning_label",
                caption = {"fp.no_recipe_found"},
                style_mods = {
                    font = "heading-2",
                    margin = {8, 0, 0, 8},
                },
                actions = {
                    on_refresh = function(event)
                        local element = event.element
                        local recipe_groups = element.parent.recipe_groups
                        
                        for _, e in ipairs(recipe_groups.children) do
                            if e.visible then
                                element.visible = false
                                return
                            end
                        end
                        element.visible = true
                    end
                },
            },
        },
    },
}

return recipe_dialog
