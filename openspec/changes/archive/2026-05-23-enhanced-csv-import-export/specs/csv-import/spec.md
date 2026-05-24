## MODIFIED Requirements

### Requirement: CSV 文件选择与解析
系统 SHALL 在 ProfileView 数据管理区提供"导入数据"入口，点击后打开系统文件选择
器（限制为 `.csv` 文件类型）。选择文件后系统 SHALL 读取 Header 行及唯一值采样，
并按以下优先级对列名和列值进行自动识别：

**列名自动识别顺序**：
1. 精确匹配内部字段名（rawValue，如 `timestamp`）
2. 匹配内置中文别名（如 `时间` → `timestamp`）
3. 匹配用户已保存的列名别名（UserDefaults）
4. 无法识别 → 进入 `ColumnMappingSheet`

**列值自动识别顺序（枚举列）**：
1. 精确匹配枚举 rawValue（如 `ibuprofen`）
2. 匹配枚举 displayName（如 `布洛芬`）
3. 匹配用户已保存的值别名（UserDefaults）
4. 无法识别 → 进入 `ValueMappingSheet`

日期格式检测规则与原有规范保持一致（5 种格式降级尝试）。

#### Scenario: 已知格式 CSV 自动通过，无需映射界面
- **WHEN** 用户选择一个由 feverless 导出的 CSV 文件（中文列名格式）
- **THEN** 系统自动识别所有列名和枚举值，直接进入导入预览，不弹出任何映射界面

#### Scenario: 旧版英文格式 CSV 自动向后兼容
- **WHEN** 用户选择使用旧版 `record_type,timestamp,...` 格式的 CSV
- **THEN** 系统通过 rawValue 精确匹配自动识别，直接进入导入预览，无需配置

#### Scenario: 未知列名触发列名映射界面
- **WHEN** CSV 文件包含无法自动识别的列名（如"日期"、"液温"）
- **THEN** 自动弹出 ColumnMappingSheet，展示待映射列

#### Scenario: ISO 8601 日期格式自动识别
- **WHEN** CSV 文件的时间列使用 ISO 8601 含时区格式
- **THEN** 解析成功，时间戳精确保留时区信息

#### Scenario: 非标准日期格式自动降级
- **WHEN** CSV 文件的时间列使用 `2026/05/20 10:30` 格式
- **THEN** 系统成功解析并补充设备本地时区

---

### Requirement: 格式错误提示
系统 SHALL 在解析过程中无法完成映射（必要字段缺失）或数据无效时提示用户。必要字
段（记录类型、时间）在 `ColumnMappingSheet` 中强制要求完成映射，未映射时"继续"
按钮禁用；数据行级错误（时间戳无法解析、体温数值非法）SHALL 弹出 Alert，提示行
号和原始值，导入流程终止，不写入任何数据。

#### Scenario: 表头缺失但用户完成映射后可继续
- **WHEN** CSV 文件缺少标准"记录类型"列，但用户在 ColumnMappingSheet 将其他列
  映射到"记录类型"
- **THEN** 映射完成后可正常继续导入流程

#### Scenario: 某行日期格式无法识别
- **WHEN** CSV 第 5 行的时间值为 "invalid-date"
- **THEN** 弹出 Alert："格式有误：第 5 行时间无法解析（"invalid-date"）"，不写入
  任何记录

#### Scenario: 错误后不写入数据
- **WHEN** 解析过程中发现任何数据行级格式错误
- **THEN** 不向 SwiftData 写入任何记录，数据库保持原状

---

### Requirement: 导入预览与确认
解析成功后系统 SHALL 弹出增强版预览 Sheet，展示以下内容：
1. **记录统计**：将导入的体温记录数、用药记录数、因重复将跳过的记录数
2. **示例记录**（最多 3 条）：使用中文显示名展示具体记录内容（温度值 + 测量方式
   + 时间 / 药物类型 + 时间）
3. **映射摘要**（若本次应用了自定义映射）：列名映射条数和值别名映射条数，以及每
   条映射命中的记录数

重复记录判定规则不变：与当前孩子已有记录的 `(timestamp, record_type)` 精确相同
（精确到秒）则视为重复，自动跳过。

#### Scenario: 预览使用中文显示名
- **WHEN** 导入预览展示体温记录示例
- **THEN** 测量方式显示"腋下"而非"axillary"，药物类型显示"布洛芬"而非
  "ibuprofen"

#### Scenario: 显示映射摘要
- **WHEN** 本次导入应用了自定义映射（如"美林 → 布洛芬"命中 3 条）
- **THEN** 预览底部展示映射摘要："值映射 5 条记录 — '美林' ×3 → 布洛芬，'退烧药'
  ×2 → 布洛芬"

#### Scenario: 关键词提取记录在摘要中标注
- **WHEN** 本次导入通过关键词提取产生了用药记录
- **THEN** 预览摘要中显示"关键词提取 N 条用药记录"

#### Scenario: 用户取消导入
- **WHEN** 用户在预览 Sheet 点击"取消"
- **THEN** 关闭 Sheet，不写入任何数据，映射配置也不保存

#### Scenario: 确认导入写入数据并保存配置
- **WHEN** 用户在预览 Sheet 点击"确认导入"
- **THEN** 将非重复记录写入 SwiftData，关联到当前选中孩子，保存本次映射配置到
  UserDefaults，并显示成功 Toast

#### Scenario: 所有记录均重复
- **WHEN** CSV 中所有记录均已存在于当前孩子的数据中
- **THEN** 预览 Sheet 显示"全部 N 条记录已存在，无需导入"，确认按钮禁用
