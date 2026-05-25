## ADDED Requirements

### Requirement: CSV 导出入口与时间范围选择
系统 SHALL 在 ProfileView 数据管理区提供"导出数据"入口，点击后弹出导出配置 Sheet，用户 SHALL 能选择以下时间范围之一：最近 7 天、最近 30 天、最近 3 个月、全部数据、自定义范围（日期区间选择器）。Sheet 内 SHALL 实时展示当前范围内将导出的体温记录数和用药记录数。

#### Scenario: 选择预设时间范围后看到预览数量
- **WHEN** 用户在导出 Sheet 中选择"最近 30 天"
- **THEN** Sheet 底部实时显示该范围内的体温记录数和用药记录数

#### Scenario: 选择自定义时间范围
- **WHEN** 用户选择"自定义范围"并设置开始/结束日期
- **THEN** 预览数量随日期调整实时更新

### Requirement: CSV 文件生成与分发
系统 SHALL 将当前选中孩子在所选时间范围内的所有 `DataRecord` 导出为单一 CSV 文件。

每个 DataRecord 可能产生多行 CSV 输出：
- 每个 `TemperatureReading` 产生一行，`记录类型=体温`，`数值=value`，`测量方式=positionRaw`
- 每个 `MedicationUsage` 产生一行，`记录类型=用药`，`药物类型=medicationNameRaw`
- 若 DataRecord 包含体温和用药，用药行的`同步体温`列填写同一 DataRecord 中第一个 TemperatureReading 的 value
- `备注` 列只写入第一行（避免重复），或写入每行（实现可选，保持一致即可）
- 时间列均使用父 DataRecord.timestamp

**CSV 格式**（表头和字段同原规范）：
`时间,记录类型,数值,测量方式,药物类型,同步体温,备注`

测量方式值 SHALL 使用 `TemperatureReading.positionRaw`（即 canonicalName，如"腋下"、"左侧液温"）。药物类型值 SHALL 使用 `MedicationUsage.medicationNameRaw`（即 canonicalName）。

#### Scenario: 含多体温的 DataRecord 导出
- **WHEN** DataRecord 包含腋下 38.0°C 和额温 37.8°C 两个 TemperatureReading
- **THEN** CSV 输出两行，时间相同，分别为 `体温,38.0,腋下,,,...` 和 `体温,37.8,额温,,,...`

#### Scenario: 含体温和用药的 DataRecord 导出
- **WHEN** DataRecord 包含腋下 38.0°C 和布洛芬
- **THEN** CSV 输出体温行 `体温,38.0,腋下,,,` 和用药行 `用药,,,布洛芬,38.0,`（同步体温填 38.0）

#### Scenario: 自建体温位置导出
- **WHEN** TemperatureReading.positionRaw="左侧液温"
- **THEN** CSV 该行测量方式列值为"左侧液温"

---

### Requirement: CSV 导出入口与时间范围选择（保持不变）
系统 SHALL 在 ProfileView 数据管理区提供"导出数据"入口，点击后弹出导出配置 Sheet，用户可选择时间范围，Sheet 内实时展示将导出的记录数（改为"N 条 DataRecord，含 M 次体温、K 次用药"）。

#### Scenario: 选择时间范围后看到预览数量
- **WHEN** 用户选择"最近 30 天"
- **THEN** Sheet 显示该范围内 DataRecord 总数及其中体温/用药统计
