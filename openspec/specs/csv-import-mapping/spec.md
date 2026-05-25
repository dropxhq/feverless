## ADDED Requirements

### Requirement: 列名映射配置界面
导入时若 CSV 文件存在无法自动识别的列名，系统 SHALL 自动弹出 `ColumnMappingSheet`，展示 CSV 中所有列名，并允许用户为每列选择映射类型：

- **体温列**：将该列的数值作为某个测量位置的温度值写入 DataRecord.temperatures；用户选择测量位置（从 TemperaturePositionCatalog 选取，或新建）
- **药品列**：列中的值经关键词匹配后写入 DataRecord.medications
- **关键词提取**：将该列文本写入 notes，并可勾选"同时从本列提取药物关键词"
- **备注**：写入 DataRecord.notes
- **时间**：写入 DataRecord.timestamp
- **忽略**：不导入该列

列名映射对体温位置的解析 SHALL 查询 `TemperaturePositionCatalog`（关键词 + canonicalName），而非固定 `MeasurementMethod` 枚举。

必要字段（`时间`）未完成映射时，"继续"按钮 SHALL 保持禁用。

#### Scenario: 体温列映射到自定义位置
- **WHEN** 用户将"左腋温度"列映射为体温列，并选择"左侧液温"位置（用户自建）
- **THEN** 该列数值写入 DataRecord.temperatures，positionRaw="左侧液温"

#### Scenario: 必要字段未映射时禁止继续
- **WHEN** "时间"列尚未完成映射
- **THEN** ColumnMappingSheet 底部"继续"按钮保持禁用

#### Scenario: 同一行多个体温列
- **WHEN** CSV 包含"腋温"列和"额温"列，均映射为体温列
- **THEN** 同一行产生一个 DataRecord，temperatures 包含两个 TemperatureReading

---

---

### Requirement: 列值别名映射配置界面
列名映射完成后，系统 SHALL 扫描体温位置列中的唯一值，若存在无法自动识别的值（既非 canonicalName 也非 keywords 也非已保存别名），则弹出 `ValueMappingSheet`，展示所有未识别值及出现次数，允许用户为每个值选择对应的 TemperaturePositionCatalog 条目或忽略。

若任意列启用了关键词提取（`extractsMedications == true`），系统 SHALL 在 `ValueMappingSheet` 中展示药品关键词配置区块，区块内嵌"管理药品"按钮，点击后以 `.sheet` 方式弹出 `MedicationCatalogView`。

若列名映射中存在体温位置相关的未识别值，系统 SHALL 在 `ValueMappingSheet` 中展示体温位置配置区块，区块内嵌"管理体温位置"按钮，点击后以 `.sheet` 方式弹出 `TemperaturePositionCatalogView`。

#### Scenario: 未识别体温位置值触发值映射
- **WHEN** 体温列中存在值"左耳"，不在 TemperaturePositionCatalog 中
- **THEN** ValueMappingSheet 展示"左耳（×N）"，让用户选择映射到已有位置或忽略

#### Scenario: 点击"管理体温位置"弹出 CatalogView
- **WHEN** 用户在 ValueMappingSheet 点击"管理体温位置"
- **THEN** 以 sheet 方式展示 TemperaturePositionCatalogView，用户可在其中新建"左耳"位置后返回

#### Scenario: 点击"管理药品"弹出 CatalogView
- **WHEN** 用户在 ValueMappingSheet 点击"管理药品"
- **THEN** 以 sheet 方式展示 MedicationCatalogView，用户可新建药品后返回

---

---

### Requirement: 关键词词典与匹配规则
系统 SHALL 从 `MedicationCatalog` 读取所有药品定义的 keywords 列表（含 canonicalName 本身）作为关键词词典。关键词匹配 SHALL 使用子字符串包含（`contains`）方式，按词长降序匹配（长词优先），每个命中关键词创建一个 `MedicationUsage` 写入同一 DataRecord。

#### Scenario: 同行命中多个关键词
- **WHEN** 备注列文本包含"布洛芬和泰诺"
- **THEN** DataRecord.medications 包含两个 MedicationUsage（"布洛芬" + "对乙酰氨基酚"）

---

---

### Requirement: 值映射界面关键词区块（Tag UI）
`ValueMappingSheet` 的药品关键词配置区块通过弹出 `MedicationCatalogView`（sheet 模式）实现，不再在 ValueMappingSheet 内嵌独立的 Tag UI。`TemperaturePositionCatalogView` 同理。

两个 CatalogView 关闭时 SHALL 将修改后的 catalog 状态自动持久化。

#### Scenario: CatalogView 修改在导入流程中立即生效
- **WHEN** 用户在 ValueMappingSheet 弹出的 MedicationCatalogView 中新增关键词"布洛芬悬液"后关闭
- **THEN** 返回 ValueMappingSheet 后，关键词匹配立即使用新关键词

---

---

### Requirement: 重复/空列名配置不覆盖
当 CSV 文件中存在多列共享相同列名（包括空列名 `""`）时，系统 SHALL 保证用户在
`ColumnMappingSheet` 中对其中一列配置的有意义规则（`.keywordExtract`、`.compound`、
`.simple`）不被同名其他列的"忽略"规则覆盖。

具体规则：对同一列名，若已存在非 `.ignore` 的映射规则，后续处理到同名列时若其规则为
`.ignore`，SHALL 跳过写入，保留已有规则。

#### Scenario: 空列名多列只保留有效规则
- **WHEN** CSV 有两列列名均为空 `""`，用户将其中一列配置为"备注+关键词提取"，另一列默认"忽略"
- **THEN** 最终配置中 `columnMappings[""]` 为 `.keywordExtract`，不被"忽略"覆盖

#### Scenario: 重复非空列名同样适用
- **WHEN** CSV 有两列列名均为 `"备注"`，用户将第一列配置为"备注"字段，第二列默认"忽略"
- **THEN** 最终配置中保留第一列的 `.simple(field: "notes")` 规则

---

### Requirement: 关键词提取列在值检测阶段被正确识别
`proceedToValueDetection` 阶段 SHALL 正确识别配置中所有持有 `.keywordExtract` 规则
的列，不得因 `resolveColumnName` 不处理该规则类型而将其跳过。

识别方式：在枚举值扫描循环之外，额外遍历 `pendingConfig.columnMappings` 中所有
`extractsMedications == true` 的条目，将"需展示关键词配置"标记为 `true`。

#### Scenario: 关键词提取列触发值映射界面
- **WHEN** 用户在 ColumnMappingSheet 中为某列启用了"从此列提取药物关键词"
- **THEN** ColumnMappingSheet 完成后，即使没有任何枚举未识别值，系统也 SHALL 展示包含关键词配置区块的 ValueMappingSheet

#### Scenario: 关键词提取与枚举冲突同时存在
- **WHEN** 用户配置了关键词提取列，且某枚举列也存在未识别值
- **THEN** ValueMappingSheet 同时展示枚举未识别值分组和关键词配置区块

---

### Requirement: 映射配置持久化
系统 SHALL 在用户确认导入后，将本次列名映射和值别名映射保存为全局配置
（`UserDefaults`），下次导入任意 CSV 文件时自动加载并优先应用已保存的别名。

#### Scenario: 下次导入自动应用已保存映射
- **WHEN** 用户之前已保存"美林 → 布洛芬"的值别名
- **THEN** 下次导入包含"美林"的文件时，系统自动识别，无需重新进入 ValueMappingSheet

#### Scenario: 新文件覆盖更新已保存映射
- **WHEN** 用户在新一次导入中对同一列名配置了不同映射
- **THEN** 保存时合并更新全局配置（同 key 覆盖旧值，新 key 追加）

---

### Requirement: 一行多记录（行扩展）
当一行 CSV 同时满足以下任意组合时，系统 SHALL 为该行生成多条记录：
- 多个复合列均有数值 → 各生成一条体温记录
- 关键词提取命中 N 个药物 → 生成 N 条用药记录
- 体温列有值且关键词列命中药物 → 分别生成体温记录和用药记录

#### Scenario: 体温列 + 关键词列同行
- **WHEN** 某行"液温"列值为 38.5，备注列文本命中"布洛芬"
- **THEN** 生成一条体温记录（38.5°C 腋下）和一条用药记录（布洛芬），时间戳相同

#### Scenario: 两个体温列同行均有值
- **WHEN** 某行"液温"=38.5，"额温"=37.8 均有数值
- **THEN** 生成两条体温记录（腋下 38.5 和 额温 37.8），时间戳相同

### Requirement: 重复/空列名配置不覆盖（保持不变）
当 CSV 文件中存在多列共享相同列名（包括空列名 `""`）时，系统 SHALL 保证用户在 `ColumnMappingSheet` 中对其中一列配置的有意义规则不被同名其他列的"忽略"规则覆盖。

#### Scenario: 空列名多列只保留有效规则
- **WHEN** CSV 有两列列名均为空，用户将其中一列配置为"备注+关键词提取"，另一列默认"忽略"
- **THEN** 最终配置中该列名对应规则为关键词提取，不被忽略覆盖
