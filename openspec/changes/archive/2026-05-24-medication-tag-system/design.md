## Context

当前 `MedicationType` 是硬编码 enum，共三个值：`ibuprofen`、`acetaminophen`、`other`。该枚举承担了两个职责：一是作为 `MedicationRecord.typeRaw` 的存储标识符；二是携带用药安全元数据（最短间隔、每日上限）。这导致用户无法新增药品，且 CSV 导入的关键词也只能映射到这三个固定值。

同时，`ValueMappingSheet` 中关键词添加后列表不刷新，是由于 `ForEach` 嵌套在 `@ViewBuilder` 函数内，SwiftUI `List` 无法正确追踪动态行的 identity 变化。

## Goals / Non-Goals

**Goals:**
- 引入 `MedicationDefinition` 模型，支持任意药品名 + 关键词列表 + 安全配置
- 内置默认药品（布洛芬、对乙酰氨基酚），用户可新增
- `MedicationRecord.typeRaw` 存储 canonical name（如 `"布洛芬"`），不再存 enum rawValue
- 安全提醒逻辑从 catalog 查数据，保持现有行为
- 修复 `ValueMappingSheet` ForEach 渲染 bug
- CSV 关键词解析基于 catalog

**Non-Goals:**
- 不支持多语言 canonical name（存储用显示名）
- 不引入 CloudKit 同步 for MedicationDefinition（本地持久化即可）
- 不改变 TemperatureRecord 模型
- 不重构 Widget 的药品显示逻辑（仅更新引用）

## Decisions

### Decision 1：canonical name 直接作为存储标识符

**选择**：`MedicationRecord.typeRaw` 存储用户可见的 canonical name（`"布洛芬"`），而非 UUID 或新的 rawValue。

**理由**：简化数据读写；无需跨模型 join；旧数据迁移映射表简单（3 条规则）；用户重命名药品时代价与用 ID 相近（都需全量更新历史记录）。

**备选**：UUID 作为 ID —— 带来跨表查找复杂度，对当前规模过度设计。

---

### Decision 2：MedicationDefinition 持久化用 UserDefaults（JSON）

**选择**：与 `ImportMappingConfig` 同样使用 `UserDefaults` + `Codable` 持久化，不作为 SwiftData model。

**理由**：药品定义是配置类数据，不是用户内容数据；避免 SwiftData schema 再次变更；无需 CloudKit 同步定义。

**备选**：SwiftData model —— 引入额外 migration 复杂度且无明显收益。

---

### Decision 3：保留 MedicationType enum，仅用于初始化内置数据

**选择**：不删除 `MedicationType`，改为仅在 `MedicationCatalog` 初始化内置药品时使用，不再作为存储类型。

**理由**：减少大范围重命名；Widget、Chart 等现有代码引用可逐步迁移；保留安全常量。

**备选**：完全删除 —— 破坏面更大，风险高。

---

### Decision 4：ValueMappingSheet 关键词区块重构结构

**选择**：将 `ForEach` 从 `addKeywordButton()` `@ViewBuilder` 函数内提取，直接放到 `Section` 的 closure 里，并重构为支持左侧药品名（tag key）/ 右侧关键词（tag values）的双列可编辑 UI。

**理由**：修复根因（SwiftUI `List` Section 中 `@ViewBuilder` 函数返回 `TupleView` 时 identity 不稳定）；同时满足 tag 系统新的交互需求。

## Risks / Trade-offs

- **[SwiftData 迁移]** `typeRaw` 值变更（`"ibuprofen"` → `"布洛芬"`）需要 lightweight migration 或 app 首次启动时的一次性转换 → **Mitigation**：在 `feverlessApp` 启动时检查并执行批量更新，迁移前备份无需额外操作（SwiftData 事务保证原子性）
- **[Widget 数据读取]** Widget 读取 `typeRaw` 时若仍按 enum rawValue 解析会显示"其他" → **Mitigation**：同步更新 `WidgetModels.swift` 中的药品名称显示逻辑
- **[用户重命名 canonical name]** 历史记录的 `typeRaw` 不会自动跟随更新 → **Mitigation**：MVP 阶段禁止对内置药品重命名，仅允许用户自建药品命名；v2 再加重命名+历史迁移

## Migration Plan

1. App 首次启动（版本升级后）检测到旧格式数据（`typeRaw` 为 `"ibuprofen"/"acetaminophen"/"other"`）
2. 执行一次性批量迁移：
   - `"ibuprofen"` → `"布洛芬"`
   - `"acetaminophen"` → `"对乙酰氨基酚"`
   - `"other"` → `"其他"`
3. 写入迁移完成标记到 `UserDefaults`（key: `"medication_type_migrated_v2"`）
4. 后续启动跳过迁移检查

## Open Questions

- 用户自建药品的安全配置 UI 放在哪里？（当前方案：在 RecordView 新建药品时配置，还是在 ProfileView 药品管理页？）→ 建议 ProfileView 管理页，RecordView 仅选择
- 内置药品是否允许用户修改关键词列表？→ 建议允许（只修改 keywords，不修改安全参数）
