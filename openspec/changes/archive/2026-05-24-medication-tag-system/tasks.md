## 1. MedicationDefinition 模型与 MedicationCatalog 服务

- [x] 1.1 新建 `feverless/Models/MedicationDefinition.swift`，定义 `MedicationDefinition` Codable 结构体（id, canonicalName, keywords, isBuiltIn, hasReminder, minIntervalHours, maxDailyDoses）
- [x] 1.2 新建 `feverless/Services/MedicationCatalog.swift`，实现 `MedicationCatalog` 单例（all, find, findCanonicalName, add, update, remove, save, load）
- [x] 1.3 在 `MedicationCatalog` 中初始化三个内置药品（布洛芬、对乙酰氨基酚、其他），数据来源于现有 `MedicationType` 属性
- [x] 1.4 在 `feverlessApp.swift` 启动时调用 `MedicationCatalog.shared.load()`

## 2. MedicationRecord 数据迁移

- [x] 2.1 在 `feverlessApp.swift` 添加一次性迁移函数，将旧 typeRaw 值（`"ibuprofen"` → `"布洛芬"`，`"acetaminophen"` → `"对乙酰氨基酚"`，`"other"` → `"其他"`）批量更新
- [x] 2.2 迁移函数使用 `UserDefaults` key `"medication_type_migrated_v2"` 保证只执行一次
- [x] 2.3 在 `MedicationRecord.swift` 添加注释，说明 typeRaw 现在存储 canonical name

## 3. MedicationSafetyViewModel 更新

- [x] 3.1 修改 `MedicationSafetyViewModel.availability` 方法签名，将 `for type: MedicationType` 改为 `forMedicationName: String`，新增 `catalog: MedicationCatalog` 参数
- [x] 3.2 内部逻辑改为从 catalog 查找 `MedicationDefinition`，读取 `hasReminder`、`minIntervalHours`、`maxDailyDoses`
- [x] 3.3 若 `hasReminder=false` 或 `minIntervalHours=nil`，直接返回 `.available`
- [x] 3.4 更新所有调用 `MedicationSafetyViewModel.availability` 的调用方（HomeView 等）

## 4. ImportAliasTable 关键词解析重构

- [x] 4.1 修改 `ImportAliasTable` 中 `medication_type` 的 `valueAliases` 硬编码词典，改为在解析时从 `MedicationCatalog` 动态读取
- [x] 4.2 修改 `MedicationKeywordMatcher`（或等价逻辑），关键词列表从 `MedicationCatalog.all` 展开 keywords + canonicalName 构建
- [x] 4.3 关键词匹配结果写入 `MedicationRecord.typeRaw` 时使用 `canonicalName` 而非 enum rawValue
- [x] 4.4 从 `ImportMappingConfig` 移除 `keywordExtensions` 字段，更新 encode/decode

## 5. ValueMappingSheet 重构（关键词区块）

- [x] 5.1 修复渲染 bug：将 `addKeywordButton()` 内的 `ForEach` 提取到 `Section` closure 直接层级
- [x] 5.2 重构关键词区块为双列 tag UI：左侧药品选择列表（来自 catalog）+ 右侧关键词列表
- [x] 5.3 右侧关键词支持添加（TextField + 确认按钮）和删除（swipe-to-delete 或减号按钮）
- [x] 5.4 左侧支持新增自建药品（输入 canonicalName，调用 `catalog.add`）
- [x] 5.5 `ValueMappingSheet` onDone 时将 catalog 变更持久化（`catalog.save()`）
- [x] 5.6 移除 `localConfig.keywordExtensions` 相关的所有 State 和绑定逻辑

## 6. Widget 兼容更新

- [x] 6.1 检查 `feverlessWidget/WidgetModels.swift` 和 `FeverWidgetProvider.swift` 中对 `MedicationType` rawValue 的依赖
- [x] 6.2 将 Widget 中药品名称显示逻辑改为直接展示 `typeRaw`（已是 canonical name），或从 catalog 查找
- [x] 6.3 更新 `AppIntent.swift` 中若有对 `MedicationType` enum 的硬编码引用

## 7. 其他视图更新

- [x] 7.1 更新 `RecordView.swift` 中药品选择 Picker，数据源改为 `MedicationCatalog.all`
- [x] 7.2 更新 `HomeView.swift` 中药品显示，使用 typeRaw 直接显示或从 catalog 查名称
- [x] 7.3 更新 `ChartView.swift` 中药品类型颜色/图例逻辑（内置药品保持原色，自建药品用默认色）
- [x] 7.4 （可选）在 `ProfileView.swift` 添加药品管理入口，支持查看/编辑/新增 MedicationDefinition
