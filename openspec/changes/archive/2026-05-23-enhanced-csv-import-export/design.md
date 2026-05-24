## Context

现有的 `CSVExporter` 和 `CSVImporter` 基于一套固定的内部字段名协议（英文 rawValue
列名 + 枚举 rawValue 值），仅支持自产自销的 roundtrip。`CSVImporter.parse()` 做严
格的列名匹配，任何偏差直接 throw。`CSVExporter` 硬编码英文列名和值。

本次变更在导出侧引入格式 breaking change，在导入侧引入多阶段映射管线，两者通过
内置别名表（displayName ↔ rawValue）实现向后兼容。

## Goals / Non-Goals

**Goals:**
- 导出 CSV 对人类可读（中文列名 + 显示名值）
- 导入支持任意来源的 CSV，通过三阶段映射（列名 → 值别名 → 关键词）处理差异
- 持久化映射配置，避免重复配置相同来源的文件
- 一行 CSV 可产生多条 App 记录（体温 + 用药共存行）

**Non-Goals:**
- 不支持多份命名配置（全局一份）
- 不支持 CSV 以外的格式（JSON / XML / HL7 等）
- 不做自然语言理解，关键词提取仅做 `contains` 匹配
- 不支持导出格式的版本选择（旧英文格式 / 新中文格式切换）

## Decisions

### 决策 1：列映射规则建模为 enum

```swift
enum ColumnMappingRule: Codable {
    case simple(field: String)
    // field: 主目标字段；impliedValues: 同行固定写入的字段值对
    case compound(field: String, impliedValues: [String: String])
    // extractsMedications: 是否同时做关键词提取；field: 可选地映射到备注
    case keywordExtract(field: String?, extractsMedications: Bool)
    case ignore
}
```

**备选方案**：用字符串标记 + 附属字典。  
**选择 enum**：利用 Swift 关联值使无效状态不可表达，编译期安全，序列化由
`Codable` 自动处理。

---

### 决策 2：持久化用 UserDefaults + Codable，不用 SwiftData

映射配置是用户偏好设置，不是健康数据——不需要查询、不需要关联孩子、不需要迁移。
`UserDefaults` 存一个 JSON key，零 Schema 侵入。

**备选方案**：新增 SwiftData Model。  
**拒绝原因**：过度设计，会污染数据库 Schema，且配置数据量极小。

---

### 决策 3：自动识别三层优先级

```
列名识别: rawValue → 内置中文别名 → 已保存的用户别名 → 进入 ColumnMappingSheet
列值识别: rawValue → displayName  → 已保存的用户别名 → 进入 ValueMappingSheet
```

内置中文别名表硬编码在 `ImportAliasTable` 结构体中，维护
`internalField → [String]` 和 `(internalField, rawValue) → [String]` 两张表。

---

### 决策 4：复合列的 UI 采用"内联展开"而非类型选择器

用户在 `ColumnMappingSheet` 中先选择主字段，若主字段为"数值"则自动展开
"+ 同时固定以下字段"，可附加 `测量方式` / `记录类型` 的固定值选择器。  
关键词提取通过"+ 同时从本列提取药物关键词"复选框触发。

**备选方案**：顶层"类型"下拉（简单/复合/关键词）。  
**选择内联展开**：对不需要高级功能的列零干扰，只在需要时可见。

---

### 决策 5：关键词匹配用 `contains`，内置词典按词长降序排列

中文没有空格分词，精确词边界匹配不可行。`contains` 宽松但误判率低，前提是词典中
优先匹配长词（"对乙酰氨基酚"先于"乙酰"）。

```swift
// 内置词典（含品牌名）
MedicationType.ibuprofen:      ["布洛芬","美林","芬必得","Advil","ibuprofen"]
MedicationType.acetaminophen:  ["对乙酰氨基酚","扑热息痛","泰诺","退热净","acetaminophen"]
```

匹配时按词长降序遍历整张词典，第一个命中的 medication type 为结果；一行中多个命
中则创建多条用药记录（同一时间戳）。

---

### 决策 6：同行多体温列均有值 → 分别生成记录

如 "液温=38.5，额温=37.8" 在同一行，产生两条 `TemperatureRecord`（相同时间戳，
不同 `method`）。这是对原始数据最忠实的表达。  
预览阶段会显示"本次生成 N 条体温记录（含同行多测量）"。

---

### 决策 7：导出格式 breaking change + 导入自动兼容

导出改为中文格式后旧导出文件仍可导入，依赖自动识别层的 rawValue 回退：

```
旧 CSV 列名 "record_type" → 自动识别（rawValue 精确匹配）✓
旧 CSV 值   "ibuprofen"   → rawValue 精确匹配 ✓
新 CSV 列名 "记录类型"     → 内置中文别名表 ✓
新 CSV 值   "布洛芬"       → displayName 匹配 ✓
```

不提供"导出旧格式"选项，降低长期维护负担。

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|---------|
| 关键词误判（如"布洛芬效果不好"）→ 产生多余用药记录 | 预览阶段显示所有从关键词提取的用药记录，用户确认后才写入 |
| 持久化配置与新文件格式不兼容（列名变了）→ 旧配置无效 | 自动识别层先行；配置中找不到对应列则静默跳过（降级到 ColumnMappingSheet） |
| 用户未完成必要字段映射就退出 | ColumnMappingSheet 必须字段未映射时"继续"按钮禁用，不允许绕过 |
| 值映射界面跳过部分未识别值 → `.other` 静默降级 | 预览摘要明确列出"N 条记录药物类型设为其他（未映射）" |
