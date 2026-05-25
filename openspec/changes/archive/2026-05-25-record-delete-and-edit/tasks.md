## 1. 提取并重构 RecordDisplayItem

- [x] 1.1 新建 `Views/Shared/RecordDisplayItem.swift`，定义 `.temperature` / `.medication` / `.combined` 三个 case，`var id: UUID { record.id }`，`var record: DataRecord`，`var date: Date`
- [x] 1.2 将 `HomeView.swift` 中的 `AnyRecentRecord` 定义删除，全局替换引用为 `RecordDisplayItem`
- [x] 1.3 更新 `HomeView.recentRecords` 计算属性：按 DataRecord 聚合，含 temp+med 的记录生成 `.combined` case，ForEach 改用 `id: \.id`
- [x] 1.4 更新 `ChartView` 中 `groupedRecords` / `allItems` 同样改用 `RecordDisplayItem`，ForEach 改用 `id: \.id`

## 2. 合并行 UI 渲染

- [x] 2.1 在 HomeView `recentRecordsList` 的 switch 分支中新增 `.combined` case，渲染双图标叠排样式（体温行 + 用药行，时间戳共享）
- [x] 2.2 在 ChartView `recordsListSection` 的 switch 分支中同样新增 `.combined` case 渲染

## 3. swipe 删除

- [x] 3.1 为 HomeView 记录列表的每行添加 `.swipeActions { Button("删除", role: .destructive) }`，调用 `deleteRecord(_:)`
- [x] 3.2 `deleteRecord` 函数：若 DataRecord 含多条子记录则先弹 `confirmationDialog`，确认后 `modelContext.delete(record)`，调用 `WidgetCenter.shared.reloadAllTimelines()`
- [x] 3.3 ChartView 记录列表同样添加 swipe 删除逻辑（可复用相同函数模式）

## 4. 编辑 Sheet

- [x] 4.1 新建 `Views/Record/EditRecordSheet.swift`，接受 `record: DataRecord`，根据 `record.temperatures.isEmpty` / `record.medications.isEmpty` 动态决定展示体温区、用药区或两者
- [x] 4.2 体温编辑区：复用 RecordView 的圆形进度环 + `±0.1` 微调按钮 + 位置 chip 横向滚动，初始值从 `record.temperatures.first` 预填
- [x] 4.3 用药编辑区：复用 RecordView 的 `medicationTypeRow` 列表（去掉安全提醒），初始选中值从 `record.medications.first` 预填
- [x] 4.4 共享区：`DatePicker`（预填 `record.timestamp`）+ 备注 TextField（预填 `record.notes`）
- [x] 4.5 实现"保存"逻辑：将 UI 状态写回 `record.temperatures[0].value`、`record.temperatures[0].positionRaw`、`record.medications[0].medicationNameRaw`、`record.timestamp`、`record.notes`，`try? modelContext.save()`，`WidgetCenter.shared.reloadAllTimelines()`
- [x] 4.6 HomeView 记录行添加 `onTapGesture`（非多选模式时），设置 `editingRecord = item.record`，sheet `.sheet(item: $editingRecord)`
- [x] 4.7 ChartView 记录行同样添加点击打开 EditRecordSheet

## 5. 多选模式

- [x] 5.1 HomeView 添加 `@State private var isSelecting: Bool = false` 和 `@State private var selectedIds: Set<UUID> = []`
- [x] 5.2 HomeView 记录行添加 `.onLongPressGesture`：`isSelecting = true`，将长按行 id 加入 `selectedIds`
- [x] 5.3 多选模式下记录行左侧显示 checkbox（`Image(systemName: selectedIds.contains(id) ? "checkmark.circle.fill" : "circle")`），点击行切换选中状态
- [x] 5.4 多选模式下底部显示固定操作栏：`已选 N 条 + 全选 + 取消 + 删除按钮`
- [x] 5.5 全选按钮：`selectedIds = Set(visibleItems.map(\.id))`；再次点击清空
- [x] 5.6 删除按钮：`selectedIds` 不为空时可用，点击弹确认对话框，确认后批量 `modelContext.delete(record)`，退出多选模式，刷新 Widget
- [x] 5.7 ChartView 同样实现 5.1–5.6 的多选逻辑

## 6. ChartView 分组全选

- [x] 6.1 多选模式下 ChartView 各日期分组 header 右侧添加"全选本组"按钮
- [x] 6.2 点击"全选本组"：将该分组内所有可见 DataRecord 的 id 加入 `selectedIds`

## 7. ChartView 切换时间范围清空选中

- [x] 7.1 监听 `timeRange` 变化（`.onChange(of: timeRange)`），自动 `isSelecting = false; selectedIds = []`

## 8. 验收检查

- [x] 8.1 确认 Xcode 无编译错误（`XcodeListNavigatorIssues`）
- [ ] 8.2 测试 swipe 删除纯体温、纯用药、合并行（验证确认弹窗仅在合并行出现）
- [ ] 8.3 测试点击行打开编辑 Sheet，修改后保存验证数据更新
- [ ] 8.4 测试长按进入多选、批量选中、批量删除
- [ ] 8.5 测试 ChartView 分组全选、时间范围切换后选中状态清空
- [ ] 8.6 测试 Widget 在删除/编辑后自动刷新
