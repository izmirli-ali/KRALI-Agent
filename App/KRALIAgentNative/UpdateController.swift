import Foundation
import AppKit

@MainActor
final class UpdateController: ObservableObject {
    @Published var currentVersion: String
    @Published var remoteVersion: String?
    @Published var updateAvailable = false
    @Published var isChecking = false
    @Published var isLaunchingUpdate = false
    @Published var statusText = "KRALİ aktif"

    private let rootURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Developer/KRALI-Agent", isDirectory: true)

    init() {
        currentVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0"

        Task { @MainActor [weak self] in
            try? await Task.sleep(
                for: .milliseconds(900)
            )
            self?.checkForUpdates()
        }
    }

    func checkForUpdates() {
        guard !isChecking else { return }

        isChecking = true
        statusText = "Güncelleme kontrol ediliyor…"

        let root = rootURL

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try Self.run(
                        executable: "/usr/bin/git",
                        arguments: ["-C", root.path, "fetch", "origin", "main"]
                    )

                    let local = try Self.run(
                        executable: "/usr/bin/git",
                        arguments: ["-C", root.path, "rev-parse", "HEAD"]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    let remote = try Self.run(
                        executable: "/usr/bin/git",
                        arguments: ["-C", root.path, "rev-parse", "origin/main"]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    let remoteVersion = try Self.run(
                        executable: "/usr/bin/git",
                        arguments: ["-C", root.path, "show", "origin/main:VERSION"]
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                    return (
                        localDiffersFromRemote: local != remote,
                        remoteVersion: remoteVersion
                    )
                }.value

                remoteVersion = result.remoteVersion

                let installedVersionDiffers =
                    !result.remoteVersion.isEmpty &&
                    result.remoteVersion != currentVersion

                updateAvailable =
                    result.localDiffersFromRemote ||
                    installedVersionDiffers

                if updateAvailable {
                    if let remoteVersion, !remoteVersion.isEmpty {
                        statusText = "v\(remoteVersion) hazır"
                    } else {
                        statusText = "Güncelleme hazır"
                    }
                } else {
                    statusText = "v\(currentVersion) • Güncel"
                }
            } catch {
                updateAvailable = false
                statusText = "Güncelleme kontrolü başarısız"
            }

            isChecking = false
        }
    }

    func updateNow() {
        guard !isLaunchingUpdate else { return }

        let script = rootURL
            .appendingPathComponent("Scripts/update.command")
            .path

        guard FileManager.default.fileExists(atPath: script) else {
            statusText = "Updater script bulunamadı"
            return
        }

        isLaunchingUpdate = true
        statusText = "Güncelleme başlatılıyor…"

        do {
            let logsURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs", isDirectory: true)

            try FileManager.default.createDirectory(
                at: logsURL,
                withIntermediateDirectories: true
            )

            let logPath = logsURL
                .appendingPathComponent("KRALI-Agent-Updater.log")
                .path

            let command = "/usr/bin/nohup /bin/zsh \(Self.shellQuote(script)) > \(Self.shellQuote(logPath)) 2>&1 &"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            try process.run()

            statusText = "KRALİ kapanacak; güncelleme bitince yeniden açılacak…"

            Task {
                try? await Task.sleep(for: .milliseconds(700))
                NSApplication.shared.terminate(nil)
            }
        } catch {
            isLaunchingUpdate = false
            statusText = "Updater başlatılamadı"
        }
    }

    nonisolated private static func run(
        executable: String,
        arguments: [String]
    ) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "KRALIUpdater",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }

        return output
    }

    nonisolated private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
