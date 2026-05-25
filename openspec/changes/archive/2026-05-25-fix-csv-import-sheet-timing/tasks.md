## 1. ProfileView 状态与 Sheet 修复

- [x] 1.1 在 `ProfileView` 添加 `@State private var columnMappingDidComplete: Bool = false`
- [x] 1.2 在 `ProfileView` 添加 `@State private var valueMappingDidComplete: Bool = false`
- [x] 1.3 修改 `ColumnMappingSheet` 的 `.sheet` 声明：添加 `onDismiss` 闭包，在其中判断 `columnMappingDidComplete` 为 `true` 时调用 `proceedToValueDetection()`，调用后将标志位重置为 `false`
- [x] 1.4 修改 `ColumnMappingSheet` 的 `onDone` 回调：移除 `proceedToValueDetection()` 调用，改为只执行 `pendingConfig = updatedConfig` 并将 `columnMappingDidComplete = true`
- [x] 1.5 修改 `ValueMappingSheet` 的 `.sheet` 声明：添加 `onDismiss` 闭包，在其中判断 `valueMappingDidComplete` 为 `true` 时调用 `proceedToParse()`，调用后将标志位重置为 `false`
- [x] 1.6 修改 `ValueMappingSheet` 的 `onDone` 回调：移除 `proceedToParse()` 调用，改为只执行 `pendingConfig = updatedConfig` 并将 `valueMappingDidComplete = true`

## 2. 验证

- [x] 2.1 验证：列名映射完成 → 点击"继续" → 正常弹出值映射 sheet（无白屏）
- [x] 2.2 验证：值映射完成 → 点击"继续" → 正常弹出导入预览 sheet（无白屏）
- [x] 2.3 验证：点击任意 sheet 的"取消"→ 流程终止，不触发后续步骤
- [x] 2.4 验证：无需值映射时（直接跳过 ValueMappingSheet）→ 正常弹出预览
