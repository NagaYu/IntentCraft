import Foundation

/// Small filesystem helpers shared by the CLI (and usable from the app).
public enum SwiftSourceLoader {

    /// Read a Swift file from disk, throwing an IntentCraft error on failure.
    public static func read(path: String) throws -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            throw IntentCraftError.fileNotReadable(path: path)
        }
        return text
    }

    /// Write generated source to disk, creating parent directories as needed.
    public static func write(_ contents: String, to path: String) throws {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
