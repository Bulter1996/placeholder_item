local tier_tints = require("prototypes.tier-tints")

local M = {}
local tier_count = 7
local name_prefix = "b-tiered-pump-"

local function tier_name(level)
    return name_prefix .. level
end

local function scale_power(power, multiplier)
    local value, prefix, unit = power:match("^([%d.]+)([kMGTPEZY]?)([WJ])$")
    if not value then
        error("[placeholder-item] 无法解析原版 pump 的功率值: " .. tostring(power))
    end
    return string.format("%.15g%s%s", tonumber(value) * multiplier, prefix, unit)
end

local function tinted_icons(source, tint)
    local icons = source.icons and table.deepcopy(source.icons) or {
        { icon = source.icon, icon_size = source.icon_size or 64 }
    }

    for _, layer in ipairs(icons) do
        layer.tint = tint
    end
    return icons
end

local function tint_sprite(sprite, tint)
    if not sprite then
        return
    end
    sprite.tint = tint
    sprite.tint_as_overlay = true
end

local function tint_entity_graphics(entity, tint)
    -- 只染机械主体；阴影、玻璃和液体继续表达原来的光照与介质颜色。
    for _, animation in pairs(entity.animations or {}) do
        tint_sprite(animation.layers and animation.layers[1] or animation, tint)
    end

    local connector = entity.wagon_connection_graphics
    if not connector then
        return
    end

    tint_sprite(connector.part_1, tint)
    tint_sprite(connector.part_2, tint)
    tint_sprite(connector.suction_clamp, tint)

    for _, connection_type in pairs(connector.base or {}) do
        for _, direction in pairs(connection_type) do
            tint_sprite(direction.layers and direction.layers[1] or direction, tint)
        end
    end
end

local function localised_name(level)
    return {
        "b-tiered-pump.name",
        { "b-market.tier-name-" .. level },
        tostring(level)
    }
end

local function localised_description(level, multiplier, health_multiplier)
    return {
        "b-tiered-pump.description",
        tostring(level),
        string.format("%.0f", multiplier),
        string.format("%.1f", health_multiplier)
    }
end

function M.extend()
    local source_item = data.raw.item and data.raw.item.pump
    local source_entity = data.raw.pump and data.raw.pump.pump
    local source_recipe = data.raw.recipe and data.raw.recipe.pump
    local fluid_handling = data.raw.technology and data.raw.technology["fluid-handling"]

    if not source_item or not source_entity or not source_recipe or not fluid_handling then
        error("[placeholder-item] 无法找到原版 pump 的物品、实体、配方或 fluid-handling 科技")
    end

    local prototypes = {}
    for level = 1, tier_count do
        local name = tier_name(level)
        local multiplier = 2 ^ level
        local health_multiplier = 1 + level
        local tint = tier_tints[level]
        local display_name = localised_name(level)
        local description = localised_description(level, multiplier, health_multiplier)
        local icons = tinted_icons(source_item, tint)

        local item = table.deepcopy(source_item)
        item.name = name
        item.icon = nil
        item.icons = table.deepcopy(icons)
        item.place_result = name
        item.random_tint_color = nil
        item.order = source_item.order .. string.format("-a[%02d]", level)
        item.localised_name = display_name
        item.localised_description = description

        local entity = table.deepcopy(source_entity)
        entity.name = name
        entity.icon = nil
        entity.icons = table.deepcopy(icons)
        entity.minable.result = name
        entity.max_health = source_entity.max_health * health_multiplier
        entity.pumping_speed = source_entity.pumping_speed * multiplier
        entity.energy_usage = scale_power(source_entity.energy_usage, multiplier)
        entity.energy_source.drain = scale_power(source_entity.energy_source.drain, multiplier)
        entity.next_upgrade = level < tier_count and tier_name(level + 1) or nil
        entity.localised_name = display_name
        entity.localised_description = description
        tint_entity_graphics(entity, tint)

        local recipe = table.deepcopy(source_recipe)
        recipe.name = name
        recipe.icon = nil
        recipe.icons = table.deepcopy(icons)
        recipe.subgroup = source_item.subgroup
        recipe.order = item.order
        recipe.enabled = false
        recipe.ingredients = {
            {
                type = "item",
                name = level == 1 and source_item.name or tier_name(level - 1),
                amount = 2
            }
        }
        recipe.results = { { type = "item", name = name, amount = 1 } }
        recipe.main_product = name
        recipe.localised_name = display_name
        recipe.localised_description = description

        prototypes[#prototypes + 1] = item
        prototypes[#prototypes + 1] = entity
        prototypes[#prototypes + 1] = recipe
        fluid_handling.effects[#fluid_handling.effects + 1] = {
            type = "unlock-recipe",
            recipe = name
        }
    end

    data:extend(prototypes)
end

function M.finalize()
    local pump = data.raw.pump and data.raw.pump.pump
    if not pump then
        return
    end

    -- 其他模组可能在 data-updates 阶段调整原版泵；最终同步快速替换约束，避免克隆值过期。
    for level = 1, tier_count do
        local tier = data.raw.pump[tier_name(level)]
        tier.fast_replaceable_group = pump.fast_replaceable_group
        tier.collision_box = table.deepcopy(pump.collision_box)
        tier.collision_mask = table.deepcopy(pump.collision_mask)
    end

    if pump.next_upgrade == nil then
        pump.next_upgrade = tier_name(1)
    elseif pump.next_upgrade ~= tier_name(1) then
        log("[placeholder-item] 原版 pump 已存在 next_upgrade=" .. pump.next_upgrade .. "，已保留其他模组的升级路线")
    end
end

return M
