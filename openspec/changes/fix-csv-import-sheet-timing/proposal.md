## Why

CSV 导入的多步 sheet 流程（列名映射 → 值映射 → 预览确认）存在 SwiftUI sheet 时序冲突 bug：每个 sheet 的"继续"按钮在调用 `onDone` 回调（内部立即触发下一个 sheet 的 `isPresented = true`）后才调用 `dismiss()`，导致两个 sheet 操作并发，最终呈现白屏卡死。

## What Changes

- 将 `ProfileView` 中 `ColumnMappingSheet` 和 `ValueMappingSheet` 的 sheet 声明改用 `onDismiss` 触发下一步逻辑
- `onDone` 回调仅负责保存状态（`pendingConfig`）和设置完成标志位，不再直接调用 `proceedToValueDetection()` / `proceedToParse()`
- 两个 `Bool` 标志位（`columnMappingDidComplete`、`valueMappingDidComplete`）在 `onDismiss` 中判断并触发后续流程

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `csv-import-mapping`: 修复 sheet 时序问题；`onDone` 回调语义从"完成并推进"变为"仅保存状态"，推进逻辑移至 `onDismiss`

## Impact

- 仅影响 `ProfileView.swift` 中的 sheet 声明和 import flow 相关 state
- 不涉及数据模型、CSVImporter、ColumnMappingSheet、ValueMappingSheet 等文件
- 无 API 变更，无 breaking change
