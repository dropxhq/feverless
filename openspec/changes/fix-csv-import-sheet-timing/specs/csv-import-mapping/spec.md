## MODIFIED Requirements

### Requirement: 列名映射配置界面
导入时若 CSV 文件存在无法自动识别的列名，系统 SHALL 在解析后自动弹出
`ColumnMappingSheet`，展示 CSV 中所有列名，并允许用户为每列选择以下映射类型之一：

- **简单映射**：将该列的值写入指定内部字段
- **复合映射**：将该列的数值写入指定内部字段，并可附加若干固定字段值（如"液温"
  列 → 数值 + 固定测量方式=腋下）；当主字段选择"数值"时，系统 SHALL 自动展开附
  加字段区域
- **关键词提取**：将该列文本写入备注，并可勾选"同时从本列提取药物关键词"
- **忽略**：不导入该列

必要字段（`记录类型`、`时间`）未完成映射时，"继续"按钮 SHALL 保持禁用状态。

`ColumnMappingSheet` 关闭后，系统 SHALL 在 sheet dismiss 动画**完全结束后**再触发
后续的值检测流程（`proceedToValueDetection`），以避免 SwiftUI 多 sheet 时序冲突。

#### Scenario: 自动弹出列名映射界面
- **WHEN** CSV 文件存在至少一个无法自动识别的列名
- **THEN** 解析完成后自动弹出 ColumnMappingSheet，展示所有 CSV 列名及当前识别
  状态（已识别/未识别）

#### Scenario: 复合映射展开附加字段
- **WHEN** 用户将某列的主字段设为"数值"
- **THEN** 界面自动展开"同时固定以下字段"区域，可添加测量方式、记录类型等固定值

#### Scenario: 必要字段未映射时禁止继续
- **WHEN** "记录类型"或"时间"列尚未完成映射
- **THEN** ColumnMappingSheet 底部"继续"按钮保持禁用，并提示哪些必要字段缺失

#### Scenario: 关键词提取复选框
- **WHEN** 用户为某列选择"关键词提取"类型并勾选"提取药物关键词"
- **THEN** 解析阶段对该列文本执行关键词匹配，命中的药物创建对应用药记录

#### Scenario: 取消列名映射不触发后续流程
- **WHEN** 用户点击 ColumnMappingSheet 的"取消"按钮
- **THEN** sheet 关闭后不触发值检测，导入流程终止

---

### Requirement: 列值别名映射配置界面
列名映射完成后，系统 SHALL 扫描所有具有枚举意义的列（记录类型、测量方式、药物类
型）中的唯一值，若存在无法自动识别的值（既非 rawValue 也非 displayName 也非已保
存别名），则弹出 `ValueMappingSheet`，集中展示所有未识别值及其出现次数，允许用户
为每个值选择对应的内部枚举值或选择"忽略（记为默认值）"。

**此外，只要任意列启用了关键词提取（`extractsMedications == true`），无论枚举冲突
是否存在，系统 SHALL 同样弹出 `ValueMappingSheet`，并在其中展示关键词配置区块。**

`ValueMappingSheet` 的关键词配置区块 SHALL 由独立的 `hasKeywordColumns: Bool` 参数
控制，不再依赖 `medication_type` 分组是否存在。

`ValueMappingSheet` 关闭后，系统 SHALL 在 sheet dismiss 动画**完全结束后**再触发
解析流程（`proceedToParse`），以避免 SwiftUI 多 sheet 时序冲突。

#### Scenario: 自动弹出值映射界面（枚举冲突）
- **WHEN** 枚举列中存在未识别的值（如"美林"在药物类型列）
- **THEN** ColumnMappingSheet 完成后自动弹出 ValueMappingSheet，按列分组展示所
  有未识别值及出现次数

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

#### Scenario: 完成值映射后正常进入预览
- **WHEN** 用户点击 ValueMappingSheet 的"继续"按钮
- **THEN** sheet 完全关闭后，系统触发 CSV 解析并展示 ImportPreviewSheet，不出现白屏

#### Scenario: 取消值映射不触发解析
- **WHEN** 用户点击 ValueMappingSheet 的"取消"按钮
- **THEN** sheet 关闭后不触发解析，导入流程终止
