import Foundation

enum ChatInputSource {
    case text
    case voice
}

struct ChatMessage: Identifiable, Hashable, Codable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

struct ActivityItem: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let date = Date()
}

struct FileRecord: Identifiable, Hashable {
    let url: URL
    let name: String
    let relativePath: String
    let fileExtension: String
    let isScreenshot: Bool
    let creationDate: Date?
    let modificationDate: Date?

    var id: String { url.path }
}

struct FolderRecord: Identifiable, Hashable {
    let url: URL
    let name: String
    let relativePath: String
    let creationDate: Date?
    let modificationDate: Date?

    var id: String { url.path }
}

struct PendingFileAction: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let sourceURLs: [URL]
    let destinationFolderURL: URL
}

enum DeveloperToolApprovalAction:
    String,
    Hashable {
    case desktopControlProbe
    case developerSystemEffects
}

struct PendingDeveloperToolApproval:
    Identifiable,
    Hashable {
    let id: UUID
    let action: DeveloperToolApprovalAction
    let title: String
    let reason: String
    let targetSummary: String?

    init(
        id: UUID = UUID(),
        action: DeveloperToolApprovalAction,
        title: String,
        reason: String,
        targetSummary: String? = nil
    ) {
        self.id = id
        self.action = action
        self.title = title
        self.reason = reason
        self.targetSummary = targetSummary
    }
}

struct PendingTaskApproval: Identifiable, Hashable {
    let id: UUID
    let taskID: String
    let stepIndex: Int
    let title: String
    let reason: String
    let capabilityID: String
    let operation: String
    let targetSummary: String?
    let targetName: String?
    let targetBundleIdentifier: String?
    let targetPath: String?

    init(
        id: UUID = UUID(),
        taskID: String,
        stepIndex: Int,
        title: String,
        reason: String,
        capabilityID: String,
        operation: String,
        targetSummary: String? = nil,
        targetName: String? = nil,
        targetBundleIdentifier: String? = nil,
        targetPath: String? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.stepIndex = stepIndex
        self.title = title
        self.reason = reason
        self.capabilityID = capabilityID
        self.operation = operation
        self.targetSummary = targetSummary
        self.targetName = targetName
        self.targetBundleIdentifier =
            targetBundleIdentifier
        self.targetPath = targetPath
    }
}

struct TaskApprovalAudit:
    Codable,
    Hashable,
    Sendable {
    let stepIndex: Int
    let title: String
    let capabilityID: String
    let targetSummary: String?
    let targetName: String?
    let targetBundleIdentifier: String?
    let targetPath: String?
    let decision: String
    let recordedAt: Date
}

struct FileMoveRecord: Identifiable {
    let id = UUID()
    let originalURL: URL
    let movedURL: URL
}

struct UndoFileAction {
    let moves: [FileMoveRecord]
}


enum AgentExecutionStepKind: String, Hashable {
    case reasoning
    case action
    case verification
    case response
}

enum AgentStepState: String, Hashable {
    case pending
    case running
    case completed
    case partial
    case blocked
    case attention
    case skipped

    var systemImage: String {
        switch self {
        case .pending: return "circle"
        case .running: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .blocked: return "circle.slash"
        case .attention: return "exclamationmark.triangle.fill"
        case .skipped: return "minus.circle"
        }
    }
}

struct AgentExecutionStep: Identifiable, Hashable {
    let id: UUID
    let title: String
    let detail: String
    let kind: AgentExecutionStepKind
    let capabilityID: String?
    var state: AgentStepState

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        kind: AgentExecutionStepKind = .action,
        capabilityID: String? = nil,
        state: AgentStepState = .pending
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.capabilityID = capabilityID
        self.state = state
    }
}

struct AgentExecutionPlan {
    let goal: String
    var steps: [AgentExecutionStep]
    let fallback: String?
    let requiresVerification: Bool
}

struct AgentSemanticMission: Codable, Hashable, Sendable {
    let objective: String
    let outcomes: [String]
    let steps: [AgentSemanticMissionStep]
    let requiredCapabilityIDs: [String]
    let requiresUserInput: Bool
    let userInputReason: String?
    let confidence: Double

    var normalizedConfidence: Double {
        min(1, max(0, confidence))
    }
}

struct AgentSemanticMissionStep: Codable, Hashable, Sendable {
    let title: String
    let purpose: String
    let capabilityID: String
    let operation: String
    let dependsOn: [Int]
}

struct AgentMissionReview: Codable, Hashable, Sendable {
    let passed: Bool
    let summary: String
    let missingCapabilityIDs: [String]
    let unnecessaryCapabilityIDs: [String]
    let riskNotes: [String]
}

enum AgentVerificationState: String, Hashable {
    case idle
    case checking
    case passed
    case partial
    case attention
    case skipped

    var systemImage: String {
        switch self {
        case .idle: return "circle"
        case .checking: return "magnifyingglass.circle"
        case .passed: return "checkmark.seal.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .skipped: return "minus.circle"
        }
    }
}

struct AgentVerificationResult {
    let state: AgentVerificationState
    let summary: String
    let fallback: String?
}
