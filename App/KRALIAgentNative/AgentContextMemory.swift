import Foundation

enum AgentContextMemoryKind: String, Codable, Hashable {
    case userRule
    case task
    case research
}

struct AgentContextMemoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: AgentContextMemoryKind
    let title: String
    let summary: String
    let userInput: String?
    let goal: String?
    let sourceURLs: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: AgentContextMemoryKind,
        title: String,
        summary: String,
        userInput: String? = nil,
        goal: String? = nil,
        sourceURLs: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.userInput = userInput
        self.goal = goal
        self.sourceURLs = sourceURLs
        self.createdAt = createdAt
    }
}

struct AgentContextMemoryStore {
    private let fileManager = FileManager.default

    var outputURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Memory/context-v1.json",
                isDirectory: false
            )
    }

    func load() -> [AgentContextMemoryEntry] {
        guard
            let data = try? Data(contentsOf: outputURL)
        else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = (
            try? decoder.decode(
                [AgentContextMemoryEntry].self,
                from: data
            )
        ) ?? []

        return decoded.filter {
            !isLowValueFallback($0.summary) &&
            !isLegacyMisroutedRuleTask($0)
        }
    }

    func save(_ entries: [AgentContextMemoryEntry]) {
        let directory = outputURL.deletingLastPathComponent()

        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(entries) else {
            return
        }

        try? data.write(
            to: outputURL,
            options: .atomic
        )
    }

    func captureTask(
        userInput: String,
        goal: String,
        response: String,
        researchEvidence: [WebSourceEvidence]
    ) -> AgentContextMemoryEntry? {
        let input = userInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let reply = response.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            input.count >= 4,
            reply.count >= 20,
            !isLowValueFallback(reply)
        else {
            return nil
        }

        let kind: AgentContextMemoryKind =
            researchEvidence.isEmpty ? .task : .research

        let title = shortTitle(
            from: input
        )

        let summary = compactSummary(
            reply,
            maximumCharacters: 1800
        )

        let urls = Array(
            Set(
                researchEvidence.map {
                    $0.source.url.absoluteString
                }
            )
        )
        .sorted()

        return AgentContextMemoryEntry(
            kind: kind,
            title: title,
            summary: summary,
            userInput: input,
            goal: goal,
            sourceURLs: urls
        )
    }

    func upsertRule(
        _ rawRule: String,
        in entries: [AgentContextMemoryEntry]
    ) -> [AgentContextMemoryEntry] {
        let rule = rawRule.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !rule.isEmpty else {
            return entries
        }

        let normalizedRule = normalize(rule)

        if entries.contains(
            where: {
                $0.kind == .userRule &&
                normalize($0.summary) == normalizedRule
            }
        ) {
            return entries
        }

        var updated = entries
        updated.insert(
            AgentContextMemoryEntry(
                kind: .userRule,
                title: "Çalışma kuralı",
                summary: rule
            ),
            at: 0
        )

        return trimmed(updated)
    }

    func append(
        _ entry: AgentContextMemoryEntry,
        to entries: [AgentContextMemoryEntry]
    ) -> [AgentContextMemoryEntry] {
        var updated = entries

        if let duplicateIndex = updated.firstIndex(
            where: {
                $0.kind != .userRule &&
                entry.kind != .userRule &&
                normalize($0.userInput ?? "") ==
                    normalize(entry.userInput ?? "") &&
                entry.userInput?.isEmpty == false &&
                $0.userInput?.isEmpty == false
            }
        ) {
            updated.remove(at: duplicateIndex)
        }

        updated.insert(entry, at: 0)
        return trimmed(updated)
    }

    func relevant(
        to rawQuery: String,
        from entries: [AgentContextMemoryEntry],
        limit: Int = 4
    ) -> [AgentContextMemoryEntry] {
        let query = normalize(rawQuery)
        let queryTokens = Set(tokens(query))
        let continuation = containsContinuationReference(query)
        let explicitNewTopic =
            isExplicitNewTopicIntroduction(query)
        let inlineSourceRewrite =
            isInlineSourceRewriteRequest(rawQuery)
        let transformation = isTransformationRequest(query)
        let referencesIdeas = query.contains("fikir") ||
            query.contains("reels")
        let hasDirectIdeaSource =
            transformation &&
            referencesIdeas &&
            entries.contains {
                isDirectIdeaSource($0)
            }

        func overlapCount(
            for entry: AgentContextMemoryEntry
        ) -> Int {
            let corpus = normalize(
                [
                    entry.title,
                    entry.summary,
                    entry.userInput ?? "",
                    entry.goal ?? ""
                ]
                .joined(separator: " ")
            )

            return queryTokens
                .intersection(Set(tokens(corpus)))
                .count
        }

        func identityOverlapCount(
            for entry: AgentContextMemoryEntry
        ) -> Int {
            let identityCorpus = normalize(
                [
                    entry.title,
                    entry.userInput ?? ""
                ]
                .joined(separator: " ")
            )

            return queryTokens
                .intersection(Set(tokens(identityCorpus)))
                .count
        }

        let strongestContextOverlap = entries
            .filter { $0.kind != .userRule }
            .map(overlapCount)
            .max() ?? 0

        let strongestIdentityOverlap = entries
            .filter { $0.kind != .userRule }
            .map(identityOverlapCount)
            .max() ?? 0

        var scored: [
            (entry: AgentContextMemoryEntry, score: Int)
        ] = []

        for (index, entry) in entries.enumerated() {
            var score = 0

            let corpus = normalize(
                [
                    entry.title,
                    entry.summary,
                    entry.userInput ?? "",
                    entry.goal ?? ""
                ]
                .joined(separator: " ")
            )

            let tokenOverlap = overlapCount(
                for: entry
            )
            let identityOverlap = identityOverlapCount(
                for: entry
            )
            let exactMatch =
                !query.isEmpty &&
                corpus.contains(query)

            let isRelevant: Bool
            if entry.kind != .userRule &&
               inlineSourceRewrite {
                isRelevant = false
            } else if entry.kind == .userRule {
                isRelevant =
                    tokenOverlap > 0 ||
                    exactMatch
            } else if transformation &&
                      referencesIdeas &&
                      hasDirectIdeaSource {
                let priorInput = normalize(
                    entry.userInput ?? ""
                )

                if isTransformationRequest(priorInput) {
                    isRelevant = false
                } else if isDirectIdeaSource(entry) {
                    isRelevant = true
                } else if continuation {
                    isRelevant =
                        tokenOverlap > 0 ||
                        exactMatch
                } else {
                    isRelevant =
                        tokenOverlap >= 2 ||
                        exactMatch
                }
            } else if explicitNewTopic {
                isRelevant = false
            } else if continuation {
                if strongestContextOverlap > 0 {
                    isRelevant =
                        tokenOverlap > 0 ||
                        exactMatch
                } else {
                    isRelevant = true
                }
            } else if strongestIdentityOverlap > 0 {
                isRelevant =
                    identityOverlap > 0 ||
                    exactMatch
            } else {
                isRelevant =
                    tokenOverlap >= 2 ||
                    exactMatch
            }

            guard isRelevant else {
                continue
            }

            score += tokenOverlap * 4
            score += identityOverlap * 6

            if entry.kind == .userRule,
               tokenOverlap > 0 {
                score += 3
            }

            if exactMatch {
                score += 8
            }

            if continuation,
               entry.kind != .userRule {
                score += max(
                    1,
                    12 - min(index, 10)
                )
            }

            if transformation,
               referencesIdeas,
               isDirectIdeaSource(entry) {
                score += 24
            }

            if score > 0 {
                scored.append(
                    (entry, score)
                )
            }
        }

        let rules = scored
            .filter { $0.entry.kind == .userRule }
            .sorted { $0.score > $1.score }
            .prefix(2)

        let contextual = scored
            .filter { $0.entry.kind != .userRule }
            .sorted {
                if $0.score == $1.score {
                    return $0.entry.createdAt >
                        $1.entry.createdAt
                }
                return $0.score > $1.score
            }
            .prefix(max(0, limit - rules.count))

        return (
            Array(rules) +
            Array(contextual)
        )
        .map { $0.entry }
    }

    private func isExplicitNewTopicIntroduction(
        _ text: String
    ) -> Bool {
        let normalized = normalize(text)

        return [
            "adında bir marka",
            "adinda bir marka",
            "adlı bir marka",
            "adli bir marka",
            "diye bir marka",
            "isminde bir marka",
            "adında bir şirket",
            "adinda bir sirket",
            "adlı bir şirket",
            "adli bir sirket",
            "diye bir şirket",
            "isminde bir şirket",
            "adında bir işletme",
            "adinda bir isletme",
            "adlı bir işletme",
            "adli bir isletme",
            "diye bir işletme",
            "isminde bir işletme"
        ]
        .contains {
            normalized.contains($0)
        }
    }

    private func isLegacyMisroutedRuleTask(
        _ entry: AgentContextMemoryEntry
    ) -> Bool {
        guard entry.kind != .userRule else {
            return false
        }

        let input = normalize(entry.userInput ?? "")
        let summary = normalize(entry.summary)

        let looksLikeWorkflowRule =
            input.contains("calisma bicimini") ||
            input.contains("çalışma biçimini") ||
            input.contains("calisma seklini") ||
            input.contains("çalışma şeklini")

        let containsScopeBoundary =
            input.contains("baska markalara") ||
            input.contains("başka markalara") ||
            input.contains("otomatik uygulama")

        let looksLikeFileSearchReply =
            summary.contains("eslesme buldum") ||
            summary.contains("eşleşme buldum") ||
            summary.contains("finder'da") ||
            summary.contains("finderda")

        return looksLikeWorkflowRule &&
            containsScopeBoundary &&
            looksLikeFileSearchReply
    }

    private func trimmed(
        _ entries: [AgentContextMemoryEntry]
    ) -> [AgentContextMemoryEntry] {
        let rules = entries
            .filter { $0.kind == .userRule }
            .prefix(30)

        let taskContext = entries
            .filter { $0.kind != .userRule }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(40)

        return Array(rules) + Array(taskContext)
    }

    private func shortTitle(
        from value: String
    ) -> String {
        let flattened = value
            .replacingOccurrences(
                of: "\n",
                with: " "
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if flattened.count <= 72 {
            return flattened
        }

        return String(flattened.prefix(69)) + "…"
    }

    private func compactSummary(
        _ value: String,
        maximumCharacters: Int
    ) -> String {
        let flattened = value
            .replacingOccurrences(
                of: "\n\n",
                with: " "
            )
            .replacingOccurrences(
                of: "\n",
                with: " "
            )
            .split(
                whereSeparator: { $0.isWhitespace }
            )
            .joined(separator: " ")

        guard flattened.count > maximumCharacters else {
            return flattened
        }

        return String(
            flattened.prefix(maximumCharacters - 1)
        ) + "…"
    }

    private func isLowValueFallback(
        _ value: String
    ) -> Bool {
        let normalized = normalize(value)

        return normalized.contains(
            "hedefi analiz ettim fakat mevcut yerel araclardan biriyle guvenilir bicimde eslestiremedim"
        ) ||
        normalized.contains(
            "su an en guvenli planim"
        )
    }

    private func isInlineSourceRewriteRequest(
        _ value: String
    ) -> Bool {
        let normalized = normalize(value)

        let asksRewrite = [
            "yeniden yaz",
            "tekrar yaz",
            "duzgun turkceyle",
            "düzgün türkçeyle",
            "metni duzelt",
            "metni düzelt",
            "proofread",
            "rewrite"
        ]
        .contains {
            normalized.contains($0)
        }

        let hasInlineSource =
            value.contains("“") ||
            value.contains("”") ||
            value.contains("\"") ||
            value.contains(": “") ||
            value.contains(": \"")

        return asksRewrite && hasInlineSource
    }

    private func isTransformationRequest(
        _ value: String
    ) -> Bool {
        let normalized = normalize(value)

        return [
            "cevir", "çevir",
            "donustur", "dönüştür",
            "uyarla",
            "senaryoya", "senaryosuna",
            "cekim plani", "çekim planı"
        ]
        .contains {
            normalized.contains($0)
        }
    }

    private func isDirectIdeaSource(
        _ entry: AgentContextMemoryEntry
    ) -> Bool {
        guard entry.kind != .userRule else {
            return false
        }

        let input = normalize(
            entry.userInput ?? ""
        )

        guard !isTransformationRequest(input) else {
            return false
        }

        return input.contains("fikir") ||
            input.contains("reels")
    }

    private func containsContinuationReference(
        _ value: String
    ) -> Bool {
        [
            "az once", "az önce",
            "onceki", "önceki",
            "bu hesap", "bu marka", "bu sirket", "bu şirket",
            "bu konu", "bu analiz", "bu rapor",
            "bunlardan", "bunlari", "bunları",
            "buna gore", "buna göre",
            "devam et", "devam edelim",
            "geri dön", "geri don", "dönelim", "donelim",
            "soylediklerinden", "söylediklerinden"
        ]
        .contains {
            value.contains($0)
        }
    }

    private func tokens(
        _ value: String
    ) -> [String] {
        let stopWords = Set([
            "icin", "için", "ile", "ve", "veya", "ama",
            "bunu", "bana", "bir", "bu", "su", "şu",
            "olarak", "olan", "nasil", "nasıl", "ne",
            "mi", "mı", "mu", "mü", "de", "da",
            "the", "for", "with", "from", "this", "that"
        ])

        return value
            .components(
                separatedBy: CharacterSet.alphanumerics.inverted
            )
            .filter {
                $0.count >= 3 &&
                !stopWords.contains($0)
            }
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
                locale: Locale(identifier: "tr_TR")
            )
            .lowercased()
            .replacingOccurrences(of: "ı", with: "i")
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }
}
