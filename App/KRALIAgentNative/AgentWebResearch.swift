import Foundation

struct WebResearchResult: Identifiable, Hashable {
    var id: String { url.absoluteString }

    let title: String
    let url: URL
    let domain: String
    let snippet: String?
    let evidenceEligible: Bool

    init(
        title: String,
        url: URL,
        domain: String,
        snippet: String?,
        evidenceEligible: Bool = true
    ) {
        self.title = title
        self.url = url
        self.domain = domain
        self.snippet = snippet
        self.evidenceEligible = evidenceEligible
    }
}

struct WebResearchReport: Hashable {
    let query: String
    let provider: String
    let results: [WebResearchResult]
    let fetchedAt: Date
}

enum WebResearchError: LocalizedError {
    case invalidQuery
    case invalidResponse
    case noResults
    case allProvidersFailed(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Araştırma sorgusu boş veya geçersiz."
        case .invalidResponse:
            return "Arama sağlayıcısından geçerli bir yanıt alınamadı."
        case .noResults:
            return "Web araştırması yeterince alakalı sonuç üretmedi."
        case .allProvidersFailed(let message):
            return "Tüm web araştırma sağlayıcıları başarısız oldu: \(message)"
        case .transport(let message):
            return "Web araştırması sırasında bağlantı hatası: \(message)"
        }
    }
}

actor AgentWebResearchService {
    private enum Provider: CaseIterable {
        case bingRSS
        case google
        case bingHTML
        case duckDuckGo

        var name: String {
            switch self {
            case .bingRSS: return "Bing RSS"
            case .google: return "Google HTML"
            case .bingHTML: return "Bing HTML"
            case .duckDuckGo: return "DuckDuckGo HTML"
            }
        }
    }

    private struct ScoredResult {
        let result: WebResearchResult
        let score: Int
        let conceptCoverage: Int
        let sourceKind: AgentResearchSourceKind?
        let origin: String
    }

    private let session: URLSession
    private let queryPlanner = AgentResearchQueryPlanner()
    private let developmentSourceClassifier =
        AgentDevelopmentResearchSourceClassifier()

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            "Accept": "text/html,application/xhtml+xml,application/rss+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "tr-TR,tr;q=0.9,en;q=0.8"
        ]
        session = URLSession(configuration: configuration)
    }

    func search(
        _ rawQuery: String,
        limit: Int = 5,
        developmentFacet:
            AgentDevelopmentResearchFacet? = nil
    ) async throws -> WebResearchReport {
        let query = rawQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            throw WebResearchError.invalidQuery
        }

        let safeLimit = max(2, min(limit, 8))
        let queryPlan = queryPlanner.plan(query)
        let variants = queryPlan.variants
        let requiredCoverage =
            developmentFacet == nil
            ? (
                queryPlan.isEntityResearch
                ? 1
                : min(
                    2,
                    max(1, queryPlan.conceptGroups.count)
                )
            )
            : 1

        let minimumVariantsToSearch = queryPlan.isEntityResearch
            ? min(4, variants.count)
            : 1

        var failures: [String] = []
        var providerNames: [String] = []
        var candidates: [ScoredResult] = []
        var seenURLs = Set<String>()

        for direct in queryPlan.directCandidates {
            let result = WebResearchResult(
                title: direct.title,
                url: direct.url,
                domain: direct.domain,
                snippet: nil,
                evidenceEligible: false
            )

            let evaluation = relevanceEvaluation(
                result,
                conceptGroups: queryPlan.conceptGroups,
                mandatoryConceptGroups: queryPlan.mandatoryConceptGroups,
                preferredDomains: queryPlan.preferredDomains,
                entityTerms: queryPlan.entityTerms,
                developmentFacet:
                    developmentFacet
            )

            if evaluation.mandatorySatisfied {
                let key = canonicalURLKey(result.url)
                if !seenURLs.contains(key) {
                    seenURLs.insert(key)
                    candidates.append(
                        ScoredResult(
                            result: result,
                            score: max(6, evaluation.score),
                            conceptCoverage: max(1, evaluation.coverage),
                            sourceKind: developmentFacet.map {
                                developmentSourceClassifier
                                    .assess(result, facet: $0)
                                    .kind
                            },
                            origin: researchOrigin(for: result.domain)
                        )
                    )
                }
            }
        }

        if !queryPlan.directCandidates.isEmpty {
            providerNames.append("Direct Resolver")
        }

        for (variantIndex, variant) in variants.enumerated() {
            for provider in Provider.allCases {
                do {
                    let payload = try await fetch(
                        provider: provider,
                        query: variant
                    )

                    let parsed = parseResults(
                        provider: provider,
                        payload: payload,
                        conceptGroups: queryPlan.conceptGroups,
                        mandatoryConceptGroups: queryPlan.mandatoryConceptGroups,
                        preferredDomains: queryPlan.preferredDomains,
                        entityTerms: queryPlan.entityTerms,
                        developmentFacet:
                            developmentFacet,
                        limit: safeLimit * 2
                    )

                    if !parsed.isEmpty && !providerNames.contains(provider.name) {
                        providerNames.append(provider.name)
                    }

                    for item in parsed {
                        let key = canonicalURLKey(item.result.url)
                        guard !seenURLs.contains(key) else {
                            continue
                        }

                        seenURLs.insert(key)
                        candidates.append(item)
                    }

                    candidates.sort { left, right in
                        if left.score == right.score {
                            return left.result.title.count >
                                right.result.title.count
                        }
                        return left.score > right.score
                    }

                    if candidates.filter({ $0.conceptCoverage >= requiredCoverage }).count >= safeLimit {
                        break
                    }
                } catch {
                    failures.append(
                        provider.name + ": " + error.localizedDescription
                    )
                }
            }

            let searchedEnoughVariants =
                variantIndex + 1 >= minimumVariantsToSearch

            if searchedEnoughVariants &&
               candidates.filter({
                   $0.conceptCoverage >= requiredCoverage
               }).count >= safeLimit {
                break
            }
        }

        let relevantCandidates = candidates.filter {
            $0.conceptCoverage >= requiredCoverage
        }

        let relevant = selectDiverseResults(
            relevantCandidates,
            limit: safeLimit,
            preferredSourceKinds:
                developmentFacet?.preferredSourceKinds ?? []
        )

        guard !relevant.isEmpty else {
            if failures.count == Provider.allCases.count * variants.count {
                throw WebResearchError.allProvidersFailed(
                    failures.joined(separator: " • ")
                )
            }

            throw WebResearchError.noResults
        }

        return WebResearchReport(
            query: query,
            provider: providerNames.isEmpty
                ? "Web bootstrap"
                : providerNames.joined(separator: " + "),
            results: relevant,
            fetchedAt: Date()
        )
    }

    private func fetch(
        provider: Provider,
        query: String
    ) async throws -> String {
        guard let url = searchURL(
            provider: provider,
            query: query
        ) else {
            throw WebResearchError.invalidQuery
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let (data, response) = try await session.data(
                for: request
            )

            guard
                let http = response as? HTTPURLResponse,
                (200..<400).contains(http.statusCode)
            else {
                throw WebResearchError.invalidResponse
            }

            if let text = String(data: data, encoding: .utf8) {
                return text
            }

            if let text = String(
                data: data,
                encoding: .isoLatin1
            ) {
                return text
            }

            throw WebResearchError.invalidResponse
        } catch let error as WebResearchError {
            throw error
        } catch {
            throw WebResearchError.transport(
                error.localizedDescription
            )
        }
    }

    private func searchURL(
        provider: Provider,
        query: String
    ) -> URL? {
        switch provider {
        case .bingRSS:
            var components = URLComponents(
                string: "https://www.bing.com/search"
            )
            components?.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "format", value: "rss"),
                URLQueryItem(name: "setlang", value: "tr")
            ]
            return components?.url

        case .google:
            var components = URLComponents(
                string: "https://www.google.com/search"
            )
            components?.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "num", value: "10"),
                URLQueryItem(name: "hl", value: "tr"),
                URLQueryItem(name: "filter", value: "0")
            ]
            return components?.url

        case .bingHTML:
            var components = URLComponents(
                string: "https://www.bing.com/search"
            )
            components?.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "count", value: "10"),
                URLQueryItem(name: "setlang", value: "tr")
            ]
            return components?.url

        case .duckDuckGo:
            var components = URLComponents(
                string: "https://duckduckgo.com/html/"
            )
            components?.queryItems = [
                URLQueryItem(name: "q", value: query)
            ]
            return components?.url
        }
    }

    private func parseResults(
        provider: Provider,
        payload: String,
        conceptGroups: [[String]],
        mandatoryConceptGroups: [[String]],
        preferredDomains: [String],
        entityTerms: [String],
        developmentFacet:
            AgentDevelopmentResearchFacet?,
        limit: Int
    ) -> [ScoredResult] {
        let raw: [WebResearchResult]

        switch provider {
        case .bingRSS:
            raw = parseBingRSS(
                payload,
                limit: limit
            )

        case .google:
            raw = parseHTML(
                payload,
                patterns: [
                    (
                        #"<a[^>]+href=["']/url\?q=([^&"']+)[^"']*["'][^>]*>.*?<h3[^>]*>(.*?)</h3>"#,
                        1,
                        2
                    ),
                    (
                        #"<a[^>]+href=["'](https?://[^"']+)["'][^>]*>.*?<h3[^>]*>(.*?)</h3>"#,
                        1,
                        2
                    )
                ],
                limit: limit
            )

        case .bingHTML:
            raw = parseHTML(
                payload,
                patterns: [
                    (
                        #"<li[^>]+class=["'][^"']*b_algo[^"']*["'][^>]*>.*?<h2[^>]*>.*?<a[^>]+href=["'](https?://[^"']+)["'][^>]*>(.*?)</a>"#,
                        1,
                        2
                    )
                ],
                limit: limit
            )

        case .duckDuckGo:
            raw = parseHTML(
                payload,
                patterns: [
                    (
                        #"<a[^>]*class=["'][^"']*result__a[^"']*["'][^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#,
                        1,
                        2
                    )
                ],
                limit: limit
            )
        }

        return raw.compactMap { result in
            guard !isJunkResult(result) else {
                return nil
            }

            let evaluation = relevanceEvaluation(
                result,
                conceptGroups: conceptGroups,
                mandatoryConceptGroups: mandatoryConceptGroups,
                preferredDomains: preferredDomains,
                entityTerms: entityTerms,
                developmentFacet:
                    developmentFacet
            )

            guard evaluation.mandatorySatisfied else {
                return nil
            }

            return ScoredResult(
                result: result,
                score: evaluation.score,
                conceptCoverage: evaluation.coverage,
                sourceKind: developmentFacet.map {
                    developmentSourceClassifier
                        .assess(result, facet: $0)
                        .kind
                },
                origin: researchOrigin(for: result.domain)
            )
        }
    }

    private func parseBingRSS(
        _ xml: String,
        limit: Int
    ) -> [WebResearchResult] {
        let itemPattern = #"<item>(.*?)</item>"#
        let items = regexMatches(
            pattern: itemPattern,
            in: xml
        )

        var results: [WebResearchResult] = []

        for item in items {
            guard
                results.count < limit,
                let itemRange = Range(
                    item.range(at: 1),
                    in: xml
                )
            else {
                continue
            }

            let block = String(xml[itemRange])

            guard
                let title = firstTagValue(
                    "title",
                    in: block
                ),
                let link = firstTagValue(
                    "link",
                    in: block
                ),
                let url = URL(
                    string: decodeHTMLEntities(link)
                ),
                isUsefulExternalURL(url)
            else {
                continue
            }

            let description = firstTagValue(
                "description",
                in: block
            )

            results.append(
                WebResearchResult(
                    title: cleanHTML(title),
                    url: url,
                    domain: url.host ?? "web",
                    snippet: description.map(cleanHTML)
                )
            )
        }

        return results
    }

    private func firstTagValue(
        _ tag: String,
        in text: String
    ) -> String? {
        let pattern =
            "<" + tag + "[^>]*>(.*?)</" + tag + ">"

        guard
            let match = regexMatches(
                pattern: pattern,
                in: text
            ).first,
            let range = Range(
                match.range(at: 1),
                in: text
            )
        else {
            return nil
        }

        return String(text[range])
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
    }

    private func parseHTML(
        _ html: String,
        patterns: [(String, Int, Int)],
        limit: Int
    ) -> [WebResearchResult] {
        var results: [WebResearchResult] = []
        var seen = Set<String>()

        for pattern in patterns {
            let matches = regexMatches(
                pattern: pattern.0,
                in: html
            )

            for match in matches {
                guard
                    results.count < limit,
                    match.numberOfRanges > max(
                        pattern.1,
                        pattern.2
                    ),
                    let hrefRange = Range(
                        match.range(at: pattern.1),
                        in: html
                    ),
                    let titleRange = Range(
                        match.range(at: pattern.2),
                        in: html
                    )
                else {
                    continue
                }

                let rawHref = String(html[hrefRange])
                let rawTitle = String(html[titleRange])

                guard
                    let resolvedURL = resolvedResultURL(
                        from: rawHref
                    ),
                    isUsefulExternalURL(resolvedURL)
                else {
                    continue
                }

                let title = cleanHTML(rawTitle)
                guard title.count >= 4 else { continue }

                let key = canonicalURLKey(resolvedURL)
                guard !seen.contains(key) else { continue }
                seen.insert(key)

                results.append(
                    WebResearchResult(
                        title: title,
                        url: resolvedURL,
                        domain: resolvedURL.host ?? "web",
                        snippet: nil
                    )
                )
            }
        }

        return results
    }

    private func relevanceEvaluation(
        _ result: WebResearchResult,
        conceptGroups: [[String]],
        mandatoryConceptGroups: [[String]],
        preferredDomains: [String],
        entityTerms: [String],
        developmentFacet:
            AgentDevelopmentResearchFacet? = nil
    ) -> (score: Int, coverage: Int, mandatorySatisfied: Bool) {
        let title = normalize(result.title)
        let domain = normalize(result.domain)
        let snippet = normalize(result.snippet ?? "")
        let combined = title + " " + snippet + " " + domain

        var score = 0
        var coverage = 0

        let mandatorySatisfied = mandatoryConceptGroups.allSatisfy { group in
            group
                .map(normalize)
                .contains {
                    !$0.isEmpty && combined.contains($0)
                }
        }

        let entitySatisfied =
            entityTerms.isEmpty ||
            entityTerms
                .map(normalize)
                .contains {
                    !$0.isEmpty && combined.contains($0)
                }

        guard mandatorySatisfied && entitySatisfied else {
            return (0, 0, false)
        }

        for group in conceptGroups {
            let normalizedAliases = group.map(normalize)
            let matched = normalizedAliases.contains {
                !$0.isEmpty && combined.contains($0)
            }

            if matched {
                coverage += 1

                if normalizedAliases.contains(
                    where: { !$0.isEmpty && title.contains($0) }
                ) {
                    score += 4
                } else if normalizedAliases.contains(
                    where: { !$0.isEmpty && snippet.contains($0) }
                ) {
                    score += 2
                } else {
                    score += 1
                }
            }
        }

        if preferredDomains.contains(
            where: { domain.hasSuffix(normalize($0)) }
        ) {
            score += 5
        }

        let trustedTechnicalHosts = [
            "developer.apple.com",
            "developer.adobe.com",
            "learn.microsoft.com",
            "developer.mozilla.org",
            "github.com",
            "docs.github.com"
        ]

        if trustedTechnicalHosts.contains(
            where: { domain.hasSuffix(normalize($0)) }
        ) {
            score += 2
        }

        if title.count >= 20 {
            score += 1
        }

        if let developmentFacet {
            let quality =
                developmentSourceClassifier
                    .assess(
                        result,
                        facet:
                            developmentFacet
                    )

            if quality
                .qualifiesForTechnicalCoverage {
                score += 12
            }

            switch quality.tier {
            case .a:
                score += 10
            case .b:
                score += 6
            case .c:
                score += 1
            case .d:
                score -= 18
            }
        }

        return (score, coverage, mandatorySatisfied)
    }

    private func selectDiverseResults(
        _ candidates: [ScoredResult],
        limit: Int,
        preferredSourceKinds: [AgentResearchSourceKind]
    ) -> [WebResearchResult] {
        var selected: [WebResearchResult] = []
        var remaining = candidates
        var originCounts: [String: Int] = [:]
        var selectedKinds = Set<AgentResearchSourceKind>()
        let preferredKinds = Set(preferredSourceKinds)

        for maximumPerOrigin in [1, 2] {
            while selected.count < limit {
                let eligible = remaining.filter {
                    originCounts[$0.origin, default: 0] < maximumPerOrigin
                }

                guard let next = eligible.max(by: { left, right in
                    diversityRank(
                        left,
                        selectedKinds: selectedKinds,
                        preferredKinds: preferredKinds
                    ) < diversityRank(
                        right,
                        selectedKinds: selectedKinds,
                        preferredKinds: preferredKinds
                    )
                }) else {
                    break
                }

                selected.append(next.result)
                originCounts[next.origin, default: 0] += 1
                if let kind = next.sourceKind {
                    selectedKinds.insert(kind)
                }
                remaining.removeAll { $0.result.id == next.result.id }
            }
        }

        return selected
    }

    private func diversityRank(
        _ candidate: ScoredResult,
        selectedKinds: Set<AgentResearchSourceKind>,
        preferredKinds: Set<AgentResearchSourceKind>
    ) -> Int {
        var rank = candidate.score * 10
        if let kind = candidate.sourceKind,
           preferredKinds.contains(kind) {
            rank += 30
            if !selectedKinds.contains(kind) {
                rank += 80
            }
        }
        return rank
    }

    private func researchOrigin(for domain: String) -> String {
        let parts = normalize(domain)
            .split(separator: ".")
            .map(String.init)

        guard parts.count >= 2 else {
            return normalize(domain)
        }

        return parts.suffix(2).joined(separator: ".")
    }

    private func isJunkResult(
        _ result: WebResearchResult
    ) -> Bool {
        let title = normalize(result.title)
        let domain = normalize(result.domain)

        let junkTitles = [
            "geri bildirim",
            "feedback",
            "privacy",
            "gizlilik",
            "oturum ac",
            "sign in",
            "yardim",
            "help",
            "cache",
            "translate"
        ]

        if junkTitles.contains(
            where: { title == $0 || title.hasPrefix($0 + " ") }
        ) {
            return true
        }

        let junkDomainTitlePairs = [
            ("support.google.com", "geri bildirim"),
            ("support.google.com", "feedback"),
            ("accounts.google.com", "")
        ]

        return junkDomainTitlePairs.contains { pair in
            domain.hasSuffix(pair.0) &&
            (pair.1.isEmpty || title.contains(pair.1))
        }
    }

    private func regexMatches(
        pattern: String,
        in text: String
    ) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [
                .caseInsensitive,
                .dotMatchesLineSeparators
            ]
        ) else {
            return []
        }

        return regex.matches(
            in: text,
            options: [],
            range: NSRange(
                text.startIndex..<text.endIndex,
                in: text
            )
        )
    }

    private func resolvedResultURL(
        from rawHref: String
    ) -> URL? {
        let decoded = decodeHTMLEntities(rawHref)

        if decoded.hasPrefix("http://") ||
           decoded.hasPrefix("https://") {
            if let url = URL(string: decoded),
               url.host?.contains("duckduckgo.com") == true,
               let components = URLComponents(
                   url: url,
                   resolvingAgainstBaseURL: false
               ),
               let target = components.queryItems?
                   .first(where: { $0.name == "uddg" })?
                   .value,
               let targetURL = URL(
                   string: target.removingPercentEncoding ?? target
               ) {
                return targetURL
            }

            return URL(string: decoded)
        }

        if decoded.hasPrefix("/url?q=") {
            let value = String(
                decoded.dropFirst("/url?q=".count)
            )
            let target = value.split(
                separator: "&",
                maxSplits: 1
            ).first.map(String.init) ?? value

            return URL(
                string: target.removingPercentEncoding ?? target
            )
        }

        if decoded.hasPrefix("//") {
            return URL(string: "https:" + decoded)
        }

        return nil
    }

    private func isUsefulExternalURL(
        _ url: URL
    ) -> Bool {
        guard
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = url.host?.lowercased()
        else {
            return false
        }

        let blockedHosts = [
            "google.com",
            "www.google.com",
            "bing.com",
            "www.bing.com",
            "duckduckgo.com",
            "www.duckduckgo.com"
        ]

        return !blockedHosts.contains(host)
    }

    private func canonicalURLKey(
        _ url: URL
    ) -> String {
        var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )
        components?.fragment = nil

        if let items = components?.queryItems {
            components?.queryItems = items.filter { item in
                let name = item.name.lowercased()
                return !name.hasPrefix("utm_") &&
                    name != "gclid" &&
                    name != "fbclid"
            }
        }

        return components?.url?.absoluteString ??
            url.absoluteString
    }

    private func cleanHTML(
        _ value: String
    ) -> String {
        let withoutTags = value.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        return decodeHTMLEntities(withoutTags)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
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
