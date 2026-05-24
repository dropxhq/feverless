## Why

当前药物类型被硬编码为固定 enum（布洛芬、对乙酰氨基酚、其他），无法新增药品，且 CSV 导入的关键词配置 UI 存在渲染 bug 导致已添加的关键词无法显示。用户需要一个可自由拓展的药品 tag 系统，支持自定义药品名及其别名关键词，同时保留内置药品的用药安全提醒功能。

## What Changes

- **新增** `MedicationDefinition` 数据结构：药品名（canonicalName）+ 关键词列表（keywords）+ 安全配置（minIntervalHours, maxDailyDoses, hasReminder）
- **新增** `MedicationCatalog`：管理内置及用户自定义药品定义，持久化到 UserDefaults / AppStorage
- **修改** `MedicationRecord.typeRaw`：从存储 enum rawValue（`"ibuprofen"`）改为存储 canonical name（`"布洛芬"`）**BREAKING**
- **修改** `MedicationSafetyViewModel`：从枚举属性读取安全数据，改为从 catalog 查找
- **修改** `ValueMappingSheet`：关键词配置区块重构为 tag-based UI（左侧药品名 / 右侧关键词均可无限拓展），修复 ForEach 不刷新 bug
- **修改** `ImportAliasTable`：keyword 解析从 catalog 中查找，不再依赖 `MedicationType` enum 的硬编码映射
- **移除** `ImportMappingConfig.keywordExtensions`：合并进 `MedicationDefinition.keywords`
- **数据迁移**：现有 `MedicationRecord` 中的旧 rawValue 自动映射为新 canonical name

## Capabilities

### New Capabilities

- `medication-catalog`: 药品目录管理 —— MedicationDefinition 模型、内置默认药品、用户自建药品、持久化、CRUD 接口

### Modified Capabilities

- `data-models`: MedicationRecord 的 `typeRaw` 字段语义变更（enum rawValue → canonical name），需要数据迁移
- `medication-safety`: 安全校验数据源从 `MedicationType` enum 属性改为从 `MedicationCatalog` 查询
- `csv-import-mapping`: 关键词提取改为基于 `MedicationCatalog`；`ValueMappingSheet` 关键词区块重构为可拓展 tag UI；修复关键词添加后列表不刷新的渲染 bug

## Impact

- `feverless/Models/Enums.swift` — `MedicationType` 保留但降级为初始化内置 catalog 的来源，不再是存储类型
- `feverless/Models/MedicationRecord.swift` — `typeRaw` 字段含义变更（schema migration 必须）
- `feverless/Models/ImportMapping.swift` — 移除 `keywordExtensions` 字段
- 新增 `feverless/Models/MedicationDefinition.swift`
- 新增 `feverless/Services/MedicationCatalog.swift`
- `feverless/Services/ImportAliasTable.swift` — keyword 解析逻辑重写
- `feverless/ViewModels/MedicationSafetyViewModel.swift` — 入参类型变更
- `feverless/Views/Profile/ValueMappingSheet.swift` — 关键词区块完整重构
- Widget（`feverlessWidget`）中引用 `MedicationType` 的代码需同步更新
