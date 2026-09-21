import Foundation

enum SemanticGymFailureClass: String, Codable, CaseIterable, Hashable {
    case intent
    case scope
    case entity
    case rank
    case output
    case safety
    case capability
    case verification
}

enum SemanticGymLearningKind: String, Codable, Hashable {
    case semanticStrategy
    case capabilityRouting
    case verificationStrategy
}

struct SemanticGymCaseResult: Identifiable, Codable, Hashable {
    var id: String { scenarioID }

    let scenarioID: String
    let familyID: String
    let prompt: String
    let passed: Bool
    let failureClasses: [SemanticGymFailureClass]
    let diagnostics: [String]
    let selectedCapabilities: [String]
}

struct SemanticGymFailureSummary: Codable, Hashable {
    let failureClass: SemanticGymFailureClass
    let count: Int
}

struct SemanticGymLearningCandidate: Identifiable, Codable, Hashable {
    let id: String
    let failureClass: SemanticGymFailureClass
    let kind: SemanticGymLearningKind
    let summary: String
    let evidenceScenarioIDs: [String]
    let sourceMutationAllowed: Bool
    let requiresCapabilityGapReview: Bool
}

struct SemanticGymReport: Codable, Hashable {
    let createdAt: Date
    let appVersion: String
    let total: Int
    let passed: Int
    let failed: Int
    let families: [String]
    let failureSummary: [SemanticGymFailureSummary]
    let learningCandidates: [SemanticGymLearningCandidate]
    let results: [SemanticGymCaseResult]
}

private struct SemanticGymFileCase {
    let id: String
    let prompt: String
    let scope: AgentFileSearchScope
    let target: AgentTargetKind
    let sortMode: AgentSortMode
    let dateField: AgentDateField
    let resultLimit: Int?
    let output: AgentFileOutputProjection
    let extensions: Set<String>
    let prohibitions: Set<AgentFileQueryProhibition>
}

struct AgentSemanticGym {
    private let familyID = "file-retrieval-semantic-contract"
    private let brain = AgentBrain()
    private let goalInterpreter = AgentGoalInterpreter()
    private let capabilityRegistry = AgentCapabilityRegistry()
    private let fileQueryParser = AgentFileQueryParser()

    func run() -> SemanticGymReport {
        let results = makeFileCases().map(evaluate)
        let failedResults = results.filter { !$0.passed }

        let failureSummary =
            SemanticGymFailureClass.allCases.compactMap { failureClass in
                let count = failedResults.filter {
                    $0.failureClasses.contains(failureClass)
                }.count

                guard count > 0 else {
                    return nil
                }

                return SemanticGymFailureSummary(
                    failureClass: failureClass,
                    count: count
                )
            }

        let learningCandidates =
            makeLearningCandidates(
                from: failedResults
            )

        return SemanticGymReport(
            createdAt: Date(),
            appVersion: Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "unknown",
            total: results.count,
            passed: results.filter(\.passed).count,
            failed: failedResults.count,
            families: [familyID],
            failureSummary: failureSummary,
            learningCandidates: learningCandidates,
            results: results
        )
    }

    private func evaluate(
        _ test: SemanticGymFileCase
    ) -> SemanticGymCaseResult {
        let context = trainingContext()

        let query =
            fileQueryParser.parse(
                test.prompt
            )

        let decision =
            brain.analyze(
                test.prompt,
                context: context
            )

        let goal =
            goalInterpreter.interpret(
                test.prompt,
                decision: decision,
                context: context
            )

        let capabilities =
            capabilityRegistry.select(
                for: test.prompt,
                decision: decision,
                context: context,
                goal: goal
            )

        let selectedCapabilityIDs =
            Set(
                capabilities.map(\.id)
            )

        let actualTarget =
            fileQueryParser
                .resolveTargetEntity(
                    test.prompt
                )

        var failures =
            Set<SemanticGymFailureClass>()
        var diagnostics: [String] = []

        if decision.intent != .fileSearch ||
           !query.isFileSearchRequest {
            failures.insert(.intent)
            diagnostics.append(
                "[intent] Structured file retrieval contract seçilmedi."
            )
        }

        if query.scope != test.scope ||
           !query.scopeIsExplicit {
            failures.insert(.scope)
            diagnostics.append(
                "[scope] Explicit scope semantic contract korunmadı."
            )
        }

        if actualTarget != test.target ||
           query.extensions != test.extensions {
            failures.insert(.entity)
            diagnostics.append(
                "[entity] Hedef entity veya extension/type filtresi uyuşmuyor."
            )
        }

        if query.sortMode != test.sortMode ||
           query.dateField != test.dateField ||
           query.resultLimit != test.resultLimit {
            failures.insert(.rank)
            diagnostics.append(
                "[rank] Ordering/date/limit semantic contract uyuşmuyor."
            )
        }

        if query.outputProjection != test.output {
            failures.insert(.output)
            diagnostics.append(
                "[output] İstenen çıktı projection korunmadı."
            )
        }

        if !test.prohibitions.isSubset(
            of: query.prohibitions
        ) {
            failures.insert(.safety)
            diagnostics.append(
                "[safety] Kullanıcının yasakladığı işlemler eksik çözüldü."
            )
        }

        if !goal.requiredCapabilityIDs.contains(
            "files.search"
        ) ||
           !selectedCapabilityIDs.contains(
            "files.search"
           ) {
            failures.insert(.capability)
            diagnostics.append(
                "[capability] files.search capability semantic sözleşmeye taşınmadı."
            )
        }

        return SemanticGymCaseResult(
            scenarioID: test.id,
            familyID: familyID,
            prompt: test.prompt,
            passed: failures.isEmpty,
            failureClasses:
                failures.sorted {
                    $0.rawValue <
                        $1.rawValue
                },
            diagnostics: diagnostics,
            selectedCapabilities:
                selectedCapabilityIDs.sorted()
        )
    }

    private func makeLearningCandidates(
        from failedResults: [SemanticGymCaseResult]
    ) -> [SemanticGymLearningCandidate] {
        SemanticGymFailureClass.allCases.compactMap {
            failureClass in

            let evidence =
                failedResults.filter {
                    $0.failureClasses
                        .contains(
                            failureClass
                        )
                }

            guard !evidence.isEmpty else {
                return nil
            }

            let kind: SemanticGymLearningKind
            let summary: String
            let gapReview: Bool

            switch failureClass {
            case .intent:
                kind = .semanticStrategy
                summary =
                    "Retrieval sinyallerini fiile bağlı kalmadan semantic contract olarak çöz; tek prompta özel branch ekleme."
                gapReview = false

            case .scope:
                kind = .semanticStrategy
                summary =
                    "Açık kullanıcı scope'unu workspace varsayımından ayır ve explicit scope invariant'ını koru."
                gapReview = false

            case .entity:
                kind = .semanticStrategy
                summary =
                    "Dosya türü/entity çözümünü ifade varyasyonlarından bağımsız canonical hedefe dönüştür."
                gapReview = false

            case .rank:
                kind = .semanticStrategy
                summary =
                    "Created/modified/downloaded zaman semantiğini ordering ve result-limit sözleşmesinden ayrı çöz."
                gapReview = false

            case .output:
                kind = .semanticStrategy
                summary =
                    "İstenen projection'ı işlem niyetinden ayır; ad/konum/boyut gibi çıktıları ayrı semantic slot olarak koru."
                gapReview = false

            case .safety:
                kind = .semanticStrategy
                summary =
                    "Negatif kullanıcı kısıtlarını arama sorgusuna karıştırmadan ayrı prohibition seti olarak taşı."
                gapReview = false

            case .capability:
                kind = .capabilityRouting
                summary =
                    "Önce mevcut generic capability routing'i düzelt; ancak mevcut primitive'ler yetersizse Capability Gap incelemesi aç."
                gapReview = true

            case .verification:
                kind = .verificationStrategy
                summary =
                    "Başarıyı gerçek observation/postcondition ile doğrula; evidence yoksa PASS üretme."
                gapReview = false
            }

            return SemanticGymLearningCandidate(
                id:
                    familyID + ":" +
                    failureClass.rawValue,
                failureClass: failureClass,
                kind: kind,
                summary: summary,
                evidenceScenarioIDs:
                    evidence.map(\.scenarioID),
                sourceMutationAllowed: false,
                requiresCapabilityGapReview:
                    gapReview
            )
        }
    }

    private func makeFileCases()
        -> [SemanticGymFileCase] {
        [
            SemanticGymFileCase(
                id: "desktop-image-modified",
                prompt:
                    "Masaüstündeki en son değiştirilen görsel dosyasının sadece adını söyle. Dosyayı açma veya değiştirme.",
                scope: .desktop,
                target: .image,
                sortMode: .newestFirst,
                dateField: .modified,
                resultLimit: 1,
                output: .namesOnly,
                extensions: [],
                prohibitions: [.open, .modify]
            ),
            SemanticGymFileCase(
                id: "downloads-pdf-created",
                prompt:
                    "İndirilenler klasöründeki son indirilen PDF dosyasının yalnızca adını ver. Dosyayı açma.",
                scope: .downloads,
                target: .pdf,
                sortMode: .newestFirst,
                dateField: .created,
                resultLimit: 1,
                output: .namesOnly,
                extensions: ["pdf"],
                prohibitions: [.open]
            ),
            SemanticGymFileCase(
                id: "documents-document-modified",
                prompt:
                    "Belgeler klasöründeki bugün değiştirilen belgelerin isimlerini listele; hiçbirini değiştirme.",
                scope: .documents,
                target: .document,
                sortMode: .relevance,
                dateField: .modified,
                resultLimit: nil,
                output: .namesOnly,
                extensions: [],
                prohibitions: [.modify]
            ),
            SemanticGymFileCase(
                id: "desktop-video-modified",
                prompt:
                    "Masaüstündeki son değiştirilen videonun adını göster, dosyayı açma.",
                scope: .desktop,
                target: .video,
                sortMode: .newestFirst,
                dateField: .modified,
                resultLimit: 1,
                output: .namesOnly,
                extensions: [],
                prohibitions: [.open]
            ),
            SemanticGymFileCase(
                id: "downloads-archive-created",
                prompt:
                    "İndirilenler'deki son indirilen ZIP dosyasının sadece ismini söyle; taşıma veya silme.",
                scope: .downloads,
                target: .any,
                sortMode: .newestFirst,
                dateField: .created,
                resultLimit: 1,
                output: .namesOnly,
                extensions: ["zip"],
                prohibitions: [.move, .delete]
            )
        ]
    }

    private func trainingContext()
        -> AgentContextSnapshot {
        AgentContextSnapshot(
            hasWorkspace: true,
            workspaceName:
                "Semantic Gym Workspace",
            fileCount: 120,
            imageCount: 30,
            videoCount: 20,
            projectCount: 8,
            documentCount: 30,
            screenshotCount: 12,
            hasPendingAction: false,
            previousFileResultCount: 0,
            previousFolderResultCount: 0,
            lastTarget: nil,
            lastGoal: nil,
            relevantMemoryCount: 0,
            lastMemoryGoal: nil
        )
    }
}

struct SemanticGymStore {
    private let fileManager =
        FileManager.default

    var outputURL: URL {
        fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor/gym-latest.json",
                isDirectory: false
            )
    }

    func save(
        _ report: SemanticGymReport
    ) throws {
        let directory =
            outputURL
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
        encoder.dateEncodingStrategy =
            .iso8601

        let data =
            try encoder.encode(
                report
            )

        try data.write(
            to: outputURL,
            options: .atomic
        )
    }

    func load()
        -> SemanticGymReport? {
        guard
            let data = try? Data(
                contentsOf: outputURL
            )
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy =
            .iso8601

        return try? decoder.decode(
            SemanticGymReport.self,
            from: data
        )
    }
}
