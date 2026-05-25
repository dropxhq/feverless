## ADDED Requirements

### Requirement: CSV 文件选择与解析
系统 SHALL 在 ProfileView 数据管理区提供"导入数据"入口，点击后打开系统文件选择器（限制为 `.csv` 文件类型）。选择文件后系统 SHALL 读取 Header 行及唯一值采样，并按以下优先级对列名和列值进行自动识别：

**列名自动识别顺序**：
1. 精确匹配内部字段名（如 `timestamp`）
2. 匹配内置中文别名（如 `时间` → `timestamp`）
3. 匹配用户已保存的列名别名（UserDefaults）
4. 无法识别 → 进入 `ColumnMappingSheet`

**体温位置列识别**：列名或列值可通过 `TemperaturePositionCatalog` 的关键词表自动识别对应 canonicalName（如"液温"→"腋下"）。

**列值自动识别（体温位置）**：
1. 精确匹配 TemperaturePositionCatalog 中的 canonicalName
2. 匹配 TemperaturePositionCatalog 中的 keywords
3. 用户已保存的值别名
4. 无法识别 → 进入 `ValueMappingSheet`

日期格式检测规则与原有规范保持一致（多种格式降级尝试）。

**解析输出**：`CSVParseResult` SHALL 包含 `[DataRecord]`（替代原有的 `temperatureRows: [TemperatureRecord]` 和 `medicationRows: [MedicationRecord]`），每个 DataRecord 可含多个 `TemperatureReading` 和多个 `MedicationUsage`。

**空行忽略规则**：解析完一行后，若产生的 DataRecord 满足 `temperatures.isEmpty && medications.isEmpty && notes.isEmpty`，系统 SHALL 静默丢弃该记录，不计入有效数据，不触发错误。

#### Scenario: 已知格式 CSV 自动通过，无需映射界面
- **WHEN** 用户选择一个由 feverless 导出的 CSV 文件（中文列名格式）
- **THEN** 系统自动识别所有列名和位置值，直接进入导入预览，不弹出任何映射界面

#### Scenario: 一行包含多个体温位置
- **WHEN** CSV 行包含"腋温"列值 37.8 和"额温"列值 37.5
- **THEN** 解析产生一个 DataRecord，temperatures 包含两个 TemperatureReading

#### Scenario: 一行包含多个药品
- **WHEN** CSV 行的备注列文本匹配"布洛芬"和"泰诺"两个关键词
- **THEN** 解析产生一个 DataRecord，medications 包含两个 MedicationUsage

#### Scenario: 空行静默忽略
- **WHEN** CSV 中某行所有有效列均为空值
- **THEN** 系统不创建 DataRecord，不报错，继续处理下一行

#### Scenario: 某行日期格式无法识别
- **WHEN** CSV 第 5 行的时间值为 "invalid-date"
- **THEN** 弹出 Alert："格式有误：第 5 行时间无法解析（"invalid-date"）"，不写入任何记录

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

### Requirement: 导入预览与确认
解析成功后系统 SHALL 弹出预览 Sheet，展示：
1. **记录统计**：将导入的有效 DataRecord 数、其中含体温的记录数、含用药的记录数、因重复将跳过的记录数
2. **示例记录**（最多 3 条）：展示 DataRecord 内容（各体温读数位置+值、药品名、备注、时间）
3. **映射摘要**（若本次应用了自定义映射）：列名映射条数、值别名映射条数、关键词提取记录数

重复记录判定：与当前孩子已有 DataRecord 的 `(timestamp, temperatures首项, medications首项)` 精确匹配（精确到秒）则视为重复，自动跳过。

#### Scenario: 预览展示多体温读数
- **WHEN** DataRecord 包含两个 TemperatureReading
- **THEN** 示例记录展示"腋下 37.8°C · 额温 37.5°C · 10:30"

#### Scenario: 确认导入写入 DataRecord
- **WHEN** 用户点击"确认导入"
- **THEN** 将非重复 DataRecord（含子对象）写入 SwiftData，关联到当前选中孩子
