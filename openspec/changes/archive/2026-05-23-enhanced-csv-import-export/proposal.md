## Why

现有的 CSV 导出使用英文内部字段名（`ibuprofen`、`axillary`），在 Excel/Numbers
中对用户完全不可读；导入仅支持自身导出的固定格式，无法处理用户从其他来源（手工
Excel、其他健康 App）带来的真实数据文件，极大限制了数据可移植性。

## What Changes

- **BREAKING — 导出格式升级**：列名和值全部改用中文显示名，时间列前置；旧格式导
  出的 CSV 仍可导入（向后兼容由导入侧的自动识别保障）
- **新增列名映射**：导入时支持三种列映射类型——简单（1:1 列名对应）、复合（单列
  携带隐含字段值，如"液温"列自动设置测量方式=腋下）、关键词提取（从文本列提取
  用药记录）
- **新增值别名映射**：导入时支持枚举列（记录类型、测量方式、药物类型）的值别名
  映射，包含品牌名（"美林" → 布洛芬）、口语表达（"退烧药" → 布洛芬）
- **持久化映射配置**：全局保存一份映射配置，下次导入同格式文件时自动加载
- **增强导入预览**：预览内容全部使用中文显示名，并附加映射摘要（本次应用了哪些
  自定义映射，各命中多少条）
- **一行多记录**：当 CSV 一行同时包含体温数据和药物关键词时，分别生成对应记录

## Capabilities

### New Capabilities

- `csv-import-mapping`：CSV 导入映射配置系统——列名映射（简单/复合/关键词提取）、
  列值别名映射、关键词词典、持久化存储与加载；包含 ColumnMappingSheet 和
  ValueMappingSheet 两个配置界面

### Modified Capabilities

- `csv-import`：新增映射配置阶段（列名 → 值 → 关键词），支持一行生成多条记录，
  导入预览改用中文显示名并附加映射摘要，自动识别层（rawValue → displayName →
  已保存别名）取代旧的严格匹配
- `csv-export`：**BREAKING** 导出格式变更——时间列前置，所有列名改为中文显示名，
  枚举值改用 displayName；新增内置中英别名表供导入侧自动识别

## Impact

- **Services**：`CSVExporter` 重写导出格式；`CSVImporter` 新增映射管线，拆分为
  解析、列映射、值映射、行扩展四个阶段
- **Models**：新增 `ImportMappingConfig`（Codable，存 UserDefaults）、
  `ColumnMappingRule`（enum：simple/compound/keywordExtract/ignore）、
  `ImportMappingReport`（本次映射应用情况，随 CSVParseResult 传递）
- **Views**：新增 `ColumnMappingSheet`、`ValueMappingSheet`；`ImportPreviewSheet`
  增加显示名渲染和映射摘要 Section
- **依赖**：零外部依赖，纯 Swift 实现
- **存储**：UserDefaults 写入一个 JSON key，无 SwiftData Schema 变更
