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
                archive(
                    Array(active.prefix(overflowCount))
                )
                active = Array(
                    active.suffix(retainedAfterArchive)
                )
            }
        }

        write(
            active,
            to: activeURL
        )

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
    ) {
        guard !messages.isEmpty else {
            return
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
            "conversation-(stamp)-(UUID().uuidString.prefix(8)).json",
            isDirectory: false
        )

        write(
            messages,
            to: url
        )
    }

    private func write(
        _ messages: [ChatMessage],
        to url: URL
    ) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard
            let data = try? encoder.encode(messages)
        else {
            return
        }

        try? data.write(
            to: url,
            options: .atomic
        )
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
