## 1. 修复 Tab 时序 Bug（sheet item 重构）

- [x] 1.1 在 `ContentView.swift` 中定义 `RecordRequest: Identifiable` 结构体，包含 `child: Child` 和 `tab: RecordTab` 字段
- [x] 1.2 将 `@State private var showRecordView: Bool` 和 `@State private var recordInitialTab: RecordTab` 替换为 `@State private var recordRequest: RecordRequest?`
- [x] 1.3 将 `.sheet(isPresented: $showRecordView)` 改为 `.sheet(item: $recordRequest)`，从 item 读取 child 和 tab
- [x] 1.4 更新 deep link 处理逻辑，改为设置 `recordRequest` 而非两个独立状态
- [x] 1.5 更新 `HomeView` 签名：将 `showRecordView: Binding<Bool>` 和 `recordInitialTab: Binding<RecordTab>` 替换为 `recordRequest: Binding<RecordRequest?>`
- [x] 1.6 更新 `HomeView` 内两个快捷按钮，改为直接写入 `recordRequest`
- [ ] 1.7 验证：点击"记录用药"按钮，RecordView 打开时直接显示用药 Tab

## 2. 微调按钮长按加速

- [x] 2.1 在 `RecordView` 中新增 `@State` 变量：`isPressing: Bool`、`pressStepCount: Int`，用于追踪按压状态和步数
- [x] 2.2 将 `−`/`+` 两个 `Button` 改为携带 `DragGesture(minimumDistance: 0)` 的自定义可点击视图，`onChanged` 时启动重复触发，`onEnded` 时停止
- [x] 2.3 实现 `startRepeating(delta:)` 函数：首次立即触发一次 `adjustTemp`，然后用递归 `DispatchQueue.main.asyncAfter` 按加速曲线持续触发
- [x] 2.4 实现加速曲线：stepCount < 3 → 0.35s，stepCount < 8 → 0.15s，stepCount ≥ 8 → 0.08s
- [x] 2.5 在 `adjustTemp` 边界检查中，到达 35.0 或 42.9 时将 `isPressing` 设为 `false` 以中断递归调度
- [x] 2.6 实现 `stopRepeating()` 函数：将 `isPressing` 设为 `false`、重置 `pressStepCount`
- [x] 2.7 调整圆环进度动画：`pressStepCount >= 8` 时使用 `.interactiveSpring(duration: 0.1)`，否则保留 `.spring(duration: 0.3)`
- [ ] 2.8 验证：点击单次步进 0.1°C；长按约 2s 后步进加速；到达边界后松手无动画积压

## 3. 时间选择器改为 compact 样式

- [x] 3.1 移除 `@State private var showDatePicker: Bool`
- [x] 3.2 在 `timeSection` 中删除"修改/完成"按钮和 `if showDatePicker` 条件展开逻辑
- [x] 3.3 替换为单个 `DatePicker("记录时间", selection: $recordTime, in: ...Date(), displayedComponents: [.date, .hourAndMinute])` 并应用 `.datePickerStyle(.compact)`
- [ ] 3.4 验证：时间选择器紧凑显示，点击后以系统浮层弹出，不影响页面纵向布局；不允许选择未来时间
