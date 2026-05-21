## ADDED Requirements

### Requirement: CSV 文件选择与解析
系统 SHALL 在 ProfileView 数据管理区提供"导入数据"入口，点击后打开系统文件选择器（限制为 `.csv` 文件类型）。选择文件后系统 SHALL 自动解析文件，解析时 SHALL 自动检测 `timestamp` 列的日期格式，按以下优先级依次尝试：
1. ISO 8601 含时区（`2026-05-20T10:30:00+08:00`）
2. ISO 8601 UTC（`2026-05-20T10:30:00Z`）
3. ISO 8601 无时区（`2026-05-20T10:30:00`，补充设备本地时区）
4. 中文常用格式（`2026/05/20 10:30`，补充设备本地时区）
5. 纯日期（`2026-05-20`，时间补 `00:00:00` + 本地时区）

#### Scenario: 选择 CSV 文件后自动解析
- **WHEN** 用户从文件选择器选择一个 CSV 文件
- **THEN** 系统自动解析文件，无需用户手动操作

#### Scenario: ISO 8601 日期格式自动识别
- **WHEN** CSV 文件的 timestamp 列使用 ISO 8601 含时区格式
- **THEN** 解析成功，时间戳精确保留时区信息

#### Scenario: 非标准日期格式自动降级
- **WHEN** CSV 文件的 timestamp 列使用 `2026/05/20 10:30` 格式
- **THEN** 系统成功解析并补充设备本地时区

### Requirement: 格式错误提示
系统 SHALL 在解析失败时弹出 Alert，提示具体错误信息，包含出错的行号和原始值，并建议用户参考导出文件的格式。Alert 消失后导入流程终止，不写入任何数据。

格式错误包括但不限于：
- 表头列缺失（缺少必需列 `record_type`、`timestamp`）
- `record_type` 值不为 `temperature` 或 `medication`
- `timestamp` 无法被任何支持的格式解析
- 体温记录的 `value` 字段不是有效数字

#### Scenario: 表头缺失报错
- **WHEN** CSV 文件缺少 `record_type` 列
- **THEN** 弹出 Alert："格式有误：缺少必需列 record_type。请参考导出文件的格式。"

#### Scenario: 某行日期格式无法识别
- **WHEN** CSV 第 5 行的 timestamp 值为 "invalid-date"
- **THEN** 弹出 Alert："格式有误：第 5 行 timestamp 无法解析（"invalid-date"）。请参考导出文件的格式。"

#### Scenario: 错误后不写入数据
- **WHEN** 解析过程中发现任何格式错误
- **THEN** 不向 SwiftData 写入任何记录，数据库保持原状

### Requirement: 导入预览与确认
解析成功后系统 SHALL 弹出预览 Sheet，展示将导入的体温记录数、用药记录数以及因重复将跳过的记录数，用户确认后才执行写入。重复记录判定规则：与当前孩子已有记录的 `(timestamp, record_type)` 完全相同（精确到秒）则视为重复，自动跳过。

#### Scenario: 显示导入预览
- **WHEN** CSV 解析成功
- **THEN** 弹出预览 Sheet，显示"🌡 体温记录 X 条，💊 用药记录 Y 条，⏭ 重复跳过 Z 条"

#### Scenario: 用户取消导入
- **WHEN** 用户在预览 Sheet 点击"取消"
- **THEN** 关闭 Sheet，不写入任何数据

#### Scenario: 确认导入写入数据
- **WHEN** 用户在预览 Sheet 点击"确认导入"
- **THEN** 将非重复记录写入 SwiftData，关联到当前选中孩子，并显示成功 Toast："已成功导入 N 条记录"

#### Scenario: 所有记录均重复
- **WHEN** CSV 中所有记录均已存在于当前孩子的数据中
- **THEN** 预览 Sheet 显示"全部 N 条记录已存在，无需导入"，确认按钮禁用
