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
系统 SHALL 支持多儿童场景，首页顶部展示当前儿童选择器（Picker），切换后全局数据视图跟随更新。

#### Scenario: 切换当前儿童
- **WHEN** 用户从选择器中选择另一个儿童
- **THEN** 首页、图表页均展示该儿童的数据
