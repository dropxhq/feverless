## ADDED Requirements

### Requirement: 用药间隔校验
系统 SHALL 根据以下规则计算每种药物的下次可用时间：布洛芬最短间隔 6 小时、每日上限 4 次；对乙酰氨基酚最短间隔 4 小时、每日上限 5 次。

#### Scenario: 布洛芬间隔未到
- **WHEN** 上次服用布洛芬不足 6 小时
- **THEN** 系统返回剩余等待时长（分钟精度）

#### Scenario: 布洛芬可用
- **WHEN** 上次服用布洛芬已满 6 小时
- **THEN** 系统返回"可用"状态

#### Scenario: 每日上限达到
- **WHEN** 当日布洛芬已服用 4 次
- **THEN** 系统标记"今日已达上限"

### Requirement: 用药状态枚举
系统 SHALL 提供 `MedicationAvailability` 枚举，包含 `.available`、`.cooldown(remaining: TimeInterval)`、`.dailyLimitReached` 三种状态，供 UI 层消费。

#### Scenario: 获取当前可用状态
- **WHEN** 调用 `availability(for: .ibuprofen, child: child, in: context)`
- **THEN** 返回对应的 MedicationAvailability 枚举值

### Requirement: 倒计时实时更新
UI SHALL 使用 `TimelineView(.periodic(from:by:))` 或 `Timer` 每分钟刷新用药倒计时显示。

#### Scenario: 倒计时变化
- **WHEN** 距下次可用时间每过 1 分钟
- **THEN** 首页用药提醒区域自动更新剩余时长
