import Foundation

struct ResearchFacet: Hashable {
    let id: String
    let title: String
    let query: String
}

struct ResearchQueryPlan: Hashable {
    let original: String
    let variants: [String]
    let conceptGroups: [[String]]
    let mandatoryConceptGroups: [[String]]
    let preferredDomains: [String]
    let entityTerms: [String]
    let facets: [ResearchFacet]

    var isEntityResearch: Bool {
        !entityTerms.isEmpty
    }
}

struct AgentResearchQueryPlanner {
    func plan(_ rawQuery: String) -> ResearchQueryPlan {
        let query = rawQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalized = normalize(query)

        if let socialPlan = socialProfilePlan(
            original: query,
            normalized: normalized
        ) {
            return socialPlan
        }

        let entity = extractEntity(
            from: query,
            normalized: normalized
        )
        let isBrandResearch =
            entity != nil &&
            containsAny(normalized, [
                "marka", "sirket", "firma", "rakip",
                "tarihce", "urun", "pazar", "sektor",
                "guclu", "zayif", "firsat",
                "isletme", "salon", "merkez", "studio",
                "klinik", "restoran", "kafe", "cafe"
            ])

        if let entity, isBrandResearch {
            return brandPlan(
                original: query,
                entity: entity
            )
        }

        return generalPlan(
            original: query,
            normalized: normalized
        )
    }

    private func socialProfilePlan(
        original: String,
        normalized: String
    ) -> ResearchQueryPlan? {
        let platforms: [(name: String, domain: String)] = [
            ("instagram", "instagram.com"),
            ("tiktok", "tiktok.com"),
            ("linkedin", "linkedin.com"),
            ("youtube", "youtube.com")
        ]

        guard
            let platform = platforms.first(
                where: { normalized.contains($0.name) }
            ),
            let handle = extractSocialHandle(
                from: original,
                platform: platform.name
            )
        else {
            return nil
        }

        let normalizedHandle = normalize(handle)
            .replacingOccurrences(of: "@", with: "")

        guard normalizedHandle.count >= 2 else {
            return nil
        }

        let facets = [
            ResearchFacet(
                id: "profile",
                title: "Resmi profil",
                query: "site:\(platform.domain) \(normalizedHandle)"
            ),
            ResearchFacet(
                id: "audience",
                title: "Takipçi / kitle",
                query: "\"\(normalizedHandle)\" \(platform.name) followers takipçi"
            ),
            ResearchFacet(
                id: "content",
                title: "İçerik türleri",
                query: "\"\(normalizedHandle)\" \(platform.name) reels posts içerik paylaşım"
            )
        ]

        var variants = facets.map(\.query)
        variants.append(
            contentsOf: [
                original,
                "\"\(normalizedHandle)\" \(platform.name)",
                "site:\(platform.domain) \(normalizedHandle)"
            ]
        )

        var seen = Set<String>()
        variants = variants.filter {
            let key = normalize($0)
            guard !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }

        return ResearchQueryPlan(
            original: original,
            variants: variants,
            conceptGroups: [
                [normalizedHandle],
                [
                    platform.name, "profile", "profil",
                    "followers", "takipci", "reels",
                    "posts", "icerik", "paylasim"
                ]
            ],
            mandatoryConceptGroups: [
                [normalizedHandle]
            ],
            preferredDomains: [
                platform.domain
            ],
            entityTerms: [
                normalizedHandle
            ],
            facets: facets
        )
    }

    private func extractSocialHandle(
        from original: String,
        platform: String
    ) -> String? {
        let escapedPlatform = NSRegularExpression
            .escapedPattern(
                for: platform
            )

        let patterns = [
            #"(?i)(?:@)?([A-Z0-9._]{2,})\s+"# +
                escapedPlatform,
            escapedPlatform +
                #"(?i)\s+(?:hesab(?:ı|i|ının|inin)?\s+|profil(?:i)?\s+)?(?:@)?([A-Z0-9._]{2,})"#
        ]

        for pattern in patterns {
            guard
                let regex = try? NSRegularExpression(
                    pattern: pattern
                )
            else {
                continue
            }

            let range = NSRange(
                original.startIndex..<original.endIndex,
                in: original
            )

            guard
                let match = regex.firstMatch(
                    in: original,
                    range: range
                ),
                match.numberOfRanges > 1,
                let handleRange = Range(
                    match.range(at: 1),
                    in: original
                )
            else {
                continue
            }

            let handle = String(
                original[handleRange]
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if !handle.isEmpty {
                return handle
            }
        }

        return nil
    }

    private func brandPlan(
        original: String,
        entity: String
    ) -> ResearchQueryPlan {
        let normalizedEntity = normalize(entity)
        let entityAliases = entityAliasTerms(entity)

        let facets = [
            ResearchFacet(
                id: "official",
                title: "Resmi kaynak",
                query: "\(entity) resmi site şirket"
            ),
            ResearchFacet(
                id: "history",
                title: "Tarihçe",
                query: "\(entity) tarihçe kuruluş history"
            ),
            ResearchFacet(
                id: "products",
                title: "Ürün ve hizmetler",
                query: "\(entity) ürünler hizmetler products services"
            ),
            ResearchFacet(
                id: "market",
                title: "Pazar ve rakipler",
                query: "\(entity) rakipler sektör pazar competitors market"
            ),
            ResearchFacet(
                id: "recent",
                title: "Güncel gelişmeler",
                query: "\(entity) haber yatırım üretim güncel news"
            )
        ]

        var variants = facets.map(\.query)
        variants.append(
            contentsOf: [
                original,
                "\(entity) company overview",
                "\(entity) official"
            ]
        )

        var seen = Set<String>()
        variants = variants.filter {
            let key = normalize($0)
            guard !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }

        let entityGroup = entityAliases.isEmpty
            ? [normalizedEntity]
            : entityAliases

        return ResearchQueryPlan(
            original: original,
            variants: variants,
            conceptGroups: [
                entityGroup,
                [
                    "company", "sirket", "firma", "marka",
                    "group", "holding", "corporation",
                    "isletme", "salon", "merkez", "studio",
                    "klinik"
                ]
            ],
            mandatoryConceptGroups: [
                entityGroup
            ],
            preferredDomains: [],
            entityTerms: entityGroup,
            facets: facets
        )
    }

    private func generalPlan(
        original query: String,
        normalized: String
    ) -> ResearchQueryPlan {
        var conceptGroups: [[String]] = []
        var mandatoryConceptGroups: [[String]] = []
        var englishTerms: [String] = []
        var preferredDomains: [String] = []

        if containsAny(normalized, [
            "macos", "apple", "swift", "ios"
        ]) {
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
        variants = variants.filter {
            let key = normalize($0)
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
            ).sorted(),
            entityTerms: [],
            facets: []
        )
    }

    private func extractEntity(
        from original: String,
        normalized: String
    ) -> String? {
        let markers = [
            " markasını",
            " markasini",
            " markası",
            " markasi",
            " hakkında",
            " hakkinda",
            " şirketini",
            " sirketini",
            " şirketi",
            " sirketi",
            " firmasını",
            " firmasini",
            " firması",
            " firmasi",
            " adında",
            " adinda"
        ]

        for marker in markers {
            guard let range = normalized.range(
                of: marker
            ) else {
                continue
            }

            let prefixLength = normalized.distance(
                from: normalized.startIndex,
                to: range.lowerBound
            )

            let originalIndex = original.index(
                original.startIndex,
                offsetBy: min(
                    prefixLength,
                    original.count
                )
            )

            var candidate = String(
                original[..<originalIndex]
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let removablePrefixes = [
                "bana ",
                "şu ",
                "bu ",
                "daha önce hiç konuşmadığımız ",
                "daha once hic konusmadigimiz "
            ]

            for prefix in removablePrefixes {
                if normalize(candidate).hasPrefix(
                    normalize(prefix)
                ) {
                    candidate = String(
                        candidate.dropFirst(
                            min(
                                prefix.count,
                                candidate.count
                            )
                        )
                    )
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
            }

            if candidate.count >= 2 &&
               candidate.count <= 80 {
                return candidate
            }
        }

        return nil
    }

    private func entityAliasTerms(
        _ entity: String
    ) -> [String] {
        let normalized = normalize(entity)
        var terms = [normalized]

        let compact = normalized.replacingOccurrences(
            of: " ",
            with: ""
        )

        if compact != normalized {
            terms.append(compact)
        }

        let alphanumeric = normalized
            .components(
                separatedBy: CharacterSet.alphanumerics.inverted
            )
            .filter { !$0.isEmpty }

        if alphanumeric.count == 1,
           let only = alphanumeric.first,
           only.count >= 3 {
            terms.append(only)
        }

        var seen = Set<String>()
        return terms.filter {
            guard !$0.isEmpty else { return false }
            guard !seen.contains($0) else {
                return false
            }
            seen.insert($0)
            return true
        }
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
