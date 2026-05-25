## MODIFIED Requirements

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
