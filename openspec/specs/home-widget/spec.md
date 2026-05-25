## ADDED Requirements

### Requirement: 小尺寸 Widget（systemSmall）
Widget SHALL 提供小尺寸视图，展示：儿童姓名、当前/最新体温、发烧状态（发烧中🔴/正常🟢）、最近记录时间。

#### Scenario: 发烧中小尺寸
- **WHEN** 最新体温 ≥ 发烧阈值
- **THEN** Widget 显示红色状态指示、体温值、"发烧中"文字

#### Scenario: 正常小尺寸
- **WHEN** 最新体温 < 发烧阈值或无记录
- **THEN** Widget 显示绿色/灰色状态和体温值（或"暂无记录"）

### Requirement: 中尺寸 Widget（systemMedium）
Widget SHALL 提供中尺寸视图，在小尺寸内容基础上额外展示：发烧持续时长、布洛芬/对乙酰氨基酚的用药状态（可用 / 剩余时长）、快捷操作链接（记体温/记用药）。

#### Scenario: 用药倒计时展示
- **WHEN** 中尺寸 Widget 渲染
- **THEN** 显示两种药物的用药状态，包含"Xh Ym 后可用"或"现可用"

### Requirement: Widget 数据读取
Widget Provider SHALL 从 App Group SwiftData 存储（`group.top.dropx.feverless`）只读获取最新数据，不执行写入操作。`Schema` SHALL 包含 `[Child.self, DataRecord.self, TemperatureReading.self, MedicationUsage.self]`（替代原有的 `TemperatureRecord` 和 `MedicationRecord`）。

最新体温通过查询最近 DataRecord，展开 `temperatures` 获取第一个 TemperatureReading；发烧判定通过 `TemperaturePositionCatalog.shared`（Widget 侧也加载 catalog）。用药状态通过展开 `medications` 计算。

#### Scenario: Widget Schema 包含新模型
- **WHEN** FeverWidgetProvider 构建 ModelContainer
- **THEN** Schema 包含 DataRecord、TemperatureReading、MedicationUsage、Child

#### Scenario: 读取最新体温
- **WHEN** Widget timeline 刷新
- **THEN** Provider 从最新 DataRecord.temperatures 取第一个读数作为当前体温

---
### Requirement: 强制刷新 Widget
主 App 每次保存新记录后 SHALL 调用 `WidgetCenter.shared.reloadAllTimelines()`，触发 Widget 立即更新。

#### Scenario: 录入后 Widget 更新
- **WHEN** 用户在主 App 保存一条新体温记录
- **THEN** 桌面 Widget 在数秒内展示最新体温值

### Requirement: Widget 深度链接
Widget 上的快捷操作按钮 SHALL 通过 Deep Link URL（`feverless://record?type=temperature` / `feverless://record?type=medication`）跳转到主 App 对应记录页。

#### Scenario: 点击"记体温"
- **WHEN** 用户点击 Widget 上的"记体温"按钮
- **THEN** 主 App 打开并直接展示体温记录 sheet

### Requirement: 小尺寸 Widget（保持展示逻辑不变）
Widget SHALL 提供小尺寸视图，展示：儿童姓名、当前/最新体温、发烧状态（发烧中🔴/正常🟢）、最近记录时间。

#### Scenario: 发烧中小尺寸
- **WHEN** 最新 TemperatureReading.isFever == true
- **THEN** Widget 显示红色状态指示、体温值、"发烧中"文字

---

### Requirement: 中尺寸 Widget（保持展示逻辑不变）
Widget SHALL 提供中尺寸视图，额外展示：发烧持续时长、`hasReminder=true` 药品的用药状态、快捷操作链接。

#### Scenario: 用药倒计时展示
- **WHEN** 中尺寸 Widget 渲染
- **THEN** 显示 hasReminder=true 药品的用药状态（"Xh Ym 后可用"或"现可用"）
