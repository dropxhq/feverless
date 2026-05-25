## ADDED Requirements

### Requirement: 当前儿童状态卡片
首页 SHALL 展示当前选中儿童的发烧状态卡片，包含：当前/最新体温、较上次变化量（↑/↓/—）、本次发烧持续时长（若发烧中）、最近一次记录时间。

#### Scenario: 发烧中状态展示
- **WHEN** 最新体温 ≥ 发烧阈值（腋下 37.5°C / 其他 38.0°C）
- **THEN** 卡片显示"发烧中"红色状态、持续时长、当前体温

#### Scenario: 正常状态展示
- **WHEN** 最新体温 < 发烧阈值或无记录
- **THEN** 卡片显示正常/无记录状态，不显示发烧时长

### Requirement: 用药安全提醒区域
首页 SHALL 展示布洛芬和对乙酰氨基酚的用药状态，包含：最近服用时间、距下次可用的倒计时（或"现可用"标记）。

#### Scenario: 用药冷却中
- **WHEN** 上次用药距今未达最短间隔
- **THEN** 显示剩余等待时长（如"1h 40m 后"）

#### Scenario: 可用状态
- **WHEN** 上次用药距今已超过最短间隔
- **THEN** 显示"✓ 现可用"绿色标记

### Requirement: 快捷记录按钮
首页 SHALL 提供"记录体温"和"记录用药"两个快捷操作按钮，点击后以 sheet 方式弹出 RecordView。

#### Scenario: 弹出记录页
- **WHEN** 用户点击"记录体温"或"记录用药"
- **THEN** RecordView 以 sheet 形式呈现，并预选对应 Tab（体温/用药）

### Requirement: 最近记录列表
首页 SHALL 展示当前儿童最近 5 条 DataRecord（按时间倒序），每条 DataRecord 显示为一行；同时含体温和用药的 DataRecord 合并为单行展示。列表支持 swipe 删除、点击编辑（弹出编辑 Sheet）、长按进入多选批量删除、多选模式下全选可见记录。

#### Scenario: 展示最近记录（纯体温）
- **WHEN** DataRecord 仅含 TemperatureReading
- **THEN** 列表行显示温度计图标、°C 值、测量位置、相对时间、发烧状态标签

#### Scenario: 展示最近记录（纯用药）
- **WHEN** DataRecord 仅含 MedicationUsage
- **THEN** 列表行显示药丸图标、药品名、相对时间

#### Scenario: 展示最近记录（合并行）
- **WHEN** DataRecord 同时含体温和用药
- **THEN** 列表行合并展示体温信息和用药信息，时间戳显示一次

#### Scenario: swipe 删除
- **WHEN** 用户在某行向左 swipe 并确认删除
- **THEN** 对应 DataRecord 被删除，列表刷新

#### Scenario: 点击编辑
- **WHEN** 非多选模式下用户点击某行
- **THEN** 弹出编辑 Sheet，预填该 DataRecord 当前数据

#### Scenario: 长按进入多选
- **WHEN** 用户长按某行
- **THEN** 进入多选模式，该行自动选中，底部出现删除操作栏

#### Scenario: 多选全选可见
- **WHEN** 多选模式下用户点击"全选"
- **THEN** 当前可见的最多 5 条记录全部选中