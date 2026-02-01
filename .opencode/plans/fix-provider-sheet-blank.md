# 修复 AI 服务商编辑弹窗空白问题

## 问题描述

点击添加服务商 → 选择 "Minimax (中国版)" 时，弹出的编辑窗口内容为空。

## 根因分析

`AIProviderSettingsView.swift:35-49` 中存在 SwiftUI sheet 时序问题：

```swift
.sheet(isPresented: $showPresetSheet) {
    ProviderPresetSheet { preset in
        showPresetSheet = false      // 问题1: 立即关闭
        newProviderFromPreset = AIProviderConfig.fromPreset(preset)
        showAddSheet = true          // 问题2: 立即打开另一个 sheet
    }
}
.sheet(isPresented: $showAddSheet) {
    if let presetProvider = newProviderFromPreset {
        ProviderEditSheet(provider: presetProvider, ...)
    }
}
```

在同一个事件循环中连续关闭/打开两个 sheet，SwiftUI 状态更新可能未及时传递，导致第二个 sheet 收到的 `newProviderFromPreset` 为空。

## 修复方案

改用 `sheet(item:)` 方式，更符合 SwiftUI 模式，彻底避免时序问题。

### 改动文件

**`Sources/Views/AIProviderSettingsView.swift`**

1. 将状态变量改为：
   ```swift
   @State private var showPresetSheet = false
   @State private var pendingPreset: ProviderPreset?   // 新增
   @State private var editingProvider: AIProviderConfig?
   ```

2. 修改预设选择回调：
   ```swift
   ProviderPresetSheet { preset in
       showPresetSheet = false
       pendingPreset = preset  // 直接存储 preset
   }
   ```

3. 修改 add sheet（改用 `sheet(item:)`）：
   ```swift
   .sheet(item: $pendingPreset) { preset in
       ProviderEditSheet(
           provider: AIProviderConfig.fromPreset(preset),
           isNew: true
       ) { newProvider in
           addProvider(newProvider)
           pendingPreset = nil  // 完成后清空
       }
   }
   ```

### 验证步骤

1. 运行 `./run.sh`
2. 点击 "+" 添加服务商
3. 选择 "Minimax (中国版)"
4. 确认弹窗显示正确预设信息（名称、URL、模型列表等）
5. 输入 API Key 后保存
6. 重启应用，确认配置持久化
