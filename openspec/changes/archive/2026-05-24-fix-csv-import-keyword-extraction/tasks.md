## 1. 修复重复/空列名配置碰撞

- [x] 1.1 在 `ColumnMappingSheet.buildUpdatedConfig()` 中，对同一 header key，若 `newConfig.columnMappings[header]` 已存在非 `.ignore` 规则，且当前 entry 的 rule 为 `.ignore`，则跳过写入
- [x] 1.2 验证：导入含两个空列名的 CSV，将第一个空列设为"备注+关键词提取"，第二个保持忽略，确认最终 config 中 `columnMappings[""]` 为 `.keywordExtract` 而非 `.ignore`

## 2. 修复值检测阶段跳过关键词提取列

- [x] 2.1 在 `ProfileView.proceedToValueDetection()` 的枚举扫描循环之后，额外检查 `pendingConfig.columnMappings.values` 中是否存在 `.keywordExtract(_, extractsMedications: true)` 条目，将结果存为 `hasKeywordColumns: Bool`
- [x] 2.2 将 `showValueMappingSheet = true` 的触发条件从 `!groups.isEmpty` 改为 `!groups.isEmpty || hasKeywordColumns`

## 3. 关键词配置区块解耦

- [x] 3.1 为 `ValueMappingSheet` 添加 `hasKeywordColumns: Bool` 初始化参数
- [x] 3.2 将 `addKeywordButton()` 的渲染条件从"当 `group.id == "medication_type"` 时内嵌"改为：在 List 末尾独立添加一个 Section（显示条件：`hasKeywordColumns == true`），section 标题为"药物关键词"
- [x] 3.3 在 `ProfileView` 中构建 `ValueMappingSheet` 时传入 `hasKeywordColumns` 参数

## 4. 扩展内置关键词词库

- [x] 4.1 在 `MedicationKeywordMatcher` 的 `builtinKeywords` 中新增 `("对乙", .acetaminophen)`，确保其插入位置在完整词 `"对乙酰氨基酚"` 之后（按词长降序排列，`"对乙酰氨基酚"` 7字 > `"对乙"` 2字，长词优先不受影响）
