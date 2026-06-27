import Foundation
import FoundationModels

/// A single named Swift type produced by the model (an `AppEntity` or an `AppIntent`).
///
/// Splitting the output into discrete named types — instead of one big string — lets us
/// rely on FoundationModels' *Guided Generation* to keep the model honest about structure,
/// and lets the UI render / copy each type independently.
@Generable
public struct GeneratedType: Sendable, Equatable {
    @Guide(description: "The Swift type name only, e.g. \"AddTaskIntent\" or \"TaskEntity\".")
    public var name: String

    @Guide(description: "Complete, compilable Swift source for this single type, including the full body. No markdown fences, no commentary, no leading import lines.")
    public var code: String
}

/// The full, structured result of an IntentCraft generation pass.
///
/// The model fills each field via Guided Generation; ``IntentCraftGenerator`` then assembles
/// the fields into one clean, copy-paste-ready `.swift` file via ``assembledSource``.
@Generable
public struct GeneratedIntentCode: Sendable, Equatable {
    @Guide(description: "Every Swift import the generated code needs, one module per element, e.g. \"AppIntents\", \"Foundation\". Do not include the word \"import\".")
    public var imports: [String]

    @Guide(description: "Each AppEntity type required to expose the developer's data structures to Siri / Spotlight. Empty array if none are needed.")
    public var appEntities: [GeneratedType]

    @Guide(description: "Each AppIntent type that wraps a developer function or action so the system AI can invoke it. At least one is expected.")
    public var appIntents: [GeneratedType]

    @Guide(description: "The single AppShortcutsProvider type wiring the generated intents into Siri phrases. Full Swift source, no import lines. Empty string only if genuinely not applicable.")
    public var appShortcutsProvider: String

    @Guide(description: "One or two plain-language sentences telling the developer what was generated and any manual wiring still required.")
    public var summary: String
}

public extension GeneratedIntentCode {
    /// Assemble the structured pieces into a single clean Swift file, ready to drop into a project.
    var assembledSource: String {
        var blocks: [String] = []

        let importLines = imports
            .map { $0.replacingOccurrences(of: "import ", with: "").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        // AppIntents always needs to be imported; guarantee it even if the model forgot.
        var modules = importLines
        if !modules.contains("AppIntents") { modules.insert("AppIntents", at: 0) }
        if !modules.contains("Foundation") { modules.append("Foundation") }
        // Stable de-dupe preserving first-seen order.
        var seen = Set<String>()
        modules = modules.filter { seen.insert($0).inserted }
        blocks.append(modules.map { "import \($0)" }.joined(separator: "\n"))

        func section(_ title: String, _ types: [GeneratedType]) {
            guard !types.isEmpty else { return }
            blocks.append("// MARK: - \(title)")
            for type in types {
                blocks.append(GeneratedIntentCode.sanitize(type.code))
            }
        }

        section("App Entities", appEntities)
        section("App Intents", appIntents)

        let provider = GeneratedIntentCode.sanitize(appShortcutsProvider)
        if !provider.isEmpty {
            blocks.append("// MARK: - App Shortcuts")
            blocks.append(provider)
        }

        return blocks.joined(separator: "\n\n") + "\n"
    }

    /// Clean a single `code` field coming back from the on-device model.
    ///
    /// The small on-device model occasionally leaks Guided-Generation array punctuation
    /// (e.g. a trailing `}],`) into a `code` field. Each field is contractually ONE Swift
    /// type, so we keep the source only up to the brace that balances the first `{`,
    /// discarding any trailing junk. Inputs with no braces are returned trimmed as-is.
    static func sanitize(_ raw: String) -> String {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstBrace = code.firstIndex(of: "{") else { return code }

        var depth = 0
        var endIndex: String.Index? = nil
        var i = firstBrace
        while i < code.endIndex {
            let ch = code[i]
            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 { endIndex = code.index(after: i); break }
            }
            i = code.index(after: i)
        }

        guard let end = endIndex else { return code } // unbalanced — leave untouched
        return String(code[code.startIndex..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
