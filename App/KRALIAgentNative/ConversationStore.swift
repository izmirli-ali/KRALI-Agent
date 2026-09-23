import Foundation

struct ConversationArchiveSegment: Identifiable, Hashable {
    let id: String
    let url: URL
    let title: String
    let subtitle: String
    let messageCount: Int
    let createdAt: Date
}

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
        loadMessages(at: activeURL)
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

    func archiveActiveConversation(
        _ messages: [ChatMessage]
    ) -> Bool {
        let hasUserMessage = messages.contains {
            $0.role == .user
        }

        guard hasUserMessage else {
            return write([], to: activeURL)
        }

        guard archive(messages) else {
            return false
        }

        return write([], to: activeURL)
    }

    func archiveSegments() -> [ConversationArchiveSegment] {
        archivedSegmentURLs()
            .compactMap { url in
                let messages = loadMessages(at: url)
                guard !messages.isEmpty else {
                    return nil
                }

                let values = try? url.resourceValues(
                    forKeys: [
                        .creationDateKey,
                        .contentModificationDateKey
                    ]
                )

                let createdAt =
                    values?.creationDate ??
                    values?.contentModificationDate ??
                    messages.first?.createdAt ??
                    Date.distantPast

                let rawTitle =
                    messages.first(
                        where: {
                            $0.role == .user
                        }
                    )?.text ??
                    "Geçmiş sohbet"

                return ConversationArchiveSegment(
                    id: url.lastPathComponent,
                    url: url,
                    title: compactTitle(rawTitle),
                    subtitle: formattedDate(createdAt),
                    messageCount: messages.count,
                    createdAt: createdAt
                )
            }
            .sorted {
                $0.createdAt > $1.createdAt
            }
    }

    func loadArchive(
        _ segment: ConversationArchiveSegment
    ) -> [ChatMessage] {
        loadMessages(at: segment.url)
    }

    @discardableResult
    func deleteArchive(
        _ segment: ConversationArchiveSegment
    ) -> Bool {
        ensureDirectories()

        let archiveRoot =
            archiveURL
                .standardizedFileURL
                .resolvingSymlinksInPath()
        let candidate =
            segment.url
                .standardizedFileURL
                .resolvingSymlinksInPath()

        guard
            candidate.deletingLastPathComponent() ==
                archiveRoot,
            candidate.pathExtension
                .lowercased() == "json"
        else {
            return false
        }

        do {
            try fileManager.removeItem(
                at: candidate
            )
            return true
        } catch {
            return false
        }
    }

    private func archivedSegmentURLs() -> [URL] {
        ensureDirectories()

        let urls = (
            try? fileManager.contentsOfDirectory(
                at: archiveURL,
                includingPropertiesForKeys: [
                    .creationDateKey,
                    .contentModificationDateKey
                ],
                options: [.skipsHiddenFiles]
            )
        ) ?? []

        return urls.filter {
            $0.pathExtension.lowercased() == "json"
        }
    }

    private func loadMessages(
        at url: URL
    ) -> [ChatMessage] {
        guard
            let data = try? Data(contentsOf: url)
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
        ensureDirectories()

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

    private func compactTitle(
        _ value: String
    ) -> String {
        let flattened = value
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

        guard flattened.count > 46 else {
            return flattened
        }

        return String(flattened.prefix(43)) + "…"
    }

    private func formattedDate(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier: "tr_TR"
        )
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
