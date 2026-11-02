//
//  ReaderKeyboardShortcutsTests.swift
//  Aidoku
//

import AidokuRunner
import Testing
import UIKit

@testable import Aidomiku

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
