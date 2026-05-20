## 1. 项目清理与目录结构

- [x] 1.1 删除 `feverless/feverless/Item.swift` 模板文件
- [x] 1.2 创建目录结构：`Models/`、`Views/Home/`、`Views/Record/`、`Views/Chart/`、`Views/Profile/`、`ViewModels/`、`Utilities/`

## 2. 数据模型

- [ ] 2.1 创建 `Models/Child.swift`：`@Model` class，字段 id/name/birthDate/avatarEmoji/createdAt，所有字段兼容 CloudKit（有默认值或可选）
- [ ] 2.2 创建 `Models/TemperatureRecord.swift`：`@Model` class，字段 id/childId/value/method(枚举)/timestamp/notes
- [ ] 2.3 创建 `Models/MedicationRecord.swift`：`@Model` class，字段 id/childId/type(枚举)/timestamp/concurrentTemperature/notes
- [ ] 2.4 定义 `MeasurementMethod` 枚举（axillary/ear/rectal/oral/forehead）及 feverThreshold 计算属性
- [ ] 2.5 定义 `MedicationType` 枚举（ibuprofen/acetaminophen/other）及显示名/颜色属性

## 3. App 入口与 CloudKit 配置

- [ ] 3.1 更新 `feverlessApp.swift`：使用 App Group 路径创建 `ModelContainer`，启用 `cloudKitDatabase: .automatic`
- [ ] 3.2 注册 Child/TemperatureRecord/MedicationRecord 到 Schema（替换 Item）
- [ ] 3.3 添加 Deep Link URL scheme `feverless://` 处理（`onOpenURL` 跳转记录页）

## 4. 业务逻辑层

- [ ] 4.1 创建 `Utilities/FeverEpisodeDetector.swift`：根据测量方式判断发烧阈值，计算当前发烧周期开始时间和持续时长
- [ ] 4.2 创建 `ViewModels/MedicationSafetyViewModel.swift`：实现 `MedicationAvailability` 枚举（.available / .cooldown(remaining:) / .dailyLimitReached），提供 `availability(for:records:)` 方法
- [ ] 4.3 实现布洛芬（6h 间隔/4次/日）和对乙酰氨基酚（4h 间隔/5次/日）校验逻辑

## 5. 首页（HomeView）

- [ ] 5.1 创建 `Views/Home/HomeView.swift`：TabView 顶层，顶部当前儿童 Picker
- [ ] 5.2 实现发烧状态卡片（体温、较上次变化量、发烧时长）
- [ ] 5.3 实现用药安全提醒区域（布洛芬/对乙酰氨基酚状态），使用 `TimelineView(.periodic)` 实时更新倒计时
- [ ] 5.4 实现"记录体温"/"记录用药"快捷按钮，sheet 弹出 RecordView 并预选对应 Tab
- [ ] 5.5 实现最近 5 条记录列表（体温+用药混合，倒序）

## 6. 记录页（RecordView）

- [ ] 6.1 创建 `Views/Record/RecordView.swift`：sheet 呈现，顶部 Tab 切换"体温"/"用药"
- [ ] 6.2 实现体温输入：整数（35-42）+ 小数（0-9）双 `.wheel` Picker，大号实时预览，−/+ 微调按钮
- [ ] 6.3 实现测量方式选择（5种，横向 Chip 或 SegmentedControl）
- [ ] 6.4 实现"同时记录用药"选项（布洛芬/对乙酰氨基酚/其他/无）
- [ ] 6.5 实现用药 Tab：三种药物选择 + 当前可用状态展示 + 冷却期警告
- [ ] 6.6 实现记录时间选择（默认当前时间，"修改"弹出 DatePicker，限制不超过当前时间）
- [ ] 6.7 实现备注输入框
- [ ] 6.8 实现保存逻辑：写入 SwiftData，调用 `WidgetCenter.shared.reloadAllTimelines()`

## 7. 图表页（ChartView）

- [ ] 7.1 创建 `Views/Chart/ChartView.swift`：顶部时间范围筛选（今天/昨天/7天）
- [ ] 7.2 用 Swift Charts `LineMark` 绘制体温折线，添加 37.0°C 参考线 `RuleMark`
- [ ] 7.3 用 `RuleMark` 叠加用药时间标注（布洛芬黄色/对乙酰氨基酚蓝色）
- [ ] 7.4 实现记录明细列表（体温记录显示测量方式和发烧状态标签，用药记录显示药物名）

## 8. 我的页面（ProfileView）

- [ ] 8.1 创建 `Views/Profile/ProfileView.swift`：儿童档案列表
- [ ] 8.2 实现添加儿童表单（姓名必填，出生日期可选，头像 Emoji 选择）
- [ ] 8.3 实现编辑/删除儿童（删除时 cascade 删除所有关联记录）
- [ ] 8.4 实现首次启动引导（无儿童档案时跳转创建页）

## 9. 主 TabView 入口

- [ ] 9.1 重写 `ContentView.swift` 为 `TabView`，包含首页（🏠）、图表（📈）、我的（👤）三个 Tab

## 10. Widget 实现

- [ ] 10.1 创建 `feverlessWidget/FeverWidgetEntry.swift`：TimelineEntry 包含体温、发烧状态、用药可用状态等字段
- [ ] 10.2 创建 `feverlessWidget/FeverWidgetProvider.swift`：从 App Group SwiftData 只读路径读取数据，生成 Timeline（每 15 分钟刷新）
- [ ] 10.3 创建 `feverlessWidget/FeverWidgetSmallView.swift`：小尺寸 Widget 视图
- [ ] 10.4 创建 `feverlessWidget/FeverWidgetMediumView.swift`：中尺寸 Widget 视图（含用药倒计时 + 深度链接按钮）
- [ ] 10.5 更新 `feverlessWidget/feverlessWidget.swift`：替换模板为 `StaticConfiguration`，注册 small/medium 两种尺寸
- [ ] 10.6 更新 `feverlessWidget/feverlessWidgetBundle.swift`：注册实际 Widget

## 11. 验收

- [ ] 11.1 在模拟器上验证：首页发烧状态卡片、用药倒计时实时更新
- [ ] 11.2 验证：录入体温后 Widget 立即刷新
- [ ] 11.3 验证：多儿童切换后数据视图正确切换
- [ ] 11.4 验证：应用冷启动后数据正确从 SwiftData 恢复
