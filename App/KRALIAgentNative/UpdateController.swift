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
    @Published var updateChannel: String?

    private let rootURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Developer/KRALI-Agent", isDirectory: true)

    private let failureMarkerURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(
            "Library/Application Support/KRALI Agent/update-failure.txt",
            isDirectory: false
        )

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
        let installedVersion = currentVersion
        let installedSourceRevision = currentSourceRevision()

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let branch = try Self.run(
                        executable: "/usr/bin/git",
                        arguments: ["-C", root.path, "branch", "--show-current"]
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                    let upstream = (
                        try? Self.run(
                            executable: "/usr/bin/git",
                            arguments: [
                                "-C", root.path,
                                "rev-parse",
                                "--abbrev-ref",
                                "--symbolic-full-name",
                                "@{u}"
                            ]
                        )
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    )

                    let upstreamRef: String
                    if let upstream, !upstream.isEmpty {
                        upstreamRef = upstream
                    } else if !branch.isEmpty {
                        upstreamRef = "origin/" + branch
                    } else {
                        upstreamRef = "origin/main"
                    }

                    let remoteBranch =
                        upstreamRef.hasPrefix("origin/")
                        ? String(upstreamRef.dropFirst("origin/".count))
                        : branch

                    if !remoteBranch.isEmpty {
                        _ = try Self.run(
                            executable: "/usr/bin/git",
                            arguments: [
                                "-C", root.path,
                                "fetch", "origin", remoteBranch
                            ]
                        )
                    }

                    let remoteVersion = try Self.run(
                        executable: "/usr/bin/git",
                        arguments: [
                            "-C", root.path,
                            "show", upstreamRef + ":VERSION"
                        ]
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                    let versionIsNewer =
                        Self.isVersion(
                            remoteVersion,
                            newerThan: installedVersion
                        )

                    var relevantCodeIsNewer = false

                    if let installedSourceRevision,
                       !installedSourceRevision.isEmpty,
                       !installedSourceRevision.hasSuffix("-dirty") {
                        let sourceExists = Self.runStatus(
                            executable: "/usr/bin/git",
                            arguments: [
                                "-C", root.path,
                                "cat-file", "-e",
                                installedSourceRevision + "^{commit}"
                            ]
                        ) == 0

                        let remoteDescendsFromSource =
                            sourceExists &&
                            Self.runStatus(
                                executable: "/usr/bin/git",
                                arguments: [
                                    "-C", root.path,
                                    "merge-base",
                                    "--is-ancestor",
                                    installedSourceRevision,
                                    upstreamRef
                                ]
                            ) == 0

                        if remoteDescendsFromSource {
                            let diffStatus = Self.runStatus(
                                executable: "/usr/bin/git",
                                arguments: [
                                    "-C", root.path,
                                    "diff", "--quiet",
                                    installedSourceRevision,
                                    upstreamRef,
                                    "--",
                                    "App",
                                    "Scripts",
                                    "VERSION"
                                ]
                            )

                            relevantCodeIsNewer =
                                diffStatus == 1
                        }
                    }

                    return (
                        upstreamRef: upstreamRef,
                        remoteVersion: remoteVersion,
                        versionIsNewer: versionIsNewer,
                        relevantCodeIsNewer: relevantCodeIsNewer
                    )
                }.value

                remoteVersion = result.remoteVersion
                updateChannel = result.upstreamRef

                updateAvailable =
                    result.versionIsNewer ||
                    result.relevantCodeIsNewer

                if updateAvailable,
                   let failure = readFailureMarker(),
                   failure.version == result.remoteVersion {
                    statusText =
                        "v\(failure.version) kurulamadı • " +
                        failure.message
                } else if updateAvailable {
                    statusText =
                        "v\(result.remoteVersion) hazır • " +
                        result.upstreamRef
                } else {
                    statusText =
                        "v\(currentVersion) • Güncel • " +
                        result.upstreamRef
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

            statusText = "Güncelleme hazırlanıyor… KRALİ build tamamlanana kadar açık kalacak."
        } catch {
            isLaunchingUpdate = false
            statusText = "Updater başlatılamadı"
        }
    }

    private func currentSourceRevision() -> String? {
        guard let url = Bundle.main.url(
            forResource: "KRALISourceRevision",
            withExtension: "txt"
        ),
        let raw = try? String(
            contentsOf: url,
            encoding: .utf8
        )
        else {
            return nil
        }

        let value = raw.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return value.isEmpty ? nil : value
    }

    nonisolated private static func isVersion(
        _ candidate: String,
        newerThan current: String
    ) -> Bool {
        let lhs = candidate
            .split(separator: ".")
            .map { Int($0) ?? 0 }
        let rhs = current
            .split(separator: ".")
            .map { Int($0) ?? 0 }

        let count = max(lhs.count, rhs.count)

        for index in 0..<count {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0

            if a != b {
                return a > b
            }
        }

        return false
    }

    private func readFailureMarker()
        -> (version: String, message: String)? {
        guard
            let content = try? String(
                contentsOf: failureMarkerURL,
                encoding: .utf8
            )
        else {
            return nil
        }

        let parts = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(
                separator: "|",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )

        guard !parts.isEmpty else {
            return nil
        }

        let version = String(parts[0])
        let message =
            parts.count > 1
                ? String(parts[1])
                : "Güncelleme başarısız"

        return (version, message)
    }

    nonisolated private static func run(
        executable: String,
        arguments: [String]
    ) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let outputData =
            outputPipe.fileHandleForReading
                .readDataToEndOfFile()
        let errorData =
            errorPipe.fileHandleForReading
                .readDataToEndOfFile()

        process.waitUntilExit()

        let output =
            String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput =
            String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "KRALIUpdater",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        errorOutput.isEmpty
                        ? output
                        : errorOutput
                ]
            )
        }

        return output
    }

    nonisolated private static func runStatus(
        executable: String,
        arguments: [String]
    ) -> Int32 {
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: executable
        )
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    nonisolated private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
