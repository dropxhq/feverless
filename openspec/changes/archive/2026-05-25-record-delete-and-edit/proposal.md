## Why

用户在凌晨三点操作时容易误触或输错数值，却没有任何方式纠正或删除错误记录。记录数据的不可更改性会导致发烧趋势图失真，并干扰用药安全计算。

## What Changes

- 将 `AnyRecentRecord` 替换为 `RecordDisplayItem`，以 DataRecord 为单位展示：同时含体温和用药的 DataRecord 合并为一行
- HomeView 最近记录列表支持：swipe 删除、点击编辑、长按进入多选批量删除、全选可见
- ChartView 记录明细列表支持：swipe 删除、点击编辑、长按进入多选批量删除、全选可见、按日期分组全选
- 编辑以 Sheet 形式呈现，复用 RecordView 的体温/用药 UI 组件，预填当前值

## Capabilities

### New Capabilities
- `record-management`: 对已创建的 DataRecord 进行删除（单删/批量删除）和编辑（体温值、测量方式、药品名称、时间戳、备注）

### Modified Capabilities
- `home-screen`: 最近记录列表从只读展示升级为可交互列表，支持 swipe 删除、点击编辑、长按多选；DataRecord 合并行展示
- `fever-chart`: 记录明细列表从只读展示升级为可交互列表，支持 swipe 删除、点击编辑、长按多选、按日期分组全选；DataRecord 合并行展示

## Impact

- `Views/Home/HomeView.swift`：重写 `recentRecordsList`，引入多选状态管理
- `Views/Chart/ChartView.swift`：重写 `recordsListSection`，引入多选状态管理和分组全选
- `Views/Home/HomeView.swift` 中的 `AnyRecentRecord` → 提取为独立文件 `RecordDisplayItem.swift`，新增 `.combined` case
- 新增 `Views/Record/EditRecordSheet.swift`：编辑 Sheet，复用 RecordView 组件
- 删除操作直接在 `modelContext` 上删除 DataRecord，cascade 自动清理子记录
