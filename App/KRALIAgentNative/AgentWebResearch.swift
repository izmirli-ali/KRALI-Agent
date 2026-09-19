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
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Araştırma sorgusu boş veya geçersiz."
        case .invalidResponse:
            return "Arama sağlayıcısından geçerli bir yanıt alınamadı."
        case .noResults:
            return "Web araştırması sonuç üretmedi."
        case .transport(let message):
            return "Web araştırması sırasında bağlantı hatası: \(message)"
        }
    }
}

actor AgentWebResearchService {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"
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

        var components = URLComponents(
            string: "https://html.duckduckgo.com/html/"
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]

        guard let url = components?.url else {
            throw WebResearchError.invalidQuery
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard
                let http = response as? HTTPURLResponse,
                (200..<400).contains(http.statusCode),
                let html = String(
                    data: data,
                    encoding: .utf8
                )
            else {
                throw WebResearchError.invalidResponse
            }

            let results = parseResults(
                from: html,
                limit: max(1, min(limit, 8))
            )

            guard !results.isEmpty else {
                throw WebResearchError.noResults
            }

            return WebResearchReport(
                query: query,
                provider: "DuckDuckGo HTML bootstrap",
                results: results,
                fetchedAt: Date()
            )
        } catch let error as WebResearchError {
            throw error
        } catch {
            throw WebResearchError.transport(
                error.localizedDescription
            )
        }
    }

    private func parseResults(
        from html: String,
        limit: Int
    ) -> [WebResearchResult] {
        let pattern = #"<a[^>]*class=["'][^"']*result__a[^"']*["'][^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsRange = NSRange(
            html.startIndex..<html.endIndex,
            in: html
        )

        let matches = regex.matches(
            in: html,
            options: [],
            range: nsRange
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

            let rawHref = String(html[hrefRange])
            let rawTitle = String(html[titleRange])

            guard
                let resolvedURL = resolvedResultURL(
                    from: rawHref
                ),
                ["http", "https"].contains(
                    resolvedURL.scheme?.lowercased() ?? ""
                )
            else {
                continue
            }

            let key = resolvedURL.absoluteString
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let title = cleanHTML(rawTitle)
            guard !title.isEmpty else { continue }

            results.append(
                WebResearchResult(
                    title: title,
                    url: resolvedURL,
                    domain: resolvedURL.host ?? "web",
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

        let normalized: String
        if decoded.hasPrefix("//") {
            normalized = "https:" + decoded
        } else {
            normalized = decoded
        }

        guard let url = URL(string: normalized) else {
            return nil
        }

        if url.host?.contains("duckduckgo.com") == true,
           let components = URLComponents(
               url: url,
               resolvingAgainstBaseURL: false
           ),
           let encodedTarget = components.queryItems?
               .first(where: { $0.name == "uddg" })?
               .value,
           let target = encodedTarget.removingPercentEncoding,
           let targetURL = URL(string: target) {
            return targetURL
        }

        return url
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
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
