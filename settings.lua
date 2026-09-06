data:extend({
    {
        type = "string-setting",
        name = "b-market-distinguishing-items",
        setting_type = "startup",
        -- 默认覆盖常用基础材料、物流容器与中间产物，顺序即游戏内子分组的显示顺序。
        default_value = '["iron-plate","iron-gear-wheel","electronic-circuit","flying-robot-frame","sulfur","solid-fuel","automation-science-pack","wooden-chest","iron-chest","steel-chest"]',
        allow_blank = false,
        order = "a"
    }
})
