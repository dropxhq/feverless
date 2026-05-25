## ADDED Requirements

### Requirement: 单条记录删除
系统 SHALL 允许用户在记录列表中通过向左 swipe 删除单条 DataRecord（含其所有子记录）。

#### Scenario: swipe 删除纯体温记录
- **WHEN** 用户在记录行向左 swipe 并点击"删除"
- **THEN** 该 DataRecord 及其 TemperatureReading 被从 SwiftData 中删除，列表移除该行

#### Scenario: swipe 删除含多条子记录的 DataRecord
- **WHEN** 用户 swipe 一条同时含体温和用药的合并行并点击"删除"
- **THEN** 弹出确认提示说明将同时删除体温和用药记录，用户确认后删除整条 DataRecord

#### Scenario: 删除后 Widget 更新
- **WHEN** 删除成功
- **THEN** 调用 `WidgetCenter.shared.reloadAllTimelines()` 刷新 Widget 数据

### Requirement: 编辑已有记录
系统 SHALL 允许用户点击记录行弹出编辑 Sheet，修改该 DataRecord 的体温值、测量位置、药品名称、时间戳或备注，保存后立即生效。

#### Scenario: 点击体温记录行进入编辑
- **WHEN** 用户点击一条体温记录行（非多选模式下）
- **THEN** 弹出编辑 Sheet，预填当前体温值、测量位置、时间戳和备注

#### Scenario: 点击用药记录行进入编辑
- **WHEN** 用户点击一条用药记录行（非多选模式下）
- **THEN** 弹出编辑 Sheet，预填当前药品名称、时间戳和备注

#### Scenario: 点击合并行进入编辑
- **WHEN** 用户点击一条同时含体温和用药的合并行
- **THEN** 弹出编辑 Sheet，同时展示体温编辑区和用药编辑区，均预填当前值

#### Scenario: 保存编辑
- **WHEN** 用户修改字段后点击"保存"
- **THEN** DataRecord 的 timestamp、notes 及对应子记录字段被更新，Sheet 关闭，列表刷新，Widget 重新加载

#### Scenario: 取消编辑
- **WHEN** 用户点击"取消"
- **THEN** 所有修改丢弃，Sheet 关闭，原数据不变

### Requirement: 长按进入多选模式
系统 SHALL 允许用户长按任意记录行进入多选模式，长按的那条记录自动进入选中状态。

#### Scenario: 长按触发多选
- **WHEN** 用户长按某条记录行
- **THEN** 列表进入多选模式，所有行左侧出现圆形 checkbox，被长按的行呈选中状态，底部出现操作栏（含删除按钮和"已选 N 条"计数）

#### Scenario: 多选模式下点击切换选中
- **WHEN** 多选模式下用户点击某行
- **THEN** 该行选中状态切换（选中→取消 / 取消→选中）

#### Scenario: 退出多选模式
- **WHEN** 用户点击"取消"或清空所有选中后
- **THEN** 退出多选模式，checkbox 消失，底部操作栏隐藏

### Requirement: 批量删除选中记录
系统 SHALL 允许用户在多选模式下删除所有选中的 DataRecord。

#### Scenario: 批量删除
- **WHEN** 用户在多选模式下选中若干记录后点击底部"删除"按钮
- **THEN** 弹出确认对话框显示将删除的条数，用户确认后批量删除所有选中 DataRecord，退出多选模式，Widget 刷新

#### Scenario: 未选中时删除按钮禁用
- **WHEN** 多选模式下未选中任何记录
- **THEN** 底部"删除"按钮呈禁用状态

### Requirement: 全选可见记录
系统 SHALL 在多选模式下提供"全选"按钮，选中当前列表中所有可见的 DataRecord。

#### Scenario: 全选
- **WHEN** 多选模式下用户点击"全选"
- **THEN** 当前列表所有可见行均进入选中状态，计数更新为可见总数

#### Scenario: 全选后反选
- **WHEN** 已全选状态下用户点击"全选"（此时显示为"取消全选"）
- **THEN** 所有行取消选中

#### Scenario: 全选不影响不可见记录
- **WHEN** 用户点击"全选"
- **THEN** 未渲染在屏幕上或不在当前时间范围内的记录不受影响，不被选中

### Requirement: 合并行展示
系统 SHALL 将同时含 TemperatureReading 和 MedicationUsage 的 DataRecord 在列表中显示为单一合并行，而非两行。

#### Scenario: 合并行样式
- **WHEN** 一条 DataRecord 同时含体温和用药子记录
- **THEN** 列表中该 DataRecord 显示为单行，同时展示体温图标+数值和用药图标+药名，时间戳显示一次

#### Scenario: 纯体温行样式
- **WHEN** DataRecord 仅含 TemperatureReading
- **THEN** 显示原有体温行样式（温度计图标、°C 值、测量位置、发烧状态标签）

#### Scenario: 纯用药行样式
- **WHEN** DataRecord 仅含 MedicationUsage
- **THEN** 显示原有用药行样式（药丸图标、药品名）
