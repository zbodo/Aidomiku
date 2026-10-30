# macOS 单窗口尺寸恢复设计

## 目标

让 Apple Silicon Mac 上运行的“为 iPad 设计”版本在退出并重新打开后，由系统恢复上次的窗口大小，不再总是创建固定尺寸的新窗口。

## 方案

将 `Aidoku/Info.plist` 中 `UIApplicationSceneManifest-macos` 下的 `UIApplicationSupportsMultipleScenes` 从 `true` 改为 `false`。保留通用 iOS/iPadOS scene 配置不变。

单 scene 应用的窗口状态由 macOS 和 UIKit 自动恢复，因此不增加窗口尺寸监听、`UserDefaults` 持久化或自定义几何恢复代码。

## 行为变化

- macOS 版本只允许一个应用窗口。
- 用户调整窗口大小后，正常退出并重新打开应用时，系统恢复该窗口大小。
- iPhone 和 iPad 上的行为保持不变。
- 不保存或强制恢复窗口位置，位置仍由系统管理。

## 验证

1. 构建并在 Apple Silicon Mac 上运行“为 iPad 设计”版本。
2. 调整窗口大小，使用 Command-Q 正常退出应用，然后重新打开。
3. 确认窗口恢复为退出前的大小。
4. 确认 macOS 菜单不再提供创建第二个应用窗口的能力。
5. 确认 iPhone 或 iPad 构建仍能正常启动。
