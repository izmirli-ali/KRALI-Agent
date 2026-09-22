import Foundation

enum CapabilityLearningProgress: String, Codable, Hashable {
    case detected
    case blockedByPrerequisite
    case readyToResearch
    case researching
    case proposalReady
    case awaitingApproval
    case interrupted
    case enabled

    var title: String {
        switch self {
        case .detected: return "Eksik yetkinlik algılandı"
        case .blockedByPrerequisite: return "Ön koşul bekliyor"
        case .readyToResearch: return "Araştırmaya hazır"
        case .researching: return "Araştırılıyor"
        case .proposalReady: return "Çözüm önerisi hazır"
        case .awaitingApproval: return "Onay bekliyor"
        case .interrupted: return "Geçici müdahale"
        case .enabled: return "Öğrenme tamamlandı"
        }
    }

    var systemImage: String {
        switch self {
        case .detected: return "exclamationmark.circle"
        case .blockedByPrerequisite: return "lock.circle"
        case .readyToResearch: return "magnifyingglass.circle"
        case .researching: return "sparkles"
        case .proposalReady: return "doc.badge.gearshape"
        case .awaitingApproval: return "person.crop.circle.badge.checkmark"
        case .interrupted: return "pause.circle"
        case .enabled: return "checkmark.seal.fill"
        }
    }
}

struct CapabilityLearningTask: Identifiable, Codable, Hashable {
    var id: String { capabilityID }

    let capabilityID: String
    var capabilityName: String
    var progress: CapabilityLearningProgress
    var researchGoal: String
    var nextStep: String
    let firstSeenAt: Date
    var updatedAt: Date
    var encounterCount: Int
    var validatedAt: Date? = nil
    var validatedAppVersion: String? = nil
    var validationSummary: String? = nil
}

struct AgentLearningStore {
    private let key = "krali.capability.learning.backlog.v1"

    func load() -> [CapabilityLearningTask] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let tasks = try? JSONDecoder().decode(
                [CapabilityLearningTask].self,
                from: data
            )
        else {
            return []
        }

        return tasks.sorted { left, right in
            if left.progress == .enabled && right.progress != .enabled {
                return false
            }
            if right.progress == .enabled && left.progress != .enabled {
                return true
            }
            return left.updatedAt > right.updatedAt
        }
    }

    func merge(
        existing: [CapabilityLearningTask],
        plans: [CapabilityLearningPlan],
        capabilities: [AgentCapability]
    ) -> [CapabilityLearningTask] {
        var byID = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.capabilityID, $0) }
        )

        let now = Date()

        let appVersion =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "unknown"

        for capability in capabilities where capability.isAvailable {
            guard var task = byID[capability.id] else { continue }
            task.progress = .enabled
            task.updatedAt = now

            if task.validatedAt == nil {
                task.validatedAt = now
            }

            task.validatedAppVersion =
                appVersion
            task.validationSummary =
                "Provider bu sürümde available; öğrenme sonucu kalıcı capability olarak doğrulandı."
            task.nextStep =
                "Öğrenme tamamlandı. Aynı capability için yeniden learning başlatma; yalnız gerçek runtime bozulması varsa repair/revalidation uygula."

            byID[capability.id] = task
        }

        for plan in plans {
            if var task = byID[plan.capabilityID] {
                task.capabilityName = plan.capabilityName
                task.researchGoal = plan.researchGoal
                task.nextStep = plan.nextStep
                task.updatedAt = now
                task.encounterCount += 1

                if task.progress != .researching &&
                   task.progress != .proposalReady &&
                   task.progress != .awaitingApproval {
                    task.progress = progress(for: plan)
                }

                byID[plan.capabilityID] = task
            } else {
                byID[plan.capabilityID] = CapabilityLearningTask(
                    capabilityID: plan.capabilityID,
                    capabilityName: plan.capabilityName,
                    progress: progress(for: plan),
                    researchGoal: plan.researchGoal,
                    nextStep: plan.nextStep,
                    firstSeenAt: now,
                    updatedAt: now,
                    encounterCount: 1
                )
            }
        }

        let tasks = Array(byID.values).sorted { left, right in
            if left.progress == .enabled && right.progress != .enabled {
                return false
            }
            if right.progress == .enabled && left.progress != .enabled {
                return true
            }
            return left.updatedAt > right.updatedAt
        }

        save(tasks)
        return tasks
    }

    func update(
        existing: [CapabilityLearningTask],
        capabilityID: String,
        progress: CapabilityLearningProgress,
        nextStep: String? = nil
    ) -> [CapabilityLearningTask] {
        var tasks = existing
        guard let index = tasks.firstIndex(
            where: { $0.capabilityID == capabilityID }
        ) else {
            return tasks
        }

        tasks[index].progress = progress
        tasks[index].updatedAt = Date()

        if let nextStep, !nextStep.isEmpty {
            tasks[index].nextStep = nextStep
        }

        tasks.sort { left, right in
            if left.progress == .enabled && right.progress != .enabled {
                return false
            }
            if right.progress == .enabled && left.progress != .enabled {
                return true
            }
            return left.updatedAt > right.updatedAt
        }

        save(tasks)
        return tasks
    }

    func save(_ tasks: [CapabilityLearningTask]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func progress(
        for plan: CapabilityLearningPlan
    ) -> CapabilityLearningProgress {
        switch plan.state {
        case .readyToResearch:
            return .readyToResearch
        case .waitingForResearchAccess, .bootstrapRequired:
            return .blockedByPrerequisite
        case .integrationRequired:
            return plan.canResearchAutonomously
                ? .readyToResearch
                : .blockedByPrerequisite
        }
    }
}


struct AgentSkillLibraryStore {
    private let fileManager = FileManager.default

    private var rootURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Skills",
                isDirectory: true
            )
    }

    private var candidatesURL: URL {
        rootURL.appendingPathComponent(
            "Candidates",
            isDirectory: true
        )
    }

    private var libraryURL: URL {
        rootURL.appendingPathComponent(
            "skill-library.json",
            isDirectory: false
        )
    }

    func promoteLatestExperimentalSkill(
        capabilityID: String,
        appVersion: String,
        verificationSummary: String
    ) -> String? {
        guard
            !capabilityID.isEmpty,
            let candidateURLs =
                try? fileManager.contentsOfDirectory(
                    at: candidatesURL,
                    includingPropertiesForKeys: [
                        .contentModificationDateKey
                    ],
                    options: [
                        .skipsHiddenFiles
                    ]
                )
        else {
            return nil
        }

        let ordered =
            candidateURLs
                .filter {
                    $0.pathExtension
                        .lowercased() == "json"
                }
                .sorted { left, right in
                    let leftDate =
                        (
                            try? left.resourceValues(
                                forKeys: [
                                    .contentModificationDateKey
                                ]
                            )
                        )?.contentModificationDate ??
                        .distantPast
                    let rightDate =
                        (
                            try? right.resourceValues(
                                forKeys: [
                                    .contentModificationDateKey
                                ]
                            )
                        )?.contentModificationDate ??
                        .distantPast

                    return leftDate > rightDate
                }

        for candidateURL in ordered {
            guard
                var candidate =
                    readObject(
                        at: candidateURL
                    ),
                candidate["state"] as? String ==
                    "experimental",
                candidate["capability_id"] as? String ==
                    capabilityID,
                let provenance =
                    candidate["provenance"]
                        as? [String: Any],
                provenance["app_version"] as? String ==
                    appVersion,
                var validation =
                    candidate["validation"]
                        as? [String: Any],
                validation["build_passed"] as? Bool ==
                    true,
                validation["regression_passed"] as? Bool ==
                    true
            else {
                continue
            }

            validation[
                "runtime_postcondition_verified"
            ] = true
            validation[
                "runtime_validation_summary"
            ] = verificationSummary

            candidate["state"] = "promoted"
            candidate["validation"] = validation
            candidate["updated_at"] =
                ISO8601DateFormatter()
                    .string(from: Date())

            guard
                writeObject(
                    candidate,
                    to: candidateURL
                )
            else {
                return nil
            }

            var library =
                readObject(
                    at: libraryURL
                ) ?? [
                    "schema_version": 1,
                    "skills": []
                ]

            var skills =
                library["skills"]
                    as? [[String: Any]] ??
                []

            let skillID =
                candidate["id"] as? String ??
                candidateURL
                    .deletingPathExtension()
                    .lastPathComponent

            skills.removeAll {
                ($0["id"] as? String) ==
                    skillID
            }
            skills.insert(
                candidate,
                at: 0
            )

            skills =
                Array(
                    skills
                        .filter {
                            $0["state"] as? String ==
                                "promoted"
                        }
                        .prefix(200)
                )

            library["schema_version"] = 1
            library["skills"] = skills

            guard
                writeObject(
                    library,
                    to: libraryURL
                )
            else {
                return nil
            }

            return candidate["name"] as? String ??
                skillID
        }

        return nil
    }

    private func readObject(
        at url: URL
    ) -> [String: Any]? {
        guard
            let data =
                try? Data(
                    contentsOf: url
                ),
            let rawObject =
                try? JSONSerialization
                    .jsonObject(
                        with: data
                    ),
            let object =
                rawObject as?
                    [String: Any]
        else {
            return nil
        }

        return object
    }

    @discardableResult
    private func writeObject(
        _ object: [String: Any],
        to url: URL
    ) -> Bool {
        guard
            JSONSerialization
                .isValidJSONObject(
                    object
                ),
            let data =
                try? JSONSerialization
                    .data(
                        withJSONObject:
                            object,
                        options: [
                            .prettyPrinted,
                            .sortedKeys,
                            .withoutEscapingSlashes
                        ]
                    )
        else {
            return false
        }

        do {
            try fileManager
                .createDirectory(
                    at:
                        url
                            .deletingLastPathComponent(),
                    withIntermediateDirectories:
                        true
                )
            try data.write(
                to: url,
                options: .atomic
            )
            return true
        } catch {
            return false
        }
    }
}
