local item_prototypes = {}
local recipe_prototypes = {}
local subgroup_prototypes = {}

local tier_tints = require("prototypes.tier-tints")

-- 等所有模组完成数据修改后再接入原版泵，避免覆盖其他模组已有的升级路线。
require("prototypes.tiered-pumps").finalize()

local configured_json = settings.startup["b-market-distinguishing-items"].value
-- Factorio 的 LuaObject 方法不能安全地脱离对象直接传给 pcall，必须包一层函数调用。
local json_ok, configured_items = pcall(function()
    return helpers.json_to_table(configured_json)
end)

if not json_ok or type(configured_items) ~= "table" then
    log("[placeholder-item] 区别元素配置不是有效的 JSON 字符串数组，已跳过全部配置项。示例: [\"iron-gear-wheel\"]")
    configured_items = {}
end

local function find_item_prototype(item_name)
    -- 支持普通物品以及模块、工具、弹药等常见 ItemPrototype 子类型。
    local item_types = {
        "item", "ammo", "armor", "blueprint", "blueprint-book", "capsule",
        "copy-paste-tool", "deconstruction-item", "gun", "item-with-entity-data",
        "item-with-inventory", "item-with-label", "item-with-tags", "mining-tool",
        "module", "rail-planner", "repair-tool", "selection-tool", "spidertron-remote",
        "tool", "upgrade-item"
    }

    for _, item_type in ipairs(item_types) do
        if data.raw[item_type] and data.raw[item_type][item_name] then
            return data.raw[item_type][item_name]
        end
    end
end

local function source_icon_layers(source)
    if source.icons then
        return table.deepcopy(source.icons)
    end
    return { { icon = source.icon, icon_size = source.icon_size or 64 } }
end

local function make_composite_icons(source, level)
    local icons = {
        {
            -- 每一级使用同色的超市底图，例如赤色等级使用 b_market_1.png。
            icon = "__placeholder-item__/graphics/icons/b_market_" .. level .. ".png",
            icon_size = 64
        }
    }

    for _, layer in ipairs(source_icon_layers(source)) do
        local icon_size = layer.icon_size or source.icon_size or 64
        icons[#icons + 1] = {
            icon = layer.icon,
            icon_size = icon_size,

            -- 将任意尺寸的源图标统一缩放到约 18 像素，再放到右上角。
            scale = 18 / icon_size,
            shift = { 9, -9 },

            -- 直接对区别元素施加当前等级的浅色遮罩，不绘制额外光晕副本。
            tint = tier_tints[level],

            -- 避免右上角图层参与边界计算后导致 64 像素底图被自动缩小。
            floating = true
        }
    end

    return icons
end

local generated_names = {}

local function generate_tiers(config_index, source_name)
    if type(source_name) ~= "string" or source_name == "" then
        log("[placeholder-item] 已跳过配置列表第 " .. config_index .. " 项：必须是非空物品 name 字符串")
        return
    end

    local source = find_item_prototype(source_name)
    if not source then
        log("[placeholder-item] 已跳过不存在的物品 prototype: " .. source_name)
        return
    end
    if not source.icon and not source.icons then
        log("[placeholder-item] 已跳过没有 icon/icons 素材的物品 prototype: " .. source_name)
        return
    end

    -- Factorio 原型名统一使用连字符；同时规范化其他模组可能提供的下划线或特殊字符。
    local safe_source_name = source_name:gsub("[^%a%d%-]", "-")
    local subgroup_name = "b-market-subgroup-" .. safe_source_name

    if generated_names[safe_source_name] then
        log("[placeholder-item] 已跳过重复或规范化后名称冲突的配置项: " .. source_name)
        return
    end
    generated_names[safe_source_name] = true

    -- 避免与其他模组或旧版本遗留的同名物品、配方发生 prototype 冲突。
    for level = 1, 7 do
        local candidate_name = "b-market-" .. safe_source_name .. "-" .. level
        if find_item_prototype(candidate_name) or (data.raw.recipe and data.raw.recipe[candidate_name]) then
            log("[placeholder-item] 已跳过名称冲突的区别元素系列: " .. source_name .. " -> " .. candidate_name)
            return
        end
    end

    -- 每个区别元素独占一行子分组，七个等级在该行从左到右排列。
    subgroup_prototypes[#subgroup_prototypes + 1] = {
        type = "item-subgroup",
        name = subgroup_name,
        group = "supermarket-items",
        order = string.format("b[%03d]", config_index),
        localised_name = {
            "b-market.generated-subgroup-name",
            source.localised_name or { "item-name." .. source_name }
        }
    }

    for level = 1, 7 do
        local generated_name = "b-market-" .. safe_source_name .. "-" .. level
        local previous_name = "b-market-" .. safe_source_name .. "-" .. (level - 1)
        local ingredient_name = level == 1 and source_name or previous_name
        local icons = make_composite_icons(source, level)
        local source_localised_name = source.localised_name or { "item-name." .. source_name }

        -- 深拷贝确保堆叠、燃料、放置结果等业务属性继续继承自区别元素。
        local item = table.deepcopy(source)
        item.name = generated_name
        item.icon = nil
        item.icons = icons
        item.pictures = nil
        item.subgroup = subgroup_name
        item.order = string.format("a[%02d]", level)
        item.localised_name = {
            "b-market.generated-item-name",
            source_localised_name,
            tostring(level),
            { "b-market.tier-name-" .. level }
        }
        item.localised_description = {
            "b-market.generated-item-description",
            source_localised_name,
            tostring(level),
            { "b-market.tier-name-" .. level }
        }
        item_prototypes[#item_prototypes + 1] = item

        -- 第 1 级消耗 1 个区别元素，后续等级各消耗 1 个前一级物品，制作时间均为 1 秒。
        recipe_prototypes[#recipe_prototypes + 1] = {
            type = "recipe",
            name = generated_name,
            icons = table.deepcopy(icons),
            subgroup = subgroup_name,
            order = string.format("a[%02d]", level),
            energy_required = 1,
            enabled = true,
            ingredients = { { type = "item", name = ingredient_name, amount = 1 } },
            results = { { type = "item", name = generated_name, amount = 1 } },
            main_product = generated_name,
            localised_name = item.localised_name,
            localised_description = item.localised_description
        }
    end
end

for config_index, source_name in ipairs(configured_items) do
    generate_tiers(config_index, source_name)
end

-- Factorio 不接受 data:extend({})，因此空配置或全部被跳过时不能调用 extend。
-- 子分组必须先于引用它们的物品和配方注册。
if #subgroup_prototypes > 0 then
    data:extend(subgroup_prototypes)
end
if #item_prototypes > 0 then
    data:extend(item_prototypes)
end
if #recipe_prototypes > 0 then
    data:extend(recipe_prototypes)
end
