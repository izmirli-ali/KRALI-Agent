import Foundation

struct WebResearchResult: Identifiable, Hashable {
    var id: String { url.absoluteString }

    let title: String
    let url: URL
    let domain: String
    let snippet: String?
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
            return "Web araştırması sonuç üretmedi."
        case .allProvidersFailed(let message):
            return "Tüm web araştırma sağlayıcıları başarısız oldu: \(message)"
        case .transport(let message):
            return "Web araştırması sırasında bağlantı hatası: \(message)"
        }
    }
}

actor AgentWebResearchService {
    private enum Provider: CaseIterable {
        case google
        case bing
        case duckDuckGo

        var name: String {
            switch self {
            case .google: return "Google HTML bootstrap"
            case .bing: return "Bing HTML fallback"
            case .duckDuckGo: return "DuckDuckGo HTML fallback"
            }
        }
    }

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "tr-TR,tr;q=0.9,en;q=0.8"
        ]
        session = URLSession(configuration: configuration)
    }

    func search(
        _ rawQuery: String,
        limit: Int = 5
    ) async throws -> WebResearchReport {
        let query = rawQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            throw WebResearchError.invalidQuery
        }

        let safeLimit = max(1, min(limit, 8))
        var failures: [String] = []

        for provider in Provider.allCases {
            do {
                let html = try await fetchHTML(
                    provider: provider,
                    query: query
                )

                let results = parseResults(
                    provider: provider,
                    html: html,
                    limit: safeLimit
                )

                if !results.isEmpty {
                    return WebResearchReport(
                        query: query,
                        provider: provider.name,
                        results: results,
                        fetchedAt: Date()
                    )
                }

                failures.append(
                    provider.name + ": sonuç ayrıştırılamadı"
                )
            } catch {
                failures.append(
                    provider.name + ": " + error.localizedDescription
                )
            }
        }

        throw WebResearchError.allProvidersFailed(
            failures.joined(separator: " • ")
        )
    }

    private func fetchHTML(
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

            if let html = String(data: data, encoding: .utf8) {
                return html
            }

            if let html = String(
                data: data,
                encoding: .isoLatin1
            ) {
                return html
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

        case .bing:
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
        html: String,
        limit: Int
    ) -> [WebResearchResult] {
        let patterns: [(String, Int, Int)]

        switch provider {
        case .google:
            patterns = [
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
            ]

        case .bing:
            patterns = [
                (
                    #"<li[^>]+class=["'][^"']*b_algo[^"']*["'][^>]*>.*?<h2[^>]*>.*?<a[^>]+href=["'](https?://[^"']+)["'][^>]*>(.*?)</a>"#,
                    1,
                    2
                )
            ]

        case .duckDuckGo:
            patterns = [
                (
                    #"<a[^>]*class=["'][^"']*result__a[^"']*["'][^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#,
                    1,
                    2
                )
            ]
        }

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
                guard title.count >= 3 else { continue }

                let key = resolvedURL.absoluteString
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

            if results.count >= limit {
                break
            }
        }

        if results.isEmpty {
            results = genericAnchorFallback(
                html: html,
                limit: limit
            )
        }

        return Array(results.prefix(limit))
    }

    private func regexMatches(
        pattern: String,
        in html: String
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
            in: html,
            options: [],
            range: NSRange(
                html.startIndex..<html.endIndex,
                in: html
            )
        )
    }

    private func genericAnchorFallback(
        html: String,
        limit: Int
    ) -> [WebResearchResult] {
        let pattern = #"<a[^>]+href=["'](https?://[^"']+)["'][^>]*>(.*?)</a>"#
        let matches = regexMatches(
            pattern: pattern,
            in: html
        )

        var results: [WebResearchResult] = []
        var seen = Set<String>()

        for match in matches {
            guard
                results.count < limit,
                let hrefRange = Range(
                    match.range(at: 1),
                    in: html
                ),
                let titleRange = Range(
                    match.range(at: 2),
                    in: html
                )
            else {
                continue
            }

            let href = String(html[hrefRange])
            let title = cleanHTML(
                String(html[titleRange])
            )

            guard
                title.count >= 8,
                let url = URL(string: decodeHTMLEntities(href)),
                isUsefulExternalURL(url)
            else {
                continue
            }

            let key = url.absoluteString
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            results.append(
                WebResearchResult(
                    title: title,
                    url: url,
                    domain: url.host ?? "web",
                    snippet: nil
                )
            )
        }

        return results
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
