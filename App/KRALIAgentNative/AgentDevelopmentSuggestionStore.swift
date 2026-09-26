import Foundation

enum AgentSourceRevisionPolicy {
    static func exactRevision(
        _ raw: String?
    ) -> String? {
        guard let raw else {
            return nil
        }

        let value =
            raw.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard value.count == 40 else {
            return nil
        }

        let allowed =
            CharacterSet(
                charactersIn: "0123456789abcdef"
            )

        guard value.unicodeScalars.allSatisfy({
            allowed.contains($0)
        }) else {
            return nil
        }

        return value
    }
}

enum AgentDevelopmentSuggestionSource:
    String,
    Codable,
    Hashable,
    Sendable {
    case capabilityGap
    case research
    case arena
    case training
    case mentor
    case developerFailure
    case architecture
    case usability

    var title: String {
        switch self {
        case .capabilityGap:
            return "Capability"
        case .research:
            return "Araştırma"
        case .arena:
            return "Arena"
        case .training:
            return "Training"
        case .mentor:
            return "Mentor"
        case .developerFailure:
            return "Developer"
        case .architecture:
            return "Mimari"
        case .usability:
            return "Arayüz"
        }
    }
}

enum AgentDevelopmentSuggestionState:
    String,
    Codable,
    Hashable,
    Sendable {
    case proposed
    case deferred
    case suppressed
    case approved
    case developing
    case readyForReview
    case failed
    case released
    case completed

    var title: String {
        switch self {
        case .proposed:
            return "Önerildi"
        case .deferred:
            return "Bekletildi"
        case .suppressed:
            return "Gizlendi"
        case .approved:
            return "Onaylandı"
        case .developing:
            return "Geliştiriliyor"
        case .readyForReview:
            return "Aday hazır"
        case .failed:
            return "Durdu"
        case .released:
            return "Yayınlandı"
        case .completed:
            return "Tamamlandı"
        }
    }
}

struct AgentDevelopmentSuggestion:
    Identifiable,
    Codable,
    Hashable,
    Sendable {
    let id: UUID
    let fingerprint: String
    let source:
        AgentDevelopmentSuggestionSource
    let capabilityID: String?
    let capabilityName: String?
    let capabilityKind:
        CapabilityGapKind?
    let learningPath:
        CapabilityLearningPath?
    let candidateCapabilityIDs: [String]
    let title: String
    let reason: String
    let expectedBenefit: String
    let provenanceIDs: [String]
    let sourceRevision: String?
    let risk: String
    var occurrenceCount: Int
    var state:
        AgentDevelopmentSuggestionState
    var developerJobID: UUID? = nil
    var candidateBranch: String? = nil
    let createdAt: Date
    var updatedAt: Date

    var isExecutableCapabilityGap: Bool {
        source == .capabilityGap &&
        capabilityID != nil &&
        capabilityName != nil &&
        capabilityKind != nil &&
        AgentSourceRevisionPolicy
            .exactRevision(
                sourceRevision
            ) != nil
    }
}

struct AgentDevelopmentRegressionMemory: Codable, Hashable, Sendable {
    let failedCandidateCount: Int
    let releasedCandidateCount: Int
    let matchingFailureCount: Int
    let risk: String
    let summary: String
    let replayChecks: [String]
}

struct AgentDevelopmentSuggestionStore {
    private let fileManager =
        FileManager.default

    private var directoryURL: URL {
        fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Developer",
                isDirectory: true
            )
    }

    var suggestionsURL: URL {
        directoryURL
            .appendingPathComponent(
                "development-suggestions.json",
                isDirectory: false
            )
    }

    func load()
        -> [AgentDevelopmentSuggestion] {
        guard
            let data = try? Data(
                contentsOf:
                    suggestionsURL
            )
        else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy =
            .iso8601

        return (
            try? decoder.decode(
                [AgentDevelopmentSuggestion].self,
                from: data
            )
        ) ?? []
    }

    /// First-run suggestions are deliberately small, deterministic and
    /// non-executing.  They make the user-controlled development surface
    /// discoverable when runtime research has not produced a proposal yet.
    func seededFallbackSuggestions(
        sourceRevision: String?
    ) -> [AgentDevelopmentSuggestion] {
        guard
            let exactRevision =
                AgentSourceRevisionPolicy
                    .exactRevision(
                        sourceRevision
                    )
        else {
            return []
        }

        let now = Date()
        let definitions: [(
            title: String,
            reason: String,
            benefit: String,
            fingerprint: String
        )] = [
            (
                title: "KRALİ araştırma kalitesini iyileştir",
                reason: "Kaynak çeşitliliği ve kanıt bağlama kalitesini kontrollü olarak gözden geçirmek için başlangıç önerisi.",
                benefit: "Araştırma cevaplarında daha tutarlı, doğrulanabilir kaynak ve bulgu eşleştirmesi.",
                fingerprint: "fallback:research-quality"
            ),
            (
                title: "KRALİ arayüz önerilerini iyileştir",
                reason: "Araştırma sonuçlarındaki öneri metinlerinin okunabilirliğini ve öncelik sırasını kontrollü olarak incelemek için başlangıç önerisi.",
                benefit: "Kullanıcıya sunulan araştırma önerilerinin daha açık ve taranabilir olması.",
                fingerprint: "fallback:ui-readability"
            ),
            (
                title: "KRALİ eğitim raporu analizini iyileştir",
                reason: "Eğitim raporlarındaki bulgu ve öneri özetlerinin daha tutarlı analiz edilmesi için başlangıç önerisi.",
                benefit: "Eğitim raporlarından daha anlaşılır, kanıta dayalı geliştirme bulguları üretmek.",
                fingerprint: "fallback:training-report-analyzer"
            )
        ]

        return definitions.map { definition in
            AgentDevelopmentSuggestion(
                id: UUID(),
                fingerprint: definition.fingerprint,
                source: .research,
                capabilityID: nil,
                capabilityName: nil,
                capabilityKind: nil,
                learningPath: nil,
                candidateCapabilityIDs: [],
                title: definition.title,
                reason: definition.reason,
                expectedBenefit: definition.benefit,
                provenanceIDs: [
                    "deterministic-fallback:" + definition.fingerprint
                ],
                sourceRevision: exactRevision,
                risk: "low",
                occurrenceCount: 1,
                state: .proposed,
                developerJobID: nil,
                candidateBranch: nil,
                createdAt: now,
                updatedAt: now
            )
        }
    }

    /// Add fallback cards only when the sidebar would otherwise have no
    /// visible suggestion. Existing and suppressed fingerprints are both
    /// retained: a user's dismissal is never converted back to proposed.
    func ensureVisibleFallbackSuggestions(
        sourceRevision: String?,
        in existing: [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        guard
            !existing.contains(
                where: {
                    $0.state != .suppressed
                }
            )
        else {
            return existing
        }

        let existingFingerprints =
            Set(
                existing.map(\.fingerprint)
            )
        let suppressedFingerprints =
            Set(
                existing
                    .filter {
                        $0.state == .suppressed
                    }
                    .map(\.fingerprint)
            )

        let additions =
            seededFallbackSuggestions(
                sourceRevision: sourceRevision
            )
            .filter {
                !existingFingerprints.contains(
                    $0.fingerprint
                ) &&
                !suppressedFingerprints.contains(
                    $0.fingerprint
                )
            }

        return existing + additions
    }

    /// The original research-quality trial predates the bounded candidate
    /// workflow. It is replaced by the fresh innovation queue, so remove that
    /// known legacy lineage rather than allowing it to reappear as a card.
    func pruneLegacyStoppedResearch(
        _ existing: [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        existing.filter {
            !$0.fingerprint.hasPrefix("fallback:research-quality")
        }
    }

    /// Generated ideas are tied to an exact source revision. Do not present a
    /// stale idea as if it can be safely developed on a newer build. While the
    /// user is focusing on UI work, untouched generated research ideas are
    /// also rotated out so the compact queue leads with UI candidates.
    func pruneStaleInnovationSuggestions(
        sourceRevision: String?,
        in existing: [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        guard let revision = AgentSourceRevisionPolicy.exactRevision(sourceRevision) else {
            return existing
        }

        return existing.filter {
            !(
                $0.fingerprint.hasPrefix("innovation:") &&
                (
                    $0.sourceRevision != revision ||
                    ($0.source == .research &&
                        ($0.state == .proposed || $0.state == .deferred || $0.state == .failed))
                )
            )
        }
    }

    /// Keep the discovery surface useful after the first-run cards have been
    /// shown. This is deliberately a queue refresh, not a self-modification
    /// mechanism: the returned cards still require the normal bounded-task
    /// compiler and an explicit user approval before any candidate can run.
    /// A suppressed idea is never offered again.
    func refreshInnovationSuggestions(
        sourceRevision: String?,
        in existing: [AgentDevelopmentSuggestion],
        now: Date = Date()
    ) -> [AgentDevelopmentSuggestion] {
        guard let revision = AgentSourceRevisionPolicy.exactRevision(sourceRevision) else {
            return existing
        }

        let definitions: [(String, String, String, String, AgentDevelopmentSuggestionSource)] = [
            (
                "KRALİ araştırma sonuç ekranını iyileştir",
                "Kaynak, kanıt, çelişki ve puan özetini daha taranabilir bir hiyerarşide sunmak.",
                "Uzun araştırma sonuçlarında kritik bulgulara daha hızlı ulaşılması.",
                "innovation:ui-research-results",
                .usability
            ),
            (
                "KRALİ geliştirme öneri akışını iyileştir",
                "Yeni fikirler, öneriler, geliştirme durumu ve inceleme gereksinimini daha sade bir kontrol yüzeyinde toplamak.",
                "Kullanıcının doğru geliştirme kararını daha az arayüz gürültüsüyle vermesi.",
                "innovation:ui-development-flow",
                .usability
            ),
            (
                "KRALİ erişilebilirlik ve klavye akışını iyileştir",
                "Önemli durumlar, odak sırası ve klavye ile erişilebilir geliştirme kontrollerini gözden geçirmek.",
                "Arayüzün daha hızlı, öngörülebilir ve erişilebilir kullanılması.",
                "innovation:ui-accessibility",
                .usability
            ),
            (
                "KRALİ araştırma kaynak kartlarını iyileştir",
                "Kaynak türü, güncellik, kanıt gücü ve bağımsızlık bilgisini kompakt kartlarda görünür kılmak.",
                "Araştırma kalitesinin kaynak bazında daha anlaşılır değerlendirilmesi.",
                "innovation:ui-source-cards",
                .usability
            ),
            (
                "KRALİ kanıt çelişkisi incelemesini iyileştir",
                "Aynı iddia için farklı kaynakların uyuşmayan bulgularını ayrı bir inceleme kuyruğunda görünür kılmak.",
                "Araştırma sonuçlarında güven derecesi ve belirsizliğin daha açık gösterilmesi.",
                "innovation:claim-contradictions",
                .research
            ),
            (
                "KRALİ araştırma tekrar üretilebilirliğini iyileştir",
                "Kaynak tarihi, sürümü, erişim zamanı ve kanıt alıntısını tutarlı bir araştırma kaydında birleştirmek.",
                "Bulguların daha sonra denetlenmesi ve aynı araştırmanın tekrar çalıştırılabilmesi.",
                "innovation:research-reproducibility",
                .research
            ),
            (
                "KRALİ geliştirme regresyon hafızasını iyileştir",
                "Geçmiş candidate hatalarını test sonucu, hata sınıfı ve kullanıcı geri bildirimiyle ilişkilendirmek.",
                "Benzer geliştirmelerde daha erken risk uyarısı ve daha güvenli planlama.",
                "innovation:regression-memory",
                .research
            ),
            (
                "KRALİ bağımlılık etkisi analizini iyileştir",
                "Önerilen dosya değişikliklerinin çağrı zinciri ve doğrulama kapsamına etkisini araştırmak.",
                "Daha küçük, geri alınabilir ve test kapsamı açık candidate paketleri.",
                "innovation:dependency-impact",
                .research
            ),
            (
                "KRALİ çok dilli araştırma değerlendirmesini iyileştir",
                "Aynı araştırma iddiasını Türkçe ve İngilizce sorgularla karşılaştırarak kaynak kör noktalarını ölçmek.",
                "Dil kaynaklı bulgu kaybını azaltan daha dengeli araştırma kalitesi.",
                "innovation:multilingual-evaluation",
                .research
            ),
            (
                "KRALİ geliştirme benchmark geçmişini iyileştir",
                "Araştırma ve candidate çıktılarının kalite puanlarını zaman içinde karşılaştırılabilir biçimde kaydetmek.",
                "Gelişimin gerçek görevlerde ölçülmesi ve gerilemelerin fark edilmesi.",
                "innovation:quality-history",
                .research
            )
        ]

        let fingerprints = Set(existing.map(\.fingerprint))
        let suppressed = Set(existing.filter { $0.state == .suppressed }.map(\.fingerprint))
        let activeInnovationCount = existing.filter {
            $0.fingerprint.hasPrefix("innovation:") &&
            ($0.state == .proposed || $0.state == .deferred)
        }.count

        // Keep the sidebar compact while giving the user a useful choice set.
        // A fresh queue fills up to three user-actionable ideas at once.
        guard activeInnovationCount < 3 else { return existing }

        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        let uiDefinitions = definitions.filter { $0.4 == .usability }
        let researchDefinitions = definitions.filter { $0.4 == .research }
        let orderedUI = (0..<uiDefinitions.count).map {
            uiDefinitions[(day + $0) % uiDefinitions.count]
        }
        let orderedResearch = (0..<researchDefinitions.count).map {
            researchDefinitions[(day + $0) % researchDefinitions.count]
        }
        let ordered = orderedUI + orderedResearch

        let additions = ordered.filter {
            !fingerprints.contains($0.3) && !suppressed.contains($0.3)
        }
        .prefix(3 - activeInnovationCount)

        guard !additions.isEmpty else {
            return existing
        }

        var refreshed = existing
        for definition in additions {
            refreshed.append(
            AgentDevelopmentSuggestion(
                id: UUID(),
                fingerprint: definition.3,
                source: definition.4,
                capabilityID: nil,
                capabilityName: nil,
                capabilityKind: nil,
                learningPath: nil,
                candidateCapabilityIDs: [],
                title: definition.0,
                reason: definition.1,
                expectedBenefit: definition.2,
                provenanceIDs: ["innovation-queue:" + definition.3],
                sourceRevision: revision,
                risk: "low",
                occurrenceCount: 1,
                state: .proposed,
                developerJobID: nil,
                candidateBranch: nil,
                createdAt: now,
                updatedAt: now
            )
            )
        }
        return refreshed
    }

    func save(
        _ suggestions:
            [AgentDevelopmentSuggestion]
    ) {
        do {
            try fileManager
                .createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories:
                        true
                )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes
            ]
            encoder.dateEncodingStrategy =
                .iso8601

            try encoder
                .encode(suggestions)
                .write(
                    to: suggestionsURL,
                    options: .atomic
                )
        } catch {
            // Suggestion persistence must
            // never block the user task.
        }
    }

    /// A stopped diagnosis can be reconsidered only through an explicit user
    /// action. The original record remains intact for auditability; the new
    /// proposal is bound to the current exact source revision and still needs
    /// a separate "Geliştir" approval before any candidate may start.
    func retry(
        suggestionID: UUID,
        sourceRevision: String?,
        in existing: [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        guard
            let revision = AgentSourceRevisionPolicy.exactRevision(sourceRevision),
            let original = existing.first(where: { $0.id == suggestionID }),
            original.state == .failed || original.state == .readyForReview,
            original.sourceRevision != revision
        else {
            return existing
        }

        let fingerprint = original.fingerprint + "|retry|" + compactIdentifier(revision)
        guard !existing.contains(where: { $0.fingerprint == fingerprint }) else {
            return existing
        }

        let now = Date()
        var provenance = Array(original.provenanceIDs.prefix(8))
        provenance.append("user-retry:" + compactIdentifier(original.id.uuidString))

        var updated = existing
        updated.append(
            AgentDevelopmentSuggestion(
                id: UUID(),
                fingerprint: fingerprint,
                source: original.source,
                capabilityID: original.capabilityID,
                capabilityName: original.capabilityName,
                capabilityKind: original.capabilityKind,
                learningPath: original.learningPath,
                candidateCapabilityIDs: original.candidateCapabilityIDs,
                title: original.title,
                reason: "Kullanıcı önceki teşhis/denemeden sonra bu önerinin güncel kaynak revizyonunda yeniden araştırılmasını istedi.",
                expectedBenefit: original.expectedBenefit,
                provenanceIDs: provenance,
                sourceRevision: revision,
                risk: original.risk,
                occurrenceCount: original.occurrenceCount + 1,
                state: .proposed,
                developerJobID: nil,
                candidateBranch: nil,
                createdAt: now,
                updatedAt: now
            )
        )
        save(updated)
        return updated
    }

    func observeCapabilityGaps(
        _ gaps: [CapabilityGapResolution],
        sourceRevision: String?,
        provenancePrefix: String,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        var suggestions = existing

        for gap in gaps {
            let fingerprint =
                capabilityFingerprint(
                    gap
                )

            let now = Date()
            let provenanceID =
                provenancePrefix +
                ":" +
                compactIdentifier(
                    gap.capabilityID
                )

            if let index =
                suggestions.firstIndex(
                    where: {
                        $0.fingerprint ==
                            fingerprint
                    }
                ) {
                suggestions[index]
                    .occurrenceCount += 1
                suggestions[index]
                    .updatedAt = now

                // Suppression is sticky and
                // deferred suggestions never
                // become executable merely
                // because the gap reappears.
                continue
            }

            suggestions.append(
                AgentDevelopmentSuggestion(
                    id: UUID(),
                    fingerprint:
                        fingerprint,
                    source:
                        .capabilityGap,
                    capabilityID:
                        gap.capabilityID,
                    capabilityName:
                        gap.capabilityName,
                    capabilityKind:
                        gap.kind,
                    learningPath:
                        gap.learningPath,
                    candidateCapabilityIDs:
                        Array(
                            gap
                                .candidateCapabilityIDs
                                .prefix(8)
                        ),
                    title:
                        compactText(
                            gap.capabilityName,
                            limit: 90
                        ),
                    reason:
                        compactText(
                            gap.reason,
                            limit: 360
                        ),
                    expectedBenefit:
                        "KRALİ'nin " +
                        compactText(
                            gap.capabilityName,
                            limit: 90
                        ) +
                        " yeteneğini kontrollü bir candidate ile geliştirmek.",
                    provenanceIDs: [
                        provenanceID
                    ],
                    sourceRevision:
                        AgentSourceRevisionPolicy
                            .exactRevision(
                                sourceRevision
                            ),
                    risk:
                        riskLabel(
                            for: gap
                        ),
                    occurrenceCount: 1,
                    state: .proposed,
                    developerJobID: nil,
                    candidateBranch: nil,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        save(suggestions)
        return suggestions
    }

    func observeResearch(
        _ synthesis:
            AgentDevelopmentResearchSynthesis,
        sourceRevision: String?,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        guard
            synthesis.mutationRecommended,
            !synthesis.mutationStarted,
            !synthesis
                .selectedImprovement
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
        else {
            return existing
        }

        let fingerprint =
            "research|" +
            compactIdentifier(
                synthesis
                    .selectedImprovement
            )

        var suggestions = existing
        let now = Date()
        let regressionMemory = regressionMemory(
            for: synthesis.selectedImprovement,
            in: existing
        )

        if let index =
            suggestions.firstIndex(
                where: {
                    $0.fingerprint ==
                        fingerprint
                }
            ) {
            suggestions[index]
                .occurrenceCount += 1
            suggestions[index]
                .updatedAt = now
            save(suggestions)
            return suggestions
        }

        let externalIDs =
            synthesis
                .proposal
                .evidenceIDs
                .prefix(6)
                .map {
                    "research:" + $0
                }

        let repositoryIDs =
            synthesis
                .proposal
                .repositoryEvidenceIDs
                .prefix(6)
                .map {
                    "repository:" + $0
                }

        suggestions.append(
            AgentDevelopmentSuggestion(
                id: UUID(),
                fingerprint:
                    fingerprint,
                source: .research,
                capabilityID: nil,
                capabilityName: nil,
                capabilityKind: nil,
                learningPath: nil,
                candidateCapabilityIDs: [],
                title:
                    compactText(
                        synthesis
                            .selectedImprovement,
                        limit: 110
                    ),
                reason:
                    compactText(
                        synthesis
                            .biggestGap,
                        limit: 360
                    ),
                expectedBenefit:
                    compactText(
                        synthesis
                            .proposal
                            .expectedBehavior,
                        limit: 360
                    ) + " Historical regression memory: " + regressionMemory.summary +
                    " Replay checks: " + regressionMemory.replayChecks.joined(separator: " • "),
                provenanceIDs:
                    Array(
                        externalIDs +
                        repositoryIDs
                    ),
                sourceRevision:
                    AgentSourceRevisionPolicy
                        .exactRevision(
                            sourceRevision
                        ),
                risk: regressionMemory.risk,
                occurrenceCount: 1,
                state: .proposed,
                developerJobID: nil,
                candidateBranch: nil,
                createdAt: now,
                updatedAt: now
            )
        )

        save(suggestions)
        return suggestions
    }

    func regressionMemory(
        for candidateTitle: String,
        in suggestions: [AgentDevelopmentSuggestion]
    ) -> AgentDevelopmentRegressionMemory {
        let failed = suggestions.filter { $0.state == .failed }
        let released = suggestions.filter {
            $0.state == .released || $0.state == .completed
        }
        let candidateTokens = meaningfulTokens(candidateTitle)
        let matchingFailures = failed.filter {
            !candidateTokens.isEmpty &&
            !candidateTokens.intersection(
                meaningfulTokens($0.title + " " + $0.reason)
            ).isEmpty
        }

        let risk: String
        if matchingFailures.count >= 2 {
            risk = "high"
        } else if !matchingFailures.isEmpty {
            risk = "medium"
        } else {
            risk = "low"
        }

        let summary: String
        if matchingFailures.isEmpty {
            summary = "No matching historical failure was found; normal review remains required."
        } else {
            summary = String(matchingFailures.count) + " similar failed candidate(s) found; require explicit regression checks before review."
        }

        let replayChecks: [String]
        if matchingFailures.isEmpty {
            replayChecks = [
                "Run the proposal verification contract before lead review.",
                "Keep the candidate isolated until the rollback condition is verified."
            ]
        } else {
            replayChecks = matchingFailures.prefix(3).map {
                "Replay the failed-candidate boundary: " + compactText($0.title, limit: 90)
            } + [
                "Run the proposal verification contract before lead review.",
                "Confirm the rollback condition before any publication decision."
            ]
        }

        return AgentDevelopmentRegressionMemory(
            failedCandidateCount: failed.count,
            releasedCandidateCount: released.count,
            matchingFailureCount: matchingFailures.count,
            risk: risk,
            summary: summary,
            replayChecks: replayChecks
        )
    }

    private func meaningfulTokens(_ value: String) -> Set<String> {
        let ignored = Set([
            "krali", "agent", "research", "arastirma", "gelistirme",
            "quality", "kalitesi", "improve", "iyilestir", "system"
        ])
        return Set(
            value
                .folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: Locale(identifier: "tr_TR")
                )
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 && !ignored.contains($0) }
        )
    }

    func observeArena(
        _ report: AgentArenaReport,
        sourceRevision: String?,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        guard
            report.failed > 0 ||
            report.reviewerFlagged > 0
        else {
            return existing
        }

        let failedIDs =
            report.results
                .filter {
                    !$0.passed ||
                    $0.reviewerPassed == false
                }
                .map(\.scenarioID)
                .sorted()

        let fingerprint =
            "arena|" +
            failedIDs
                .prefix(8)
                .joined(separator: ",")

        var suggestions = existing
        let now = Date()

        if let index =
            suggestions.firstIndex(
                where: {
                    $0.fingerprint ==
                        fingerprint
                }
            ) {
            suggestions[index]
                .occurrenceCount += 1
            suggestions[index]
                .updatedAt = now
            save(suggestions)
            return suggestions
        }

        suggestions.append(
            AgentDevelopmentSuggestion(
                id: UUID(),
                fingerprint:
                    fingerprint,
                source: .arena,
                capabilityID: nil,
                capabilityName: nil,
                capabilityKind: nil,
                learningPath: nil,
                candidateCapabilityIDs: [],
                title:
                    "Arena güvenilirlik önerisi",
                reason:
                    "Arena " +
                    String(report.failed) +
                    " başarısız ve " +
                    String(
                        report
                            .reviewerFlagged
                    ) +
                    " reviewer-flagged senaryo buldu.",
                expectedBenefit:
                    "Açık-dünya regression'larını kullanıcı onayından sonra kontrollü bir geliştirme göreviyle azaltmak.",
                provenanceIDs:
                    failedIDs
                        .prefix(8)
                        .map {
                            "arena:" + $0
                        },
                sourceRevision:
                    AgentSourceRevisionPolicy
                        .exactRevision(
                            sourceRevision
                        ),
                risk: "medium",
                occurrenceCount: 1,
                state: .proposed,
                createdAt: now,
                updatedAt: now
            )
        )

        save(suggestions)
        return suggestions
    }

    func transition(
        _ id: UUID,
        to state:
            AgentDevelopmentSuggestionState,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        var suggestions = existing

        guard
            let index =
                suggestions.firstIndex(
                    where: {
                        $0.id == id
                    }
                )
        else {
            return suggestions
        }

        suggestions[index].state =
            state
        suggestions[index].updatedAt =
            Date()
        save(suggestions)
        return suggestions
    }

    func linkDevelopmentJob(
        suggestionID: UUID,
        jobID: UUID,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        var suggestions = existing

        guard
            let index =
                suggestions.firstIndex(
                    where: {
                        $0.id ==
                            suggestionID
                    }
                )
        else {
            return suggestions
        }

        suggestions[index]
            .developerJobID = jobID
        suggestions[index]
            .updatedAt = Date()
        save(suggestions)
        return suggestions
    }

    func updateDevelopmentState(
        jobID: UUID,
        state:
            AgentDevelopmentSuggestionState,
        candidateBranch: String? = nil,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        var suggestions = existing

        guard
            let index =
                suggestions.firstIndex(
                    where: {
                        $0.developerJobID ==
                            jobID
                    }
                )
        else {
            return suggestions
        }

        suggestions[index].state =
            state

        if let candidateBranch {
            suggestions[index]
                .candidateBranch =
                    candidateBranch
        }

        suggestions[index]
            .updatedAt = Date()
        save(suggestions)
        return suggestions
    }

    func updateSuggestionDevelopmentState(
        suggestionID: UUID,
        state:
            AgentDevelopmentSuggestionState,
        candidateBranch: String? = nil,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        var suggestions = existing

        guard
            let index =
                suggestions.firstIndex(
                    where: {
                        $0.id ==
                            suggestionID
                    }
                )
        else {
            return suggestions
        }

        suggestions[index].state =
            state

        if let candidateBranch {
            suggestions[index]
                .candidateBranch =
                    candidateBranch
        }

        suggestions[index]
            .updatedAt = Date()
        save(suggestions)
        return suggestions
    }

    func approvedGap(
        from suggestion:
            AgentDevelopmentSuggestion
    ) -> CapabilityGapResolution? {
        guard
            suggestion
                .isExecutableCapabilityGap,
            let capabilityID =
                suggestion.capabilityID,
            let capabilityName =
                suggestion.capabilityName,
            let kind =
                suggestion.capabilityKind
        else {
            return nil
        }

        return CapabilityGapResolution(
            capabilityID:
                capabilityID,
            capabilityName:
                capabilityName,
            kind:
                kind,
            reason:
                suggestion.reason,
            candidateCapabilityIDs:
                suggestion
                    .candidateCapabilityIDs,
            researchGoal:
                "Research the minimum safe implementation for the user-approved capability proposal: " +
                capabilityName,
            developerBrief:
                "Implement the minimum bounded candidate for capability " +
                capabilityID +
                ". Preserve existing approval/security boundaries and verify the change deterministically.",
            learningPath:
                suggestion.learningPath
        )
    }

    private func capabilityFingerprint(
        _ gap: CapabilityGapResolution
    ) -> String {
        [
            "capability-gap",
            compactIdentifier(
                gap.capabilityID
            ),
            gap.kind.rawValue
        ]
        .joined(separator: "|")
    }

    private func riskLabel(
        for gap: CapabilityGapResolution
    ) -> String {
        switch gap.kind {
        case .knowledge,
             .strategy:
            return "low"
        case .code:
            return "medium"
        case .integration:
            return "medium"
        }
    }

    private func compactText(
        _ value: String,
        limit: Int
    ) -> String {
        let clean =
            value
                .replacingOccurrences(
                    of: "\n",
                    with: " "
                )
                .split(
                    whereSeparator: {
                        $0.isWhitespace
                    }
                )
                .joined(separator: " ")

        return String(
            clean.prefix(limit)
        )
    }

    private func compactIdentifier(
        _ value: String
    ) -> String {
        value
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale:
                    Locale(
                        identifier:
                            "tr_TR"
                    )
            )
            .lowercased()
            .components(
                separatedBy:
                    CharacterSet
                        .alphanumerics
                        .inverted
            )
            .filter {
                !$0.isEmpty
            }
            .prefix(6)
            .joined(separator: "-")
    }
}
