import Foundation

struct ConversationStore {
    private let fileManager = FileManager.default

    private let activeLimit = 160
    private let retainedAfterArchive = 120

    private var rootURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Conversations",
                isDirectory: true
            )
    }

    private var activeURL: URL {
        rootURL.appendingPathComponent(
            "active-v1.json",
            isDirectory: false
        )
    }

    private var archiveURL: URL {
        rootURL.appendingPathComponent(
            "Archive",
            isDirectory: true
        )
    }

    func loadActive() -> [ChatMessage] {
        guard
            let data = try? Data(contentsOf: activeURL)
        else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (
            try? decoder.decode(
                [ChatMessage].self,
                from: data
            )
        ) ?? []
    }

    @discardableResult
    func persistActive(
        _ messages: [ChatMessage]
    ) -> [ChatMessage] {
        ensureDirectories()

        var active = messages

        if active.count > activeLimit {
            let overflowCount = max(
                0,
                active.count - retainedAfterArchive
            )

            if overflowCount > 0 {
                let overflow = Array(
                    active.prefix(overflowCount)
                )

                if archive(overflow) {
                    active = Array(
                        active.suffix(retainedAfterArchive)
                    )
                }
            }
        }

        guard write(
            active,
            to: activeURL
        ) else {
            return messages
        }

        return active
    }

    func archivedSegmentURLs() -> [URL] {
        ensureDirectories()

        let urls = (
            try? fileManager.contentsOfDirectory(
                at: archiveURL,
                includingPropertiesForKeys: [
                    .contentModificationDateKey
                ],
                options: [.skipsHiddenFiles]
            )
        ) ?? []

        return urls
            .filter {
                $0.pathExtension.lowercased() == "json"
            }
            .sorted {
                $0.lastPathComponent >
                    $1.lastPathComponent
            }
    }

    private func archive(
        _ messages: [ChatMessage]
    ) -> Bool {
        guard !messages.isEmpty else {
            return true
        }

        ensureDirectories()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime
        ]

        let stamp = formatter
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let url = archiveURL.appendingPathComponent(
            "conversation-\(stamp)-\(UUID().uuidString.prefix(8)).json",
            isDirectory: false
        )

        return write(
            messages,
            to: url
        )
    }

    @discardableResult
    private func write(
        _ messages: [ChatMessage],
        to url: URL
    ) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard
            let data = try? encoder.encode(messages)
        else {
            return false
        }

        do {
            try data.write(
                to: url,
                options: .atomic
            )
            return true
        } catch {
            return false
        }
    }

    private func ensureDirectories() {
        try? fileManager.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        try? fileManager.createDirectory(
            at: archiveURL,
            withIntermediateDirectories: true
        )
    }
}
