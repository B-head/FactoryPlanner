local P, S = {}, {}
local C = require("data.calculation.class")
local util = require("data.calculation.solver_util")

-- local function check_loop(recipe_line, path_stack)
--     for _, v in ipairs(path_stack) do
--         if v == recipe_line then
--             return true
--         end
--     end
--     return false
-- end

-- local function follow_from_product(recipe_line, item_name, target_amount, path_stack)
--     local p = recipe_line.products[item_name]
--     assert(p)
--     if check_loop(recipe_line, path_stack) then 
--         return 0 -- todo: corresponding to the loop 
--     end
--     local request_machine_count = target_amount / p.amount_per_machine_by_second
--     recipe_line.machine_count = recipe_line.machine_count + request_machine_count

--     local actual_machine_count = request_machine_count -- todo

--     table.insert(path_stack, recipe_line)
--     for _, v in pairs(recipe_line.ingredients) do
--         local next_target_amount = v.amount_per_machine_by_second * actual_machine_count
--         for _, n in ipairs(v.neighbor_recipe_lines) do
--             local res = follow_from_product(n, v.name, next_target_amount, path_stack)
--             next_target_amount = next_target_amount - res
--             if next_target_amount <= tolerance then
--                 break
--             end
--         end
--     end
--     table.remove(path_stack)

--     return actual_machine_count * p.amount_per_machine_by_second
-- end

-- local function follow_from_ingredient(recipe_line, item_name, target_amount, path_stack)
--     -- todo
-- end

-- local function follow_from_reference(reference, normalized_top_floor)
--     local path_stack = {}
--     local item_name = reference.name

--     local target_amount = reference.amount_per_second
--     for _, v in M.visit_priority_order(normalized_top_floor) do
--         if v.products[item_name] then
--             local res = follow_from_product(v, item_name, target_amount, path_stack)
--             target_amount = target_amount - res
--             if target_amount <= tolerance then
--                 break
--             end
--         end
--     end

--     target_amount = reference.amount_per_second
--     for _, v in M.visit_priority_order(normalized_top_floor) do
--         if v.ingredients[item_name] then
--             local res = follow_from_ingredient(v, item_name, target_amount, path_stack)
--             target_amount = target_amount - res
--             if target_amount <= tolerance then
--                 break
--             end
--         end
--     end
-- end

return C.class("FollowSolver", P, S)