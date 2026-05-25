## MODIFIED Requirements

### Requirement: 记录明细列表
图表页 SHALL 在图表下方展示当前时间范围内所有 DataRecord，每条 DataRecord 显示为一行（同时含体温和用药者合并为单行），按时间倒序排列。列表支持 swipe 删除、点击编辑（弹出编辑 Sheet）、长按进入多选批量删除、按日期分组全选、全选当前时间范围内可见记录。切换时间范围时退出多选模式并清空选中状态。

#### Scenario: 展示记录明细（纯体温）
- **WHEN** DataRecord 仅含 TemperatureReading
- **THEN** 列表行显示温度计图标、°C 值、测量位置、格式化时间、发烧状态标签

#### Scenario: 展示记录明细（纯用药）
- **WHEN** DataRecord 仅含 MedicationUsage
- **THEN** 列表行显示药丸图标、药品名、格式化时间

#### Scenario: 展示记录明细（合并行）
- **WHEN** DataRecord 同时含体温和用药
- **THEN** 列表行合并展示体温信息和用药信息，时间戳显示一次

#### Scenario: swipe 删除
- **WHEN** 用户在某行向左 swipe 并确认删除
- **THEN** 对应 DataRecord 被删除，列表和图表刷新

#### Scenario: 点击编辑
- **WHEN** 非多选模式下用户点击某行
- **THEN** 弹出编辑 Sheet，预填该 DataRecord 当前数据

#### Scenario: 长按进入多选
- **WHEN** 用户长按某行
- **THEN** 进入多选模式，该行自动选中，底部出现删除操作栏

#### Scenario: 按日期分组全选
- **WHEN** 多选模式下用户点击某日期分组 header 中的"全选本组"按钮
- **THEN** 该日期分组内所有可见行均进入选中状态

#### Scenario: 全选当前范围可见记录
- **WHEN** 多选模式下用户点击全局"全选"
- **THEN** 当前时间范围内所有可见 DataRecord 均选中

#### Scenario: 切换时间范围清空选中
- **WHEN** 多选模式下用户切换时间范围
- **THEN** 退出多选模式，选中集合清空
