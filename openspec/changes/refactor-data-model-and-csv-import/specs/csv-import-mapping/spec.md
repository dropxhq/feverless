## MODIFIED Requirements

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

### Requirement: 关键词词典与匹配规则
系统 SHALL 从 `MedicationCatalog` 读取所有药品定义的 keywords 列表（含 canonicalName 本身）作为关键词词典。关键词匹配 SHALL 使用子字符串包含（`contains`）方式，按词长降序匹配（长词优先），每个命中关键词创建一个 `MedicationUsage` 写入同一 DataRecord。

#### Scenario: 同行命中多个关键词
- **WHEN** 备注列文本包含"布洛芬和泰诺"
- **THEN** DataRecord.medications 包含两个 MedicationUsage（"布洛芬" + "对乙酰氨基酚"）

---

### Requirement: 值映射界面关键词区块（Tag UI）
`ValueMappingSheet` 的药品关键词配置区块通过弹出 `MedicationCatalogView`（sheet 模式）实现，不再在 ValueMappingSheet 内嵌独立的 Tag UI。`TemperaturePositionCatalogView` 同理。

两个 CatalogView 关闭时 SHALL 将修改后的 catalog 状态自动持久化。

#### Scenario: CatalogView 修改在导入流程中立即生效
- **WHEN** 用户在 ValueMappingSheet 弹出的 MedicationCatalogView 中新增关键词"布洛芬悬液"后关闭
- **THEN** 返回 ValueMappingSheet 后，关键词匹配立即使用新关键词

---

### Requirement: 重复/空列名配置不覆盖（保持不变）
当 CSV 文件中存在多列共享相同列名（包括空列名 `""`）时，系统 SHALL 保证用户在 `ColumnMappingSheet` 中对其中一列配置的有意义规则不被同名其他列的"忽略"规则覆盖。

#### Scenario: 空列名多列只保留有效规则
- **WHEN** CSV 有两列列名均为空，用户将其中一列配置为"备注+关键词提取"，另一列默认"忽略"
- **THEN** 最终配置中该列名对应规则为关键词提取，不被忽略覆盖
