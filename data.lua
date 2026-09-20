-- 所有动态商品都归入同一个制作菜单 Tab；每个区别元素的子分组稍后动态创建。
data:extend({
    {
        type = "item-group",
        name = "supermarket-items",
        icon = "__placeholder-item__/graphics/item-groups/supermarket-items.png",
        icon_size = 128,
        order = "zzz[supermarket-items]"
    }
})

-- 专用泵必须在 data 阶段注册，确保原版 Recycler 能在 data-updates 阶段生成默认回收配方。
require("prototypes.tiered-pumps").extend()
