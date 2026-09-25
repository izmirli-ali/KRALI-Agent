import Foundation

enum AgentLearningJobState: String, Codable, Hashable, Sendable {
    case queued
    case running
    case readyForReview
    case completed
    case failed

    var title: String {
        switch self {
        case .queued:
            return "Sırada"
        case .running:
            return "Çalışıyor"
        case .readyForReview:
            return "Aday hazır"
        case .completed:
            return "Tamamlandı"
        case .failed:
            return "Başarısız"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .readyForReview, .completed, .failed:
            return true
        case .queued, .running:
            return false
        }
    }
}

struct AgentLearningEvidenceSnapshot: Codable, Hashable, Sendable {
    let sourceGoal: String
    let capturedAt: Date
    let runtimeEvidence: [String]
    let resolverTraceJSON: String?
}

struct AgentLearningJob: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let fingerprint: String
    let capabilityID: String
    let capabilityName: String
    let kind: CapabilityGapKind
    let reason: String
    let researchGoal: String
    let developerBrief: String
    let candidateCapabilityIDs: [String]
    var sourceGoals: [String]
    var evidenceCount: Int
    var evidenceSnapshots:
        [AgentLearningEvidenceSnapshot]? = nil
    let createdAt: Date
    var updatedAt: Date
    var state: AgentLearningJobState
    var branch: String?
    var worktree: String?
    var lastStatus: String?
    var learningPath:
        CapabilityLearningPath? = nil
    /// nil in legacy persisted jobs is deliberately treated as false.
    var userApproved: Bool? = nil

    var shortID: String {
        String(id.uuidString.prefix(8))
    }
}

struct AgentLearningJobBrief: Codable, Sendable {
    let jobID: UUID
    let fingerprint: String
    let gap: CapabilityGapResolution
    let sourceGoals: [String]
    let evidenceCount: Int
    let evidenceSnapshots:
        [AgentLearningEvidenceSnapshot]?
    let createdAt: Date
}

struct AgentLearningQueueStore {
    private let fileManager = FileManager.default

    private var directoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Developer",
                isDirectory: true
            )
    }

    var queueURL: URL {
        directoryURL
            .appendingPathComponent(
                "learning-queue.json",
                isDirectory: false
            )
    }

    private var mentorDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor",
                isDirectory: true
            )
    }

    func load() -> [AgentLearningJob] {
        guard
            let data = try? Data(
                contentsOf: queueURL
            )
        else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (
            try? decoder.decode(
                [AgentLearningJob].self,
                from: data
            )
        ) ?? []
    }

    func save(
        _ jobs: [AgentLearningJob]
    ) {
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes
            ]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(jobs)
            try data.write(
                to: queueURL,
                options: .atomic
            )
        } catch {
            // Queue persistence failure must not block the user's task.
        }
    }

    func enqueue(
        gaps: [CapabilityGapResolution],
        sourceGoal: String,
        into existing: [AgentLearningJob],
        persist: Bool = true,
        userApproved: Bool = false
    ) -> [AgentLearningJob] {
        var jobs = existing

        for gap in gaps {
            let evidenceSnapshot =
                captureEvidenceSnapshot(
                    for: gap,
                    sourceGoal:
                        sourceGoal
                )
            guard !isTransientReason(
                gap.reason
            ) else {
                continue
            }

            let fingerprint =
                self.fingerprint(
                    for: gap
                )

            if let index =
                jobs.firstIndex(
                    where: {
                        $0.fingerprint ==
                            fingerprint &&
                        (
                            !$0.state.isTerminal ||
                            $0.state ==
                                .readyForReview
                        )
                    }
                ) {
                if !jobs[index]
                    .sourceGoals
                    .contains(sourceGoal) {
                    jobs[index]
                        .sourceGoals
                        .append(sourceGoal)
                    jobs[index]
                        .evidenceCount += 1
                }

                if let evidenceSnapshot {
                    var snapshots =
                        jobs[index]
                            .evidenceSnapshots ??
                        []

                    if !snapshots.contains(
                        evidenceSnapshot
                    ) {
                        snapshots.append(
                            evidenceSnapshot
                        )
                        jobs[index]
                            .evidenceSnapshots =
                            Array(
                                snapshots
                                    .suffix(8)
                            )
                    }
                }

                jobs[index].updatedAt = Date()
                if userApproved {
                    jobs[index].userApproved = true
                }
                jobs[index].lastStatus =
                    "Yeni immutable kanıt aynı öğrenme işine eklendi."
                continue
            }

            let now = Date()
            jobs.append(
                AgentLearningJob(
                    id: UUID(),
                    fingerprint:
                        fingerprint,
                    capabilityID:
                        gap.capabilityID,
                    capabilityName:
                        gap.capabilityName,
                    kind: gap.kind,
                    reason: gap.reason,
                    researchGoal:
                        gap.researchGoal,
                    developerBrief:
                        gap.developerBrief,
                    candidateCapabilityIDs:
                        gap.candidateCapabilityIDs,
                    sourceGoals:
                        [sourceGoal],
                    evidenceCount: 1,
                    evidenceSnapshots:
                        evidenceSnapshot
                            .map { [$0] },
                    createdAt: now,
                    updatedAt: now,
                    state: .queued,
                    branch: nil,
                    worktree: nil,
                    lastStatus:
                        "Öğrenme kuyruğuna eklendi.",
                    learningPath:
                        gap.learningPath,
                    userApproved: userApproved
                )
            )
        }

        if persist {
            save(jobs)
        }

        return jobs
    }

    func nextQueued(
        from jobs: [AgentLearningJob]
    ) -> AgentLearningJob? {
        jobs
            .filter {
                $0.state == .queued && $0.userApproved == true
            }
            .sorted {
                if $0.evidenceCount !=
                    $1.evidenceCount {
                    return $0.evidenceCount >
                        $1.evidenceCount
                }

                return $0.createdAt <
                    $1.createdAt
            }
            .first
    }

    func materializeBrief(
        for job: AgentLearningJob
    ) -> URL? {
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let url =
                directoryURL
                    .appendingPathComponent(
                        "learning-job-" +
                        job.id.uuidString +
                        ".json",
                        isDirectory: false
                    )

            let brief =
                AgentLearningJobBrief(
                    jobID: job.id,
                    fingerprint:
                        job.fingerprint,
                    gap:
                        CapabilityGapResolution(
                            capabilityID:
                                job.capabilityID,
                            capabilityName:
                                job.capabilityName,
                            kind: job.kind,
                            reason: job.reason,
                            candidateCapabilityIDs:
                                job.candidateCapabilityIDs,
                            researchGoal:
                                job.researchGoal,
                            developerBrief:
                                job.developerBrief,
                            learningPath:
                                job.learningPath
                        ),
                    sourceGoals:
                        job.sourceGoals,
                    evidenceCount:
                        job.evidenceCount,
                    evidenceSnapshots:
                        job.evidenceSnapshots,
                    createdAt:
                        job.createdAt
                )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes
            ]
            encoder.dateEncodingStrategy = .iso8601

            try encoder
                .encode(brief)
                .write(
                    to: url,
                    options: .atomic
                )

            return url
        } catch {
            return nil
        }
    }

    func recoverInterruptedJobs(
        _ jobs: [AgentLearningJob],
        activeRunIsFresh: Bool
    ) -> [AgentLearningJob] {
        guard !activeRunIsFresh else {
            return jobs
        }

        var recovered = jobs

        for index in recovered.indices {
            if isTransientReason(
                recovered[index].reason
            ) {
                recovered[index].state =
                    .failed
                recovered[index].updatedAt =
                    Date()
                recovered[index].lastStatus =
                    "Geçici kullanıcı/foreground müdahalesi capability eksikliği değildir; öğrenme işi kapatıldı."
                continue
            }

            if recovered[index]
                .developerBrief
                .contains(
                    "Operation: capability.contract"
                ) {
                recovered[index].state =
                    .failed
                recovered[index].updatedAt =
                    Date()
                recovered[index].lastStatus =
                    "Synthetic capability.contract gelecekteki gerçek bir runtime step değildir; erken öğrenme işi kapatıldı."
                continue
            }

            if recovered[index].state ==
                .running {
                recovered[index].state =
                    .failed
                recovered[index].updatedAt =
                    Date()
                recovered[index].lastStatus =
                    "Önceki app sürümündeki worker kesildi. Planner/provider değişmiş olabileceği için otomatik yeniden başlatılmadı; aynı gap yeni runtime'da tekrar doğrulanırsa yeni öğrenme işi oluşturulacak."
            }
        }

        save(recovered)
        return recovered
    }

    private func captureEvidenceSnapshot(
        for gap: CapabilityGapResolution,
        sourceGoal: String
    ) -> AgentLearningEvidenceSnapshot? {
        let mentorURL =
            mentorDirectoryURL
                .appendingPathComponent(
                    "latest.json",
                    isDirectory: false
                )
        let resolverURL =
            mentorDirectoryURL
                .appendingPathComponent(
                    "application-resolution-latest.json",
                    isDirectory: false
                )

        let mentor =
            readJSONObject(
                at: mentorURL
            )
        let mentorInput =
            mentor?["userInput"]
                as? String

        var runtimeEvidence: [String] = []

        if let mentor,
           normalize(
                mentorInput ?? ""
           ) ==
            normalize(sourceGoal),
           let gaps =
                mentor["capabilityGaps"]
                    as? [[String: Any]],
           gaps.contains(
                where: {
                    normalize(
                        $0["capabilityID"]
                            as? String ??
                        ""
                    ) ==
                    normalize(
                        gap.capabilityID
                    )
                }
           ),
           let activity =
                mentor["activityTail"]
                    as? [[String: Any]] {
            runtimeEvidence =
                activity
                    .compactMap {
                        $0["text"]
                            as? String
                    }
                    .filter {
                        let normalized =
                            normalize($0)

                        return
                            normalized
                                .contains(
                                    "basarisiz"
                                ) ||
                            normalized
                                .contains(
                                    "bulunamadi"
                                ) ||
                            normalized
                                .contains(
                                    "runtime capability gap"
                                ) ||
                            normalized
                                .contains(
                                    "postcondition"
                                ) ||
                            normalized
                                .contains(
                                    "failed"
                                ) ||
                            normalized
                                .contains(
                                    "error"
                                )
                    }
                    .prefix(10)
                    .map { $0 }
        }

        var resolverTraceJSON: String?

        if gap.capabilityID ==
            "desktop.app",
           let resolverObject =
                readJSONObject(
                    at: resolverURL
                ),
           normalize(
                resolverObject[
                    "requestedText"
                ] as? String ?? ""
           ) ==
            normalize(sourceGoal),
           let resolverData =
                try? Data(
                    contentsOf:
                        resolverURL
                ) {
            resolverTraceJSON =
                String(
                    data: resolverData,
                    encoding: .utf8
                )
        }

        guard
            !runtimeEvidence.isEmpty ||
            resolverTraceJSON != nil
        else {
            return nil
        }

        return AgentLearningEvidenceSnapshot(
            sourceGoal:
                sourceGoal,
            capturedAt:
                Date(),
            runtimeEvidence:
                runtimeEvidence,
            resolverTraceJSON:
                resolverTraceJSON
        )
    }

    private func readJSONObject(
        at url: URL
    ) -> [String: Any]? {
        guard
            let data = try? Data(
                contentsOf: url
            ),
            let object =
                try? JSONSerialization
                    .jsonObject(
                        with: data
                    ),
            let dictionary =
                object as? [String: Any]
        else {
            return nil
        }

        return dictionary
    }

    private func isTransientReason(
        _ reason: String
    ) -> Bool {
        let normalized =
            normalize(reason)

        let markers = [
            "frontmost kalmadi",
            "odagi degistirmis olabilir",
            "observation boyunca frontmost kalmadi",
            "observation interrupted",
            "focus changed",
            "foreground changed",
            "observation hazir degil",
            "ocr kaniti uretmedi",
            "observation belirsiz",
            "tam hedef domain dogrulanamadi",
            "gecici algi/yuklenme belirsizligi"
        ]

        return markers.contains {
            normalized.contains($0)
        }
    }

    private func fingerprint(
        for gap: CapabilityGapResolution
    ) -> String {
        let normalizedReason =
            normalize(
                gap.reason
            )

        let operationTail: String
        if let separator =
            normalizedReason
                .range(
                    of: " • ",
                    options: .backwards
                ) {
            operationTail =
                String(
                    normalizedReason[
                        separator.upperBound...
                    ]
                )
        } else {
            operationTail =
                normalizedReason
        }

        return [
            normalize(gap.capabilityID),
            gap.kind.rawValue,
            operationTail
        ]
        .joined(separator: "|")
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
