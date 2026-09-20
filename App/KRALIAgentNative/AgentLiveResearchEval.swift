import Foundation

struct LiveResearchProbeResult: Identifiable, Codable, Hashable {
    var id: String { probeID }

    let probeID: String
    let title: String
    let query: String
    let passed: Bool
    let sourceCount: Int
    let evidenceCount: Int
    let uniqueDomainCount: Int
    let provider: String
    let diagnostics: [String]
}

struct LiveResearchEvalReport: Codable, Hashable {
    let createdAt: Date
    let appVersion: String
    let total: Int
    let passed: Int
    let failed: Int
    let probes: [LiveResearchProbeResult]
}

actor AgentLiveResearchEval {
    private let research = AgentWebResearchService()
    private let reader = AgentWebSourceReader()

    func run() async -> LiveResearchEvalReport {
        let probes = [
            (
                id: "brand-grounding",
                title: "Marka araştırması / entity grounding",
                query: "HABAŞ markasını detaylı araştır; tarihçesini, ürünlerini, rakiplerini ve güncel gelişmelerini bul",
                minSources: 3,
                minEvidence: 2,
                minDomains: 2
            ),
            (
                id: "technical-official",
                title: "Teknik araştırma / resmi kaynak",
                query: "Apple Developer Vision AVFoundation macOS video analysis framework official documentation",
                minSources: 2,
                minEvidence: 2,
                minDomains: 1
            )
        ]

        var results: [LiveResearchProbeResult] = []

        for probe in probes {
            do {
                let report = try await research.search(
                    probe.query,
                    limit: 6
                )

                let evidence = await reader.read(
                    report.results,
                    query: probe.query,
                    limit: 4
                )

                let domains = Set(
                    report.results.map {
                        $0.domain.lowercased()
                    }
                )

                var diagnostics: [String] = []

                if report.results.count < probe.minSources {
                    diagnostics.append(
                        "Kaynak sayısı düşük: \(report.results.count)/\(probe.minSources)"
                    )
                }

                if evidence.count < probe.minEvidence {
                    diagnostics.append(
                        "Derin okuma kanıtı düşük: \(evidence.count)/\(probe.minEvidence)"
                    )
                }

                if domains.count < probe.minDomains {
                    diagnostics.append(
                        "Kaynak çeşitliliği düşük: \(domains.count)/\(probe.minDomains) domain"
                    )
                }

                results.append(
                    LiveResearchProbeResult(
                        probeID: probe.id,
                        title: probe.title,
                        query: probe.query,
                        passed: diagnostics.isEmpty,
                        sourceCount: report.results.count,
                        evidenceCount: evidence.count,
                        uniqueDomainCount: domains.count,
                        provider: report.provider,
                        diagnostics: diagnostics
                    )
                )
            } catch {
                results.append(
                    LiveResearchProbeResult(
                        probeID: probe.id,
                        title: probe.title,
                        query: probe.query,
                        passed: false,
                        sourceCount: 0,
                        evidenceCount: 0,
                        uniqueDomainCount: 0,
                        provider: "none",
                        diagnostics: [
                            error.localizedDescription
                        ]
                    )
                )
            }
        }

        return LiveResearchEvalReport(
            createdAt: Date(),
            appVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown",
            total: results.count,
            passed: results.filter(\.passed).count,
            failed: results.filter { !$0.passed }.count,
            probes: results
        )
    }
}

struct LiveResearchEvalStore {
    private let fileManager = FileManager.default

    var outputURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor/live-eval-latest.json",
                isDirectory: false
            )
    }

    func save(_ report: LiveResearchEvalReport) throws {
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

    func load() -> LiveResearchEvalReport? {
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
            LiveResearchEvalReport.self,
            from: data
        )
    }
}
