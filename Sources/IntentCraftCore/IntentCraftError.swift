import Foundation
import FoundationModels

/// User-facing errors surfaced by the core. Both front-ends render `errorDescription` directly.
public enum IntentCraftError: Error, LocalizedError, Sendable {
    /// Apple Intelligence is off, the device is ineligible, or the model is still downloading.
    case modelUnavailable(reason: String)
    /// The provided source was empty / unreadable.
    case emptySource
    /// The file could not be read from disk.
    case fileNotReadable(path: String)
    /// The on-device model declined or failed to generate.
    case generationFailed(underlying: String)

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return "On-device model unavailable: \(reason)"
        case .emptySource:
            return "No Swift source was provided to analyze."
        case .fileNotReadable(let path):
            return "Could not read Swift file at: \(path)"
        case .generationFailed(let underlying):
            return "Code generation failed: \(underlying)"
        }
    }
}
