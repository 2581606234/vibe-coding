import Foundation
import Testing
@testable import VibePMCore

@Suite("Localization")
struct LocalizationTests {
    @Test("System language resolves Chinese variants")
    func systemLanguageResolvesChinese() {
        #expect(AppLanguage.system.resolved(systemLanguages: ["zh-Hans-CN"]) == .simplifiedChinese)
        #expect(AppLanguage.system.resolved(systemLanguages: ["zh-Hant-TW"]) == .simplifiedChinese)
    }

    @Test("System language falls back to English")
    func systemLanguageFallsBackToEnglish() {
        #expect(AppLanguage.system.resolved(systemLanguages: ["fr-FR"]) == .english)
        #expect(AppLanguage.system.resolved(systemLanguages: []) == .english)
    }

    @Test("Explicit language overrides system language")
    func explicitLanguageWins() {
        #expect(AppLanguage.english.resolved(systemLanguages: ["zh-Hans"]) == .english)
        #expect(AppLanguage.simplifiedChinese.resolved(systemLanguages: ["en-US"]) == .simplifiedChinese)
    }

    @Test("Known strings and format arguments are localized")
    func knownStringsAreLocalized() {
        #expect(L10n.text("Today", language: .simplifiedChinese) == "今天")
        #expect(L10n.text("Today", language: .english) == "Today")
        #expect(
            L10n.format("%d Tasks", language: .simplifiedChinese, arguments: [3]) == "3 个任务"
        )
        #expect(
            L10n.format("Delete %d Tasks?", language: .simplifiedChinese, arguments: [2]) == "删除 2 个任务？"
        )
        #expect(
            L10n.format("Delete \"%@\"?", language: .simplifiedChinese, arguments: ["发布计划"])
                == "删除“发布计划”？"
        )
        #expect(
            L10n.text("Priority: High to Low", language: .simplifiedChinese) == "优先级：从高到低"
        )
        #expect(L10n.text("Empty Trash", language: .simplifiedChinese) == "清空废纸篓")
        #expect(L10n.text("Empty Trash", language: .english) == "Empty Trash")
        #expect(
            L10n.format("Moved to Trash: %@", language: .simplifiedChinese, arguments: ["2026-09-20 16:00"])
                == "进入废纸篓：2026-09-20 16:00"
        )
    }

    @Test("Unknown strings remain readable")
    func unknownStringsFallBackToKey() {
        #expect(L10n.text("Unregistered copy", language: .simplifiedChinese) == "Unregistered copy")
    }
}
