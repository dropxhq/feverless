## ADDED Requirements

### Requirement: 儿童档案创建
系统 SHALL 允许用户创建儿童档案，必填字段为姓名，可选字段为出生日期和头像 Emoji。

#### Scenario: 创建第一个儿童
- **WHEN** 用户首次打开 App 且无任何儿童档案
- **THEN** 引导用户创建第一个儿童档案后进入首页

#### Scenario: 添加更多儿童
- **WHEN** 用户在"我的"页面点击"添加儿童"
- **THEN** 展示创建表单，保存后新儿童出现在列表

### Requirement: 儿童档案编辑与删除
系统 SHALL 允许用户编辑儿童姓名/出生日期/头像，或删除儿童档案。删除时 SHALL 同时删除该儿童的所有体温和用药记录（cascade delete）。

#### Scenario: 删除儿童档案
- **WHEN** 用户确认删除某儿童档案
- **THEN** 该儿童及其所有记录从 SwiftData 中删除，CloudKit 同步删除

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

### Requirement: 体温位置管理入口
系统 SHALL 在 ProfileView 的药品管理入口下方（或同一区域）新增"体温位置管理" `NavigationLink`，点击后进入 `TemperaturePositionCatalogView`。

#### Scenario: 进入体温位置管理
- **WHEN** 用户在"我的"页面点击"体温位置管理"
- **THEN** 导航进入 TemperaturePositionCatalogView，展示内置和自建测量位置

#### Scenario: 药品管理和体温位置管理平行展示
- **WHEN** 用户查看"我的"页面
- **THEN** 列表中同时显示"药品管理"和"体温位置管理"两个入口，顺序相邻
