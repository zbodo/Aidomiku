# macOS 单窗口尺寸恢复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 关闭“为 iPad 设计”的 macOS 版本的多 scene 能力，使 UIKit 和 macOS 自动恢复唯一窗口的大小。

**Architecture:** 仅修改 macOS 专用的 scene manifest，不添加运行时代码或自定义持久化。窗口大小恢复继续由系统负责，iPhone 和 iPad 的通用 scene 配置保持不变。

**Tech Stack:** UIKit scene 生命周期、XML property list、Xcode 27

## Global Constraints

- macOS 版本只允许一个应用窗口。
- 不添加窗口尺寸监听、`UserDefaults` 持久化或自定义几何恢复代码。
- iPhone 和 iPad 上的行为保持不变。
- 不保存或强制恢复窗口位置。

---

### Task 1: 关闭 macOS 多 scene 能力

**Files:**
- Modify: `Aidoku/Info.plist:89-106`

**Interfaces:**
- Consumes: `UIApplicationSceneManifest-macos` 中现有的 macOS scene 配置。
- Produces: 值为 `false` 的 `UIApplicationSupportsMultipleScenes` macOS 配置。

- [ ] **Step 1: 验证修改前配置**

Run:

```bash
/usr/libexec/PlistBuddy -c 'Print :UIApplicationSceneManifest-macos:UIApplicationSupportsMultipleScenes' Aidoku/Info.plist
```

Expected: 输出 `true`。

- [ ] **Step 2: 修改 macOS scene 配置**

将以下配置：

```xml
<key>UIApplicationSupportsMultipleScenes</key>
<true/>
```

改为：

```xml
<key>UIApplicationSupportsMultipleScenes</key>
<false/>
```

仅修改 `UIApplicationSceneManifest-macos` 字典内的值。

- [ ] **Step 3: 验证 plist 语法和目标值**

Run:

```bash
plutil -lint Aidoku/Info.plist
/usr/libexec/PlistBuddy -c 'Print :UIApplicationSceneManifest-macos:UIApplicationSupportsMultipleScenes' Aidoku/Info.plist
```

Expected: 分别输出 `Aidoku/Info.plist: OK` 和 `false`。

- [ ] **Step 4: 验证工程构建**

Run:

```bash
xcodebuild -project Aidoku.xcodeproj -scheme Aidoku -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: 输出 `** BUILD SUCCEEDED **`。如果本机依赖解析或 Xcode 服务不可用，保留 plist 验证结果并明确报告构建阻塞原因。

- [ ] **Step 5: 检查最终差异**

Run:

```bash
git diff --check
git diff -- Aidoku/Info.plist
```

Expected: 无空白错误，且只显示 macOS 专用布尔值由 `true` 变为 `false`。

- [ ] **Step 6: 提交实现**

```bash
git add Aidoku/Info.plist
git commit -m "fix: restore macOS window size"
```
