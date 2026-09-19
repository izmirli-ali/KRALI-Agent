import Foundation

struct WebSourceEvidence: Identifiable, Hashable {
    var id: String { source.url.absoluteString }

    let source: WebResearchResult
    let excerpt: String
    let conceptCoverage: Int
    let matchedConcepts: [String]
    let fetchedAt: Date
}

actor AgentWebSourceReader {
    private let session: URLSession
    private let queryPlanner = AgentResearchQueryPlanner()

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "tr-TR,tr;q=0.9,en;q=0.8"
        ]
        session = URLSession(configuration: configuration)
    }

    func read(
        _ sources: [WebResearchResult],
        query: String,
        limit: Int = 4
    ) async -> [WebSourceEvidence] {
        let plan = queryPlanner.plan(query)
        let requiredCoverage = min(
            2,
            max(1, plan.conceptGroups.count)
        )

        var evidence: [WebSourceEvidence] = []
        var seenDomains: [String: Int] = [:]

        let prioritized = sources.sorted { left, right in
            let leftPreferred = isPreferred(
                left.domain,
                preferredDomains: plan.preferredDomains
            )
            let rightPreferred = isPreferred(
                right.domain,
                preferredDomains: plan.preferredDomains
            )

            if leftPreferred != rightPreferred {
                return leftPreferred && !rightPreferred
            }

            return left.title.count > right.title.count
        }

        for source in prioritized {
            guard evidence.count < max(1, min(limit, 6)) else {
                break
            }

            let domainCount = seenDomains[source.domain, default: 0]
            if domainCount >= 2 &&
               !isPreferred(
                   source.domain,
                   preferredDomains: plan.preferredDomains
               ) {
                continue
            }

            if let item = await readSource(
                source,
                plan: plan,
                requiredCoverage: requiredCoverage
            ) {
                evidence.append(item)
                seenDomains[source.domain, default: 0] += 1
            }
        }

        return evidence.sorted { left, right in
            if left.conceptCoverage == right.conceptCoverage {
                return left.excerpt.count > right.excerpt.count
            }
            return left.conceptCoverage > right.conceptCoverage
        }
    }

    private func readSource(
        _ source: WebResearchResult,
        plan: ResearchQueryPlan,
        requiredCoverage: Int
    ) async -> WebSourceEvidence? {
        let pageText: String?

        do {
            var request = URLRequest(url: source.url)
            request.httpMethod = "GET"

            let (data, response) = try await session.data(
                for: request
            )

            guard
                let http = response as? HTTPURLResponse,
                (200..<400).contains(http.statusCode)
            else {
                return fallbackEvidence(
                    source,
                    plan: plan,
                    requiredCoverage: requiredCoverage
                )
            }

            if let html = String(data: data, encoding: .utf8) {
                pageText = readableText(from: html)
            } else if let html = String(
                data: data,
                encoding: .isoLatin1
            ) {
                pageText = readableText(from: html)
            } else {
                pageText = nil
            }
        } catch {
            pageText = nil
        }

        let candidateText = [
            source.title,
            source.snippet ?? "",
            pageText ?? ""
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ". ")

        let selected = bestEvidence(
            in: candidateText,
            plan: plan
        )

        guard selected.coverage >= requiredCoverage else {
            return fallbackEvidence(
                source,
                plan: plan,
                requiredCoverage: requiredCoverage
            )
        }

        return WebSourceEvidence(
            source: source,
            excerpt: selected.excerpt,
            conceptCoverage: selected.coverage,
            matchedConcepts: selected.matches,
            fetchedAt: Date()
        )
    }

    private func fallbackEvidence(
        _ source: WebResearchResult,
        plan: ResearchQueryPlan,
        requiredCoverage: Int
    ) -> WebSourceEvidence? {
        let fallbackText = [
            source.title,
            source.snippet ?? ""
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ". ")

        let selected = bestEvidence(
            in: fallbackText,
            plan: plan
        )

        guard selected.coverage >= requiredCoverage else {
            return nil
        }

        return WebSourceEvidence(
            source: source,
            excerpt: selected.excerpt,
            conceptCoverage: selected.coverage,
            matchedConcepts: selected.matches,
            fetchedAt: Date()
        )
    }

    private func bestEvidence(
        in text: String,
        plan: ResearchQueryPlan
    ) -> (
        excerpt: String,
        coverage: Int,
        matches: [String]
    ) {
        let compact = text
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !compact.isEmpty else {
            return ("", 0, [])
        }

        let chunks = compact
            .components(
                separatedBy: CharacterSet(
                    charactersIn: ".!?\n"
                )
            )
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { $0.count >= 25 }

        var scored: [(
            text: String,
            score: Int,
            matches: [String]
        )] = []

        for chunk in chunks.prefix(250) {
            let normalized = normalize(chunk)
            var matches: [String] = []
            var score = 0

            for group in plan.conceptGroups {
                let alias = group.first {
                    normalized.contains(normalize($0))
                }

                if let alias {
                    matches.append(alias)
                    score += 3
                }
            }

            if plan.preferredDomains.contains(
                where: { normalized.contains(normalize($0)) }
            ) {
                score += 1
            }

            if chunk.count >= 60 && chunk.count <= 420 {
                score += 1
            }

            scored.append(
                (
                    text: chunk,
                    score: score,
                    matches: matches
                )
            )
        }

        let top = scored
            .sorted { left, right in
                if left.matches.count == right.matches.count {
                    return left.score > right.score
                }
                return left.matches.count > right.matches.count
            }
            .prefix(3)

        let excerpt = top
            .map(\.text)
            .joined(separator: ". ")

        let allMatches = top
            .flatMap(\.matches)

        var seen = Set<String>()
        let uniqueMatches = allMatches.filter {
            let key = normalize($0)
            guard !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }

        return (
            excerpt: String(excerpt.prefix(900)),
            coverage: uniqueMatches.count,
            matches: uniqueMatches
        )
    }

    private func readableText(
        from html: String
    ) -> String {
        var text = html

        let removePatterns = [
            #"(?is)<script[^>]*>.*?</script>"#,
            #"(?is)<style[^>]*>.*?</style>"#,
            #"(?is)<noscript[^>]*>.*?</noscript>"#,
            #"(?is)<svg[^>]*>.*?</svg>"#,
            #"(?is)<nav[^>]*>.*?</nav>"#,
            #"(?is)<footer[^>]*>.*?</footer>"#
        ]

        for pattern in removePatterns {
            text = text.replacingOccurrences(
                of: pattern,
                with: " ",
                options: .regularExpression
            )
        }

        text = text.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )

        return decodeHTMLEntities(text)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private func isPreferred(
        _ domain: String,
        preferredDomains: [String]
    ) -> Bool {
        let normalizedDomain = normalize(domain)
        return preferredDomains.contains {
            normalizedDomain.hasSuffix(normalize($0))
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
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private func decodeHTMLEntities(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
