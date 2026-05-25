## ADDED Requirements

### Requirement: 体温趋势折线图
图表页 SHALL 使用 Swift Charts 渲染当前发烧周期内的体温折线图。数据源改为查询 `DataRecord`，遍历 `DataRecord.temperatures` 展开 `TemperatureReading` 作为图表点；Y 轴参考线（37.0°C）和发烧阈值线通过 `TemperaturePositionCatalog` 动态获取（默认腋下阈值 37.5°C）。

#### Scenario: 展示折线图
- **WHEN** 存在当前发烧周期的 DataRecord 含 TemperatureReading
- **THEN** 折线图展示各读数点，Y 轴包含 36–40°C 范围

#### Scenario: 无数据时
- **WHEN** 无任何 DataRecord 或所有 DataRecord.temperatures 均为空
- **THEN** 展示空状态占位图

---
### Requirement: 用药标记
图表页 SHALL 在折线图上用 `RuleMark`（竖线）标注每次用药时间。数据源改为遍历 `DataRecord.medications`，取父 `DataRecord.timestamp` 作为标注时间；颜色通过 `MedicationCatalog.shared.findByCanonicalName()` 查找（布洛芬黄色、对乙酰氨基酚蓝色，其他灰色）。

#### Scenario: 用药时间标注
- **WHEN** DataRecord.medications 包含布洛芬 MedicationUsage
- **THEN** 对应 timestamp 出现黄色竖线标注

---
### Requirement: 时间范围筛选
图表页 SHALL 提供"今天 / 昨天 / 7天"三档时间范围筛选，默认"今天"。

#### Scenario: 切换时间范围
- **WHEN** 用户点击"7天"
- **THEN** 图表 X 轴扩展为最近 7 天，展示全部记录

### Requirement: 记录明细列表
图表页 SHALL 在图表下方展示当前时间范围内的所有 DataRecord，按 timestamp 倒序排列。每个 DataRecord 可展开显示其所有 TemperatureReading 和 MedicationUsage。测量方式显示 `TemperatureReading.positionRaw`（即 canonicalName，如"腋下"）。

#### Scenario: 展示含多体温的记录
- **WHEN** DataRecord 包含两个 TemperatureReading
- **THEN** 记录行展示"腋下 38.0°C · 额温 37.8°C · 10:30"
