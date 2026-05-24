## Why

现有数据模型将 `TemperatureRecord` 和 `MedicationRecord` 设计为两个独立的扁平记录，体温测量位置使用固定枚举 `MeasurementMethod`，无法支持用户自定义体温位置（如"左侧液温"）；同时 CSV 导入在处理"一行包含多个体温 + 多个药品"时依赖 compound rule 拼凑，语义不清晰。重构统一数据模型并同步扩展导入能力，是支持更丰富用药/体温记录场景的基础。

## What Changes

- **BREAKING** 移除 `TemperatureRecord`、`MedicationRecord`、`MeasurementMethod` 枚举
- **BREAKING** 新增统一数据模型：`DataRecord`（含 `@Relationship` 子模型 `TemperatureReading`、`MedicationUsage`）
- 新增 `TemperaturePositionDefinition` + `TemperaturePositionCatalog`，支持用户自定义体温测量位置（含关键词、发烧阈值）
- 「我的」页面新增「体温位置管理」入口，与「药品管理」平行
- CSV 导入流程全面升级：支持多体温位置列、自定义位置名列名映射、一行写入多条体温/药品
- `ValueMappingSheet` 和 `ColumnMappingSheet` 中的药品/体温位置管理 UI 改为直接弹出 `MedicationCatalogView` / `TemperaturePositionCatalogView`，与「我的」页面共享同一套组件
- 全量更新所有依赖旧数据模型的组件：ChartView、HomeView、RecordView、FeverEpisodeDetector、MedicationSafetyViewModel、FeverWidgetProvider、CSVExporter 等

## Capabilities

### New Capabilities

- `temperature-position-catalog`：体温测量位置目录，支持内置位置（腋下、耳温、额温、肛温、口腔）和用户自定义位置，每个位置包含关键词列表和发烧阈值，用于导入映射和 `isFever` 判断

### Modified Capabilities

- `data-models`：**BREAKING** — 用 `DataRecord + TemperatureReading + MedicationUsage` 替换 `TemperatureRecord + MedicationRecord`；移除 `MeasurementMethod` 枚举；无数据迁移，开发期重置数据库
- `csv-import`：更新导入输出类型为 `[DataRecord]`；一行可产生多个 `TemperatureReading` 和多个 `MedicationUsage`；导入空行（无体温、无药品、无备注）自动忽略
- `csv-import-mapping`：列名映射逻辑适配新模型；`ImportAliasTable` 中的体温位置解析改为查询 `TemperaturePositionCatalog`；`ValueMappingSheet` 弹出共享 CatalogView 替代内嵌 UI；新增「导入时创建体温位置」能力（对应 `TemperaturePositionCatalogView`）
- `profile-management`：新增「体温位置管理」`NavigationLink`；`MedicationCatalogView` 和新建的 `TemperaturePositionCatalogView` 均支持 `NavigationLink` 和 `.sheet` 两种展示方式
- `medication-catalog`：`MedicationCatalogView` 提取为可复用组件，支持从 `ValueMappingSheet` 以 `.sheet` 方式弹出
- `fever-chart`：查询 `DataRecord`，从 `temperatures` 关系展开体温点，从 `TemperaturePositionCatalog` 读取发烧阈值
- `fever-episode`：`FeverEpisodeDetector` 输入改为 `[DataRecord]`，`isFever` 判断依赖 `TemperaturePositionCatalog`
- `home-screen`：适配 `DataRecord` 查询
- `home-widget`：`FeverWidgetProvider` 更新 Schema 和 FetchDescriptor
- `medication-safety`：`MedicationSafetyViewModel` 输入改为 `[DataRecord]`，遍历 `medications` 关系
- `record-entry`：`RecordView` 写入 `DataRecord`（含 `TemperatureReading` / `MedicationUsage` 子对象）
- `csv-export`：适配 `DataRecord` 结构，展开子对象输出 CSV 列

## Impact

- **SwiftData Schema**：移除旧模型，新增 3 个 `@Model` 类；Widget extension 的 Schema 同步更新；开发期无需 Migration，直接重置
- **所有视图**：ChartView、HomeView 及子视图、RecordView、ProfileView 均需更新 `@Query` 和数据绑定
- **所有服务/工具**：CSVImporter、CSVExporter、ImportAliasTable、MedicationKeywordMatcher（小改）
- **ViewModels/Utilities**：MedicationSafetyViewModel、FeverEpisodeDetector API 签名变更
- **Widget**：FeverWidgetProvider Schema + FetchDescriptor 全量更新
