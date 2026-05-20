## Context

RecordView 是用户最高频使用的页面（发烧期间每次测温/用药都要打开）。目前存在三个具体问题：

1. **Tab 时序 Bug**：ContentView 使用 `sheet(isPresented:)` + 独立的 `@State recordInitialTab`。HomeView 通过 `@Binding` 同时写入这两个状态，由于 SwiftUI sheet 的 content closure 在 `showRecordView` 变为 `true` 那一帧就被求值，而 Binding 更新从子视图传回父视图存在一帧延迟，导致 `initialTab` 有时仍是旧值（`.temperature`）。

2. **微调按钮无加速**：当前 `+`/`-` 按钮每次点击步进 0.1°C，从 37.0 到 39.5 需要点击 25 次。发烧场景下家长常单手操作，多次点击体验差。

3. **图形日历内联展开**：`DatePicker(.graphical)` 展开后高度约 350pt，把备注区和保存按钮推到页面底部，需要大幅滚动。

## Goals / Non-Goals

**Goals:**
- 原子化 sheet 触发，确保 initialTab 始终与意图一致
- 温度微调按钮支持长按持续触发，并随持续时长加速
- 时间选择器改为紧凑浮层，不占用页面纵向空间

**Non-Goals:**
- 圆环拖拽手势（探索阶段评估后认为精度和遮挡问题大于收益）
- 修改数据模型、Widget 或其他视图
- 多指手势或任何无障碍功能退化

## Decisions

### Decision 1：用 `sheet(item:)` 替换 `sheet(isPresented:)` + 独立状态

ContentView 引入 `RecordRequest: Identifiable` 结构体，持有 `child: Child` 和 `tab: RecordTab`。HomeView 只需要写入单个 `@Binding<RecordRequest?>`，sheet 的 content closure 从 item 中读取，彻底消除两个状态之间的时序依赖。

**备选方案**：在 HomeView 按钮里加 `DispatchQueue.main.async` 延迟写入第二个状态——可行但属于 hack，不如结构性修复。

### Decision 2：长按加速用递归 `DispatchQueue` 而非 `Timer`

使用 `DragGesture(minimumDistance: 0)` 检测按下/抬起，触发后用递归 `DispatchQueue.main.asyncAfter` 调度重复触发，每次触发后缩短 `repeatInterval` 直至下限。

加速曲线：
- 初始间隔：0.35s（慢）
- 超过 3 步后：0.15s（中）
- 超过 8 步后：0.08s（快，≈12次/s）

**为何不用 `Timer.scheduledTimer`**：递归 `DispatchQueue` 在每次触发时重新计算间隔更灵活，且不需要手动 invalidate（用布尔标志 `isPressing` 控制停止）。

**动画**：高速触发时将圆环进度动画切换为 `.interactiveSpring(duration: 0.1)` 防止动画帧积压。

### Decision 3：`DatePicker` 改为 `.compact` 样式

将现有 `if showDatePicker { DatePicker(.graphical) }` 逻辑替换为单个 `DatePicker(.compact)`，移除 `showDatePicker` 状态和"修改/完成"按钮。iOS 的 compact picker 会自动以 popover 形式弹出。

**备选方案**：用 `.sheet` 包一个 `DatePicker(.graphical)` 弹出——控制更精细，但代码量增加；compact 样式已是 iOS 原生模式，体验一致性更好。

## Risks / Trade-offs

- **长按与点击的手势冲突** → 使用 `.simultaneousGesture` 或将按钮改为自定义 View，确保单次 tap 和长按都能响应，不互相干扰
- **快速步进到边界值时的动画重叠** → 在 `adjustTemp` 内加边界检查，到达极值时主动停止重复调度，防止无效触发积压
- **compact DatePicker 在 iPad 上行为不同**（popover vs inline）→ 当前 App 未适配 iPad，暂不处理
