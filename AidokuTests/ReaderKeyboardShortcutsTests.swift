//
//  ReaderKeyboardShortcutsTests.swift
//  Aidoku
//

import AidokuRunner
import Testing
import UIKit

@testable import Aidomiku

@MainActor
@Suite struct ReaderKeyboardShortcutsTests {
    @Test func pageNavigationKeysUsePreviousAndNextPageActions() {
        let manga = AidokuRunner.Manga(sourceKey: "test", key: "test", title: "Test")
        let chapter = AidokuRunner.Chapter(key: "test")
        let controller = ReaderViewController(source: nil, manga: manga, chapter: chapter)
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
}
