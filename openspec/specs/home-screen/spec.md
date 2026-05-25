## ADDED Requirements

### Requirement: 当前儿童状态卡片
首页 SHALL 展示当前选中儿童的发烧状态卡片。数据源改为查询 `DataRecord`，从 `DataRecord.temperatures` 中取最新读数；发烧判定通过 `TemperatureReading.isFever`（查询 `TemperaturePositionCatalog`）。

#### Scenario: 发烧中状态展示
- **WHEN** 最新 TemperatureReading.isFever == true
- **THEN** 卡片显示"发烧中"红色状态、持续时长、当前体温值和测量位置

#### Scenario: 正常状态展示
- **WHEN** 最新 TemperatureReading.isFever == false 或无 DataRecord
- **THEN** 卡片显示正常/无记录状态，不显示发烧时长

---
### Requirement: 用药安全提醒区域
首页 SHALL 展示各药品的用药状态。`MedicationSafetyViewModel.availability` 接收 `[DataRecord]`（替代原 `[MedicationRecord]`），药品列表从 `MedicationCatalog.shared.all` 动态读取（展示 `hasReminder=true` 的药品）。

#### Scenario: 用药冷却中
- **WHEN** 含该药品的最新 DataRecord 不足最短间隔前
- **THEN** 显示剩余等待时长（如"1h 40m 后"）

#### Scenario: 可用状态
- **WHEN** 含该药品的最新 DataRecord 已超过最短间隔
- **THEN** 显示"✓ 现可用"绿色标记

---
### Requirement: 快捷记录按钮
首页 SHALL 提供"记录体温"和"记录用药"两个快捷操作按钮，点击后以 sheet 方式弹出 RecordView。

#### Scenario: 弹出记录页
- **WHEN** 用户点击"记录体温"或"记录用药"
- **THEN** RecordView 以 sheet 形式呈现，并预选对应 Tab（体温/用药）

### Requirement: 最近记录列表
首页 SHALL 展示当前儿童最近 5 条 DataRecord（按 timestamp 倒序）。每条 DataRecord 展示：所有 TemperatureReading（位置名 + 温度值）、所有 MedicationUsage（药品名）、备注（若有）、时间。

#### Scenario: 展示最近记录
- **WHEN** 存在 DataRecord
- **THEN** 列表展示 DataRecord 内容，体温显示"腋下 38.0°C"，用药显示"布洛芬"
