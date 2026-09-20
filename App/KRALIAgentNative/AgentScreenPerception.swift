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
    let visibleApplications: [String]
    let visibleWindows: [String]
    let recognizedText: [String]
    let semanticSummary: String
}

enum ScreenPerceptionError: LocalizedError {
    case noDisplay
    case captureUnavailable

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "Yakalanabilir ekran bulunamadı."
        case .captureUnavailable:
            return "Ekran görüntüsü alınamadı. macOS Ekran Kaydı iznini kontrol et."
        }
    }
}

actor AgentScreenPerception {
    private let localIntelligence = AgentLocalIntelligence()

    func observe(
        goal: String
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

        let excludedApplications =
            content.applications.filter {
                $0.bundleIdentifier ==
                    Bundle.main.bundleIdentifier
            }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()

        let maxWidth = 1600
        let sourceWidth = max(display.width, 1)
        let sourceHeight = max(display.height, 1)
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

        let visibleApplications =
            Array(
                Set(
                    content.applications.compactMap {
                        $0.applicationName
                    }
                )
            )
            .sorted()

        let visibleWindows = content.windows
            .filter {
                $0.isOnScreen &&
                !$0.title.isEmpty
            }
            .prefix(40)
            .map {
                let appName =
                    $0.owningApplication?
                        .applicationName ??
                    "Bilinmeyen uygulama"

                return appName +
                    " — " +
                    $0.title
            }

        let semanticSummary =
            await localIntelligence
                .summarizeScreenState(
                    goal: goal,
                    visibleApplications:
                        visibleApplications,
                    visibleWindows:
                        Array(visibleWindows),
                    recognizedText:
                        recognizedText
                ) ??
            fallbackSummary(
                visibleApplications:
                    visibleApplications,
                visibleWindows:
                    Array(visibleWindows),
                recognizedText:
                    recognizedText
            )

        return ScreenPerceptionReport(
            createdAt: Date(),
            goal: goal,
            displayID: display.displayID,
            pixelWidth: configuration.width,
            pixelHeight: configuration.height,
            visibleApplications:
                visibleApplications,
            visibleWindows:
                Array(visibleWindows),
            recognizedText: recognizedText,
            semanticSummary: semanticSummary
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
