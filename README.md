<div align="center">

<img src="docs/banner.svg" alt="IntentCraft" width="100%"/>

# 🪄 IntentCraft

**Turn your existing Swift code into Siri & Apple Intelligence integrations — 100% on-device.**

[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.1-orange?logo=swift)](https://swift.org)
[![FoundationModels](https://img.shields.io/badge/Apple-FoundationModels-blue?logo=apple)](https://developer.apple.com/documentation/foundationmodels)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

### ▶︎ See it in action

<img src="docs/demo.gif" alt="IntentCraft generating App Intents code from real on-device output" width="80%"/>

<sub>Real output from Apple's on-device model — TaskManager.swift → AppEntity + AppIntent + AppShortcutsProvider, generated entirely on-device.</sub>

</div>

---

### What is IntentCraft?

Adopting **App Intents** — the framework that lets Siri, Spotlight, the Shortcuts app, and
**Apple Intelligence** drive your app — means writing a lot of repetitive boilerplate:
`AppIntent` types, `AppEntity` wrappers, parameter declarations, and an `AppShortcutsProvider`.

**IntentCraft reads your existing Swift functions and data structures and writes that boilerplate
for you**, using Apple's own on-device large language model via the
[**FoundationModels**](https://developer.apple.com/documentation/foundationmodels) framework.

> 🔒 **Nothing leaves your Mac.** Your source code is processed by the on-device model (or Apple's
> Private Cloud Compute), never by a third-party API. No keys, no accounts, no usage fees.

It ships as both a **command-line tool** and a **native macOS app**, sharing one core engine.

<p align="center"><img src="docs/how-it-works.svg" alt="How IntentCraft works: your Swift code goes through the on-device LLM and comes out as App Intents code" width="100%"/></p>

### ✨ Features

- 🧠 **On-device generation** — powered by Apple FoundationModels (Apple Intelligence). Fully offline.
- 🔁 **Guided Generation** — uses FoundationModels' structured output (`@Generable` / `@Guide`) so the
  model returns clean, compilable Swift — not chatty markdown.
- 🧩 **Generates the full stack** — `AppIntent`, `AppEntity`, `@Parameter`s, and an `AppShortcutsProvider`
  with natural-language Siri phrases.
- 💻 **Two front-ends, one engine** — a scriptable CLI and a drag-and-drop SwiftUI desktop app share
  the same `IntentCraftCore` module.
- 🎨 **Readable output** — syntax-highlighted streaming in the terminal; copy-button output in the app.
- 🆓 **Free & MIT-licensed** — use it personally or commercially, no strings attached.

### 📋 Requirements

- macOS **26 (Tahoe)** or later, on an Apple-Intelligence-capable Mac
- **Apple Intelligence** enabled in *System Settings ▸ Apple Intelligence & Siri*
- **Xcode 26+** to build from source (the `@Generable` macro plugin ships with Xcode)

### 📦 Installation

#### Option A — Download the app
Grab the latest `IntentCraft-x.y.z.dmg` from [Releases](../../releases), open it, and drag
**IntentCraft** to your Applications folder.

#### Option B — Build from source
```bash
git clone https://github.com/NagaYu/IntentCraft.git
cd IntentCraft

# Build & install the CLI to /usr/local/bin
./build.sh --cli

# …or build the desktop app + a distributable .dmg into ./dist
./build.sh
```

> If you have both Xcode and the bare Command Line Tools installed, point builds at Xcode:
> `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (the build script does this for you).

### 🚀 Usage

#### CLI

```bash
# Stream the generated code into your terminal (syntax-highlighted)
intentcraft Sources/MyApp/TaskStore.swift

# Write it straight to a file
intentcraft Sources/MyApp/TaskStore.swift -o Sources/MyApp/AppIntents.swift

# Print only the final result (no live streaming)
intentcraft TaskStore.swift --no-stream
```

| Argument / Option | Description |
| --- | --- |
| `<input-file>` | Path to the Swift file you want to expose to Siri. |
| `-o, --output <path>` | Write generated Swift to a file instead of the terminal. |
| `--no-stream` | Disable live streaming; print only the final code. |

#### Desktop app

<p align="center"><img src="docs/app-mockup.svg" alt="IntentCraft macOS app: source code on the left, generated App Intents on the right" width="92%"/></p>

1. **Left pane** — drop a `.swift` file or paste your functions/structs.
2. Press **⌘↵ / Generate**.
3. **Right pane** — watch the `AppIntent` / `AppEntity` code stream in, then hit **Copy**.
4. **Bottom bar** — follow the progress (*Checking model → Analyzing → Generating → Done*).

### 🔎 Example

**Input** — your existing code (`TaskStore.swift`):

```swift
final class TaskStore {
    static let shared = TaskStore()
    func addTask(title: String) -> TodoTask { /* … */ }
    func completeTask(named title: String) { /* … */ }
}
```

**Output** — what IntentCraft generates (illustrative):

```swift
import AppIntents
import Foundation

// MARK: - App Intents

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"

    @Parameter(title: "Title")
    var title: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let task = TaskStore.shared.addTask(title: title)
        return .result(value: task.title)
    }
}

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"

    @Parameter(title: "Task Name")
    var name: String

    func perform() async throws -> some IntentResult {
        TaskStore.shared.completeTask(named: name)
        return .result()
    }
}

// MARK: - App Shortcuts

struct TaskShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: ["Add a task in \(.applicationName)"]
        )
        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: ["Complete a task in \(.applicationName)"]
        )
    }
}
```

Paste it into your Xcode target and Siri can now run your code. ✅

### 🏗 Architecture

```
IntentCraft (Swift Package)
├── IntentCraftCore     ← shared engine (FoundationModels, prompts, guided generation)
│   ├── IntentCraftGenerator   – session, availability, one-shot + streaming APIs
│   ├── GeneratedIntentCode    – @Generable structured output schema
│   ├── Prompts                – the "senior Apple architect" persona + rules
│   └── SwiftSourceLoader      – file I/O helpers
├── IntentCraftCLI      ← `intentcraft` command (swift-argument-parser)
└── IntentCraftApp      ← SwiftUI desktop app (drag-and-drop, ViewModel → Core)
```

The CLI and the app are thin shells; **all analysis and generation lives in `IntentCraftCore`**, so
behaviour is identical across both.

### 🔐 Privacy

IntentCraft uses `SystemLanguageModel.default` from FoundationModels. Inference runs **on-device**, or
on Apple's **Private Cloud Compute** for larger requests — in both cases inside Apple's privacy
boundary. Your proprietary code is never sent to OpenAI, Anthropic, Google, or any external service.

### 🤝 Contributing

Issues and PRs welcome. The whole project builds with `swift build` and tests with `swift test`
(use the Xcode toolchain so the FoundationModels macros resolve).

### 📄 License

[MIT](LICENSE) — free for personal and commercial use.

---

<div align="center">
Made with 🪄 and Apple's on-device intelligence.
</div>
