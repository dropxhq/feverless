## Context

`ProfileView` 通过三个链式 sheet 完成 CSV 导入流程：

```
ColumnMappingSheet → ValueMappingSheet → ImportPreviewSheet
```

每个 sheet 的"继续"按钮调用 `onDone` 回调，回调内立即触发下一个 sheet 的
`isPresented = true`，随后调用 `dismiss()`。SwiftUI 不允许在同一 runloop
cycle 内同时 present 和 dismiss 两个 sheet，导致白屏卡死。

## Goals / Non-Goals

**Goals:**
- 修复 ValueMappingSheet 点击"继续"后白屏的 bug
- 同时修复 ColumnMappingSheet 相同模式的潜在问题
- 改动范围最小，不影响任何子 sheet 组件

**Non-Goals:**
- 重构 sheet 架构（不合并为单一 NavigationStack）
- 修改 ColumnMappingSheet / ValueMappingSheet / ImportPreviewSheet 内部逻辑

## Decisions

### 决策：使用 `onDismiss` + 标志位模式

**问题**：`onDone` 回调中直接触发下一个 sheet 会造成时序冲突。

**选型对比**：

| 方案 | 可靠性 | 改动量 | 说明 |
|------|--------|--------|------|
| A. `onDismiss` + 标志位 | 高 | 最小 | SwiftUI 保证 onDismiss 在动画完成后执行 |
| B. `Task.sleep` 延迟 | 中 | 小 | 魔法数字，设备性能不同可能失效 |
| C. 合并为单一 sheet | 高 | 大 | 彻底解决，但需重构三个 sheet 组件 |

**选择方案 A**。

**实现方式**：

1. 在 `ProfileView` 新增两个标志位 `@State`：
   - `columnMappingDidComplete: Bool`
   - `valueMappingDidComplete: Bool`

2. 修改两个 sheet 声明，将 `proceedToXxx()` 调用从 `onDone` 移至 `onDismiss`：

```swift
// Before
.sheet(isPresented: $showValueMappingSheet) {
    ValueMappingSheet(...) { updatedConfig in
        pendingConfig = updatedConfig
        proceedToParse()          // ← 冲突：此时 sheet 未完成 dismiss
    }
}

// After
.sheet(isPresented: $showValueMappingSheet, onDismiss: {
    guard valueMappingDidComplete else { return }
    valueMappingDidComplete = false
    proceedToParse()              // ← 安全：sheet 已完全消失
}) {
    ValueMappingSheet(...) { updatedConfig in
        pendingConfig = updatedConfig
        valueMappingDidComplete = true   // ← 只存状态
    }
}
```

3. 对 `ColumnMappingSheet` 应用同样的模式（`columnMappingDidComplete`）。

## Risks / Trade-offs

- **用户取消 sheet**：标志位为 `false`，`onDismiss` 直接 return，无副作用。
- **onDismiss 调用时机**：SwiftUI 在 sheet dismiss 动画完成后保证调用，无需额外延迟。
- **状态重置**：标志位在 `onDismiss` 内立即置回 `false`，不影响下次导入流程。
