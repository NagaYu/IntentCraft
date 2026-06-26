import Foundation
import ArgumentParser
import IntentCraftCore

// ANSI styling helpers — kept tiny and dependency-free.
enum Ansi {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    static let cyan = "\u{001B}[36m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let red = "\u{001B}[31m"
    static let magenta = "\u{001B}[35m"

    /// Whether to emit color: a TTY that isn't being piped and hasn't opted out via NO_COLOR.
    static var enabled: Bool {
        if ProcessInfo.processInfo.environment["NO_COLOR"] != nil { return false }
        return isatty(fileno(stdout)) == 1
    }

    static func wrap(_ text: String, _ codes: String...) -> String {
        guard enabled else { return text }
        return codes.joined() + text + reset
    }
}

func printErr(_ s: String) {
    FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
}

/// A naive but pleasant Swift syntax highlighter for terminal output.
/// Not a real tokenizer — just enough to make pasted code readable.
enum SwiftHighlighter {
    static let keywords: Set<String> = [
        "import", "struct", "class", "enum", "actor", "protocol", "extension",
        "func", "var", "let", "static", "public", "private", "internal", "open",
        "final", "async", "throws", "await", "try", "return", "self", "some",
        "init", "guard", "if", "else", "for", "in", "while", "switch", "case",
        "default", "nil", "true", "false", "nonisolated", "where", "associatedtype"
    ]

    static func highlight(_ source: String) -> String {
        guard Ansi.enabled else { return source }
        var out = ""
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") {
                out += Ansi.wrap(line, Ansi.dim) + "\n"
                continue
            }
            // Highlight @Attributes and keywords token-by-token, preserving spacing.
            var rendered = ""
            var token = ""
            func flush() {
                guard !token.isEmpty else { return }
                if token.hasPrefix("@") {
                    rendered += Ansi.wrap(token, Ansi.magenta)
                } else if keywords.contains(token) {
                    rendered += Ansi.wrap(token, Ansi.cyan, Ansi.bold)
                } else if let first = token.first, first.isUppercase {
                    rendered += Ansi.wrap(token, Ansi.green) // type names
                } else {
                    rendered += token
                }
                token = ""
            }
            for ch in line {
                if ch.isLetter || ch.isNumber || ch == "_" || ch == "@" {
                    token.append(ch)
                } else {
                    flush()
                    rendered.append(ch)
                }
            }
            flush()
            out += rendered + "\n"
        }
        return out
    }
}

@main
struct IntentCraft: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "intentcraft",
        abstract: "Generate Apple App Intents boilerplate from existing Swift code, fully on-device.",
        discussion: """
        IntentCraft reads your Swift functions and data structures and uses Apple's on-device
        FoundationModels LLM to emit the AppIntent / AppEntity / AppShortcutsProvider code needed
        to make your app work with Siri and Apple Intelligence. Nothing leaves your Mac.
        """,
        version: "0.1.0"
    )

    @Argument(help: "Path to the Swift file containing the code you want to expose to Siri.")
    var inputFile: String

    @Option(name: [.short, .long], help: "Write the generated Swift to this path instead of the terminal.")
    var output: String?

    @Flag(name: .long, help: "Disable live streaming; print only the final result.")
    var noStream: Bool = false

    func run() async throws {
        // 1. Availability gate.
        if case .failure(let error) = IntentCraftGenerator.availability() {
            printErr(Ansi.wrap("✗ ", Ansi.red) + (error.errorDescription ?? "Model unavailable"))
            throw ExitCode.failure
        }

        // 2. Load source.
        let source: String
        do {
            source = try SwiftSourceLoader.read(path: inputFile)
        } catch {
            let message = (error as? IntentCraftError)?.errorDescription ?? "\(error)"
            printErr(Ansi.wrap("✗ ", Ansi.red) + message)
            throw ExitCode.failure
        }

        let fileName = (inputFile as NSString).lastPathComponent
        printErr(Ansi.wrap("● ", Ansi.cyan) + "Analyzing \(Ansi.wrap(fileName, Ansi.bold)) with Apple's on-device model…")

        let generator = IntentCraftGenerator()

        if let output {
            // File output: run to completion, no streaming noise.
            let result = try await generator.generate(fromSwiftSource: source, fileName: fileName)
            try SwiftSourceLoader.write(result.assembledSource, to: output)
            printErr(Ansi.wrap("✓ ", Ansi.green) + "Wrote App Intents code to \(Ansi.wrap(output, Ansi.bold))")
            printErr(Ansi.wrap("  " + result.summary, Ansi.dim))
            return
        }

        // Terminal output.
        printRule("Generated App Intents")
        if noStream {
            let result = try await generator.generate(fromSwiftSource: source, fileName: fileName)
            print(SwiftHighlighter.highlight(result.assembledSource))
            printRule("Summary")
            print(Ansi.wrap(result.summary, Ansi.dim))
        } else {
            // Stream: redraw the highlighted buffer as it grows.
            var last = ""
            for try await snapshot in generator.streamSource(fromSwiftSource: source, fileName: fileName) {
                last = snapshot
            }
            // Final clean render (streaming partials can be noisy mid-flight).
            print(SwiftHighlighter.highlight(last))
        }
        printRule(nil)
    }

    private func printRule(_ title: String?) {
        let width = 64
        if let title {
            let label = " \(title) "
            let dashes = max(0, width - label.count)
            let left = dashes / 2
            let right = dashes - left
            print(Ansi.wrap(String(repeating: "─", count: left) + label + String(repeating: "─", count: right), Ansi.dim))
        } else {
            print(Ansi.wrap(String(repeating: "─", count: width), Ansi.dim))
        }
    }
}
