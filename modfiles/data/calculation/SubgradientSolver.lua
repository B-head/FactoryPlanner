local P, S = {}, {}
local C = require("data.calculation.class")
local util = require("data.calculation.solver_util")
local Matrix = require("data.calculation.Matrix")

function P:__new(flat_recipe_lines, normalized_references)
    self.flat_recipe_lines = flat_recipe_lines
    self.normalized_references = normalized_references
    self.map = self:create_id_map(self.flat_recipe_lines)
end

function P:solve()
    local x = Matrix.new_vector(#self.map):fill(0)
    for i = 1, 1000 do
        local o = self:objective(x)
        local g = self:objective_gradients(x)
        local a = 10 / i
        x = x - a * g
    end
    return self:vector_to_table(self.map, x)
end

function P:objective(x)
    local ret = 0
    local machine_counts = self:vector_to_table(self.map, x)
    local total_products, total_ingredients = self:get_total_amounts_per_tick(self.flat_recipe_lines, machine_counts)
    for k, v in pairs(self.normalized_references) do
        local a, p, i = v.amount_per_second, total_products[k] or 0, total_ingredients[k] or 0
        ret = ret + (math.abs(a - p) + math.abs(a - i)) * 10
    end
    for k, p in pairs(total_products) do
        local i = total_ingredients[k]
        if i then
            ret = ret + math.abs(p - i)
        end
    end
    -- todo: priority
    return ret
end

function P:objective_gradients(x)
    local ret = {}
    local machine_counts = self:vector_to_table(self.map, x)
    local total_products, total_ingredients = self:get_total_amounts_per_tick(self.flat_recipe_lines, machine_counts)
    for i, k in ipairs(self.map) do
        local v = self.flat_recipe_lines[k]
        local g = 0
        local function f(s, m)
            if s > 0 then
                g = g + m
            elseif s < 0 then
                g = g - m
            else
                -- g = g +- 0
            end
        end
        for _, u in pairs(v.products) do
            local r = self.normalized_references[u.name]
            local a, b = total_products[u.name], total_ingredients[u.name]
            if a and r then
                f(a - r.amount_per_second, u.amount_per_machine_by_second * 10)
            end
            if a and b then
                f(a - b, u.amount_per_machine_by_second)    
            end
        end
        for _, u in pairs(v.ingredients) do
            local r = self.normalized_references[u.name]
            local a, b = total_products[u.name], total_ingredients[u.name]
            if b and r then
                f(b - r.amount_per_second, u.amount_per_machine_by_second * 10)
            end
            if b and a then
                f(b - a, u.amount_per_machine_by_second)
            end
        end
        ret[i] = g
    end
    return Matrix.list_to_vector(ret)
end

function P:create_id_map(recipe_lines)
    local ret = {}
    for k, _ in util.iterate_recipe_lines(recipe_lines) do
        table.insert(ret, k)
    end
    return ret
end

function P:vector_to_table(map, vector)
    local ret = {}
    if vector.height == 1 then
        for x = 1, vector.width do
            ret[map[x]] = vector[1][x]
        end
    elseif vector.width == 1 then
        for y = 1, vector.height do
            ret[map[y]] = vector[y][1]
        end
    else
        assert()
    end
    return ret
end

function P:get_total_amounts_per_tick(recipe_lines, machine_counts)
    local total_products, total_ingredients = {}, {}
    for id, l in util.iterate_recipe_lines(recipe_lines) do
        local mc = machine_counts[id]
        for k, v in pairs(l.products) do
            local a = total_products[k] or 0
            total_products[k] = a + mc * v.amount_per_machine_by_second
        end
        for k, v in pairs(l.ingredients) do
            local a = total_ingredients[k] or 0
            total_ingredients[k] = a + mc * v.amount_per_machine_by_second
        end
    end
    return total_products, total_ingredients
end

return C.class("SubgradientSolver", P, S)