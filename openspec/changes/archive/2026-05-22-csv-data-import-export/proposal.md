## Why

用户目前无法将体温和用药数据带出 App，无法备份数据、换设备时迁移数据，也无法在就医时将历史记录提供给医生。CSV 是零依赖、跨平台的通用格式，可在 Numbers、Excel 中直接打开，是 iOS 上最实用的数据交换方案。

## What Changes

- **新增 CSV 导出**：在"我的"页面为每个孩子提供按时间范围导出体温和用药记录为单一 CSV 文件的能力，通过系统 ShareSheet 分发
- **新增 CSV 导入**：支持将符合导出格式的 CSV 文件导入到指定孩子的数据中，自动检测日期格式，重复记录自动跳过并提示
- **重构 ProfileView**：将简陋的孩子列表升级为带统计信息的卡片列表，并在底部增加"数据管理"区域作为导入导出的入口

## Capabilities

### New Capabilities

- `csv-export`: 将指定孩子在指定时间范围内的体温记录和用药记录导出为单一 CSV 文件，通过 ShareSheet 分发
- `csv-import`: 解析 CSV 文件并将记录导入到当前孩子，自动检测日期格式，格式错误给出行级提示，重复记录（相同 timestamp + record_type）自动跳过

### Modified Capabilities

- `profile-management`: 新增数据管理区入口（导入/导出操作），孩子行展示最近一次体温记录作为辅助信息

## Impact

- **Views**：ProfileView 重构，新增 ExportSheet、ImportPreviewSheet
- **Services**：新增 CSVExporter、CSVImporter（含 DateFormatDetector）
- **Models**：无需改动（TemperatureRecord、MedicationRecord 字段直接映射为 CSV 列）
- **依赖**：零外部依赖，纯 Swift 实现
- **权限**：需要在 Info.plist 声明 UIFileSharingEnabled 以支持文件访问（如尚未声明）
