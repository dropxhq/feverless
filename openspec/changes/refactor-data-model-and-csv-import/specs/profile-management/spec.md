## ADDED Requirements

### Requirement: 体温位置管理入口
系统 SHALL 在 ProfileView 的药品管理入口下方（或同一区域）新增"体温位置管理" `NavigationLink`，点击后进入 `TemperaturePositionCatalogView`。

#### Scenario: 进入体温位置管理
- **WHEN** 用户在"我的"页面点击"体温位置管理"
- **THEN** 导航进入 TemperaturePositionCatalogView，展示内置和自建测量位置

#### Scenario: 药品管理和体温位置管理平行展示
- **WHEN** 用户查看"我的"页面
- **THEN** 列表中同时显示"药品管理"和"体温位置管理"两个入口，顺序相邻
