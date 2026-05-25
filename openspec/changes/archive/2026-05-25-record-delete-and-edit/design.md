## Context

当前 HomeView 和 ChartView 中的记录列表均为只读展示，无法删除或编辑已有记录。两个视图共享 `AnyRecentRecord` 枚举（定义于 `HomeView.swift`）将 DataRecord 展开为子记录列表项，导致一个含体温+用药的 DataRecord 会显示为两行。删除和编辑的粒度均以 DataRecord 为单位。

## Goals / Non-Goals

**Goals:**
- HomeView 和 ChartView 记录列表支持 swipe 删除、点击编辑、长按多选批量删除
- ChartView 额外支持按日期分组全选
- 两个列表均支持全选可见记录
- 同时含体温和用药的 DataRecord 合并显示为一行
- 编辑 Sheet 复用 RecordView 已有 UI 组件（体温环、微调按钮、chip 选择器、DatePicker、备注）

**Non-Goals:**
- 不新增独立的历史记录页，功能保留在现有两个列表中
- 不支持将一条 DataRecord 拆分为多条，或合并多条为一条
- 不对子记录（TemperatureReading / MedicationUsage）做独立粒度的操作

## Decisions

### D1：以 DataRecord 为操作和显示单元

**决策**：所有删除/编辑操作以 DataRecord 为单元；列表中每个 DataRecord 对应一行。

**理由**：DataRecord 是系统中一次完整记录事件的容器，用户心智模型是"一次记录"，而非内部子结构。以子记录为粒度会导致删除"体温行"时用药行孤立存在。

**替代方案**：以 TemperatureReading / MedicationUsage 为粒度 → 需要处理空容器清理逻辑，且用户无法理解"体温行被删了但用药还在"的情况。

### D2：新增 RecordDisplayItem 替代 AnyRecentRecord

**决策**：将 `AnyRecentRecord` 重命名并重构为 `RecordDisplayItem`，提取到独立文件，新增 `.combined` case。

```swift
enum RecordDisplayItem: Identifiable {
    case temperature(record: DataRecord, reading: TemperatureReading)
    case medication(record: DataRecord, usage: MedicationUsage)
    case combined(record: DataRecord, reading: TemperatureReading, usage: MedicationUsage)

    var id: UUID { record.id }
    var record: DataRecord { ... }
    var date: Date { record.timestamp }
}
```

**理由**：使用 `record.id`（UUID）作为稳定标识符，取代原来不稳定的 `\.offset`，同时支持多选状态管理。

### D3：多选状态用 Set\<UUID\> 管理

**决策**：在视图层用 `@State private var selectedIds: Set<UUID> = []` 存储选中的 DataRecord ID，`@State private var isSelecting: Bool` 控制多选模式。

**理由**：UUID 是 Hashable，Set 操作 O(1)，不需要引入额外状态对象。选中状态是纯 UI 临时状态，不需要持久化。

### D4：编辑 Sheet 动态适配三种 DataRecord 类型

**决策**：`EditRecordSheet` 接受 `DataRecord`，根据其内容动态渲染：
- 仅体温：体温环 + 微调 + 位置 chips + 时间 + 备注
- 仅用药：药物列表 + 时间 + 备注
- 体温+用药（combined）：体温环 + 微调 + 位置 chips + 药物选择 + 时间 + 备注

这与 RecordView 的 temperatureTab（含 concurrentMedPicker）结构完全对应，可最大化复用。

### D5：删除直接操作 modelContext

**决策**：调用 `modelContext.delete(record)` 删除 DataRecord，SwiftData 的 cascade deleteRule 自动清理 TemperatureReading 和 MedicationUsage。无需手动处理空容器。

## Risks / Trade-offs

- **合并行删除的副作用**：swipe 删除"38.2°C 腋下"行时，同一 DataRecord 中的"布洛芬"用药记录也会被删除。需在 swipe action 或确认对话框中说明（如"同时删除关联用药记录"）。→ 缓解：swipe 时显示确认提示（仅当 DataRecord 含多条子记录时）。

- **ChartView 多选状态与时间范围联动**：切换时间范围时当前选中集合中可能有部分记录不在新范围内。→ 缓解：切换时间范围时清空 `selectedIds` 并退出多选模式。

- **HomeView 最近列表只显示 5 条**："全选可见"只能选到最多 5 条，符合预期但需在 UI 上体现（如"全选 5 条"）。

## Migration Plan

纯 UI 变更，无数据模型变动。无需迁移。`AnyRecentRecord` 在两处被引用（HomeView + ChartView），替换时统一更新。
