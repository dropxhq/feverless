## MODIFIED Requirements

### Requirement: MedicationCatalogView 管理界面
系统 SHALL 提供 `MedicationCatalogView`，展示所有药品，支持：
- 左侧：药品列表（内置在前，自建在后），选中后右侧显示关键词列表和安全配置
- 右侧：关键词列表可添加/删除；安全配置（minIntervalHours、maxDailyDoses）可编辑（仅自建药品）
- 可新增自建药品（输入 canonicalName，可选安全参数）
- 内置药品不可删除，但可编辑 keywords
- 视图关闭时自动持久化修改

该视图 SHALL 同时支持两种呈现方式：
- **NavigationLink 模式**：从 ProfileView 进入，使用导航栈
- **Sheet 模式**：从 ValueMappingSheet 弹出，toolbar 显示"完成"关闭按钮

两种模式下数据源均为 `MedicationCatalog.shared`，修改结果完全一致。

#### Scenario: 添加关键词立即显示
- **WHEN** 用户在关键词输入框输入"布洛芬悬液"并点击"添加"
- **THEN** 关键词列表立即出现"布洛芬悬液"，无需关闭重开

#### Scenario: Sheet 模式有关闭按钮
- **WHEN** MedicationCatalogView 以 sheet 模式展示（从 ValueMappingSheet 弹出）
- **THEN** toolbar 显示"完成"按钮，点击后关闭 sheet，修改已持久化

#### Scenario: NavigationLink 模式无独立关闭按钮
- **WHEN** MedicationCatalogView 从 ProfileView 以 NavigationLink 打开
- **THEN** 使用系统返回手势/按钮导航，无额外"完成"按钮
