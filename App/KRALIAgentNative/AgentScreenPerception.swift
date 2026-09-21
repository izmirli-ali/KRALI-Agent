import Foundation
import AppKit
import ScreenCaptureKit
import Vision

struct ScreenPerceptionReport: Codable, Hashable, Sendable {
    let createdAt: Date
    let goal: String
    let displayID: UInt32
    let pixelWidth: Int
    let pixelHeight: Int
    let frontmostApplication: String?
    let visibleApplications: [String]
    let visibleWindows: [String]
    let recognizedText: [String]
    let semanticSummary: String
    let captureScope: String?
    let capturedApplicationBundleIdentifier: String?
    let capturedWindowTitle: String?
    let capturedWindowID: UInt32?
}

enum ScreenPerceptionError: LocalizedError {
    case noDisplay
    case captureUnavailable
    case targetWindowUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "Yakalanabilir ekran bulunamadı."
        case .captureUnavailable:
            return "Ekran görüntüsü alınamadı. macOS Ekran Kaydı iznini kontrol et."
        case .targetWindowUnavailable(let bundleIdentifier):
            return "Hedef uygulamaya ait görünür pencere bulunamadı: \(bundleIdentifier)"
        }
    }
}

actor AgentScreenPerception {
    private let localIntelligence = AgentLocalIntelligence()

    func observe(
        goal: String,
        targetBundleIdentifier: String? = nil,
        targetWindowID: UInt32? = nil
    ) async throws -> ScreenPerceptionReport {
        let content = try await SCShareableContent
            .excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

        guard let display = preferredDisplay(
            from: content
        ) else {
            throw ScreenPerceptionError.noDisplay
        }

        let targetWindow: SCWindow?
        if let targetBundleIdentifier {
            targetWindow =
                content.windows.first {
                    window in

                    guard
                        window.isOnScreen,
                        let application =
                            window.owningApplication,
                        application.bundleIdentifier ==
                            targetBundleIdentifier,
                        targetWindowID == nil ||
                            window.windowID ==
                                targetWindowID
                    else {
                        return false
                    }

                    return window.frame.width >= 180 &&
                        window.frame.height >= 120
                }

            guard targetWindow != nil else {
                throw ScreenPerceptionError
                    .targetWindowUnavailable(
                        targetBundleIdentifier
                    )
            }
        } else {
            targetWindow = nil
        }

        let filter: SCContentFilter
        let sourceWidth: Int
        let sourceHeight: Int

        if let targetWindow {
            filter = SCContentFilter(
                desktopIndependentWindow:
                    targetWindow
            )

            sourceWidth = max(
                Int(targetWindow.frame.width),
                1
            )
            sourceHeight = max(
                Int(targetWindow.frame.height),
                1
            )
        } else {
            let excludedApplications =
                content.applications.filter {
                    $0.bundleIdentifier ==
                        Bundle.main.bundleIdentifier
                }

            filter = SCContentFilter(
                display: display,
                excludingApplications:
                    excludedApplications,
                exceptingWindows: []
            )

            sourceWidth = max(
                display.width,
                1
            )
            sourceHeight = max(
                display.height,
                1
            )
        }

        let configuration =
            SCStreamConfiguration()

        let maxWidth = 1600
        let scale = min(
            1.0,
            Double(maxWidth) /
                Double(sourceWidth)
        )

        configuration.width = max(
            1,
            Int(Double(sourceWidth) * scale)
        )
        configuration.height = max(
            1,
            Int(Double(sourceHeight) * scale)
        )
        configuration.showsCursor = true

        let image = try await SCScreenshotManager
            .captureImage(
                contentFilter: filter,
                configuration: configuration
            )

        let recognizedText = recognizeText(
            in: image
        )

        let frontmostApplication =
            NSWorkspace.shared.frontmostApplication?
                .localizedName?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let visibleApplications: [String]
        let visibleWindows: [String]

        if let targetWindow {
            let appName =
                targetWindow
                    .owningApplication?
                    .applicationName
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ) ?? ""

            visibleApplications =
                appName.isEmpty
                ? []
                : [appName]

            let title =
                targetWindow.title?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ) ?? ""

            visibleWindows =
                title.isEmpty
                ? []
                : [
                    (appName.isEmpty
                        ? "Hedef uygulama"
                        : appName) +
                    " — " +
                    title
                ]
        } else {
            visibleApplications =
                Array(
                    Set(
                        content.applications.compactMap {
                            let name = $0.applicationName
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )

                            return name.isEmpty
                                ? nil
                                : name
                        }
                    )
                )
                .sorted()

            visibleWindows =
                Array(
                    content.windows
                        .compactMap {
                            window -> String? in

                            guard
                                window.isOnScreen,
                                let title =
                                    window.title?
                                        .trimmingCharacters(
                                            in:
                                                .whitespacesAndNewlines
                                        ),
                                !title.isEmpty
                            else {
                                return nil
                            }

                            let appName =
                                window
                                    .owningApplication?
                                    .applicationName ??
                                "Bilinmeyen uygulama"

                            return appName +
                                " — " +
                                title
                        }
                        .prefix(40)
                )
        }

        let semanticSummary =
            await localIntelligence
                .summarizeScreenState(
                    goal: goal,
                    frontmostApplication:
                        frontmostApplication,
                    visibleApplications:
                        visibleApplications,
                    visibleWindows:
                        visibleWindows,
                    recognizedText:
                        recognizedText
                ) ??
            fallbackSummary(
                visibleApplications:
                    visibleApplications,
                visibleWindows:
                    visibleWindows,
                recognizedText:
                    recognizedText
            )

        return ScreenPerceptionReport(
            createdAt: Date(),
            goal: goal,
            displayID: display.displayID,
            pixelWidth: configuration.width,
            pixelHeight: configuration.height,
            frontmostApplication:
                frontmostApplication,
            visibleApplications:
                visibleApplications,
            visibleWindows:
                visibleWindows,
            recognizedText: recognizedText,
            semanticSummary: semanticSummary,
            captureScope:
                targetWindow == nil
                ? "display"
                : "window",
            capturedApplicationBundleIdentifier:
                targetWindow?
                    .owningApplication?
                    .bundleIdentifier,
            capturedWindowTitle:
                targetWindow?
                    .title,
            capturedWindowID:
                targetWindow?
                    .windowID
        )
    }

    private func preferredDisplay(
        from content: SCShareableContent
    ) -> SCDisplay? {
        if let screenNumber =
            NSScreen.main?.deviceDescription[
                NSDeviceDescriptionKey(
                    "NSScreenNumber"
                )
            ] as? NSNumber {
            let displayID =
                CGDirectDisplayID(
                    screenNumber.uint32Value
                )

            if let display =
                content.displays.first(
                    where: {
                        $0.displayID == displayID
                    }
                ) {
                return display
            }
        }

        return content.displays.first
    }

    private func recognizeText(
        in image: CGImage
    ) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(
            cgImage: image,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let observations =
            request.results ?? []

        var lines: [String] = []
        var seen = Set<String>()

        for observation in observations {
            guard
                let candidate =
                    observation.topCandidates(1).first
            else {
                continue
            }

            let value = candidate.string
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard
                !value.isEmpty,
                !seen.contains(value)
            else {
                continue
            }

            seen.insert(value)
            lines.append(value)

            if lines.count >= 120 {
                break
            }
        }

        return lines
    }

    private func fallbackSummary(
        visibleApplications: [String],
        visibleWindows: [String],
        recognizedText: [String]
    ) -> String {
        let apps = visibleApplications
            .prefix(6)
            .joined(separator: ", ")

        let windows = visibleWindows
            .prefix(5)
            .joined(separator: " • ")

        let text = recognizedText
            .prefix(8)
            .joined(separator: " | ")

        return [
            apps.isEmpty
                ? nil
                : "Açık uygulamalar: " + apps,
            windows.isEmpty
                ? nil
                : "Görünen pencereler: " + windows,
            text.isEmpty
                ? nil
                : "Ekranda okunan metin: " + text
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}

struct ScreenPerceptionStore {
    private let fileManager = FileManager.default

    var statusURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor/screen-perception-status.txt",
                isDirectory: false
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

    func saveStatus(_ value: String) {
        let directory = statusURL
            .deletingLastPathComponent()

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

    var outputURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor/screen-perception-latest.json",
                isDirectory: false
            )
    }

    func save(
        _ report: ScreenPerceptionReport
    ) throws {
        let directory = outputURL
            .deletingLastPathComponent()

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

    func load() -> ScreenPerceptionReport? {
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
            ScreenPerceptionReport.self,
            from: data
        )
    }
}
