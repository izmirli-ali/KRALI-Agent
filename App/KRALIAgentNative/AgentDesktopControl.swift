import Foundation
import AppKit
import ApplicationServices

struct DesktopAppActionResult: Codable, Hashable, Sendable {
    let requestedText: String
    let resolvedApplicationName: String
    let resolvedApplicationURL: String?
    let wasRunning: Bool
    let launchOrActivateSucceeded: Bool
    let frontmostAfter: String?
    let screenVerifiedFrontmost: Bool
    let screenSummary: String?
}

struct DesktopControlProbeReport: Codable, Hashable, Sendable {
    let createdAt: Date
    let requestedApplication: String
    let resolvedApplicationURL: String?
    let accessibilityTrustedBeforePrompt: Bool
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

    func openOrFocusApplication(
        from userText: String
    ) async throws -> DesktopAppActionResult {
        guard let candidate =
            resolveRequestedApplication(
                from: userText
            )
        else {
            throw DesktopControlError
                .applicationNotFound(userText)
        }

        let runningBefore =
            matchingRunningApplication(
                named: candidate.name,
                preferredBundleIdentifier:
                    candidate.bundleIdentifier
            )

        let activated: Bool
        if let runningBefore {
            activated = runningBefore.activate(
                options: [.activateAllWindows]
            )
        } else {
            activated = try await openApplication(
                at: candidate.url
            )
        }

        guard activated else {
            throw DesktopControlError
                .launchFailed(candidate.name)
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
                    "\(candidate.name) uygulamasının açıldığını ve önde olduğunu yalnızca ekran kanıtından doğrula."
            )

        let afterNormalized =
            normalize(after ?? "")

        let candidateNormalized =
            normalize(candidate.name)

        let screenVerified =
            screenReport.map {
                let reportFrontmost =
                    normalize(
                        $0.frontmostApplication ?? ""
                    )

                return
                    reportFrontmost == candidateNormalized ||
                    (!afterNormalized.isEmpty &&
                     reportFrontmost == afterNormalized)
            } ?? false

        return DesktopAppActionResult(
            requestedText: userText,
            resolvedApplicationName:
                candidate.name,
            resolvedApplicationURL:
                candidate.url.path,
            wasRunning: runningBefore != nil,
            launchOrActivateSucceeded:
                activated,
            frontmostAfter: after,
            screenVerifiedFrontmost:
                screenVerified,
            screenSummary:
                screenReport?.semanticSummary
        )
    }

    func probeOpenApplication(
        named name: String,
        preferredBundleIdentifier: String? = nil
    ) async throws -> DesktopControlProbeReport {
        let before =
            NSWorkspace.shared.frontmostApplication?
                .localizedName

        let trustedBefore =
            accessibilityTrusted(
                promptIfNeeded: false
            )

        _ = accessibilityTrusted(
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

        let trusted =
            await waitForAccessibilityTrust(
                maxAttempts: 12,
                delayMilliseconds: 500
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
            accessibilityTrustedBeforePrompt:
                trustedBefore,
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

    private struct ApplicationCandidate {
        let name: String
        let aliases: [String]
        let bundleIdentifier: String?
        let url: URL
    }

    private func resolveRequestedApplication(
        from userText: String
    ) -> ApplicationCandidate? {
        let corpus = normalize(userText)
        let candidates = installedApplicationCandidates()

        let exact = candidates
            .filter { candidate in
                candidate.aliases.contains { alias in
                    let normalized =
                        normalize(alias)

                    return
                        !normalized.isEmpty &&
                        corpus.contains(normalized)
                }
            }
            .sorted {
                let lhs = $0.aliases
                    .map { normalize($0).count }
                    .max() ?? 0
                let rhs = $1.aliases
                    .map { normalize($0).count }
                    .max() ?? 0
                return lhs > rhs
            }

        if let candidate = exact.first {
            return candidate
        }

        let tokens = Set(
            corpus.split(separator: " ")
                .map(String.init)
                .filter { $0.count >= 3 }
        )

        return candidates
            .map { candidate in
                let nameTokens = Set(
                    candidate.aliases
                        .flatMap {
                            normalize($0)
                                .split(separator: " ")
                                .map(String.init)
                        }
                )

                return (
                    candidate,
                    tokens.intersection(
                        nameTokens
                    ).count
                )
            }
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 == $1.1 {
                    return
                        $0.0.name.count <
                        $1.0.name.count
                }

                return $0.1 > $1.1
            }
            .first?
            .0
    }

    private func installedApplicationCandidates()
        -> [ApplicationCandidate] {
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

        var results: [ApplicationCandidate] = []
        var seen = Set<String>()

        for root in roots {
            guard let entries = try? fileManager
                .contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else {
                continue
            }

            for url in entries where
                url.pathExtension
                    .lowercased() == "app" {
                let bundle = Bundle(url: url)
                let baseName =
                    url.deletingPathExtension()
                        .lastPathComponent
                let localizedName =
                    bundle?
                        .localizedInfoDictionary?[
                            "CFBundleDisplayName"
                        ] as? String ??
                    bundle?
                        .localizedInfoDictionary?[
                            "CFBundleName"
                        ] as? String ??
                    baseName
                let bundleID =
                    bundle?.bundleIdentifier

                let key =
                    (bundleID ?? url.path)
                        .lowercased()

                guard !seen.contains(key) else {
                    continue
                }

                seen.insert(key)
                let finderDisplayName =
                    fileManager.displayName(
                        atPath: url.path
                    )

                let aliases = Array(
                    Set([
                        baseName,
                        localizedName,
                        finderDisplayName
                    ])
                )
                .filter {
                    !$0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                }

                results.append(
                    ApplicationCandidate(
                        name:
                            finderDisplayName.isEmpty
                                ? localizedName
                                : finderDisplayName,
                        aliases: aliases,
                        bundleIdentifier:
                            bundleID,
                        url: url
                    )
                )
            }
        }

        return results
    }

    private func waitForAccessibilityTrust(
        maxAttempts: Int,
        delayMilliseconds: Int
    ) async -> Bool {
        if accessibilityTrusted(
            promptIfNeeded: false
        ) {
            return true
        }

        for _ in 0..<maxAttempts {
            try? await Task.sleep(
                for: .milliseconds(
                    delayMilliseconds
                )
            )

            if accessibilityTrusted(
                promptIfNeeded: false
            ) {
                return true
            }
        }

        return false
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
