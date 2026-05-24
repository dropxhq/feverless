## MODIFIED Requirements

### Requirement: 体温输入 Picker
记录页体温 Tab SHALL 提供原生 `.wheel` Picker 输入体温，整数部分范围 35–42，小数部分 0–9（步进 0.1°C），默认值 37.5°C，并以大号字体实时展示当前值。

#### Scenario: 拨动选择体温
- **WHEN** 用户拨动整数或小数 Picker
- **THEN** 预览区实时更新体温显示（如 "38.9 °C"）

#### Scenario: 微调按钮单次点击
- **WHEN** 用户点击 −/+ 按钮
- **THEN** 体温值以 0.1°C 步进递减/递增，边界值时对应按钮禁用

---

### Requirement: 测量方式选择
记录页 SHALL 从 `TemperaturePositionCatalog.shared.all` 动态读取测量位置列表，以分段控件或横向滚动 Chip 展示，默认选中"腋下"。不再使用 `MeasurementMethod` 枚举的 `allCases`。

#### Scenario: 展示自建位置
- **WHEN** 用户在 TemperaturePositionCatalog 中新建了"左侧液温"
- **THEN** 记录页测量方式选择中出现"左侧液温"选项

#### Scenario: 选择测量方式
- **WHEN** 用户选中某测量方式（如"耳温"）
- **THEN** 保存记录时 TemperatureReading.positionRaw 写入"耳温"

---

### Requirement: 同时记录用药
记录页体温 Tab SHALL 提供"同时记录用药"选项，从 `MedicationCatalog.shared.all` 动态读取药品列表（可多选）。保存后同一个 `DataRecord` 中同时包含体温读数和选中的药品。

#### Scenario: 同时记录体温和用药
- **WHEN** 用户选择体温并勾选布洛芬后保存
- **THEN** 系统创建一个 DataRecord，temperatures=[TemperatureReading("腋下", 38.0)]，medications=[MedicationUsage("布洛芬")]

---

### Requirement: 用药 Tab
记录页用药 Tab SHALL 从 `MedicationCatalog.shared.all` 动态读取药品列表，并展示该药物当前是否可用（根据用药间隔规则）。保存后创建一个 DataRecord，temperatures=[]，medications=[MedicationUsage(选中药品)]。

#### Scenario: 记录用药
- **WHEN** 用户选择布洛芬并保存
- **THEN** 系统创建 DataRecord，medications=[MedicationUsage("布洛芬")]，temperatures=[]

---

### Requirement: 记录时间可修改（保持不变）
记录页 SHALL 默认记录时间为当前时间，并以紧凑形式展示，用户点击后以系统浮层选择历史时间；不允许选择未来时间。

#### Scenario: 选择历史时间
- **WHEN** 用户通过 DatePicker 选择昨天 10:30
- **THEN** DataRecord.timestamp 保存为对应 Date 值
