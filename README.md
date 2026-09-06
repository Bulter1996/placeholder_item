# Market Assembling Item

适用于 Factorio 2.1。
生成许多占位物品，用来扩展关联箱的id数量有限

启动设置“区别元素物品列表”接受物品内部 name 的 JSON 数组，例如
`["iron-gear-wheel","copper-plate"]`。每个元素都会生成 7 个继承源物品属性的等级，
例如 `b_market_iron_gear_wheel_1` 至 `b_market_iron_gear_wheel_7`。七级依次使用
`b_market_1.png` 至 `b_market_7.png` 作为底图，并在右上角叠加经过赤、橙、黄、
绿、青、蓝、紫浅色染色的区别元素。

每个区别元素单独占据“超市物品”Tab 中的一个子分组。第 1 级消耗 1 个区别元素，
之后每一级消耗 1 个前一级物品，全部制作时间均为 1 秒。

找不到配置的物品 name、遇到非字符串、重复项或无图标物品时，模组会在日志中记录
原因并跳过该项，不会因此中断加载。

全部生成物品都位于独立的“超市物品”制作 Tab 中。

## 安装

将发布 ZIP 放入 Factorio 的 `mods` 目录，或直接将本目录作为
`placeholder_item` 放入 `mods` 目录。

## 测试命令

进入地图后可在控制台输入：

```text
/c game.player.insert{name="b_market_iron_gear_wheel_1", count=1}
```
