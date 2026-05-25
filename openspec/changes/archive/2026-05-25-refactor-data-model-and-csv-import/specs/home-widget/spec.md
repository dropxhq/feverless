## MODIFIED Requirements

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
