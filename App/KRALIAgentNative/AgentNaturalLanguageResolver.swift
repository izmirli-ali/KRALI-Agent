import Foundation

struct AgentNaturalLanguageResolver: Sendable {
    private let openVerbs = Set([
        "ac", "baslat", "calistir",
        "getir", "goster"
    ])

    private let commandNoise = Set([
        "uygulama", "uygulamayi", "uygulamasini",
        "uygulamasina", "uygulamaya",
        "pencere", "pencereyi",
        "ac", "baslat", "calistir",
        "one", "getir", "goster",
        "gec", "lutfen", "hemen",
        "bir", "su", "sunu", "bunu"
    ])

    private let deepInteractionWords = Set([
        "tikla", "bas", "buton", "menu",
        "alana", "yaz", "surukle", "sec",
        "isaretle", "klavye", "mouse"
    ])

    private let nonAppObjectWords = Set([
        "dosya", "pdf", "belge", "klasor",
        "finder", "indirilenler", "masaustu",
        "web", "site", "internet", "tarayici",
        "url", "sayfa"
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

        guard
            wordSet.intersection(
                deepInteractionWords
            ).isEmpty,
            wordSet.intersection(
                nonAppObjectWords
            ).isEmpty
        else {
            return false
        }

        return !targetTokens(raw).isEmpty
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
        let targets = targetTokens(raw)

        guard !targets.isEmpty else {
            return 0
        }

        let aliasVariants =
            aliases
                .flatMap {
                    let normalizedAlias =
                        normalized($0)

                    return
                        [normalizedAlias] +
                        normalizedAlias
                            .split(separator: " ")
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

        var best = 0.0

        for target in targets {
            for alias in aliasVariants {
                if target == alias {
                    return 1.0
                }

                if target.count >= 4,
                   alias.count >= 4,
                   (
                    target.contains(alias) ||
                    alias.contains(target)
                   ) {
                    best = max(best, 0.94)
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
