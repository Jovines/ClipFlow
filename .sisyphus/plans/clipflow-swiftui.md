# ClipFlow - SwiftUI 原生剪切板助手实现方案

## TL;DR

> **快速摘要**: 基于 SwiftUI + AppKit + Core Data 构建的 macOS 原生剪切板助手，通过快捷键唤起浮窗显示剪切板历史，支持文本和图片内容、标签分类、高级搜索。

**交付物**:
- 可运行的 macOS 桌面应用 (.app / .dmg)
- 完整的 Xcode 项目源代码
- 遵循 Apple 平台最佳实践的技术架构

## Context

### 原始需求

用户希望构建一个类似 Clipy 的剪切板助手应用，技术栈偏好从 Tauri + React 迁移到 Apple 原生技术（SwiftUI + AppKit）。

### 技术栈映射

| 原 Tauri 方案 | SwiftUI 原生方案 |
|--------------|------------------|
| React + TypeScript | SwiftUI + Swift |
| Zustand Store | @Published + Observable |
| Radix UI + Tailwind | SwiftUI 原生组件 |
| Tauri Commands | ViewModel + Combine |
| SQLite | Core Data |
| arboard (Rust) | NSPasteboard (原生) |
| global-shortcut | Carbon Events / HotKey |
| Heroicons | SF Symbols |
| Flexoki 配色 | 系统 Color Assets |

### 访谈总结

**关键讨论点**:
- 技术栈选择: SwiftUI + AppKit + Core Data + XcodeGen + Swift Package Manager
- 核心功能: 快捷键唤起的浮窗式剪切板历史、文本+图片支持、高级搜索、手动标签系统
- 监控方式: NSPasteboard 事件监听模式（高效省资源）
- UI 风格: 鼠标位置唤起浮窗、SF Symbols 图标、跟随系统主题

## Work Objectives

### 核心目标

构建一个原生 macOS 剪切板助手，提供以下核心能力:
1. 快速唤起: 通过自定义快捷键即时显示剪切板历史
2. 内容捕获: 自动捕获并存储文本和图片内容
3. 高效搜索: 支持关键词模糊匹配和标签筛选
4. 灵活管理: 手动标签系统和可配置的历史管理策略

### 具体交付物

**应用核心**:
- 可执行的 macOS 桌面应用 (.app)
- SwiftUI 主界面 + AppKit 浮窗
- Core Data 本地数据库

**功能模块**:
- NSPasteboard 监控服务
- 浮窗 UI 组件（SwiftUI in NSWindow）
- 历史记录管理 (CRUD)
- 标签系统
- 高级搜索功能
- 设置面板

**技术基础设施**:
- XcodeGen 项目生成
- SwiftLint 代码规范
- Swift Package Manager 依赖管理

### 完成定义

- [ ] 应用可通过快捷键唤起浮窗
- [ ] 浮窗显示最近 10 条剪切板历史预览
- [ ] 点击历史记录直接复制到剪贴板
- [ ] 支持文本和图片内容的捕获和存储
- [ ] 支持手动添加标签
- [ ] 支持关键词搜索和标签筛选
- [ ] 可配置快捷键、历史管理策略
- [ ] 跟随系统主题 (深色/浅色)
- [ ] macOS 平台正常运行

### 必须包含

- NSPasteboard 事件监听模式的剪贴板监控
- 鼠标位置唤起的浮窗 UI（SwiftUI in NSWindowHost）
- SF Symbols 图标系统
- Core Data 数据库存储
- XcodeGen 项目配置

### 必须不包含 (Guardrails)

- AI-slop 模式避免: 不实现 AI 语义搜索，不添加自动标签分类
- 范围边界: 第一期仅 macOS 平台，不支持富文本内容
- 技术约束: 不使用 Docker，不添加自动化测试（后期）

---

## Execution Strategy

### Phase 1: 项目初始化
- 1.1: 项目脚手架搭建 (XcodeGen)
- 1.2: 开发工具链配置 (SwiftLint + SPM)
- 1.3: App 结构配置 (AppKit + SwiftUI)
- 1.4: Core Data 设计

### Phase 2: 核心后端
- 2.1: 剪贴板监控服务 (NSPasteboard)
- 2.2: Core Data 操作层
- 2.3: 快捷键系统 (Carbon/HotKey)
- 2.4: 浮窗窗口管理 (NSWindow + SwiftUI)

### Phase 3: UI 基础
- 3.1: SwiftUI 基础组件
- 3.2: 主题系统 (跟随系统)
- 3.3: 状态管理 (@Published + Observable)
- 3.4: 标签系统基础组件

### Phase 4: 核心功能
- 4.1: 浮窗 UI 实现
- 4.2: 历史记录列表
- 4.3: 图片预览组件
- 4.4: 搜索功能
- 4.5: 标签添加/编辑

### Phase 5: 设置系统
- 5.1: 设置界面布局
- 5.2: 快捷键配置
- 5.3: 存储设置
- 5.4: 标签管理

### Phase 6: 测试优化
- 6.1: 功能测试
- 6.2: 性能优化
- 6.3: 打包发布

---

## TODOs

### Phase 1: 项目初始化

- [ ] 1.1 项目脚手架搭建

  **要做的事情**:
  - 创建 XcodeGen 项目配置 (project.yml)
  - 配置 Swift Package Manager 依赖
  - 设置标准目录结构 (Sources + Resources)
  - 配置 Info.plist

  **参考**:
  - XcodeGen 官方文档: https://github.com/yonaskolb/XcodeGen

  **验收标准**:
  - [ ] `project.yml` 创建
  - [ ] 目录结构: Sources/, Resources/, Tests/
  - [ ] Xcode 项目生成成功
  - [ ] 编译测试通过

  **验证命令**:
  ```bash
  xcodegen generate
  xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -destination 'platform=macOS' build
  ```

  **Commit**: 是
  - Message: feat: initialize SwiftUI + XcodeGen project

- [ ] 1.2 开发工具链配置

  **要做的事情**:
  - 配置 SwiftLint
  - 配置 Xcode 构建配置 (Debug/Release)
  - 配置代码签名

  **验证命令**:
  ```bash
  swiftlint
  xcodebuild -project ClipFlow.xcodeproj build
  ```

- [ ] 1.3 App 结构配置

  **要做的事情**:
  - 配置 AppDelegate 和 SceneDelegate
  - 设置 SwiftUI App 入口
  - 配置应用权限（剪贴板、快捷键）

  **参考**:
  - SwiftUI App: https://developer.apple.com/documentation/swiftui/app

  **验收标准**:
  - [ ] ClipFlowApp.swift 创建
  - [ ] AppDelegate 配置权限
  - [ ] 应用启动正常

- [ ] 1.4 Core Data 设计

  **要做的事情**:
  - 设计 Core Data 数据模型
  - 创建 .xcdatamodeld 文件
  - 配置 Core Data Stack

  **数据库 Schema 设计**:
  ```
  ClipboardItem 实体:
  - id: UUID (主键)
  - content: String
  - contentType: String (text | image)
  - imageData: Binary (可选)
  - createdAt: Date
  - updatedAt: Date

  Tag 实体:
  - id: UUID (主键)
  - name: String
  - color: String
  - createdAt: Date

  关联:
  - ClipboardItem <-> Tag (多对多)
  ```

  **验收标准**:
  - [ ] ClipFlow.xcdatamodeld 创建
  - [ ] Core Data Stack 配置
  - [ ] 数据库操作测试通过

### Phase 2: 核心后端

- [ ] 2.1 剪贴板监控服务

  **要做的事情**:
  - 实现 NSPasteboard.changeCount 监控
  - 实现文本内容读取
  - 实现图片内容读取 (NSImage -> Data)
  - 实现内容类型检测

  **参考**:
  - NSPasteboard: https://developer.apple.com/documentation/appkit/nspasteboard

  **验收标准**:
  - [ ] NSPasteboard 监控服务创建
  - [ ] 文本捕获测试通过
  - [ ] 图片捕获测试通过
  - [ ] 事件监听模式 (非轮询)

- [ ] 2.2 Core Data 操作层

  **要做的事情**:
  - 实现 CRUD 操作
  - 实现标签关联操作
  - 实现分页查询
  - 实现搜索查询

  **验收标准**:
  - [ ] insert_clipboard 操作
  - [ ] get_clipboard_history 操作（分页）
  - [ ] delete_clipboard 操作
  - [ ] search_clipboard 操作

- [ ] 2.3 快捷键系统

  **要做的事情**:
  - 实现全局快捷键注册 (Carbon Events)
  - 实现快捷键冲突检测
  - 实现快捷键配置持久化

  **参考**:
  - Carbon Events: https://developer.apple.com/documentation/carbon/hot_keys

  **验收标准**:
  - [ ] 快捷键注册 API
  - [ ] 默认快捷键 (如 Cmd+Shift+V)
  - [ ] 快捷键持久化
  - [ ] 快捷键触发浮窗显示

- [ ] 2.4 浮窗窗口管理

  **要做的事情**:
  - 创建 NSWindow 用于浮窗
  - 配置 SwiftUI View 到 NSWindow
  - 实现窗口定位 (鼠标位置)
  - 实现窗口显示/隐藏

  **参考**:
  - NSWindowRepresentable: https://developer.apple.com/documentation/swiftui/nswindowrepresentable

  **验收标准**:
  - [ ] FloatingWindow 创建
  - [ ] 鼠标位置定位正确
  - [ ] 窗口显示/隐藏正常
  - [ ] ESC 键关闭功能正常

### Phase 3: UI 基础

- [ ] 3.1 SwiftUI 基础组件

  **要做的事情**:
  - 创建基础组件 (Button, Input, Card, List)
  - 配置 SF Symbols 图标
  - 创建通用样式

  **参考**:
  - SF Symbols: https://developer.apple.com/sf-symbols/

- [ ] 3.2 主题系统

  **要做的事情**:
  - 实现深色/浅色主题跟随
  - 配置 Color Assets
  - 实现主题切换

- [ ] 3.3 状态管理

  **要做的事情**:
  - 创建 ClipboardViewModel (@Published)
  - 创建设置 ViewModel
  - 实现状态持久化 (UserDefaults)

- [ ] 3.4 标签组件

  **要做的事情**:
  - 创建 TagView 组件
  - 创建 TagEditor 组件
  - 实现颜色选择

### Phase 4: 核心功能

- [ ] 4.1 浮窗 UI 实现

  **要做的事情**:
  - 创建 FloatingWindowView
  - 实现鼠标位置定位
  - 实现淡入淡出动画
  - 实现浮窗交互逻辑

- [ ] 4.2 历史记录列表

  **要做的事情**:
  - 创建 HistoryListView
  - 实现分页加载
  - 实现点击复制功能
  - 实现 List 滚动

- [ ] 4.3 图片预览组件

  **要做的事情**:
  - 创建 ImagePreviewView
  - 实现等比缩放
  - 实现点击查看大图

- [ ] 4.4 搜索功能

  **要做的事情**:
  - 创建 SearchBar 组件
  - 实现关键词搜索
  - 实现标签筛选

- [ ] 4.5 标签系统

  **要做的事情**:
  - 实现标签添加/删除
  - 实现标签持久化
  - 实现标签关联显示

### Phase 5: 设置系统

- [ ] 5.1 设置界面布局

  **要做的事情**:
  - 创建设置面板 (SettingsView)
  - 实现分类标签页 (TabView)

- [ ] 5.2 快捷键配置

  **要做的事情**:
  - 创建快捷键录制组件
  - 实现快捷键冲突检测
  - 实现快捷键保存

- [ ] 5.3 存储设置

  **要做的事情**:
  - 创建存储设置组件
  - 实现数量限制配置
  - 实现清理策略配置

- [ ] 5.4 标签管理

  **要做的事情**:
  - 创建标签管理列表
  - 实现标签颜色配置
  - 实现标签删除

### Phase 6: 测试优化

- [ ] 6.1 功能测试

  **测试清单**:
  - [ ] 快捷键唤起浮窗
  - [ ] 剪贴板监控功能
  - [ ] 历史记录显示
  - [ ] 点击复制功能
  - [ ] 图片预览功能
  - [ ] 搜索功能
  - [ ] 标签功能
  - [ ] 设置功能
  - [ ] 主题切换

- [ ] 6.2 性能优化

  **性能优化点**:
  - Core Data 查询优化
  - 列表渲染优化 (List 优化)
  - 图片加载优化

- [ ] 6.3 打包发布

  **要做的事情**:
  - 配置打包选项
  - 创建 .dmg 安装包
  - 代码签名（如需要）
  - 测试安装包

  **参考**:
  - macOS 打包: https://developer.apple.com/documentation/xcode/packaging-your-macos-app

  **验证命令**:
  ```bash
  xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -configuration Release archive
  xcodebuild -exportArchive -archivePath ClipFlow.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath ./dist
  ```

---

## Verification Strategy

### 测试决策

- 基础设施存在: 是 (Xcode + Swift + SPM)
- 用户想要测试: 否（后期添加）
- QA 方案: 手动验证 + Swift 编译器检查

### 手动执行验证

1. **构建验证**:
   ```bash
   xcodegen generate
  xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -destination 'platform=macOS' build
   swiftlint
   ```

2. **功能验证**:
   - 启动应用测试快捷键唤起浮窗
   - 测试剪贴板捕获功能
   - 测试搜索功能
   - 测试标签添加
   - 测试设置保存

3. **平台验证**:
   - 在 macOS 上测试所有功能
   - 验证浮窗位置正确性
   - 验证主题切换效果

---

## Commit Strategy

| 任务 | Message | Files |
|------|---------|-------|
| 1.1 | feat: initialize SwiftUI + XcodeGen project | project.yml, Sources/ |
| 2.1 | feat: implement clipboard monitoring service | Sources/Services/ClipboardMonitor.swift |
| 2.2 | feat: implement Core Data operations | Sources/Persistence/ |
| 2.3 | feat: implement global shortcut system | Sources/Services/HotKeyManager.swift |
| 2.4 | feat: implement floating window management | Sources/Views/FloatingWindow.swift |
| 3.1 | feat: configure SwiftUI components | Sources/Views/Components/ |
| 3.3 | feat: implement state management | Sources/ViewModels/ |
| 4.1 | feat: implement floating window UI | Sources/Views/FloatingWindowView.swift |
| 4.2 | feat: implement history list | Sources/Views/HistoryListView.swift |
| 4.3 | feat: implement image preview | Sources/Views/ImagePreviewView.swift |
| 4.4 | feat: implement search functionality | Sources/Views/SearchBar.swift |
| 4.5 | feat: implement tagging system | Sources/Views/TagEditor.swift |
| 5.1 | feat: implement settings interface | Sources/Views/SettingsView.swift |
| 6.3 | chore: build and package application | 打包产物 |

---

## Success Criteria

### 验证命令

```bash
# 1. 项目构建
xcodegen generate
  xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow build

# 2. SwiftLint 检查
swiftlint

# 3. 功能验证清单
# [ ] 快捷键唤起浮窗 (默认: Cmd+Shift+V)
# [ ] 剪贴板监控 (复制文本/ ] 历史记录显示图片)
# [ (默认10条)
# [ ] 点击复制功能
# [ ] 搜索功能 (输入关键词)
# [ ] 标签功能 (添加/删除标签)
# [ ] 设置功能 (快捷键、存储配置)
# [ ] 主题切换 (深色/浅色)

# 4. 打包验证
  xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -configuration Release archive
```

### 最终检查清单

- [ ] 所有必须包含功能实现
- [ ] 没有必须不包含功能
- [ ] macOS 平台运行正常
- [ ] 快捷键功能正常
- [ ] 剪贴板监控正常
- [ ] 搜索功能正常
- [ ] 标签系统正常
- [ ] 设置功能正常
- [ ] 主题切换正常
- [ ] 打包成功
- [ ] 安装包可正常运行

---

**创建时间**: 2026-01-29
**版本**: 1.0
**状态**: 待用户确认后执行
