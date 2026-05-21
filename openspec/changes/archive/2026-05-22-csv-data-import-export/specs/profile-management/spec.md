## MODIFIED Requirements

### Requirement: 当前儿童切换
系统 SHALL 支持多儿童场景，ProfileView 的孩子列表中每个孩子行 SHALL 展示该孩子的最近一次体温记录值和记录时间（如有）作为辅助信息。当前选中的孩子 SHALL 通过视觉高亮（`checkmark.circle.fill` 图标 + 蓝色背景或边框）与其他孩子明显区分。点击孩子行即切换当前选中孩子。

#### Scenario: 切换当前儿童
- **WHEN** 用户点击列表中另一个孩子的行
- **THEN** 该孩子被选中（显示对勾图标），首页和图表页数据随之更新

#### Scenario: 孩子行展示最近体温
- **WHEN** ProfileView 孩子列表渲染某孩子行
- **THEN** 若该孩子有体温记录，副标题显示"最近体温: XX.X°C · N 天前"；若无记录，显示"暂无体温记录"

## ADDED Requirements

### Requirement: 数据管理区
系统 SHALL 在 ProfileView 底部展示"数据管理"Section，标题 SHALL 动态显示为 `"<当前孩子名> 的数据"`。该 Section 包含两行操作：
- "导出数据..." → 触发导出配置 Sheet（csv-export 能力）
- "导入数据..." → 触发文件选择器（csv-import 能力）

若当前无选中孩子，该 Section SHALL 不显示。

#### Scenario: 有选中孩子时显示数据管理区
- **WHEN** 用户进入 ProfileView 且已有选中孩子（如"小明"）
- **THEN** 列表底部显示标题为"小明 的数据"的 Section，包含"导出数据..."和"导入数据..."两行

#### Scenario: 无选中孩子时隐藏数据管理区
- **WHEN** 用户进入 ProfileView 且无任何选中孩子
- **THEN** ProfileView 不显示数据管理 Section
