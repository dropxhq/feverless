## MODIFIED Requirements

### Requirement: 用药间隔校验
系统 SHALL 根据 `MedicationCatalog` 中对应药品定义的安全配置计算下次可用时间。`MedicationSafetyViewModel.availability(forMedicationName:catalog:childId:records:)` SHALL 接受 `[DataRecord]` 作为 `records` 参数（替代原 `[MedicationRecord]`），从 `DataRecord.medications` 关系中展开 `MedicationUsage` 进行过滤和时间计算，时间戳取自父 `DataRecord.timestamp`。

#### Scenario: 布洛芬间隔未到
- **WHEN** 上次含布洛芬的 DataRecord 不足 6 小时前
- **THEN** 系统返回剩余等待时长（分钟精度）

#### Scenario: 布洛芬可用
- **WHEN** 上次含布洛芬的 DataRecord 已满 6 小时
- **THEN** 系统返回"可用"状态

#### Scenario: 每日上限达到
- **WHEN** 当日含布洛芬的 DataRecord 已有 4 条
- **THEN** 系统标记"今日已达上限"

#### Scenario: 自建药品无安全限制
- **WHEN** 用户服用自建药品"退热贴"（minIntervalHours=nil）
- **THEN** 系统始终返回"可用"状态，不显示倒计时

---

### Requirement: 用药状态枚举（保持不变）
系统 SHALL 提供 `MedicationAvailability` 枚举，包含 `.available`、`.cooldown(remaining: TimeInterval)`、`.dailyLimitReached` 三种状态，供 UI 层消费。

#### Scenario: 获取当前可用状态
- **WHEN** 调用 `availability(forMedicationName: "布洛芬", childId: child.id, records: dataRecords, catalog: catalog)`
- **THEN** 返回对应的 MedicationAvailability 枚举值
