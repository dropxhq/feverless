## 1. 数据模型与持久化层

- [x] 1.1 新建 `ColumnMappingRule` enum（simple / compound / keywordExtract / ignore），实现 `Codable`
- [x] 1.2 新建 `ImportMappingConfig` struct（columnMappings + valueMappings + keywordExtensions），实现 `Codable`
- [x] 1.3 新建 `ImportConfigStore`（UserDefaults 读写，key: `csv_import_mapping_config`）
- [x] 1.4 新建 `ImportMappingReport` struct（appliedColumnMappings + appliedValueCounts，用于传递给预览）
- [x] 1.5 扩展 `CSVParseResult`，新增 `mappingReport: ImportMappingReport` 字段

## 2. 自动识别层（ImportAliasTable）

- [x] 2.1 新建 `ImportAliasTable` struct，硬编码内置中文列名别名表（`时间`→`timestamp` 等 7 个字段）
- [x] 2.2 在 `ImportAliasTable` 中硬编码枚举值 displayName 别名表（MeasurementMethod + MedicationType + record_type）
- [x] 2.3 实现 `resolveColumnName(_ header: String, config: ImportMappingConfig) -> String?`（三层优先级查找）
- [x] 2.4 实现 `resolveValue(_ value: String, forField: String, config: ImportMappingConfig) -> String?`

## 3. 关键词提取

- [x] 3.1 新建 `MedicationKeywordMatcher`，内置词典（布洛芬/美林/芬必得/Advil/ibuprofen；对乙酰氨基酚/扑热息痛/泰诺/退热净/acetaminophen）
- [x] 3.2 实现 `extract(from text: String, userExtensions: [String: String]) -> [MedicationType]`，按词长降序匹配，支持多命中
- [x] 3.3 用户自定义关键词扩展存入 `ImportMappingConfig.keywordExtensions`，合并到匹配逻辑

## 4. CSVImporter 重构

- [x] 4.1 新增 `detectUnresolvedColumns(headers: [String], config: ImportMappingConfig) -> [String]`
- [x] 4.2 新增 `detectUnresolvedValues(rows: [[String]], columnIndex: Int, field: String, config: ImportMappingConfig) -> [String]`
- [x] 4.3 重写 `parse(url:childId:config:)` 支持 `ColumnMappingRule` 和复合映射，替换旧的严格匹配逻辑
- [x] 4.4 实现行扩展逻辑：单行根据复合列数和关键词命中数生成多条记录
- [x] 4.5 解析过程中收集 `ImportMappingReport`（统计每条映射规则的命中次数）

## 5. CSVExporter 更新

- [x] 5.1 将 header 改为 `时间,记录类型,数值,测量方式,药物类型,同步体温,备注`
- [x] 5.2 调整列顺序，时间列前置
- [x] 5.3 `record_type` 值改为 `method.displayName`（体温/用药）
- [x] 5.4 `method` 值改为 `MeasurementMethod.displayName`
- [x] 5.5 `medication_type` 值改为 `MedicationType.displayName`

## 6. ColumnMappingSheet

- [x] 6.1 新建 `ColumnMappingSheet` View，接受 CSV headers 数组 + 当前 config，返回更新后的 config
- [x] 6.2 实现列表行：CSV 列名 + 识别状态标记（已识别 ✓ / 待映射 !）+ 主字段 Picker
- [x] 6.3 当主字段选择"数值"时，内联展开"固定附加字段"区域（测量方式 + 记录类型选择器）
- [x] 6.4 实现"关键词提取"复选框（仅当主字段为空或备注时可用）
- [x] 6.5 必要字段（记录类型、时间）未完成映射时禁用"继续"按钮，提示缺失字段名
- [x] 6.6 "忽略此列"选项

## 7. ValueMappingSheet

- [x] 7.1 新建 `ValueMappingSheet` View，接受未识别值列表（按字段分组，含出现次数）+ 当前 config
- [x] 7.2 按字段（记录类型 / 测量方式 / 药物类型）分 Section 展示未识别值
- [x] 7.3 每行显示"原始值 (×N)"+ 目标枚举值 Picker（含"忽略，记为默认值"选项）
- [x] 7.4 用户自定义关键词扩展入口：在药物类型 Section 提供"+ 添加关键词"，写入 `config.keywordExtensions`

## 8. ImportPreviewSheet 增强

- [x] 8.1 示例记录区域：取前 3 条记录，温度记录用"38.5°C 腋下 HH:mm"格式，用药记录用"布洛芬 HH:mm"
- [x] 8.2 新增"映射摘要" Section：展示 `ImportMappingReport` 中的列名映射条数和值映射命中明细
- [x] 8.3 关键词提取条数在摘要中单独一行展示
- [x] 8.4 确认导入前调用 `ImportConfigStore.save(config)` 持久化本次映射配置

## 9. 导入流程协调（ProfileView）

- [x] 9.1 重构 ProfileView 的导入入口，加载 `ImportConfigStore` 配置后执行自动识别
- [x] 9.2 自动识别后若存在未解析列，弹出 `ColumnMappingSheet`；完成后再检测未解析值
- [x] 9.3 若存在未解析值，弹出 `ValueMappingSheet`；完成后执行完整解析
- [x] 9.4 解析成功后弹出增强版 `ImportPreviewSheet`
- [x] 9.5 行级错误（日期/数值解析失败）弹出 Alert，使用中文列名而非 rawValue

## 10. 收尾

- [x] 10.1 确认旧格式（英文列名）CSV 能被自动识别，不需要映射界面（向后兼容测试）
- [x] 10.2 确认 feverless 自导出的新格式 CSV 能被自动识别，不需要映射界面（roundtrip 测试）
- [x] 10.3 确认"液温 + 备注含美林"场景从头到尾走通（复合列 + 关键词提取 + 行扩展）
- [x] 10.4 检查 `ImportPreviewSheet` 所有枚举值不出现英文 rawValue
