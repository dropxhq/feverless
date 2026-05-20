## ADDED Requirements

### Requirement: 体温输入 Picker
记录页体温 Tab SHALL 提供原生 `.wheel` Picker 输入体温，整数部分范围 35–42，小数部分 0–9（步进 0.1°C），默认值 37.5°C，并以大号字体实时展示当前值。

#### Scenario: 拨动选择体温
- **WHEN** 用户拨动整数或小数 Picker
- **THEN** 预览区实时更新体温显示（如 "38.9 °C"）

#### Scenario: 微调按钮
- **WHEN** 用户点击 −/+ 按钮
- **THEN** 体温值以 0.1°C 步进递减/递增，边界值（35.0 / 42.9）时对应按钮禁用

### Requirement: 测量方式选择
记录页 SHALL 提供腋下、耳温、肛温、口腔、额温五种测量方式选择，以分段控件或横向滚动 Chip 展示，默认选中"腋下"。

#### Scenario: 选择测量方式
- **WHEN** 用户选中某测量方式
- **THEN** 保存记录时 method 字段写入对应枚举值

### Requirement: 同时记录用药
记录页体温 Tab SHALL 提供"同时记录用药"选项，可在同一次操作中选择布洛芬/对乙酰氨基酚/其他/无。

#### Scenario: 同时记录体温和用药
- **WHEN** 用户选择体温并勾选某药物后保存
- **THEN** 系统同时创建 TemperatureRecord 和 MedicationRecord，后者 concurrentTemperature 设为本次体温值

### Requirement: 用药 Tab
记录页用药 Tab SHALL 提供布洛芬/对乙酰氨基酚/其他三种选择，并展示该药物当前是否可用（根据用药间隔规则）。

#### Scenario: 记录用药（冷却中警告）
- **WHEN** 用户选择仍在冷却期内的药物
- **THEN** 界面显示警告提示，但仍允许用户保存（不强制阻止）

### Requirement: 记录时间可修改
记录页 SHALL 默认记录时间为当前时间，并提供"修改"按钮供用户调整为历史时间。

#### Scenario: 修改记录时间
- **WHEN** 用户点击"修改"
- **THEN** 展示 DatePicker，允许选择过去时间（不允许未来时间）

### Requirement: 备注输入
记录页 SHALL 提供可选备注输入框，内容存入 notes 字段。

#### Scenario: 输入备注
- **WHEN** 用户输入备注文字并保存
- **THEN** 记录的 notes 字段包含该文字
