import Foundation
import AppKit
import ApplicationServices

struct DesktopControlProbeReport: Codable, Hashable, Sendable {
    let createdAt: Date
    let requestedApplication: String
    let resolvedApplicationURL: String?
    let accessibilityTrusted: Bool
    let wasRunning: Bool
    let launchOrActivateSucceeded: Bool
    let frontmostBefore: String?
    let frontmostAfter: String?
    let screenVerifiedFrontmost: Bool
    let screenSummary: String?
}

enum DesktopControlError: LocalizedError {
    case applicationNotFound(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .applicationNotFound(let name):
            return "Uygulama bulunamadı: \(name)"
        case .launchFailed(let name):
            return "Uygulama açılamadı veya öne getirilemedi: \(name)"
        }
    }
}

actor AgentDesktopControl {
    private let fileManager = FileManager.default
    private let screenPerception = AgentScreenPerception()

    func accessibilityTrusted(
        promptIfNeeded: Bool
    ) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue()
                as String: promptIfNeeded
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(
            options
        )
    }

    func probeOpenApplication(
        named name: String,
        preferredBundleIdentifier: String? = nil
    ) async throws -> DesktopControlProbeReport {
        let before =
            NSWorkspace.shared.frontmostApplication?
                .localizedName

        let trusted = accessibilityTrusted(
            promptIfNeeded: true
        )

        let runningBefore =
            matchingRunningApplication(
                named: name,
                preferredBundleIdentifier:
                    preferredBundleIdentifier
            )

        let appURL: URL?
        if let preferredBundleIdentifier,
           let resolved =
            NSWorkspace.shared.urlForApplication(
                withBundleIdentifier:
                    preferredBundleIdentifier
            ) {
            appURL = resolved
        } else {
            appURL = resolveApplicationURL(
                named: name
            )
        }

        var activated = false

        if let runningBefore {
            activated = runningBefore.activate(
                options: [.activateAllWindows]
            )
        } else {
            guard let appURL else {
                throw DesktopControlError
                    .applicationNotFound(name)
            }

            activated = try await openApplication(
                at: appURL
            )
        }

        guard activated else {
            throw DesktopControlError
                .launchFailed(name)
        }

        try? await Task.sleep(
            for: .milliseconds(700)
        )

        let after =
            NSWorkspace.shared.frontmostApplication?
                .localizedName

        let screenReport =
            try? await screenPerception.observe(
                goal:
                    "\(name) uygulamasının açıldığını ve önde olduğunu yalnızca ekran kanıtından doğrula."
            )

        let frontmostNormalized =
            normalize(after ?? "")

        let nameNormalized =
            normalize(name)

        let screenVerified =
            screenReport.map {
                let reportFrontmost =
                    normalize(
                        $0.frontmostApplication ?? ""
                    )

                return
                    reportFrontmost == nameNormalized ||
                    (!frontmostNormalized.isEmpty &&
                     reportFrontmost ==
                        frontmostNormalized)
            } ?? false

        return DesktopControlProbeReport(
            createdAt: Date(),
            requestedApplication: name,
            resolvedApplicationURL:
                appURL?.path,
            accessibilityTrusted: trusted,
            wasRunning: runningBefore != nil,
            launchOrActivateSucceeded: activated,
            frontmostBefore: before,
            frontmostAfter: after,
            screenVerifiedFrontmost:
                screenVerified,
            screenSummary:
                screenReport?.semanticSummary
        )
    }

    private func matchingRunningApplication(
        named name: String,
        preferredBundleIdentifier: String?
    ) -> NSRunningApplication? {
        let requested = normalize(name)

        return NSWorkspace.shared.runningApplications
            .first { app in
                if let preferredBundleIdentifier,
                   app.bundleIdentifier ==
                    preferredBundleIdentifier {
                    return true
                }

                let localized =
                    normalize(
                        app.localizedName ?? ""
                    )

                return
                    localized == requested ||
                    localized.contains(requested) ||
                    requested.contains(localized)
            }
    }

    private func resolveApplicationURL(
        named name: String
    ) -> URL? {
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Applications",
                    isDirectory: true
                )
        ]

        let requested = normalize(name)
        var fallback: URL?

        for root in roots {
            guard let entries = try? fileManager
                .contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: nil,
                    options: [
                        .skipsHiddenFiles,
                        .skipsPackageDescendants
                    ]
                )
            else {
                continue
            }

            for url in entries where
                url.pathExtension.lowercased() == "app" {
                let baseName =
                    normalize(
                        url.deletingPathExtension()
                            .lastPathComponent
                    )

                let bundle = Bundle(url: url)
                let localizedDisplayName =
                    normalize(
                        bundle?
                            .localizedInfoDictionary?[
                                "CFBundleDisplayName"
                            ] as? String ??
                        bundle?
                            .localizedInfoDictionary?[
                                "CFBundleName"
                            ] as? String ??
                        ""
                    )

                if baseName == requested ||
                   localizedDisplayName ==
                    requested {
                    return url
                }

                if fallback == nil &&
                   (
                    baseName.contains(requested) ||
                    requested.contains(baseName) ||
                    localizedDisplayName
                        .contains(requested)
                   ) {
                    fallback = url
                }
            }
        }

        return fallback
    }

    private func openApplication(
        at url: URL
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation {
            continuation in

            let configuration =
                NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.addsToRecentItems = false

            NSWorkspace.shared.openApplication(
                at: url,
                configuration: configuration
            ) { app, error in
                if let error {
                    continuation.resume(
                        throwing: error
                    )
                    return
                }

                guard let app else {
                    continuation.resume(
                        returning: false
                    )
                    return
                }

                let activated = app.activate(
                    options: [.activateAllWindows]
                )

                continuation.resume(
                    returning: activated
                )
            }
        }
    }

    private func normalize(
        _ value: String
    ) -> String {
        value
            .folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive
                ],
                locale:
                    Locale(identifier: "tr_TR")
            )
            .lowercased()
            .replacingOccurrences(
                of: "ı",
                with: "i"
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }
}

struct DesktopControlProbeStore {
    private let fileManager = FileManager.default

    var outputURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor/desktop-control-latest.json",
                isDirectory: false
            )
    }

    var statusURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor/desktop-control-status.txt",
                isDirectory: false
            )
    }

    func save(
        _ report: DesktopControlProbeReport
    ) throws {
        let directory =
            outputURL.deletingLastPathComponent()

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(report)
        try data.write(
            to: outputURL,
            options: .atomic
        )
    }

    func saveStatus(
        _ value: String
    ) {
        let directory =
            statusURL.deletingLastPathComponent()

        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        try? value.write(
            to: statusURL,
            atomically: true,
            encoding: .utf8
        )
    }

    func readStatus() -> String? {
        try? String(
            contentsOf: statusURL,
            encoding: .utf8
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    func load() -> DesktopControlProbeReport? {
        guard
            let data = try? Data(
                contentsOf: outputURL
            )
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try? decoder.decode(
            DesktopControlProbeReport.self,
            from: data
        )
    }
}
