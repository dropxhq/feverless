## ADDED Requirements

### Requirement: 外部入口指定初始 Tab
RecordView SHALL 在被外部（首页快捷按钮、deep link）打开时，直接显示调用方指定的 Tab（体温或用药），无需用户额外点击切换。

#### Scenario: 从首页"记录用药"按钮打开
- **WHEN** 用户点击首页"记录用药"按钮
- **THEN** RecordView 打开后立即显示用药 Tab，而非体温 Tab

#### Scenario: 从首页"记录体温"按钮打开
- **WHEN** 用户点击首页"记录体温"按钮
- **THEN** RecordView 打开后立即显示体温 Tab

#### Scenario: 通过 deep link 打开
- **WHEN** App 收到 `feverless://record?type=medication` deep link
- **THEN** RecordView 打开后立即显示用药 Tab

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
### Requirement: 记录时间可修改
记录页 SHALL 默认记录时间为当前时间，并以紧凑形式（compact DatePicker）展示，用户点击后以系统浮层选择历史时间；不允许选择未来时间。

#### Scenario: 查看当前记录时间
- **WHEN** 用户打开记录页
- **THEN** 时间选择器以紧凑格式显示当前时间（如"5月21日 14:30"），不占用额外纵向空间

#### Scenario: 修改记录时间
- **WHEN** 用户点击时间选择器
- **THEN** 系统以浮层形式弹出日期+时间选择界面，允许选择过去时间，不允许选择未来时间

### Requirement: 备注输入
记录页 SHALL 提供可选备注输入框，内容存入 notes 字段。

#### Scenario: 输入备注
- **WHEN** 用户输入备注文字并保存
- **THEN** 记录的 notes 字段包含该文字

### Requirement: 记录时间可修改（保持不变）
记录页 SHALL 默认记录时间为当前时间，并以紧凑形式展示，用户点击后以系统浮层选择历史时间；不允许选择未来时间。

#### Scenario: 选择历史时间
- **WHEN** 用户通过 DatePicker 选择昨天 10:30
- **THEN** DataRecord.timestamp 保存为对应 Date 值
