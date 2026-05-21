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
系统 SHALL 将当前选中孩子在所选时间范围内的所有体温记录和用药记录导出为单一 CSV 文件，文件名格式为 `feverless_<孩子名>_<开始日期>_<结束日期>.csv`（全部数据时日期范围取实际最早和最晚记录日期）。生成后 SHALL 通过系统 ShareSheet 呈现，支持保存到文件 App、AirDrop 及其他共享方式。

**CSV 格式规范**：
- 第一行为表头：`record_type,timestamp,value,method,medication_type,concurrent_temperature,notes`
- `record_type` 值为 `temperature` 或 `medication`
- `timestamp` 使用 ISO 8601 含时区格式（`yyyy-MM-dd'T'HH:mm:ssXXXXX`）
- 不适用字段留空
- 含逗号、双引号或换行的字段值须用双引号包裹（RFC 4180）
- 文件编码为 UTF-8

#### Scenario: 成功生成并分享 CSV
- **WHEN** 用户点击导出 Sheet 中的"导出 CSV"按钮
- **THEN** 系统弹出 ShareSheet，文件名符合命名规范，文件内容包含该孩子所选时间范围内所有体温和用药记录

#### Scenario: 无记录时导出
- **WHEN** 所选时间范围内无任何记录
- **THEN** 导出按钮显示为禁用状态（灰色不可点击），并提示"所选时间范围内无记录"
