import Foundation

enum CapabilityLearningProgress: String, Codable, Hashable {
    case detected
    case blockedByPrerequisite
    case readyToResearch
    case researching
    case proposalReady
    case awaitingApproval
    case enabled

    var title: String {
        switch self {
        case .detected: return "Eksik yetkinlik algılandı"
        case .blockedByPrerequisite: return "Ön koşul bekliyor"
        case .readyToResearch: return "Araştırmaya hazır"
        case .researching: return "Araştırılıyor"
        case .proposalReady: return "Çözüm önerisi hazır"
        case .awaitingApproval: return "Onay bekliyor"
        case .enabled: return "Etkin"
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

        for capability in capabilities where capability.isAvailable {
            guard var task = byID[capability.id] else { continue }
            task.progress = .enabled
            task.updatedAt = now
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
