import Foundation

enum ChatInputSource {
    case text
    case voice
}

struct ChatMessage: Identifiable, Hashable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
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

struct FileMoveRecord: Identifiable {
    let id = UUID()
    let originalURL: URL
    let movedURL: URL
}

struct UndoFileAction {
    let moves: [FileMoveRecord]
}


enum AgentStepState: String, Hashable {
    case pending
    case running
    case completed
    case attention
    case skipped

    var systemImage: String {
        switch self {
        case .pending: return "circle"
        case .running: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .skipped: return "minus.circle"
        }
    }
}

struct AgentExecutionStep: Identifiable, Hashable {
    let id: UUID
    let title: String
    let detail: String
    var state: AgentStepState

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        state: AgentStepState = .pending
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

struct AgentExecutionPlan {
    let goal: String
    var steps: [AgentExecutionStep]
    let fallback: String?
    let requiresVerification: Bool
}

enum AgentVerificationState: String, Hashable {
    case idle
    case checking
    case passed
    case attention
    case skipped

    var systemImage: String {
        switch self {
        case .idle: return "circle"
        case .checking: return "magnifyingglass.circle"
        case .passed: return "checkmark.seal.fill"
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
