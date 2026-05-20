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

## MODIFIED Requirements

### Requirement: 体温输入 Picker
记录页体温 Tab SHALL 提供原生 `.wheel` Picker 输入体温，整数部分范围 35–42，小数部分 0–9（步进 0.1°C），默认值 37.5°C，并以大号字体实时展示当前值。

#### Scenario: 拨动选择体温
- **WHEN** 用户拨动整数或小数 Picker
- **THEN** 预览区实时更新体温显示（如 "38.9 °C"）

#### Scenario: 微调按钮单次点击
- **WHEN** 用户点击 −/+ 按钮
- **THEN** 体温值以 0.1°C 步进递减/递增，边界值（35.0 / 42.9）时对应按钮禁用

#### Scenario: 微调按钮长按加速
- **WHEN** 用户长按 −/+ 按钮
- **THEN** 按钮持续以递增频率触发步进：按住 0–0.5s 约 3 次/s，0.5–1.5s 约 7 次/s，1.5s 后约 12 次/s；到达边界值时立即停止

#### Scenario: 长按到边界后松手
- **WHEN** 用户长按 + 按钮直到体温达到 42.9°C 后松手
- **THEN** 步进停止，按钮保持禁用状态，无重复触发或动画积压

### Requirement: 记录时间可修改
记录页 SHALL 默认记录时间为当前时间，并以紧凑形式（compact DatePicker）展示，用户点击后以系统浮层选择历史时间；不允许选择未来时间。

#### Scenario: 查看当前记录时间
- **WHEN** 用户打开记录页
- **THEN** 时间选择器以紧凑格式显示当前时间（如"5月21日 14:30"），不占用额外纵向空间

#### Scenario: 修改记录时间
- **WHEN** 用户点击时间选择器
- **THEN** 系统以浮层形式弹出日期+时间选择界面，允许选择过去时间，不允许选择未来时间
