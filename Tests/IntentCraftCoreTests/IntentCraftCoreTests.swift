import Testing
import Foundation
@testable import IntentCraftCore

@Suite("IntentCraft core")
struct IntentCraftCoreTests {

    @Test("Assembled source always imports AppIntents and Foundation")
    func assembledImports() {
        let code = GeneratedIntentCode(
            imports: ["AppIntents"],
            appEntities: [],
            appIntents: [GeneratedType(name: "DoThingIntent", code: "struct DoThingIntent: AppIntent {}")],
            appShortcutsProvider: "",
            summary: "x"
        )
        let src = code.assembledSource
        #expect(src.contains("import AppIntents"))
        #expect(src.contains("import Foundation"))
        #expect(src.contains("struct DoThingIntent"))
    }

    @Test("Import lines are de-duplicated and `import ` prefix is stripped")
    func dedupesImports() {
        let code = GeneratedIntentCode(
            imports: ["AppIntents", "import AppIntents", "Foundation"],
            appEntities: [],
            appIntents: [],
            appShortcutsProvider: "",
            summary: ""
        )
        let importBlock = code.assembledSource.split(separator: "\n\n").first.map(String.init) ?? ""
        let count = importBlock.components(separatedBy: "import AppIntents").count - 1
        #expect(count == 1)
    }

    @Test("Sections and shortcuts provider are emitted with MARKs")
    func sectionsAndProvider() {
        let code = GeneratedIntentCode(
            imports: [],
            appEntities: [GeneratedType(name: "TaskEntity", code: "struct TaskEntity: AppEntity {}")],
            appIntents: [GeneratedType(name: "AddTaskIntent", code: "struct AddTaskIntent: AppIntent {}")],
            appShortcutsProvider: "struct Shortcuts: AppShortcutsProvider {}",
            summary: "ok"
        )
        let src = code.assembledSource
        #expect(src.contains("// MARK: - App Entities"))
        #expect(src.contains("// MARK: - App Intents"))
        #expect(src.contains("// MARK: - App Shortcuts"))
        #expect(src.contains("TaskEntity"))
        #expect(src.contains("Shortcuts: AppShortcutsProvider"))
    }

    @Test("sanitize() truncates a code field to its first balanced type")
    func sanitizeTruncatesArtifacts() {
        // The on-device model sometimes leaks Guided-Generation array punctuation.
        #expect(GeneratedIntentCode.sanitize("struct Q: EntityQuery { var t: String } }],")
                == "struct Q: EntityQuery { var t: String }")
        #expect(GeneratedIntentCode.sanitize("struct A: AppIntent { func perform() {} }")
                == "struct A: AppIntent { func perform() {} }")
        // No braces → returned trimmed, unchanged.
        #expect(GeneratedIntentCode.sanitize("  import AppIntents  ") == "import AppIntents")
    }

    @Test("Empty source is rejected before hitting the model")
    func emptySourceThrows() async {
        let gen = IntentCraftGenerator()
        await #expect(throws: IntentCraftError.self) {
            // Availability may pass or fail; either way empty source must not silently succeed.
            _ = try await gen.generate(fromSwiftSource: "   \n  ")
        }
    }

    @Test("File loader reports unreadable paths")
    func fileLoaderThrows() {
        #expect(throws: IntentCraftError.self) {
            _ = try SwiftSourceLoader.read(path: "/nonexistent/\(UUID().uuidString).swift")
        }
    }
}
