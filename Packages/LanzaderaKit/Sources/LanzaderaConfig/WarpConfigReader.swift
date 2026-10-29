import Foundation
import LanzaderaCore
import Yams

/// Lee las *Launch Configurations* de Warp. Cada archivo es un documento YAML.
public enum WarpConfigReader {
    public static let defaultDirectory = URL.homeDirectory.appending(path: ".warp/launch_configurations", directoryHint: .isDirectory)

    public struct ReadError: Error, Sendable, CustomStringConvertible {
        public var file: String
        public var message: String
        public var description: String { "\(file): \(message)" }
    }

    /// Todos los `.yaml`/`.yml` de la carpeta, ordenados por nombre. Los ilegibles se informan aparte.
    public static func read(directory: URL = defaultDirectory) -> (configs: [WarpLaunchConfig], errors: [ReadError]) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var configs: [WarpLaunchConfig] = []
        var errors: [ReadError] = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where ["yaml", "yml"].contains(file.pathExtension.lowercased()) {
            do {
                let text = try String(contentsOf: file, encoding: .utf8)
                configs.append(try parse(text, fallbackName: file.deletingPathExtension().lastPathComponent))
            } catch {
                errors.append(ReadError(file: file.lastPathComponent, message: String(describing: error)))
            }
        }
        return (configs, errors)
    }

    public static func parse(_ text: String, fallbackName: String) throws -> WarpLaunchConfig {
        let file = try YAMLDecoder().decode(WarpFile.self, from: text)
        return WarpLaunchConfig(
            name: file.name ?? fallbackName,
            activeWindowIndex: file.activeWindowIndex ?? 0,
            windows: (file.windows ?? []).map { window in
                WarpWindow(
                    activeTabIndex: window.activeTabIndex ?? 0,
                    tabs: (window.tabs ?? []).map { tab in
                        let layout = tab.layout?.layout ?? .pane(cwd: nil, isFocused: false, commands: [])
                        return WarpTab(title: tab.title, color: tab.color, layout: layout)
                    }
                )
            }
        )
    }
}

// MARK: - Esquema de Warp

private struct WarpFile: Decodable {
    var name: String?
    var activeWindowIndex: Int?
    var windows: [WarpFileWindow]?

    enum CodingKeys: String, CodingKey {
        case name, windows
        case activeWindowIndex = "active_window_index"
    }
}

private struct WarpFileWindow: Decodable {
    var activeTabIndex: Int?
    var tabs: [WarpFileTab]?

    enum CodingKeys: String, CodingKey {
        case tabs
        case activeTabIndex = "active_tab_index"
    }
}

private struct WarpFileTab: Decodable {
    var title: String?
    var color: String?
    var layout: WarpFileLayout?
}

/// Hoja (`cwd`, `is_focused`, `commands`) o división (`split_direction` + `panes`).
private struct WarpFileLayout: Decodable {
    var cwd: String?
    var isFocused: Bool?
    var commands: [WarpFileCommand]?
    var splitDirection: String?
    var panes: [WarpFileLayout]?

    enum CodingKeys: String, CodingKey {
        case cwd, commands, panes
        case isFocused = "is_focused"
        case splitDirection = "split_direction"
    }

    var layout: WarpLayout {
        if let panes, !panes.isEmpty {
            return .split(direction: splitDirection ?? "horizontal", panes: panes.map(\.layout))
        }
        return .pane(cwd: cwd, isFocused: isFocused ?? false, commands: (commands ?? []).compactMap(\.exec))
    }
}

private struct WarpFileCommand: Decodable {
    var exec: String?
}
