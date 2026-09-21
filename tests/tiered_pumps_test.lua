package.path = "./?.lua;./?/init.lua;" .. package.path

local function deepcopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[deepcopy(key, seen)] = deepcopy(child, seen)
    end
    return copy
end

table.deepcopy = deepcopy
log = function() end

local directions = { "north", "east", "south", "west" }
local animations = {}
local connector_input = {}
local connector_output = {}
for _, direction in ipairs(directions) do
    animations[direction] = { layers = { { filename = "body" }, { filename = "shadow", draw_as_shadow = true } } }
    connector_input[direction] = { layers = { { filename = "input" }, { filename = "shadow", draw_as_shadow = true } } }
    connector_output[direction] = { layers = { { filename = "output" }, { filename = "shadow", draw_as_shadow = true } } }
end

data = {
    raw = {
        item = {
            pump = {
                type = "item",
                name = "pump",
                icon = "pump.png",
                icon_size = 64,
                subgroup = "energy-pipe-distribution",
                order = "b[pipe]-c[pump]",
                place_result = "pump",
                random_tint_color = { r = 1 }
            }
        },
        pump = {
            pump = {
                type = "pump",
                name = "pump",
                icon = "pump.png",
                minable = { result = "pump" },
                max_health = 180,
                fast_replaceable_group = "pipe",
                collision_box = { { -0.29, -0.9 }, { 0.29, 0.9 } },
                collision_mask = { layers = { object = true } },
                pumping_speed = 20,
                energy_usage = "29kW",
                energy_source = { type = "electric", drain = "1kW" },
                animations = animations,
                wagon_connection_graphics = {
                    part_1 = { filename = "part-1" },
                    part_2 = { filename = "part-2" },
                    suction_clamp = { filename = "clamp" },
                    base = { input = connector_input, output = connector_output }
                }
            }
        },
        recipe = {
            pump = {
                type = "recipe",
                name = "pump",
                energy_required = 2,
                enabled = false,
                ingredients = {},
                results = {}
            }
        },
        technology = {
            ["fluid-handling"] = { effects = {} }
        }
    }
}

function data:extend(prototypes)
    for _, prototype in ipairs(prototypes) do
        self.raw[prototype.type] = self.raw[prototype.type] or {}
        self.raw[prototype.type][prototype.name] = prototype
    end
end

local tiered_pumps = require("prototypes.tiered-pumps")
tiered_pumps.extend()

-- 模拟 Krastorio2 在 data-updates 阶段修改原版泵，最终修正必须跟随修改后的替换约束。
data.raw.pump.pump.fast_replaceable_group = "pump"
data.raw.pump.pump.collision_box = { { -0.4, -0.9 }, { 0.4, 0.9 } }
data.raw.pump.pump.collision_mask = { layers = { object = true, train = true } }
tiered_pumps.finalize()

assert(data.raw.pump.pump.next_upgrade == "b-tiered-pump-1")
assert(#data.raw.technology["fluid-handling"].effects == 7)

local first_item = data.raw.item["b-tiered-pump-1"]
local first_entity = data.raw.pump["b-tiered-pump-1"]
local first_recipe = data.raw.recipe["b-tiered-pump-1"]
assert(first_item.place_result == "b-tiered-pump-1")
assert(first_item.random_tint_color == nil)
assert(first_entity.minable.result == "b-tiered-pump-1")
assert(first_entity.max_health == 360)
assert(first_entity.fast_replaceable_group == "pump")
assert(first_entity.collision_box[1][1] == -0.4)
assert(first_entity.collision_mask.layers.train == true)
assert(first_entity.pumping_speed == 40)
assert(first_entity.energy_usage == "58kW")
assert(first_entity.energy_source.drain == "2kW")
assert(first_entity.next_upgrade == "b-tiered-pump-2")
assert(first_entity.animations.north.layers[1].tint_as_overlay == true)
assert(first_entity.animations.north.layers[2].tint == nil)
assert(first_recipe.ingredients[1].name == "pump")
assert(first_recipe.ingredients[1].amount == 2)

local last_entity = data.raw.pump["b-tiered-pump-7"]
local last_recipe = data.raw.recipe["b-tiered-pump-7"]
assert(last_entity.max_health == 1440)
assert(last_entity.pumping_speed == 2560)
assert(last_entity.energy_usage == "3712kW")
assert(last_entity.energy_source.drain == "128kW")
assert(last_entity.next_upgrade == nil)
assert(last_recipe.ingredients[1].name == "b-tiered-pump-6")

data.raw.pump.pump.next_upgrade = "other-mod-pump"
tiered_pumps.finalize()
assert(data.raw.pump.pump.next_upgrade == "other-mod-pump")

print("tiered_pumps_test: ok")
