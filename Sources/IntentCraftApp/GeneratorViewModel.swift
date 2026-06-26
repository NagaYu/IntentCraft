import Foundation
import Observation
import IntentCraftCore

/// Drives the desktop UI. Owns the shared ``IntentCraftGenerator`` and exposes
/// observable state for the view to render.
@MainActor
@Observable
public final class GeneratorViewModel {

    /// Coarse pipeline stage, surfaced in the bottom progress bar.
    public enum Stage: Equatable {
        case idle
        case checkingModel
        case analyzing
        case generating
        case done
        case failed

        var label: String {
            switch self {
            case .idle:          return "Ready"
            case .checkingModel: return "Checking on-device model…"
            case .analyzing:     return "Analyzing your code…"
            case .generating:    return "Generating App Intents…"
            case .done:          return "Done"
            case .failed:        return "Failed"
            }
        }

        /// Indeterminate-ish fraction for the progress bar (0…1).
        var fraction: Double {
            switch self {
            case .idle:          return 0.0
            case .checkingModel: return 0.15
            case .analyzing:     return 0.35
            case .generating:    return 0.7
            case .done:          return 1.0
            case .failed:        return 1.0
            }
        }

        var isBusy: Bool {
            self == .checkingModel || self == .analyzing || self == .generating
        }
    }

    public var sourceCode: String = ""
    public var generatedCode: String = ""
    public var stage: Stage = .idle
    public var errorMessage: String?
    /// True when Apple Intelligence is available on this Mac.
    public var modelAvailable: Bool = true
    public var modelUnavailableReason: String?

    private let generator = IntentCraftGenerator()
    private var currentTask: Task<Void, Never>?

    public init() {
        refreshAvailability()
    }

    public func refreshAvailability() {
        switch IntentCraftGenerator.availability() {
        case .success:
            modelAvailable = true
            modelUnavailableReason = nil
        case .failure(let error):
            modelAvailable = false
            modelUnavailableReason = error.errorDescription
        }
    }

    public var canGenerate: Bool {
        modelAvailable && !stage.isBusy &&
        !sourceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func generate() {
        guard canGenerate else { return }
        currentTask?.cancel()
        errorMessage = nil
        generatedCode = ""

        currentTask = Task { [weak self] in
            guard let self else { return }
            self.stage = .checkingModel
            self.refreshAvailability()
            guard self.modelAvailable else {
                self.errorMessage = self.modelUnavailableReason
                self.stage = .failed
                return
            }

            self.stage = .analyzing
            let source = self.sourceCode
            do {
                // Brief analyzing beat, then switch to generating as the stream produces output.
                self.stage = .generating
                for try await snapshot in self.generator.streamSource(fromSwiftSource: source) {
                    if Task.isCancelled { return }
                    self.generatedCode = snapshot
                }
                self.stage = .done
            } catch {
                self.errorMessage = (error as? IntentCraftError)?.errorDescription ?? error.localizedDescription
                self.stage = .failed
            }
        }
    }

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        if stage.isBusy { stage = .idle }
    }

    public func loadFile(at url: URL) {
        do {
            sourceCode = try SwiftSourceLoader.read(path: url.path)
        } catch {
            errorMessage = (error as? IntentCraftError)?.errorDescription ?? error.localizedDescription
        }
    }
}
