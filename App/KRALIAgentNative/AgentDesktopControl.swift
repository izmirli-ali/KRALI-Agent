import Foundation
import AppKit
import ApplicationServices
import ScreenCaptureKit

struct DesktopAppActionResult: Codable, Hashable, Sendable {
    let requestedText: String
    let resolvedApplicationName: String
    let resolvedApplicationURL: String?
    let wasRunning: Bool
    let launchOrActivateSucceeded: Bool
    let frontmostAfter: String?
    let frontmostVerified: Bool
    let verificationSource: String
    let screenSummary: String?
}

struct DesktopWebActionResult: Hashable, Sendable {
    let requestedURL: String
    let openSucceeded: Bool
    let expectedHandlerApplicationURL: String?
    let expectedHandlerBundleIdentifier: String?
    let frontmostAfter: String?
    let frontmostBundleIdentifier: String?
    let handlerVerifiedFrontmost: Bool
    let observationStable: Bool
    let screenSummary: String
    let recognizedText: [String]
    let visibleWindows: [String]
    let captureScope: String
    let capturedApplicationBundleIdentifier: String?
    let capturedWindowTitle: String?
    let capturedWindowID: UInt32?
    let observationAttemptCount: Int
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
    case invalidWebURL(String)
    case webURLOpenFailed(String)

    var errorDescription: String? {
        switch self {
        case .applicationNotFound(let name):
            return "Uygulama bulunamadı: \(name)"
        case .launchFailed(let name):
            return "Uygulama açılamadı veya öne getirilemedi: \(name)"
        case .invalidWebURL(let value):
            return "Geçerli HTTP/HTTPS adresi çözülemedi: \(value)"
        case .webURLOpenFailed(let value):
            return "Web adresi macOS varsayılan işleyicisiyle açılamadı: \(value)"
        }
    }
}

actor AgentDesktopControl {
    private let fileManager = FileManager.default
    private let screenPerception = AgentScreenPerception()
    private let languageResolver =
        AgentNaturalLanguageResolver()
    private var cachedApplicationCandidates:
        [ApplicationCandidate]?

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
                .applicationNotFound(
                    languageResolver
                        .applicationTargetPhrase(
                            from: userText
                        ) ?? userText
                )
        }

        let runningBefore =
            matchingRunningApplication(
                named: candidate.name,
                preferredBundleIdentifier:
                    candidate.bundleIdentifier
            )

        if let runningBefore {
            requestActivation(
                runningBefore
            )
        } else {
            let launched = try await openApplication(
                at: candidate.url
            )

            guard launched else {
                throw DesktopControlError
                    .launchFailed(candidate.name)
            }
        }

        if candidate.bundleIdentifier ==
            "com.apple.finder" {
            _ = NSWorkspace.shared.open(
                fileManager.homeDirectoryForCurrentUser
            )
        }

        _ = await focusCandidate(
            candidate,
            maxAttempts: 14,
            delayMilliseconds: 180
        )

        var after =
            NSWorkspace.shared.frontmostApplication?
                .localizedName

        var frontmostVerified =
            await visuallyForeground(
                candidate
            )

        var verificationSource =
            frontmostVerified
                ? "ScreenCaptureKit z-order"
                : "unverified"

        var fallbackScreenSummary: String?

        if !frontmostVerified,
           let running =
            matchingRunningApplication(
                named: candidate.name,
                preferredBundleIdentifier:
                    candidate.bundleIdentifier
           ) {
            let recovered =
                await recoverForeground(
                    candidate,
                    running: running
                )

            if recovered {
                frontmostVerified = true
                verificationSource =
                    "activation recovery + AX raise + ScreenCaptureKit z-order"
                after =
                    NSWorkspace.shared
                        .frontmostApplication?
                        .localizedName
            }
        }

        if !frontmostVerified {
            let screenReport =
                try? await screenPerception.observe(
                    goal:
                        "\(candidate.name) uygulamasının görünür biçimde önde olduğunu yalnızca ekran kanıtından doğrula."
                )

            fallbackScreenSummary =
                screenReport?.semanticSummary
        }

        return DesktopAppActionResult(
            requestedText: userText,
            resolvedApplicationName:
                candidate.name,
            resolvedApplicationURL:
                candidate.url.path,
            wasRunning: runningBefore != nil,
            launchOrActivateSucceeded:
                frontmostVerified,
            frontmostAfter: after,
            frontmostVerified:
                frontmostVerified,
            verificationSource:
                verificationSource,
            screenSummary:
                fallbackScreenSummary
        )
    }

    func openWebURL(
        _ url: URL
    ) async throws -> DesktopWebActionResult {
        guard
            let scheme =
                url.scheme?
                    .lowercased(),
            scheme == "http" ||
            scheme == "https",
            url.host != nil
        else {
            throw DesktopControlError
                .invalidWebURL(
                    url.absoluteString
                )
        }

        let expectedHandlerURL =
            NSWorkspace.shared
                .urlForApplication(
                    toOpen: url
                )

        let expectedHandlerBundleIdentifier =
            expectedHandlerURL
                .flatMap {
                    Bundle(url: $0)?
                        .bundleIdentifier
                }

        let opened =
            NSWorkspace.shared.open(
                url
            )

        guard opened else {
            throw DesktopControlError
                .webURLOpenFailed(
                    url.absoluteString
                )
        }

        try? await Task.sleep(
            for: .milliseconds(900)
        )

        let frontmostBeforeObservation =
            NSWorkspace.shared
                .frontmostApplication

        let handlerVerifiedBefore =
            webHandlerMatches(
                expectedApplicationURL:
                    expectedHandlerURL,
                expectedBundleIdentifier:
                    expectedHandlerBundleIdentifier,
                runningApplication:
                    frontmostBeforeObservation
            )

        let targetBundleIdentifier =
            expectedHandlerBundleIdentifier ??
            frontmostBeforeObservation?
                .bundleIdentifier

        var report =
            try await screenPerception.observe(
                goal:
                    "Şu web adresinin varsayılan tarayıcıda açıldığını ve yalnız hedef tarayıcı penceresindeki görünür sayfa içeriğini salt-okunur doğrula: " +
                    url.absoluteString,
                targetBundleIdentifier:
                    targetBundleIdentifier
            )

        var observationAttemptCount = 1
        let capturedWindowID =
            report.capturedWindowID

        while report.recognizedText.isEmpty &&
              observationAttemptCount < 3 {
            let currentFrontmost =
                NSWorkspace.shared
                    .frontmostApplication

            guard webHandlerMatches(
                expectedApplicationURL:
                    expectedHandlerURL,
                expectedBundleIdentifier:
                    expectedHandlerBundleIdentifier,
                runningApplication:
                    currentFrontmost
            ) else {
                break
            }

            try? await Task.sleep(
                for: .milliseconds(800)
            )

            report =
                try await screenPerception.observe(
                    goal:
                        "Aynı web penceresi henüz OCR kanıtı üretmedi. Sayfanın yüklenmesini bekleyip aynı pencereyi yeniden salt-okunur gözlemle: " +
                        url.absoluteString,
                    targetBundleIdentifier:
                        targetBundleIdentifier,
                    targetWindowID:
                        capturedWindowID
                )

            observationAttemptCount += 1
        }

        let frontmostAfterObservation =
            NSWorkspace.shared
                .frontmostApplication

        let handlerVerifiedAfter =
            webHandlerMatches(
                expectedApplicationURL:
                    expectedHandlerURL,
                expectedBundleIdentifier:
                    expectedHandlerBundleIdentifier,
                runningApplication:
                    frontmostAfterObservation
            )

        let sameFrontmostProcess =
            frontmostBeforeObservation?
                .processIdentifier ==
            frontmostAfterObservation?
                .processIdentifier

        let reportMatchesFrontmost =
            normalize(
                report.frontmostApplication ??
                ""
            ) ==
            normalize(
                frontmostAfterObservation?
                    .localizedName ??
                ""
            )

        let capturedExpectedWindow =
            expectedHandlerBundleIdentifier == nil ||
            report
                .capturedApplicationBundleIdentifier ==
                expectedHandlerBundleIdentifier

        let sameCapturedWindow =
            capturedWindowID == nil ||
            report.capturedWindowID ==
                capturedWindowID

        let observationStable =
            sameFrontmostProcess &&
            reportMatchesFrontmost &&
            capturedExpectedWindow &&
            sameCapturedWindow &&
            report.captureScope == "window"

        return DesktopWebActionResult(
            requestedURL:
                url.absoluteString,
            openSucceeded:
                true,
            expectedHandlerApplicationURL:
                expectedHandlerURL?.path,
            expectedHandlerBundleIdentifier:
                expectedHandlerBundleIdentifier,
            frontmostAfter:
                frontmostAfterObservation?
                    .localizedName ??
                report.frontmostApplication,
            frontmostBundleIdentifier:
                frontmostAfterObservation?
                    .bundleIdentifier,
            handlerVerifiedFrontmost:
                handlerVerifiedBefore &&
                handlerVerifiedAfter &&
                observationStable,
            observationStable:
                observationStable,
            screenSummary:
                report.semanticSummary,
            recognizedText:
                report.recognizedText,
            visibleWindows:
                report.visibleWindows,
            captureScope:
                report.captureScope ??
                "unknown",
            capturedApplicationBundleIdentifier:
                report
                    .capturedApplicationBundleIdentifier,
            capturedWindowTitle:
                report.capturedWindowTitle,
            capturedWindowID:
                report.capturedWindowID,
            observationAttemptCount:
                observationAttemptCount
        )
    }

    private func webHandlerMatches(
        expectedApplicationURL: URL?,
        expectedBundleIdentifier: String?,
        runningApplication: NSRunningApplication?
    ) -> Bool {
        guard
            let runningApplication
        else {
            return false
        }

        if let expectedBundleIdentifier,
           !expectedBundleIdentifier.isEmpty {
            return runningApplication
                .bundleIdentifier ==
                expectedBundleIdentifier
        }

        guard
            let expectedApplicationURL,
            let runningURL =
                runningApplication
                    .bundleURL
        else {
            return false
        }

        return runningURL
            .standardizedFileURL ==
            expectedApplicationURL
                .standardizedFileURL
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
        let queries = applicationResolutionQueries(
            from: userText
        )

        // Ask LaunchServices first. It knows the user's localized
        // application display names even when the on-disk .app filename and
        // InfoPlist remain English.
        for query in queries {
            if let candidate =
                launchServicesApplicationCandidate(
                    named: query
                ) {
                return candidate
            }
        }

        let installed =
            installedApplicationCandidates()

        for query in queries {
            if let candidate =
                bestApplicationCandidate(
                    from: query,
                    candidates: installed
                ) {
                return candidate
            }
        }

        cachedApplicationCandidates = nil

        let refreshed =
            installedApplicationCandidates()

        for query in queries {
            if let candidate =
                bestApplicationCandidate(
                    from: query,
                    candidates: refreshed
                ) {
                return candidate
            }
        }

        let expanded =
            mergeCandidates(
                refreshed +
                nestedApplicationCandidates()
            )

        cachedApplicationCandidates =
            expanded

        for query in queries {
            if let candidate =
                bestApplicationCandidate(
                    from: query,
                    candidates: expanded
                ) {
                return candidate
            }
        }

        return nil
    }

    private func applicationResolutionQueries(
        from userText: String
    ) -> [String] {
        let displayTarget =
            languageResolver
                .applicationTargetDisplayPhrase(
                    from: userText
                )

        let normalizedTarget =
            languageResolver
                .applicationTargetPhrase(
                    from: userText
                )

        // An explicit app target is authoritative. Keep the user's original
        // localized spelling for LaunchServices, then the normalized variant
        // for fuzzy alias matching. Never fall back to secondary nouns from
        // the compound command once an app target is known.
        let values: [String]
        if displayTarget != nil ||
           normalizedTarget != nil {
            values =
                [
                    displayTarget,
                    normalizedTarget
                ]
                .compactMap { $0 }
        } else {
            values = [userText]
        }

        var seen = Set<String>()

        return values.filter {
            let key =
                languageResolver.normalized($0)

            guard
                !key.isEmpty,
                seen.insert(key).inserted
            else {
                return false
            }

            return true
        }
    }

    private func launchServicesApplicationCandidate(
        named rawName: String
    ) -> ApplicationCandidate? {
        let requestedName =
            rawName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !requestedName.isEmpty else {
            return nil
        }

        guard let path =
            NSWorkspace.shared
                .fullPath(
                    forApplication:
                        requestedName
                )
        else {
            return nil
        }

        let url =
            URL(
                fileURLWithPath: path
            )

        guard
            url.pathExtension
                .lowercased() == "app"
        else {
            return nil
        }

        let bundle = Bundle(url: url)
        let baseName =
            url.deletingPathExtension()
                .lastPathComponent
        let finderDisplayName =
            fileManager.displayName(
                atPath: url.path
            )
        let localizedName =
            bundle?
                .localizedInfoDictionary?[
                    "CFBundleDisplayName"
                ] as? String ??
            bundle?
                .localizedInfoDictionary?[
                    "CFBundleName"
                ] as? String ??
            finderDisplayName

        let aliases =
            languageResolver
                .mergedAliases(
                    [
                        [
                            requestedName,
                            baseName,
                            finderDisplayName,
                            localizedName,
                            (
                                try? url.resourceValues(
                                    forKeys: [
                                        .localizedNameKey
                                    ]
                                )
                            )?.localizedName ?? ""
                        ],
                        localizedBundleAliases(
                            bundle
                        )
                    ]
                )

        return ApplicationCandidate(
            name:
                finderDisplayName.isEmpty
                    ? localizedName
                    : finderDisplayName,
            aliases: aliases,
            bundleIdentifier:
                bundle?.bundleIdentifier,
            url: url
        )
    }

    private func bestApplicationCandidate(
        from userText: String,
        candidates: [ApplicationCandidate]
    ) -> ApplicationCandidate? {
        let ranked = candidates
            .map { candidate in
                (
                    candidate,
                    languageResolver.bestAliasScore(
                        input: userText,
                        aliases:
                            candidate.aliases
                    )
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

        guard let best = ranked.first else {
            return nil
        }

        guard
            languageResolver
                .isConfidentAliasMatch(
                    score: best.1,
                    input: userText
                )
        else {
            return nil
        }

        if ranked.count > 1 {
            let second = ranked[1]

            if best.1 < 0.94,
               best.1 - second.1 < 0.08 {
                return nil
            }
        }

        return best.0
    }

    private func installedApplicationCandidates()
        -> [ApplicationCandidate] {
        if let cachedApplicationCandidates {
            return cachedApplicationCandidates
        }

        let roots = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Library/CoreServices"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Applications",
                    isDirectory: true
                )
        ]

        var results: [ApplicationCandidate] = []

        for app in NSWorkspace.shared.runningApplications {
            guard
                app.activationPolicy == .regular,
                let url = app.bundleURL
            else {
                continue
            }

            let bundle = Bundle(url: url)
            let baseName =
                url.deletingPathExtension()
                    .lastPathComponent
            let localizedName =
                app.localizedName ??
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
                app.bundleIdentifier ??
                bundle?.bundleIdentifier

            let aliases = Array(
                Set(
                    [
                        baseName,
                        localizedName,
                        fileManager.displayName(
                            atPath: url.path
                        ),
                        (
                            try? url.resourceValues(
                                forKeys: [
                                    .localizedNameKey
                                ]
                            )
                        )?.localizedName ?? ""
                    ] +
                    localizedBundleAliases(
                        bundle
                    )
                )
            )
            .filter {
                !$0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            }

            results.append(
                ApplicationCandidate(
                    name: localizedName,
                    aliases: aliases,
                    bundleIdentifier:
                        bundleID,
                    url: url
                )
            )
        }

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

                let finderDisplayName =
                    fileManager.displayName(
                        atPath: url.path
                    )

                let aliases = Array(
                    Set(
                        [
                            baseName,
                            localizedName,
                            finderDisplayName,
                            (
                                try? url.resourceValues(
                                    forKeys: [
                                        .localizedNameKey
                                    ]
                                )
                            )?.localizedName ?? ""
                        ] +
                        localizedBundleAliases(
                            bundle
                        )
                    )
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

        let merged =
            mergeCandidates(
                results
            )

        cachedApplicationCandidates =
            merged

        return merged
    }

    private func nestedApplicationCandidates()
        -> [ApplicationCandidate] {
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Applications",
                    isDirectory: true
                )
        ]

        var results: [ApplicationCandidate] = []

        for root in roots {
            guard let enumerator =
                fileManager.enumerator(
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

            for case let url as URL in enumerator {
                guard
                    url.pathExtension
                        .lowercased() == "app"
                else {
                    continue
                }

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
                let finderDisplayName =
                    fileManager.displayName(
                        atPath: url.path
                    )
                let aliases = Array(
                    Set(
                        [
                            baseName,
                            localizedName,
                            finderDisplayName
                        ] +
                        localizedBundleAliases(
                            bundle
                        )
                    )
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

        return mergeCandidates(
            results
        )
    }

    private func mergeCandidates(
        _ candidates: [ApplicationCandidate]
    ) -> [ApplicationCandidate] {
        var indexes: [String: Int] = [:]
        var merged: [ApplicationCandidate] = []

        for candidate in candidates {
            let key =
                (
                    candidate.bundleIdentifier ??
                    candidate.url.path
                )
                .lowercased()

            guard let existingIndex =
                indexes[key]
            else {
                indexes[key] =
                    merged.count
                merged.append(candidate)
                continue
            }

            let existing =
                merged[existingIndex]
            let aliases =
                languageResolver
                    .mergedAliases(
                        [
                            existing.aliases,
                            candidate.aliases
                        ]
                    )

            merged[existingIndex] =
                ApplicationCandidate(
                    name:
                        existing.name.isEmpty
                            ? candidate.name
                            : existing.name,
                    aliases: aliases,
                    bundleIdentifier:
                        existing.bundleIdentifier ??
                        candidate.bundleIdentifier,
                    url: existing.url
                )
        }

        return merged
    }

    private func localizedBundleAliases(
        _ bundle: Bundle?
    ) -> [String] {
        guard let bundle else {
            return []
        }

        var aliases: [String] = []
        let localizations =
            Array(
                Set(
                    bundle.localizations +
                    bundle.preferredLocalizations
                )
            )

        for localization in localizations {
            guard let path =
                bundle.path(
                    forResource: "InfoPlist",
                    ofType: "strings",
                    inDirectory: nil,
                    forLocalization:
                        localization
                ),
                let data = try? Data(
                    contentsOf:
                        URL(
                            fileURLWithPath: path
                        )
                ),
                let object = try?
                    PropertyListSerialization
                        .propertyList(
                            from: data,
                            options: [],
                            format: nil
                        ),
                let dictionary =
                    object as? [String: Any]
            else {
                continue
            }

            if let value =
                dictionary[
                    "CFBundleDisplayName"
                ] as? String {
                aliases.append(value)
            }

            if let value =
                dictionary[
                    "CFBundleName"
                ] as? String {
                aliases.append(value)
            }
        }

        return aliases
    }

    private func focusCandidate(
        _ candidate: ApplicationCandidate,
        maxAttempts: Int,
        delayMilliseconds: Int
    ) async -> Bool {
        let normalizedAliases =
            Set(
                candidate.aliases
                    .map(normalize)
                    .filter { !$0.isEmpty }
            )

        for _ in 0..<maxAttempts {
            if let front =
                NSWorkspace.shared
                    .frontmostApplication {
                if let bundleID =
                    candidate.bundleIdentifier,
                   front.bundleIdentifier ==
                    bundleID {
                    return true
                }

                let frontName =
                    normalize(
                        front.localizedName ?? ""
                    )

                if normalizedAliases.contains(
                    frontName
                ) {
                    return true
                }
            }

            if let running =
                matchingRunningApplication(
                    named: candidate.name,
                    preferredBundleIdentifier:
                        candidate.bundleIdentifier
                ) {
                requestActivation(
                    running
                )
            }

            try? await Task.sleep(
                for: .milliseconds(
                    delayMilliseconds
                )
            )
        }

        return false
    }

    private func recoverForeground(
        _ candidate: ApplicationCandidate,
        running app: NSRunningApplication
    ) async -> Bool {
        let delays = [220, 360, 520, 700]

        for (index, delay) in delays.enumerated() {
            if index >= 1,
               let current =
                NSWorkspace.shared
                    .frontmostApplication,
               current.processIdentifier ==
                ProcessInfo.processInfo
                    .processIdentifier {
                _ = current.hide()
            }

            requestActivation(
                app,
                aggressive:
                    index >= 1
            )

            try? await Task.sleep(
                for: .milliseconds(delay)
            )

            if await visuallyForeground(
                candidate
            ) {
                return true
            }
        }

        return false
    }

    private func requestActivation(
        _ app: NSRunningApplication,
        aggressive: Bool = false
    ) {
        if app.isHidden {
            _ = app.unhide()
        }

        if #available(macOS 14.0, *) {
            NSApplication.shared
                .yieldActivation(to: app)
        }

        let options: NSApplication.ActivationOptions =
            aggressive
                ? [
                    .activateAllWindows,
                    .activateIgnoringOtherApps
                ]
                : [.activateAllWindows]

        _ = app.activate(
            options: options
        )

        if accessibilityTrusted(
            promptIfNeeded: false
        ) {
            raiseAccessibilityWindows(
                for: app
            )
        }
    }

    private func raiseAccessibilityWindows(
        for app: NSRunningApplication
    ) {
        let applicationElement =
            AXUIElementCreateApplication(
                app.processIdentifier
            )

        _ = AXUIElementSetAttributeValue(
            applicationElement,
            kAXFrontmostAttribute as CFString,
            kCFBooleanTrue
        )

        var rawWindows: CFTypeRef?
        let error =
            AXUIElementCopyAttributeValue(
                applicationElement,
                kAXWindowsAttribute as CFString,
                &rawWindows
            )

        guard
            error == .success,
            let windows =
                rawWindows as? [AXUIElement]
        else {
            return
        }

        for window in windows.prefix(4) {
            _ = AXUIElementSetAttributeValue(
                window,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )

            _ = AXUIElementPerformAction(
                window,
                kAXRaiseAction as CFString
            )
        }
    }

    private func visuallyForeground(
        _ candidate: ApplicationCandidate
    ) async -> Bool {
        guard #available(macOS 15.0, *) else {
            return false
        }

        do {
            let content =
                try await SCShareableContent
                    .excludingDesktopWindows(
                        false,
                        onScreenWindowsOnly: true
                    )

            let candidateWindows =
                content.windows.filter { window in
                    guard
                        window.isOnScreen,
                        window.windowLayer == 0,
                        let app =
                            window.owningApplication
                    else {
                        return false
                    }

                    if let bundleID =
                        candidate.bundleIdentifier,
                       app.bundleIdentifier ==
                        bundleID {
                        return true
                    }

                    let appName =
                        normalize(
                            app.applicationName
                        )

                    return candidate.aliases
                        .map(normalize)
                        .contains(appName)
                }

            guard let target =
                candidateWindows.max(
                    by: {
                        ($0.frame.width *
                         $0.frame.height) <
                        ($1.frame.width *
                         $1.frame.height)
                    }
                )
            else {
                return false
            }

            let above =
                try await shareableContentAbove(
                    target
                )

            let ownBundleID =
                Bundle.main.bundleIdentifier

            let blockers =
                above.windows.filter { window in
                    guard
                        window.isOnScreen,
                        window.windowLayer == 0,
                        let app =
                            window.owningApplication
                    else {
                        return false
                    }

                    if let bundleID =
                        candidate.bundleIdentifier,
                       app.bundleIdentifier ==
                        bundleID {
                        return false
                    }

                    if app.bundleIdentifier ==
                        ownBundleID {
                        return true
                    }

                    if app.bundleIdentifier ==
                        "com.apple.dock" {
                        return false
                    }

                    let overlap =
                        target.frame.intersection(
                            window.frame
                        )

                    guard !overlap.isNull else {
                        return false
                    }

                    let targetArea =
                        max(
                            1,
                            target.frame.width *
                            target.frame.height
                        )
                    let overlapArea =
                        overlap.width *
                        overlap.height

                    return
                        overlapArea /
                        targetArea >
                        0.08
                }

            return blockers.isEmpty
        } catch {
            return false
        }
    }

    @available(macOS 15.0, *)
    private func shareableContentAbove(
        _ window: SCWindow
    ) async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation {
            continuation in

            SCShareableContent
                .getExcludingDesktopWindows(
                    false,
                    onScreenWindowsOnlyAbove:
                        window
                ) {
                    content,
                    error in

                    if let error {
                        continuation.resume(
                            throwing: error
                        )
                        return
                    }

                    guard let content else {
                        continuation.resume(
                            throwing:
                                DesktopControlError
                                    .launchFailed(
                                        "ScreenCaptureKit z-order doğrulaması"
                                    )
                        )
                        return
                    }

                    continuation.resume(
                        returning: content
                    )
                }
        }
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

                _ = app.activate(
                    options: [.activateAllWindows]
                )

                continuation.resume(
                    returning: true
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
