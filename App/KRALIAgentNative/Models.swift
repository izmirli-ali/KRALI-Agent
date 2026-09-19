import Foundation

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
