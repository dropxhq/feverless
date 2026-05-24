## Why

CSV 导入中，当 CSV 文件包含空列名或重复列名时，用户在列名映射中配置的关键词提取规则会被静默覆盖，导致药物记录完全无法提取。此外，即使列名配置正确，导入流程也不会为用户提供自定义关键词的入口——关键词配置界面只在存在枚举未识别值时才出现，而关键词提取场景下通常不会触发这一条件。

## What Changes

- **修复空/重复列名配置碰撞**：当多列共享同一列名（如多个空列名 `""`），`buildUpdatedConfig` 中后一列的 `.ignore` 规则不再覆盖前一列已设置的有意义规则（`.keywordExtract`、`.compound` 等）
- **修复关键词提取列在值检测阶段被跳过**：`proceedToValueDetection` 中，对拥有 `.keywordExtract` 规则的列也能正确识别，不再因 `resolveColumnName` 返回 nil 而跳过
- **关键词配置步骤必现**：只要任意列启用了关键词提取，导入流程在列名映射完成后 SHALL 展示关键词配置界面，不依赖枚举冲突是否存在
- **扩展内置关键词词库**：新增 `"对乙"` → 对乙酰氨基酚，覆盖常见简写（完整写法 `"对乙酰氨基酚"` 已有，但 `"对乙"` 单独作为简写未收录）

## Capabilities

### New Capabilities

_无_

### Modified Capabilities

- `csv-import-mapping`：新增对重复/空列名的去碰撞要求；关键词配置步骤出现条件从"有枚举未识别值"扩展为"有枚举未识别值 **或** 有关键词提取列"

## Impact

- `feverless/Views/Profile/ProfileView.swift`：`proceedToValueDetection()` 逻辑修改
- `feverless/Views/Profile/ColumnMappingSheet.swift`：`buildUpdatedConfig()` 去碰撞逻辑
- `feverless/Views/Profile/ValueMappingSheet.swift`：关键词配置 Section 展示条件调整（或移至独立 Sheet）
- `feverless/Services/MedicationKeywordMatcher.swift`：内置词库扩展
