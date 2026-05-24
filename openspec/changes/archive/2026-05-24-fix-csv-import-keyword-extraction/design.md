## Context

CSV 导入映射流程在处理含有空列名或重复列名的 CSV 时存在三个串联的缺陷，导致用户配置的关键词提取规则被静默丢弃。该问题在真实数据中高频出现——用户的历史记录表格通常有空白辅助列，且备注列不带标准列名。

当前状态：
- `ColumnMappingSheet.buildUpdatedConfig()` 以 `header` 字符串为 key 写入 `columnMappings`，多列同名时后者覆盖前者
- `ProfileView.proceedToValueDetection()` 调用 `aliasTable.resolveColumnName()`，该方法的 Layer 3 只处理 `.simple` 规则，对 `.keywordExtract` 返回 nil，导致关键词列被跳过
- `ValueMappingSheet` 的关键词配置 UI 嵌在 `medication_type` 分组中，仅在存在枚举未识别值时出现，而关键词提取场景通常不会触发该条件

## Goals / Non-Goals

**Goals:**
- 修复重复/空列名导致的配置规则碰撞问题
- 确保导入流程在有关键词提取列时必然展示关键词配置界面
- 将关键词配置 UI 从枚举值冲突条件中解耦
- 扩展内置词库，覆盖常见简写

**Non-Goals:**
- 重构 `ImportMappingConfig` 的存储结构（当前以 header 字符串为 key 的设计暂不变更）
- 为重复列名提供完全独立的配置（仅保证有意义的规则不被 `.ignore` 覆盖）
- UI 大改——关键词配置继续复用 `ValueMappingSheet`，不新增独立 Sheet

## Decisions

### 决策 1：重复列名碰撞的修复方式

**选择：在 `buildUpdatedConfig` 中，对同一 header key，不允许 `.ignore` 覆盖已存在的非 ignore 规则。**

规则：处理 entries 时，若 `newConfig.columnMappings[header]` 已有值且当前 entry 的 rule 是 `.ignore`，则跳过写入。

**备选方案：**
- 方案 B：将重复/空列名替换为 `"_col_<index>"` 形式的合成 key — 更彻底，但会破坏已保存的配置（`UserDefaults`），且需要同时修改 `parseRows` 中的查找逻辑
- 方案 C：将 `columnMappings` 的 key 改为列索引（Int）— 根本性修复，但为 breaking change，需迁移

方案 A 改动最小，且在实际场景中（用户通常只对"有意义的"列设置规则，空列默认 ignore）行为正确。

### 决策 2：关键词配置步骤的触发条件

**选择：`proceedToValueDetection` 在检测完枚举未识别值后，额外检查 `pendingConfig.columnMappings` 中是否存在 `.keywordExtract(_, extractsMedications: true)` 的规则。若存在，无论 `groups` 是否为空都展示 `ValueMappingSheet`。**

同时，`ValueMappingSheet` 的关键词配置 Section 改为由独立的 `hasKeywordColumns: Bool` 参数控制，不再依赖 `medication_type` 分组是否存在。

**备选方案：**
- 新建 `KeywordConfigSheet` — 流程更清晰，但增加了一个新 sheet，复用成本高
- 在 `ColumnMappingSheet` 内联关键词管理 — 单步完成但 sheet 会变复杂

### 决策 3：内置词库扩展范围

仅新增 `"对乙"` → 对乙酰氨基酚。不新增错别字（如"对已"）——错别字应由用户在关键词配置界面自行添加为自定义词条。

## Risks / Trade-offs

- **[风险] 方案 A 对同名列的处理顺序敏感** → 缓解：entries 按 CSV 列索引顺序排列，用户在 UI 中先配置的列（靠前）优先保留规则；此行为符合用户预期
- **[权衡] `ValueMappingSheet` 增加 `hasKeywordColumns` 参数** → 调用方（`ProfileView`）需传入此参数，接口略有扩展，但不影响现有功能
- **[风险] 已保存配置中可能存在历史的错误 `.ignore` 规则** → 缓解：`ImportConfigStore` 的配置仅在用户明确操作（ColumnMappingSheet 完成）时才更新写入，修复后下次导入重新配置即可覆盖
