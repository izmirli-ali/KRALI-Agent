import Foundation

struct AgentNaturalLanguageResolver: Sendable {
    private let openVerbs = Set([
        "ac", "baslat", "calistir",
        "getir", "goster", "gir", "gec"
    ])

    private let commandNoise = Set([
        "uygulama", "uygulamayi", "uygulamasini",
        "uygulamasina", "uygulamaya",
        "pencere", "pencereyi",
        "ac", "baslat", "calistir",
        "one", "getir", "goster",
        "gec", "gir", "lutfen", "hemen",
        "bir", "su", "sunu", "bunu"
    ])

    private let deepInteractionWords = Set([
        "tikla", "bas", "buton", "menu",
        "alana", "yaz", "surukle", "sec",
        "isaretle", "klavye", "mouse"
    ])

    private let nonAppObjectWords = Set([
        "dosya", "pdf", "belge", "klasor",
        "indirilenler", "masaustu",
        "web", "site", "internet", "tarayici",
        "url", "sayfa"
    ])

    private let compoundTaskWords = Set([
        "incele", "analiz", "analizet",
        "oku", "ozetle", "degerlendir",
        "cevapla", "cevap", "taslak",
        "gonder", "arastir", "ara",
        "bul", "kaydet", "yaz", "ekle",
        "olustur", "donustur", "karsilastir",
        "icerik", "sozleri", "raporla"
    ])

    func normalized(_ raw: String) -> String {
        let folded = raw
            .folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive
                ],
                locale:
                    Locale(identifier: "tr_TR")
            )
            .lowercased()
            .replacingOccurrences(
                of: "ı",
                with: "i"
            )

        let scalars = folded.unicodeScalars.map {
            CharacterSet.alphanumerics
                .contains($0)
                ? Character($0)
                : " "
        }

        return String(scalars)
            .split(whereSeparator: {
                $0.isWhitespace
            })
            .joined(separator: " ")
    }

    func tokens(_ raw: String) -> [String] {
        normalized(raw)
            .split(separator: " ")
            .map(String.init)
    }

    func isSimpleOpenCommand(
        _ raw: String
    ) -> Bool {
        let words = tokens(raw)
        guard !words.isEmpty else {
            return false
        }

        let wordSet = Set(words)

        let hasOpenIntent =
            !wordSet.intersection(
                openVerbs
            ).isEmpty ||
            (
                wordSet.contains("one") &&
                wordSet.contains("getir")
            ) ||
            wordSet.contains("gec")

        guard hasOpenIntent else {
            return false
        }

        let normalizedRaw = normalized(raw)
        if normalizedRaw.contains("finder da") ||
           normalizedRaw.contains("finderda") {
            return false
        }

        guard
            wordSet.intersection(
                deepInteractionWords
            ).isEmpty,
            wordSet.intersection(
                nonAppObjectWords
            ).isEmpty,
            wordSet.intersection(
                compoundTaskWords
            ).isEmpty
        else {
            return false
        }

        return !targetTokens(raw).isEmpty
    }

    func applicationTargetPhrase(
        from raw: String
    ) -> String? {
        let clauses = raw
            .split(
                whereSeparator: {
                    ".!?;\n".contains($0)
                }
            )
            .map(String.init)

        for clause in clauses {
            let words = tokens(clause)

            guard !words.isEmpty else {
                continue
            }

            let endIndex: Int?
            if let appIndex =
                words.firstIndex(
                    where: {
                        $0 == "uygulama" ||
                        $0.hasPrefix("uygulama")
                    }
                ),
               appIndex > 0 {
                endIndex = appIndex
            } else if let openIndex =
                words.firstIndex(
                    where: {
                        openVerbs.contains($0)
                    }
                ),
                openIndex > 0 {
                endIndex = openIndex
            } else {
                endIndex = nil
            }

            guard let endIndex else {
                continue
            }

            let detachedCaseTokens = Set([
                "yi", "yi", "yu", "yu",
                "i", "i", "u", "u",
                "ni", "ni", "nu", "nu"
            ])

            let prefix =
                words[..<endIndex]
                    .filter {
                        !commandNoise.contains($0) &&
                        !openVerbs.contains($0) &&
                        !detachedCaseTokens.contains($0) &&
                        !nonAppObjectWords.contains($0)
                    }

            guard !prefix.isEmpty else {
                continue
            }

            let phrase =
                prefix.suffix(4)
                    .joined(separator: " ")

            if !phrase.isEmpty {
                return phrase
            }
        }

        return nil
    }

    func hasApplicationOpenIntent(
        _ raw: String
    ) -> Bool {
        guard
            applicationTargetPhrase(
                from: raw
            ) != nil
        else {
            return false
        }

        let firstClause =
            raw.split(
                whereSeparator: {
                    ".!?;\n".contains($0)
                }
            )
            .first
            .map(String.init) ?? raw

        let words = Set(
            tokens(firstClause)
        )

        return !words.intersection(
            openVerbs
        ).isEmpty ||
        (
            words.contains("one") &&
            words.contains("getir")
        )
    }

    func requestsBrowserWorkflow(
        _ raw: String
    ) -> Bool {
        let value = normalized(raw)

        if containsWebAddress(raw) {
            return true
        }

        let signals = [
            "adresine git",
            "adresine gir",
            "siteye git",
            "siteye gir",
            "sitesine git",
            "sitesine gir",
            "web sitesi",
            "web sitesine",
            "sayfaya git",
            "sayfayi ac",
            "sayfayi incele",
            "yeni sekme",
            "tarayicida",
            "tarayici"
        ]

        return signals.contains {
            value.contains($0)
        }
    }

    private func containsWebAddress(
        _ raw: String
    ) -> Bool {
        let pattern =
            #"(?i)\b(?:https?://)?(?:www\.)?[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)+(?:/[^\s]*)?"#

        guard let regex =
            try? NSRegularExpression(
                pattern: pattern
            )
        else {
            return false
        }

        let range = NSRange(
            raw.startIndex..<raw.endIndex,
            in: raw
        )

        return regex.firstMatch(
            in: raw,
            range: range
        ) != nil
    }

    func targetTokens(
        _ raw: String
    ) -> [String] {
        tokens(raw)
            .filter {
                !commandNoise.contains($0)
            }
            .flatMap { token in
                wordVariants(token)
            }
            .filter {
                $0.count >= 2
            }
            .uniqued()
    }

    func bestAliasScore(
        input raw: String,
        aliases: [String]
    ) -> Double {
        let normalizedInput =
            normalized(raw)
        let targets = targetTokens(raw)

        guard !targets.isEmpty else {
            return 0
        }

        let normalizedAliases =
            aliases
                .map(normalized)
                .filter {
                    !$0.isEmpty
                }
                .uniqued()

        for alias in normalizedAliases {
            if normalizedInput == alias {
                return 1.0
            }
        }

        var best =
            normalizedAliases
                .map {
                    similarity(
                        normalizedInput,
                        $0
                    )
                }
                .max() ?? 0

        let aliasVariants =
            normalizedAliases
                .flatMap {
                    [$0] +
                    $0.split(separator: " ")
                        .flatMap {
                            wordVariants(
                                String($0)
                            )
                        }
                }
                .filter {
                    !$0.isEmpty
                }
                .uniqued()

        let multiTokenInput =
            normalizedInput
                .split(separator: " ")
                .count > 1

        for target in targets {
            for alias in aliasVariants {
                if target == alias {
                    best = max(
                        best,
                        multiTokenInput
                            ? 0.88
                            : 1.0
                    )
                    continue
                }

                if target.count >= 4,
                   alias.count >= 4,
                   (
                    target.contains(alias) ||
                    alias.contains(target)
                   ) {
                    best = max(
                        best,
                        multiTokenInput
                            ? 0.86
                            : 0.94
                    )
                    continue
                }

                best = max(
                    best,
                    similarity(
                        target,
                        alias
                    )
                )
            }
        }

        return best
    }

    func isConfidentAliasMatch(
        score: Double,
        input raw: String
    ) -> Bool {
        let longest =
            targetTokens(raw)
                .map(\.count)
                .max() ?? 0

        if longest >= 7 {
            return score >= 0.78
        }

        if longest >= 5 {
            return score >= 0.82
        }

        return score >= 0.88
    }

    func affirmativeWorkflowText(
        _ raw: String
    ) -> String {
        var value = normalized(raw)

        let prohibitions = [
            "degistirmeden",
            "degistirme",
            "degisiklik yapma",
            "olusturma",
            "ekleme",
            "gonderme",
            "silme",
            "kaydetme",
            "oynatma",
            "tiklama"
        ]

        for prohibition in prohibitions {
            value = value.replacingOccurrences(
                of: prohibition,
                with: " "
            )
        }

        return value
    }

    func mergedAliases(
        _ groups: [[String]]
    ) -> [String] {
        var seen = Set<String>()

        return groups
            .flatMap { $0 }
            .filter {
                let value =
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                let key =
                    normalized(value)

                guard
                    !value.isEmpty,
                    !key.isEmpty,
                    seen.insert(key).inserted
                else {
                    return false
                }

                return true
            }
    }

    private func wordVariants(
        _ raw: String
    ) -> [String] {
        let word = normalized(raw)
            .replacingOccurrences(
                of: " ",
                with: ""
            )

        guard !word.isEmpty else {
            return []
        }

        var values = [word]

        let suffixes = [
            "sini", "sını", "sunu", "sünü",
            "yini", "yını", "yunu", "yünü",
            "ini", "ını", "unu", "ünü",
            "yi", "yı", "yu", "yü",
            "ni", "nı", "nu", "nü",
            "ya", "ye", "na", "ne",
            "a", "e",
            "i", "ı", "u", "ü"
        ]
        .map(normalized)

        for suffix in suffixes {
            guard
                word.count >= suffix.count + 4,
                word.hasSuffix(suffix)
            else {
                continue
            }

            values.append(
                String(
                    word.dropLast(
                        suffix.count
                    )
                )
            )
        }

        return values.uniqued()
    }

    private func similarity(
        _ lhs: String,
        _ rhs: String
    ) -> Double {
        guard
            !lhs.isEmpty,
            !rhs.isEmpty
        else {
            return 0
        }

        if lhs == rhs {
            return 1
        }

        let distance =
            damerauLevenshtein(
                Array(lhs),
                Array(rhs)
            )

        let length = max(
            lhs.count,
            rhs.count
        )

        guard length > 0 else {
            return 0
        }

        return max(
            0,
            1 -
            (
                Double(distance) /
                Double(length)
            )
        )
    }

    private func damerauLevenshtein(
        _ lhs: [Character],
        _ rhs: [Character]
    ) -> Int {
        let rows = lhs.count + 1
        let columns = rhs.count + 1

        var matrix = Array(
            repeating:
                Array(
                    repeating: 0,
                    count: columns
                ),
            count: rows
        )

        for row in 0..<rows {
            matrix[row][0] = row
        }

        for column in 0..<columns {
            matrix[0][column] = column
        }

        guard
            !lhs.isEmpty,
            !rhs.isEmpty
        else {
            return max(
                lhs.count,
                rhs.count
            )
        }

        for row in 1..<rows {
            for column in 1..<columns {
                let substitution =
                    lhs[row - 1] ==
                    rhs[column - 1]
                        ? 0
                        : 1

                matrix[row][column] = min(
                    matrix[row - 1][column] + 1,
                    matrix[row][column - 1] + 1,
                    matrix[row - 1][column - 1] +
                        substitution
                )

                if row > 1,
                   column > 1,
                   lhs[row - 1] ==
                    rhs[column - 2],
                   lhs[row - 2] ==
                    rhs[column - 1] {
                    matrix[row][column] = min(
                        matrix[row][column],
                        matrix[row - 2][column - 2] +
                            1
                    )
                }
            }
        }

        return matrix[
            lhs.count
        ][
            rhs.count
        ]
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()

        return filter {
            seen.insert($0).inserted
        }
    }
}
