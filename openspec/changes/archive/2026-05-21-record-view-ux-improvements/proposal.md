## Why

RecordView 存在一个功能 Bug（从首页"记录用药"按钮进入后显示的是体温页而非用药页），以及两处体验摩擦点（温度微调只能单次点击、时间选择器以大面积图形日历内联展开占用大量页面空间）。这三个问题在实际使用中频率高，修复成本低，适合一并处理。

## What Changes

- **修复**：从首页"记录用药"按钮打开 RecordView 时，正确跳转至用药 Tab（修复 sheet item 传参时序 Bug）
- **增强**：体温 ±0.1 微调按钮支持长按加速——按住持续触发，持续时间越长步进越快
- **优化**：记录时间选择器改为 `.compact` 样式，点击后以系统浮层弹出，不再内联展开整张图形日历

## Capabilities

### New Capabilities

（无新能力引入）

### Modified Capabilities

- `record-entry`：微调按钮新增长按加速行为；记录时间选择器交互方式由内联展开改为浮层弹出；明确从外部入口打开时应跳至对应 Tab 的需求

## Impact

- `feverless/Views/Record/RecordView.swift`：修改时间选择器样式、新增长按手势及 Timer 逻辑
- `feverless/ContentView.swift`：将 `sheet(isPresented:)` 改为 `sheet(item:)` 以原子化传递 initialTab，修复时序 Bug
- 不影响数据模型、Widget、图表或其他视图
