## MODIFIED Requirements

### Requirement: 用药间隔校验
系统 SHALL 根据 `MedicationCatalog` 中对应药品定义的安全配置计算下次可用时间。若药品定义的 `hasReminder=false` 或 `minIntervalHours=nil`，则该药品始终返回 `.available`；若 `maxDailyDoses=nil`，则不检查每日上限。

内置药品的默认配置：布洛芬最短间隔 6 小时、每日上限 4 次；对乙酰氨基酚最短间隔 4 小时、每日上限 5 次。用户自建药品默认 `hasReminder=true`，但 `minIntervalHours=nil`、`maxDailyDoses=nil`（无限制）。

#### Scenario: 布洛芬间隔未到
- **WHEN** 上次服用布洛芬不足 6 小时
- **THEN** 系统返回剩余等待时长（分钟精度）

#### Scenario: 布洛芬可用
- **WHEN** 上次服用布洛芬已满 6 小时
- **THEN** 系统返回"可用"状态

#### Scenario: 每日上限达到
- **WHEN** 当日布洛芬已服用 4 次
- **THEN** 系统标记"今日已达上限"

#### Scenario: 自建药品无安全限制
- **WHEN** 用户服用自建药品"退热贴"（minIntervalHours=nil）
- **THEN** 系统始终返回"可用"状态，不显示倒计时

#### Scenario: 禁用提醒的药品
- **WHEN** 药品定义的 hasReminder=false
- **THEN** 系统始终返回"可用"状态，不参与安全检查

---

### Requirement: 用药状态枚举
系统 SHALL 提供 `MedicationAvailability` 枚举，包含 `.available`、`.cooldown(remaining: TimeInterval)`、`.dailyLimitReached` 三种状态，供 UI 层消费。

#### Scenario: 获取当前可用状态
- **WHEN** 调用 `availability(forMedicationName: "布洛芬", childId: child.id, records: records, catalog: catalog)`
- **THEN** 返回对应的 MedicationAvailability 枚举值
