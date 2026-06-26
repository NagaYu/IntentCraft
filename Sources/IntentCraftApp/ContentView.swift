import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = GeneratorViewModel()
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                inputPane
                    .frame(minWidth: 360)
                outputPane
                    .frame(minWidth: 360)
            }
            Divider()
            statusBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("IntentCraft")
                    .font(.headline)
                Text("On-device App Intents generator")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !viewModel.modelAvailable {
                Label("Apple Intelligence off", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(viewModel.modelUnavailableReason ?? "")
            }
            Button {
                viewModel.generate()
            } label: {
                Label("Generate", systemImage: "sparkles")
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canGenerate)

            if viewModel.stage.isBusy {
                Button(role: .cancel) { viewModel.cancel() } label: {
                    Image(systemName: "stop.fill")
                }
                .help("Cancel")
            }
        }
        .padding(12)
    }

    // MARK: Input (left)

    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            paneTitle("Your Swift code", systemImage: "swift")
            ZStack {
                TextEditor(text: $viewModel.sourceCode)
                    .font(.system(.body, design: .monospaced))
                    .padding(6)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                if viewModel.sourceCode.isEmpty {
                    placeholder("Drop a .swift file here, or paste your functions and structs.")
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onDrop(of: [.fileURL, .swiftSource, .plainText], isTargeted: nil, perform: handleDrop)
        }
        .padding(12)
    }

    // MARK: Output (right)

    private var outputPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                paneTitle("Generated App Intents", systemImage: "gearshape.2")
                Spacer()
                Button {
                    copyOutput()
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .disabled(viewModel.generatedCode.isEmpty)
                .controlSize(.small)
            }
            ScrollView {
                Text(viewModel.generatedCode.isEmpty ? " " : viewModel.generatedCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if viewModel.generatedCode.isEmpty && !viewModel.stage.isBusy {
                    placeholder("AppIntent / AppEntity code will appear here.")
                }
            }
        }
        .padding(12)
    }

    // MARK: Status bar (bottom)

    private var statusBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: viewModel.stage.fraction)
                .progressViewStyle(.linear)
                .tint(viewModel.stage == .failed ? .red : .accentColor)
            HStack(spacing: 8) {
                if viewModel.stage.isBusy {
                    ProgressView().controlSize(.small)
                }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(viewModel.stage == .failed ? .red : .secondary)
                Spacer()
                Text("100% on-device · powered by Apple FoundationModels")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusText: String {
        if viewModel.stage == .failed, let msg = viewModel.errorMessage {
            return msg
        }
        return viewModel.stage.label
    }

    // MARK: Helpers

    private func paneTitle(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(24)
            .allowsHitTesting(false)
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.generatedCode, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            copied = false
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in viewModel.loadFile(at: url) }
            }
            return true
        }
        if provider.canLoadObject(ofClass: NSString.self) {
            _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                guard let string = string as? String else { return }
                Task { @MainActor in viewModel.sourceCode = string }
            }
            return true
        }
        return false
    }
}
