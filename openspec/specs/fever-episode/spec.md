## ADDED Requirements

### Requirement: 发烧周期自动检测
系统 SHALL 根据数据记录自动判断发烧周期：`FeverEpisodeDetector.currentEpisode(for:)` SHALL 接受 `[DataRecord]` 作为输入，遍历所有 `DataRecord.temperatures` 子读数，通过 `TemperatureReading.isFever` 判断是否发烧。

当存在 isFever=true 的读数时，发烧周期开始；当后续所有读数均不发烧且已连续 24 小时无高温时，发烧周期自动结束。

#### Scenario: 发烧开始
- **WHEN** 新录入 DataRecord，其 temperatures 包含 TemperatureReading(positionRaw:"腋下", value:38.0)
- **THEN** 系统标记发烧周期开始时间为该 DataRecord.timestamp

#### Scenario: 发烧进行中
- **WHEN** 存在进行中的发烧周期
- **THEN** 首页展示"发烧中"状态和持续时长

#### Scenario: 发烧自动结束
- **WHEN** 上一条含高温读数的 DataRecord 距今超过 24 小时，且此后无新的高温 DataRecord
- **THEN** 发烧周期标记为已结束

---
### Requirement: 发烧阈值按测量方式区分
系统 SHALL 按测量方式应用不同阈值：腋下/额温 ≥ 37.5°C，耳温/肛温/口腔 ≥ 38.0°C。

#### Scenario: 腋下测量阈值
- **WHEN** 腋下测量体温为 37.5°C
- **THEN** 系统判定为发烧

#### Scenario: 口腔测量阈值
- **WHEN** 口腔测量体温为 37.9°C
- **THEN** 系统判定为正常

### Requirement: 发烧持续时长计算
系统 SHALL 计算当前发烧周期持续时长（从第一条高温记录到当前时间），精确到分钟，以"Xh Ym"格式展示。

#### Scenario: 计算发烧时长
- **WHEN** 发烧周期从 13:00 开始，当前时间为 21:30
- **THEN** 系统返回"8h 30m"

### Requirement: 发烧阈值按测量位置区分
系统 SHALL 通过 `TemperaturePositionCatalog.shared.find(positionRaw)?.feverThreshold` 获取各测量位置的发烧阈值，不再使用 `MeasurementMethod` 枚举的静态属性。自定义位置使用用户配置的阈值，未找到定义时默认 37.5°C。

#### Scenario: 内置位置阈值
- **WHEN** TemperatureReading.positionRaw="腋下", value=37.5
- **THEN** isFever 返回 true（腋下阈值 37.5°C）

#### Scenario: 自建位置阈值
- **WHEN** 用户自建位置"左侧液温"设定 feverThreshold=37.5，读数 value=37.4
- **THEN** isFever 返回 false

---

### Requirement: 发烧持续时长计算（保持不变）
系统 SHALL 计算当前发烧周期持续时长（从第一条高温 DataRecord 的 timestamp 到当前时间），精确到分钟，以"Xh Ym"格式展示。

#### Scenario: 计算发烧时长
- **WHEN** 发烧周期从 13:00 开始，当前时间为 21:30
- **THEN** 系统返回"8h 30m"
