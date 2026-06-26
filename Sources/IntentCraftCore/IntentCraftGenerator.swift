import Foundation
import FoundationModels

/// The shared brain of IntentCraft.
///
/// Wraps Apple's on-device `LanguageModelSession` (FoundationModels) to turn a developer's
/// existing Swift code into App Intents boilerplate. Runs entirely on-device (or via Apple's
/// Private Cloud Compute) — no developer code ever leaves Apple's privacy boundary.
///
/// Used unchanged by both the CLI and the SwiftUI app.
public final class IntentCraftGenerator: Sendable {

    public init() {}

    // MARK: Availability

    /// Whether Apple's on-device model is ready to use right now, with a human-readable reason if not.
    public static func availability() -> Result<Void, IntentCraftError> {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .success(())
        case .unavailable(let reason):
            let text: String
            switch reason {
            case .deviceNotEligible:
                text = "This Mac does not support Apple Intelligence."
            case .appleIntelligenceNotEnabled:
                text = "Apple Intelligence is not enabled. Turn it on in System Settings ▸ Apple Intelligence & Siri."
            case .modelNotReady:
                text = "The system model is still downloading or warming up. Try again shortly."
            @unknown default:
                text = "The system model is unavailable for an unknown reason."
            }
            return .failure(.modelUnavailable(reason: text))
        @unknown default:
            return .failure(.modelUnavailable(reason: "Unknown availability state."))
        }
    }

    // MARK: Generation (one-shot)

    /// Generate the full App Intents code for the given Swift source.
    ///
    /// - Parameters:
    ///   - source: The developer's existing Swift code.
    ///   - fileName: Optional originating file name, used to enrich the prompt.
    /// - Returns: A structured ``GeneratedIntentCode``; call `.assembledSource` for a ready-to-paste file.
    public func generate(
        fromSwiftSource source: String,
        fileName: String? = nil
    ) async throws -> GeneratedIntentCode {
        try Self.requireAvailable()
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IntentCraftError.emptySource }

        let session = makeSession()
        let prompt = IntentCraftPrompts.userPrompt(forSwiftSource: trimmed, fileName: fileName)

        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedIntentCode.self
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            throw IntentCraftError.generationFailed(underlying: error.errorDescription ?? "\(error)")
        } catch {
            throw IntentCraftError.generationFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: Generation (streaming)

    /// Stream the generation, yielding progressively-assembled Swift source as the model produces it.
    ///
    /// Each yielded value is the best-effort assembled source so far — ideal for live UI / terminal
    /// rendering. The final yielded value equals the completed ``GeneratedIntentCode/assembledSource``.
    public func streamSource(
        fromSwiftSource source: String,
        fileName: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try Self.requireAvailable()
                    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { throw IntentCraftError.emptySource }

                    let session = makeSession()
                    let prompt = IntentCraftPrompts.userPrompt(forSwiftSource: trimmed, fileName: fileName)
                    let stream = session.streamResponse(
                        to: prompt,
                        generating: GeneratedIntentCode.self
                    )

                    for try await partial in stream {
                        // `partial.content` is the PartiallyGenerated form; rebuild a best-effort file.
                        let snapshot = Self.assemble(partial: partial.content)
                        continuation.yield(snapshot)
                    }
                    continuation.finish()
                } catch let error as LanguageModelSession.GenerationError {
                    continuation.finish(throwing: IntentCraftError.generationFailed(underlying: error.errorDescription ?? "\(error)"))
                } catch let error as IntentCraftError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: IntentCraftError.generationFailed(underlying: error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Internals

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: IntentCraftPrompts.systemInstructions)
    }

    private static func requireAvailable() throws {
        if case .failure(let error) = availability() { throw error }
    }

    /// Build a readable snapshot from a partially-generated result during streaming.
    private static func assemble(partial: GeneratedIntentCode.PartiallyGenerated) -> String {
        var blocks: [String] = []
        let imports = (partial.imports ?? [])
            .map { $0.replacingOccurrences(of: "import ", with: "").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !imports.isEmpty {
            blocks.append(imports.map { "import \($0)" }.joined(separator: "\n"))
        } else {
            blocks.append("import AppIntents")
        }

        func section(_ title: String, _ types: [GeneratedType.PartiallyGenerated]?) {
            guard let types, !types.isEmpty else { return }
            blocks.append("// MARK: - \(title)")
            for type in types {
                if let code = type.code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(code.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        section("App Entities", partial.appEntities)
        section("App Intents", partial.appIntents)
        if let provider = partial.appShortcutsProvider?.trimmingCharacters(in: .whitespacesAndNewlines),
           !provider.isEmpty {
            blocks.append("// MARK: - App Shortcuts")
            blocks.append(provider)
        }
        return blocks.joined(separator: "\n\n") + "\n"
    }
}
