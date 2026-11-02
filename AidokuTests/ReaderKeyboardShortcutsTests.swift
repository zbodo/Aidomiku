//
//  ReaderKeyboardShortcutsTests.swift
//  Aidoku
//

import AidokuRunner
import Testing
import UIKit

@testable import Aidomiku

@MainActor
private final class ReaderReaderDelegateSpy: UIViewController, ReaderReaderDelegate {
    var readingMode: ReadingMode = .rtl
    weak var delegate: ReaderHoldingDelegate?

    private(set) var moveLeftCallCount = 0
    private(set) var moveRightCallCount = 0

    func moveLeft() {
        moveLeftCallCount += 1
    }

    func moveRight() {
        moveRightCallCount += 1
    }

    func sliderMoved(value: CGFloat) {}

    func sliderStopped(value: CGFloat) {}

    func setChapter(_ chapter: AidokuRunner.Chapter, startPage: Int) {}
}

@MainActor
@Suite(.serialized) struct ReaderKeyboardShortcutsTests {
    private enum TestError: Error {
        case timedOutWaitingForBarsToHide
    }

    private let hideBarsSettingKey = "Reader.hideBarsOnSwipe"

    private func makeController() -> (ReaderViewController, UINavigationController, ReaderReaderDelegateSpy) {
        let manga = AidokuRunner.Manga(sourceKey: "test", key: "test", title: "Test")
        let chapter = AidokuRunner.Chapter(key: "test")
        let controller = ReaderViewController(source: nil, manga: manga, chapter: chapter)
        let navigationController = UINavigationController(rootViewController: controller)
        let reader = ReaderReaderDelegateSpy()
        controller.reader = reader
        navigationController.setNavigationBarHidden(false, animated: false)
        navigationController.setToolbarHidden(false, animated: false)
        return (controller, navigationController, reader)
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

    private func withHideBarsSetting(_ enabled: Bool, perform: () async throws -> Void) async rethrows {
        let previousValue = UserDefaults.standard.object(forKey: hideBarsSettingKey)
        UserDefaults.standard.set(enabled, forKey: hideBarsSettingKey)
        defer {
            if let previousValue {
                UserDefaults.standard.set(previousValue, forKey: hideBarsSettingKey)
            } else {
                UserDefaults.standard.removeObject(forKey: hideBarsSettingKey)
            }
        }
        try await perform()
    }

    private func performPageNavigationKey(_ input: String, on controller: ReaderViewController) throws {
        let command = try #require(controller.keyCommands?.first { $0.input == input })
        let action = try #require(command.action)
        UIView.performWithoutAnimation {
            _ = controller.perform(action)
        }
    }

    private func waitForBarsToHide(on navigationController: UINavigationController) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while !navigationController.isNavigationBarHidden || !navigationController.isToolbarHidden {
            guard clock.now < deadline else {
                throw TestError.timedOutWaitingForBarsToHide
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func pageNavigationKeysUsePreviousAndNextPageActions() {
        let (controller, _, _) = makeController()
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

    @Test func allPageNavigationKeysForwardInRTLAndHideBarsWhenEnabled() async throws {
        try await withHideBarsSetting(true) {
            for (input, expectedDirection) in [
                (UIKeyCommand.inputLeftArrow, \ReaderReaderDelegateSpy.moveLeftCallCount),
                (UIKeyCommand.inputDownArrow, \ReaderReaderDelegateSpy.moveLeftCallCount),
                (UIKeyCommand.inputPageDown, \ReaderReaderDelegateSpy.moveLeftCallCount),
                (UIKeyCommand.inputRightArrow, \ReaderReaderDelegateSpy.moveRightCallCount),
                (UIKeyCommand.inputUpArrow, \ReaderReaderDelegateSpy.moveRightCallCount),
                (UIKeyCommand.inputPageUp, \ReaderReaderDelegateSpy.moveRightCallCount)
            ] {
                let (controller, navigationController, reader) = makeController()
                try performPageNavigationKey(input, on: controller)

                #expect(reader[keyPath: expectedDirection] == 1)
                #expect(reader.moveLeftCallCount + reader.moveRightCallCount == 1)
                #expect(controller.statusBarHidden)
                try await waitForBarsToHide(on: navigationController)
                #expect(navigationController.isNavigationBarHidden)
                #expect(navigationController.isToolbarHidden)
            }
        }
    }

    @Test func allPageNavigationKeysForwardInRTLAndKeepBarsVisibleWhenDisabled() throws {
        try withHideBarsSetting(false) {
            for (input, expectedDirection) in [
                (UIKeyCommand.inputLeftArrow, \ReaderReaderDelegateSpy.moveLeftCallCount),
                (UIKeyCommand.inputDownArrow, \ReaderReaderDelegateSpy.moveLeftCallCount),
                (UIKeyCommand.inputPageDown, \ReaderReaderDelegateSpy.moveLeftCallCount),
                (UIKeyCommand.inputRightArrow, \ReaderReaderDelegateSpy.moveRightCallCount),
                (UIKeyCommand.inputUpArrow, \ReaderReaderDelegateSpy.moveRightCallCount),
                (UIKeyCommand.inputPageUp, \ReaderReaderDelegateSpy.moveRightCallCount)
            ] {
                let (controller, navigationController, reader) = makeController()
                try performPageNavigationKey(input, on: controller)

                #expect(reader[keyPath: expectedDirection] == 1)
                #expect(reader.moveLeftCallCount + reader.moveRightCallCount == 1)
                #expect(!controller.statusBarHidden)
                #expect(!navigationController.isNavigationBarHidden)
                #expect(!navigationController.isToolbarHidden)
            }
        }
    }

    @Test func applePencilSharedPreviousAndNextPageSelectorsForwardInRTL() throws {
        try withHideBarsSetting(false) {
            let (controller, _, reader) = makeController()

            // UIKit does not expose a constructible squeeze event, so invoke the shared @objc entry points directly.
            UIView.performWithoutAnimation {
                _ = controller.perform(NSSelectorFromString("previousPage"))
            }
            #expect(reader.moveRightCallCount == 1)
            #expect(reader.moveLeftCallCount == 0)

            UIView.performWithoutAnimation {
                _ = controller.perform(NSSelectorFromString("nextPage"))
            }
            #expect(reader.moveLeftCallCount == 1)
            #expect(reader.moveRightCallCount == 1)
        }
    }
}
