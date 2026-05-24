## ADDED Requirements

### Requirement: 重复/空列名配置不覆盖
当 CSV 文件中存在多列共享相同列名（包括空列名 `""`）时，系统 SHALL 保证用户在
`ColumnMappingSheet` 中对其中一列配置的有意义规则（`.keywordExtract`、`.compound`、
`.simple`）不被同名其他列的"忽略"规则覆盖。

具体规则：对同一列名，若已存在非 `.ignore` 的映射规则，后续处理到同名列时若其规则为
`.ignore`，SHALL 跳过写入，保留已有规则。

#### Scenario: 空列名多列只保留有效规则
- **WHEN** CSV 有两列列名均为空 `""`，用户将其中一列配置为"备注+关键词提取"，另一列默认"忽略"
- **THEN** 最终配置中 `columnMappings[""]` 为 `.keywordExtract`，不被"忽略"覆盖

#### Scenario: 重复非空列名同样适用
- **WHEN** CSV 有两列列名均为 `"备注"`，用户将第一列配置为"备注"字段，第二列默认"忽略"
- **THEN** 最终配置中保留第一列的 `.simple(field: "notes")` 规则

---

### Requirement: 关键词提取列在值检测阶段被正确识别
`proceedToValueDetection` 阶段 SHALL 正确识别配置中所有持有 `.keywordExtract` 规则
的列，不得因 `resolveColumnName` 不处理该规则类型而将其跳过。

识别方式：在枚举值扫描循环之外，额外遍历 `pendingConfig.columnMappings` 中所有
`extractsMedications == true` 的条目，将"需展示关键词配置"标记为 `true`。

#### Scenario: 关键词提取列触发值映射界面
- **WHEN** 用户在 ColumnMappingSheet 中为某列启用了"从此列提取药物关键词"
- **THEN** ColumnMappingSheet 完成后，即使没有任何枚举未识别值，系统也 SHALL 展示包含关键词配置区块的 ValueMappingSheet

#### Scenario: 关键词提取与枚举冲突同时存在
- **WHEN** 用户配置了关键词提取列，且某枚举列也存在未识别值
- **THEN** ValueMappingSheet 同时展示枚举未识别值分组和关键词配置区块

---

## MODIFIED Requirements

### Requirement: 列值别名映射配置界面
列名映射完成后，系统 SHALL 扫描所有具有枚举意义的列（记录类型、测量方式、药物类
型）中的唯一值，若存在无法自动识别的值（既非 rawValue 也非 displayName 也非已保
存别名），则弹出 `ValueMappingSheet`，集中展示所有未识别值及其出现次数，允许用户
为每个值选择对应的内部枚举值或选择"忽略（记为默认值）"。

**此外，只要任意列启用了关键词提取（`extractsMedications == true`），无论枚举冲突
是否存在，系统 SHALL 同样弹出 `ValueMappingSheet`，并在其中展示关键词配置区块。**

`ValueMappingSheet` 的关键词配置区块 SHALL 由独立的 `hasKeywordColumns: Bool` 参数
控制，不再依赖 `medication_type` 分组是否存在。

#### Scenario: 自动弹出值映射界面（枚举冲突）
- **WHEN** 枚举列中存在未识别的值（如"美林"在药物类型列）
- **THEN** ColumnMappingSheet 完成后自动弹出 ValueMappingSheet，按列分组展示所有未识别值及出现次数

#### Scenario: 自动弹出值映射界面（关键词提取）
- **WHEN** 没有枚举冲突，但用户为某列启用了关键词提取
- **THEN** ColumnMappingSheet 完成后自动弹出 ValueMappingSheet，界面中显示关键词配置区块

#### Scenario: 展示出现次数
- **WHEN** ValueMappingSheet 展示未识别值"美林"
- **THEN** 界面显示"美林（×3）"，帮助用户判断该值的重要性

#### Scenario: 忽略未识别值
- **WHEN** 用户对某个未识别值选择"忽略（记为默认值）"
- **THEN** 该值对应的行按字段默认值处理（药物类型 → 其他，测量方式 → 腋下）

#### Scenario: 关键词配置区块独立展示
- **WHEN** ValueMappingSheet 以 hasKeywordColumns=true 展示，但 valueGroups 中无 medication_type 分组
- **THEN** 关键词配置区块仍可见，用户可添加自定义关键词

---

### Requirement: 关键词词典与匹配规则
系统 SHALL 内置药物关键词词典，并允许用户在值映射界面添加自定义关键词。内置词典
涵盖常见药品名及品牌名，包括常用简写。关键词匹配 SHALL 使用子字符串包含（`contains`）
方式，并按词长降序匹配（长词优先），每个命中关键词创建一条用药记录。

内置词典（更新后）：
- 布洛芬：`["布洛芬", "美林", "芬必得", "Advil", "ibuprofen"]`
- 对乙酰氨基酚：`["对乙酰氨基酚", "对乙", "扑热息痛", "泰诺", "退热净", "acetaminophen"]`

#### Scenario: 内置关键词自动命中
- **WHEN** 备注列文本包含"美林"
- **THEN** 系统自动创建一条药物类型=布洛芬的用药记录，时间戳同所在行

#### Scenario: 简写关键词命中
- **WHEN** 备注列文本包含"对乙2毫升"
- **THEN** 系统自动创建一条药物类型=对乙酰氨基酚的用药记录

#### Scenario: 同行命中多个关键词
- **WHEN** 备注列文本包含"布洛芬和泰诺"
- **THEN** 系统创建两条用药记录（布洛芬 + 对乙酰氨基酚），时间戳相同

#### Scenario: 无关键词命中
- **WHEN** 备注列文本不包含任何已知关键词
- **THEN** 不创建用药记录，文本仅写入体温记录的备注字段
