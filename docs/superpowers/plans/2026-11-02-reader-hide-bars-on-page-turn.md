# 阅读器翻页时隐藏栏实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将“滑动时隐藏栏”扩展为“翻页时隐藏栏”，使硬件键盘和 Apple Pencil 翻页也遵循该选项。

**Architecture:** 保留偏好键 `Reader.hideBarsOnSwipe` 以兼容已有设置，在 `ReaderViewController` 的四个离散翻页入口统一检查偏好并调用现有 `hideBars()`。滑动和点击翻页继续使用各阅读器现有逻辑；本地化标题改用反映新语义的键。

**Tech Stack:** Swift、UIKit、Swift Testing、Xcode、`.strings` 本地化资源

## Global Constraints

- 保留偏好键 `Reader.hideBarsOnSwipe` 及其默认值。
- 点击左右翻页区域继续始终隐藏栏。
- 页码滑块跳页不自动隐藏栏。
- 空格切换栏、章节切换及其他快捷键行为不变。
- 设置标题使用“翻页时隐藏栏”语义。
- 提交信息使用中文。

---

## 文件结构

- `Aidoku/Features/Reader/ReaderViewController.swift`：为键盘与 Apple Pencil 共用的离散翻页入口增加隐藏栏策略。
- `AidokuTests/ReaderKeyboardShortcutsTests.swift`：验证六个翻页键在选项开启和关闭时的栏可见性行为。
- `Aidoku/Features/Reader/ReaderSettingsView.swift`：阅读器内设置页改用新的本地化标题键。
- `Aidoku/Features/Settings/Settings.swift`：全局阅读器设置页改用新的本地化标题键。
- `Aidoku/App/Resources/Localization/*.lproj/Localizable.strings`：将设置标题从“滑动时隐藏栏”更新为“翻页时隐藏栏”。

### Task 1：让离散翻页入口遵循隐藏栏选项

**Files:**
- Modify: `AidokuTests/ReaderKeyboardShortcutsTests.swift`
- Modify: `Aidoku/Features/Reader/ReaderViewController.swift:1511-1522`
- Modify: `Aidoku/Features/Reader/ReaderViewController.swift:1761-1767`

**Interfaces:**
- Consumes: `UserDefaults.standard.bool(forKey: "Reader.hideBarsOnSwipe")`、`ReaderViewController.hideBars()`、`ReaderReaderDelegate.moveLeft()` 与 `moveRight()`。
- Produces: `ReaderViewController.hideBarsForPageTurnIfNeeded()`，由 `moveLeft()`、`moveRight()`、`nextPage()` 和 `previousPage()` 调用。

- [ ] **Step 1：先增加失败测试**

将测试套件设为串行，避免修改共享 `UserDefaults` 时相互干扰，并加入以下辅助方法和两项行为测试：

```swift
@MainActor
@Suite(.serialized) struct ReaderKeyboardShortcutsTests {
    private let hideBarsSettingKey = "Reader.hideBarsOnSwipe"
    private let pageNavigationInputs = [
        UIKeyCommand.inputLeftArrow,
        UIKeyCommand.inputRightArrow,
        UIKeyCommand.inputUpArrow,
        UIKeyCommand.inputPageUp,
        UIKeyCommand.inputDownArrow,
        UIKeyCommand.inputPageDown
    ]

    private func makeController() -> (ReaderViewController, UINavigationController) {
        let manga = AidokuRunner.Manga(sourceKey: "test", key: "test", title: "Test")
        let chapter = AidokuRunner.Chapter(key: "test")
        let controller = ReaderViewController(source: nil, manga: manga, chapter: chapter)
        let navigationController = UINavigationController(rootViewController: controller)
        return (controller, navigationController)
    }

    private func withHideBarsSetting(_ enabled: Bool, perform: () throws -> Void) rethrows {
        let previousValue = UserDefaults.standard.object(forKey: hideBarsSettingKey)
        UserDefaults.standard.set(enabled, forKey: hideBarsSettingKey)
        defer {
            if let previousValue {
                UserDefaults.standard.set(previousValue, forKey: hideBarsSettingKey)
            } else {
                UserDefaults.standard.removeObject(forKey: hideBarsSettingKey)
            }
        }
        try perform()
    }

    private func performPageNavigationKey(_ input: String, on controller: ReaderViewController) throws {
        let command = try #require(controller.keyCommands?.first { $0.input == input })
        let action = try #require(command.action)
        _ = controller.perform(action)
    }

    @Test func pageNavigationKeysUsePreviousAndNextPageActions() {
        let (controller, navigationController) = makeController()
        _ = navigationController
        let actionsByInput: [String: String] = Dictionary(
            uniqueKeysWithValues: (controller.keyCommands ?? []).compactMap { command in
                guard let input = command.input, let action = command.action else { return nil }
                return (input, NSStringFromSelector(action))
            }
        )

        #expect(actionsByInput[UIKeyCommand.inputUpArrow] == "previousPage")
        #expect(actionsByInput[UIKeyCommand.inputPageUp] == "previousPage")
        #expect(actionsByInput[UIKeyCommand.inputDownArrow] == "nextPage")
        #expect(actionsByInput[UIKeyCommand.inputPageDown] == "nextPage")
    }

    @Test func pageNavigationKeysHideBarsWhenSettingEnabled() throws {
        try withHideBarsSetting(true) {
            let (controller, navigationController) = makeController()
            _ = navigationController
            UIView.setAnimationsEnabled(false)
            defer { UIView.setAnimationsEnabled(true) }

            for input in pageNavigationInputs {
                controller.statusBarHidden = false
                try performPageNavigationKey(input, on: controller)
                #expect(controller.statusBarHidden)
            }
        }
    }

    @Test func pageNavigationKeysKeepBarsVisibleWhenSettingDisabled() throws {
        try withHideBarsSetting(false) {
            let (controller, navigationController) = makeController()
            _ = navigationController
            UIView.setAnimationsEnabled(false)
            defer { UIView.setAnimationsEnabled(true) }

            for input in pageNavigationInputs {
                controller.statusBarHidden = false
                try performPageNavigationKey(input, on: controller)
                #expect(!controller.statusBarHidden)
            }
        }
    }
}
```

- [ ] **Step 2：运行测试并确认因缺少行为而失败**

Run:

```bash
xcodebuild -project Aidoku.xcodeproj -scheme Aidoku -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -only-testing:AidokuTests/ReaderKeyboardShortcutsTests test
```

Expected: `pageNavigationKeysHideBarsWhenSettingEnabled()` 失败，报告 `statusBarHidden` 仍为 `false`；现有快捷键映射测试和关闭选项测试通过。

- [ ] **Step 3：实现最小隐藏栏策略**

在 `ReaderViewController` 的翻页方法附近增加：

```swift
private func hideBarsForPageTurnIfNeeded() {
    if UserDefaults.standard.bool(forKey: "Reader.hideBarsOnSwipe") {
        hideBars()
    }
}
```

在四个离散翻页入口转发翻页前调用该方法：

```swift
@objc private func nextPage() {
    hideBarsForPageTurnIfNeeded()
    switch readingMode {
        case .rtl: reader?.moveLeft()
        default: reader?.moveRight()
    }
}

@objc private func previousPage() {
    hideBarsForPageTurnIfNeeded()
    switch readingMode {
        case .rtl: reader?.moveRight()
        default: reader?.moveLeft()
    }
}

@objc func moveLeft() {
    hideBarsForPageTurnIfNeeded()
    reader?.moveLeft()
}

@objc func moveRight() {
    hideBarsForPageTurnIfNeeded()
    reader?.moveRight()
}
```

`nextPage()` 与 `previousPage()` 同时由纵向键盘快捷键和 Apple Pencil 挤压调用，因此不增加 Pencil 专用分支。

- [ ] **Step 4：运行聚焦测试并确认通过**

Run:

```bash
xcodebuild -project Aidoku.xcodeproj -scheme Aidoku -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -only-testing:AidokuTests/ReaderKeyboardShortcutsTests test
```

Expected: `ReaderKeyboardShortcutsTests` 全部通过。

- [ ] **Step 5：提交行为与测试**

```bash
git add Aidoku/Features/Reader/ReaderViewController.swift AidokuTests/ReaderKeyboardShortcutsTests.swift
git commit -m "功能：翻页时按设置隐藏阅读器栏"
```

### Task 2：更新设置标题及本地化

**Files:**
- Modify: `Aidoku/Features/Reader/ReaderSettingsView.swift:301-303`
- Modify: `Aidoku/Features/Settings/Settings.swift:432-434`
- Modify: `Aidoku/App/Resources/Localization/en.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/zh-Hans.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/zh-Hant.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/ja.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/sv.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/id.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/es.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/vi.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/tr.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/fr.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/hr.lproj/Localizable.strings`
- Modify: `Aidoku/App/Resources/Localization/ta.lproj/Localizable.strings`

**Interfaces:**
- Consumes: 兼容偏好键 `Reader.hideBarsOnSwipe`。
- Produces: 本地化标题键 `HIDE_BARS_ON_PAGE_TURN`，供两个设置页面使用。

- [ ] **Step 1：确认新标题键尚不存在**

Run:

```bash
rg -n '"HIDE_BARS_ON_PAGE_TURN"' Aidoku
```

Expected: 无匹配，命令以状态码 1 退出。

- [ ] **Step 2：切换两个设置页面的标题键**

在 `ReaderSettingsView.swift` 和 `Settings.swift` 中保持设置偏好键不变，仅将标题改为：

```swift
title: NSLocalizedString("HIDE_BARS_ON_PAGE_TURN"),
```

- [ ] **Step 3：替换各语言的本地化条目**

将原 `HIDE_BARS_ON_SWIPE` 条目替换为以下内容：

```text
en:      "HIDE_BARS_ON_PAGE_TURN" = "Hide Bars on Page Turn";
zh-Hans: "HIDE_BARS_ON_PAGE_TURN" = "翻页时隐藏栏";
zh-Hant: "HIDE_BARS_ON_PAGE_TURN" = "翻頁時隱藏工具列";
ja:      "HIDE_BARS_ON_PAGE_TURN" = "ページ送り時にバーを非表示";
sv:      "HIDE_BARS_ON_PAGE_TURN" = "Dölj fält vid sidbyte";
id:      "HIDE_BARS_ON_PAGE_TURN" = "Sembunyikan Bilah saat Membalik Halaman";
es:      "HIDE_BARS_ON_PAGE_TURN" = "Ocultar barras al pasar página";
vi:      "HIDE_BARS_ON_PAGE_TURN" = "Ẩn thanh khi chuyển trang";
tr:      "HIDE_BARS_ON_PAGE_TURN" = "Sayfa Çevirirken Çubukları Gizle";
fr:      "HIDE_BARS_ON_PAGE_TURN" = "Masquer les barres au changement de page";
hr:      "HIDE_BARS_ON_PAGE_TURN" = "Sakrij trake pri okretanju stranice";
ta:      "HIDE_BARS_ON_PAGE_TURN" = "பக்கம் திருப்பும்போது பட்டைகளை மறை";
```

- [ ] **Step 4：验证本地化键完整替换**

Run:

```bash
rg -n '"HIDE_BARS_ON_(SWIPE|PAGE_TURN)"' Aidoku
```

Expected: 仅有 `HIDE_BARS_ON_PAGE_TURN`；两个 Swift 调用点和 12 个本地化条目，共 14 个匹配。

- [ ] **Step 5：构建应用**

Run:

```bash
xcodebuild -project Aidoku.xcodeproj -scheme Aidoku -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 6：提交设置文案**

```bash
git add Aidoku/Features/Reader/ReaderSettingsView.swift Aidoku/Features/Settings/Settings.swift Aidoku/App/Resources/Localization
git commit -m "本地化：将隐藏栏选项改为翻页语义"
```

### Task 3：完整回归验证

**Files:**
- Verify: `Aidoku/Features/Reader/ReaderViewController.swift`
- Verify: `AidokuTests/ReaderKeyboardShortcutsTests.swift`
- Verify: `Aidoku/Features/Reader/ReaderSettingsView.swift`
- Verify: `Aidoku/Features/Settings/Settings.swift`
- Verify: `Aidoku/App/Resources/Localization/*.lproj/Localizable.strings`

**Interfaces:**
- Consumes: Task 1 的隐藏栏行为和 Task 2 的本地化标题。
- Produces: 可交付的构建与测试证据。

- [ ] **Step 1：再次运行聚焦测试**

Run:

```bash
xcodebuild -project Aidoku.xcodeproj -scheme Aidoku -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -only-testing:AidokuTests/ReaderKeyboardShortcutsTests test
```

Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 2：检查差异格式**

Run:

```bash
git diff --check HEAD~2
```

Expected: 无输出，状态码为 0。

- [ ] **Step 3：核对工作区范围**

Run:

```bash
git status --short
```

Expected: 仅保留用户原有的未跟踪 `userscripts/`，本计划产生的文件均已提交。
