import Foundation

struct DeveloperAgentStatus: Hashable {
    let state: String
    let message: String
    let branch: String?
    let worktree: String?

    var isReadyForReview: Bool {
        state == "ready_for_review" ||
        state == "build_failed"
    }

    var isSetupRequired: Bool {
        [
            "setup_required",
            "setup_node",
            "setup_homebrew",
            "setup_node_upgrade",
            "setup_cline"
        ].contains(state)
    }

    var setupHint: String? {
        switch state {
        case "setup_node":
            return "Terminal: brew install node"
        case "setup_homebrew":
            return "Önce Homebrew kur; ardından brew install node"
        case "setup_node_upgrade":
            return "Node.js 20+ gerekiyor; Homebrew kullanıyorsan brew upgrade node"
        case "setup_cline", "setup_required":
            return "Terminal: npm install -g cline → cline auth"
        default:
            return nil
        }
    }
}

struct AgentDeveloperBridge {
    private let fileManager = FileManager.default

    var statusURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Developer/latest.txt",
                isDirectory: false
            )
    }

    var scriptURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Developer/KRALI-Agent/Scripts/run-developer-agent.command",
                isDirectory: false
            )
    }

    func readStatus() -> DeveloperAgentStatus {
        guard
            let text = try? String(
                contentsOf: statusURL,
                encoding: .utf8
            )
        else {
            return DeveloperAgentStatus(
                state: "idle",
                message: "Developer Agent henüz çalıştırılmadı.",
                branch: nil,
                worktree: nil
            )
        }

        let parts = text
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .split(
                separator: "|",
                omittingEmptySubsequences: false
            )
            .map(String.init)

        return DeveloperAgentStatus(
            state: parts.indices.contains(0)
                ? parts[0]
                : "unknown",
            message: parts.indices.contains(1)
                ? parts[1]
                : "Durum bilgisi yok.",
            branch: parts.indices.contains(2) &&
                !parts[2].isEmpty
                ? parts[2]
                : nil,
            worktree: parts.indices.contains(3) &&
                !parts[3].isEmpty
                ? parts[3]
                : nil
        )
    }

    func writeStatus(
        _ status: DeveloperAgentStatus
    ) {
        let directory = statusURL
            .deletingLastPathComponent()

        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let value = [
            status.state,
            status.message,
            status.branch ?? "",
            status.worktree ?? ""
        ]
        .joined(separator: "|")

        try? value.write(
            to: statusURL,
            atomically: true,
            encoding: .utf8
        )
    }

    func run() async -> DeveloperAgentStatus {
        guard fileManager.fileExists(
            atPath: scriptURL.path
        ) else {
            return DeveloperAgentStatus(
                state: "setup_required",
                message: "Developer Agent scripti bulunamadı. Önce KRALİ'yi güncelle.",
                branch: nil,
                worktree: nil
            )
        }

        let scriptPath = scriptURL.path

        let result = await Task.detached(
            priority: .utility
        ) {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(
                fileURLWithPath: "/bin/zsh"
            )
            process.arguments = [
                scriptPath
            ]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                _ = pipe.fileHandleForReading
                    .readDataToEndOfFile()

                return Int(
                    process.terminationStatus
                )
            } catch {
                return -1
            }
        }
        .value

        let status = readStatus()

        if result == 0 || status.state != "idle" {
            return status
        }

        return DeveloperAgentStatus(
            state: "failed",
            message: "Developer Agent başlatılamadı.",
            branch: nil,
            worktree: nil
        )
    }
}
