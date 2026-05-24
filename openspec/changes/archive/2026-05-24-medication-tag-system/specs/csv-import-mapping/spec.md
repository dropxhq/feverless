## MODIFIED Requirements

### Requirement: 关键词词典与匹配规则
系统 SHALL 从 `MedicationCatalog` 读取所有药品定义的 keywords 列表（含 canonicalName 本身）作为关键词词典，不再使用硬编码内置词典。关键词匹配 SHALL 使用子字符串包含（`contains`）方式，并按词长降序匹配（长词优先），每个命中关键词创建一条用药记录，`typeRaw` 存储该关键词对应药品的 `canonicalName`。

#### Scenario: 内置关键词自动命中
- **WHEN** 备注列文本包含"美林"
- **THEN** 系统自动创建一条 typeRaw=`"布洛芬"` 的用药记录，时间戳同所在行

#### Scenario: 用户自建药品关键词命中
- **WHEN** 用户为"退热贴"配置了关键词"退热"，备注列文本包含"退热"
- **THEN** 系统自动创建一条 typeRaw=`"退热贴"` 的用药记录

#### Scenario: 同行命中多个关键词
- **WHEN** 备注列文本包含"布洛芬和泰诺"
- **THEN** 系统创建两条用药记录（typeRaw=`"布洛芬"` + typeRaw=`"对乙酰氨基酚"`），时间戳相同

#### Scenario: 无关键词命中
- **WHEN** 备注列文本不包含任何已知关键词
- **THEN** 不创建用药记录，文本仅写入体温记录的备注字段

---

### Requirement: 值映射界面关键词区块（Tag UI）
`ValueMappingSheet` 的关键词配置区块 SHALL 重构为支持 tag-based 药品管理的 UI，分为左侧药品名（canonical key）和右侧关键词列表（values）两部分，均可无限拓展。

- 左侧展示 `MedicationCatalog.all` 中的所有药品，选中后右侧显示该药品的 keywords 列表
- 右侧每个关键词可独立删除；底部有"添加关键词"输入框
- 用户可新增自定义药品（输入 canonicalName）
- 内置药品不可删除，但可编辑其 keywords
- 添加关键词后，列表 SHALL 立即显示新关键词（修复现有渲染 bug）

`ValueMappingSheet` 关闭时 SHALL 将修改后的 catalog 状态同步持久化。

#### Scenario: 添加关键词立即显示
- **WHEN** 用户在关键词输入框输入"布洛芬悬液"并点击"添加"
- **THEN** 关键词列表立即出现"布洛芬悬液"，无需关闭重开

#### Scenario: 选择不同药品切换关键词列表
- **WHEN** 用户从左侧选择"对乙酰氨基酚"
- **THEN** 右侧关键词列表更新为该药品的 keywords

#### Scenario: 新增自建药品
- **WHEN** 用户输入新药品名"退热贴"并确认
- **THEN** 左侧列表末尾出现"退热贴"，右侧初始关键词列表为空

#### Scenario: 删除关键词
- **WHEN** 用户点击"美林"旁的删除按钮
- **THEN** "美林"从关键词列表中移除，catalog 持久化更新
