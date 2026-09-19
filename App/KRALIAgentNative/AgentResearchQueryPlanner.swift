import Foundation

struct ResearchQueryPlan: Hashable {
    let original: String
    let variants: [String]
    let conceptGroups: [[String]]
    let mandatoryConceptGroups: [[String]]
    let preferredDomains: [String]
}

struct AgentResearchQueryPlanner {
    func plan(_ rawQuery: String) -> ResearchQueryPlan {
        let query = rawQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalized = normalize(query)

        var conceptGroups: [[String]] = []
        var mandatoryConceptGroups: [[String]] = []
        var englishTerms: [String] = []
        var preferredDomains: [String] = []

        if containsAny(normalized, ["macos", "apple", "swift", "ios"]) {
            let platformGroup = [
                "macos", "apple", "darwin", "swift"
            ]
            conceptGroups.append(platformGroup)
            mandatoryConceptGroups.append(platformGroup)
            englishTerms.append("macOS")
            preferredDomains.append("developer.apple.com")
        }

        if containsAny(normalized, [
            "video", "cek", "klip", "medya", "media"
        ]) {
            conceptGroups.append([
                "video", "media", "avfoundation", "avasset"
            ])
            englishTerms.append("video")
        }

        if containsAny(normalized, [
            "gorsel", "goruntu", "image", "foto", "vision"
        ]) {
            conceptGroups.append([
                "image", "vision", "visual", "photo", "camera"
            ])
            englishTerms.append("image")
        }

        if containsAny(normalized, [
            "analiz", "incele", "degerlendir", "analysis",
            "analyze", "recognition", "detect"
        ]) {
            let analysisGroup = [
                "analysis", "analyze", "vision",
                "recognition", "detect", "classification",
                "machine learning", "core ml"
            ]
            conceptGroups.append(analysisGroup)
            mandatoryConceptGroups.append(analysisGroup)
            englishTerms.append("analysis")
        }

        if containsAny(normalized, [
            "teknoloji", "framework", "sdk", "api",
            "kutuphane", "library"
        ]) {
            conceptGroups.append([
                "framework", "sdk", "api", "technology",
                "developer", "documentation"
            ])
            englishTerms.append("framework SDK API")
        }

        if containsAny(normalized, [
            "premiere", "adobe", "uxp", "cep"
        ]) {
            conceptGroups.append([
                "premiere", "adobe", "uxp", "cep"
            ])
            englishTerms.append("Adobe Premiere Pro UXP API")
            preferredDomains.append("developer.adobe.com")
        }

        if containsAny(normalized, [
            "web", "browser", "tarayici", "automation"
        ]) {
            conceptGroups.append([
                "browser", "web", "automation",
                "accessibility", "webdriver"
            ])
            englishTerms.append("browser automation")
        }

        if containsAny(normalized, [
            "mail", "gmail", "e-posta", "eposta"
        ]) {
            conceptGroups.append([
                "mail", "gmail", "email", "oauth", "imap"
            ])
            englishTerms.append("email API OAuth")
        }

        if containsAny(normalized, [
            "ses", "audio", "speech", "konusma"
        ]) {
            conceptGroups.append([
                "audio", "speech", "sound", "avfoundation"
            ])
            englishTerms.append("audio speech")
        }

        let lexicalTerms = lexicalConcepts(
            from: normalized
        )

        for term in lexicalTerms.prefix(4) {
            if !conceptGroups.contains(
                where: { $0.contains(term) }
            ) {
                conceptGroups.append([term])
            }
        }

        var variants = [query]

        if !englishTerms.isEmpty {
            variants.append(
                englishTerms.joined(separator: " ") +
                " official documentation"
            )
        }

        for domain in preferredDomains {
            let subject = englishTerms.isEmpty
                ? query
                : englishTerms.joined(separator: " ")

            variants.append(
                "site:\(domain) \(subject)"
            )
        }

        if normalized.contains("macos") &&
           conceptGroups.contains(where: {
               $0.contains("video")
           }) &&
           conceptGroups.contains(where: {
               $0.contains("analysis")
           }) {
            variants.append(
                "site:developer.apple.com Vision AVFoundation Core ML video analysis macOS"
            )
        }

        var seen = Set<String>()
        variants = variants.filter { value in
            let key = normalize(value)
            guard !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }

        return ResearchQueryPlan(
            original: query,
            variants: variants,
            conceptGroups: conceptGroups,
            mandatoryConceptGroups: mandatoryConceptGroups,
            preferredDomains: Array(
                Set(preferredDomains)
            ).sorted()
        )
    }

    private func lexicalConcepts(
        from normalized: String
    ) -> [String] {
        let stopWords = Set([
            "icin", "hangi", "nasil", "neden", "ile", "ve",
            "veya", "olarak", "uzerinde", "kullanabilecegini",
            "edebilmek", "etmek", "olan", "bir", "bu", "su",
            "web", "internet", "arastir", "ara", "bak",
            "the", "for", "with", "what", "which", "how",
            "can", "use", "using", "about", "official",
            "documentation"
        ])

        let parts = normalized
            .components(
                separatedBy: CharacterSet.alphanumerics.inverted
            )
            .filter { $0.count >= 4 }

        var seen = Set<String>()
        return parts.filter { term in
            guard !stopWords.contains(term) else {
                return false
            }
            guard !seen.contains(term) else {
                return false
            }
            seen.insert(term)
            return true
        }
    }

    private func containsAny(
        _ text: String,
        _ values: [String]
    ) -> Bool {
        values.contains { text.contains($0) }
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
}
