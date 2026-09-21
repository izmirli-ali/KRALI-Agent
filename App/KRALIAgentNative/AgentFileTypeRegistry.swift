import Foundation

struct AgentFileTypeRegistry {
    private let knownExtensions: Set<String> = [
        // Archives
        "zip", "rar", "7z", "tar", "gz", "gzip",
        "bz2", "xz", "tgz",

        // Documents
        "pdf", "doc", "docx", "txt", "rtf", "md",
        "pages", "odt",

        // Spreadsheets
        "xls", "xlsx", "csv", "tsv", "numbers", "ods",

        // Presentations
        "ppt", "pptx", "key", "odp",

        // Images
        "png", "jpg", "jpeg", "heic", "gif", "webp",
        "tif", "tiff", "bmp", "svg",

        // Video
        "mov", "mp4", "m4v", "avi", "mkv", "webm",
        "mts", "m2ts",

        // Audio
        "mp3", "wav", "m4a", "aac", "flac", "ogg",
        "aiff", "aif",

        // Creative / project
        "prproj", "aep", "psd", "psb", "ai", "indd",
        "fcpxml",

        // Code / data
        "swift", "js", "jsx", "ts", "tsx", "py", "rb",
        "go", "rs", "java", "kt", "json", "yaml", "yml",
        "xml", "html", "css", "scss", "sql",

        // Fonts
        "otf", "ttf", "woff", "woff2"
    ]

    func requestedExtensions(
        rawText: String,
        tokens: [String]
    ) -> Set<String> {
        var result = Set(
            tokens.compactMap {
                canonicalExtension(
                    for: $0
                )
            }
        )

        let tokenSet = Set(tokens)

        if tokenSet.contains("arsiv") ||
           tokenSet.contains("archive") {
            result.formUnion(
                archiveExtensions
            )
        }

        if tokenSet.contains("ses") ||
           tokenSet.contains("audio") {
            result.formUnion(
                audioExtensions
            )
        }

        if tokenSet.contains("excel") ||
           tokenSet.contains("tablo") {
            result.formUnion(
                spreadsheetExtensions
            )
        }

        if tokenSet.contains("font") ||
           tokenSet.contains("yazitipi") {
            result.formUnion(
                fontExtensions
            )
        }

        let normalized = normalize(rawText)

        result.formUnion(
            explicitDotExtensions(
                in: normalized
            )
        )

        if let suffixIndex = tokens.firstIndex(
            where: {
                $0 == "uzantili" ||
                $0 == "uzantisinda" ||
                $0 == "extension"
            }
        ),
           suffixIndex > 0 {
            let candidate =
                tokens[suffixIndex - 1]

            if isPlausibleExtension(candidate) {
                result.insert(candidate)
            }
        }

        return result
    }

    func isKnownExtension(
        _ token: String
    ) -> Bool {
        canonicalExtension(
            for: token
        ) != nil
    }

    private let archiveExtensions: Set<String> = [
        "zip", "rar", "7z", "tar", "gz",
        "gzip", "bz2", "xz", "tgz"
    ]

    private let audioExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac",
        "flac", "ogg", "aiff", "aif"
    ]

    private let spreadsheetExtensions: Set<String> = [
        "xls", "xlsx", "csv", "tsv",
        "numbers", "ods"
    ]

    private let fontExtensions: Set<String> = [
        "otf", "ttf", "woff", "woff2"
    ]

    private func canonicalExtension(
        for token: String
    ) -> String? {
        if knownExtensions.contains(token) {
            return token
        }

        let suffixes = Set([
            "ler", "lar",
            "leri", "lari",
            "lerim", "larim",
            "yi", "i", "u",
            "de", "da",
            "den", "dan"
        ])

        for ext in knownExtensions
        where token.hasPrefix(ext) {
            let suffix = String(
                token.dropFirst(ext.count)
            )

            if suffixes.contains(suffix) {
                return ext
            }
        }

        return nil
    }

    func displayLabel(
        for extensions: Set<String>
    ) -> String? {
        guard !extensions.isEmpty else {
            return nil
        }

        if extensions == archiveExtensions {
            return "ARŞİV"
        }

        if extensions == audioExtensions {
            return "SES"
        }

        if extensions == spreadsheetExtensions {
            return "TABLO"
        }

        if extensions == fontExtensions {
            return "FONT"
        }

        return extensions
            .sorted()
            .map { $0.uppercased() }
            .joined(separator: "/")
    }

    private func explicitDotExtensions(
        in text: String
    ) -> Set<String> {
        guard let expression = try? NSRegularExpression(
            pattern: #"\.([a-z0-9]{1,10})(?=\s|$|[^a-z0-9])"#,
            options: []
        ) else {
            return []
        }

        let range = NSRange(
            text.startIndex..<text.endIndex,
            in: text
        )

        return Set(
            expression.matches(
                in: text,
                options: [],
                range: range
            )
            .compactMap { match in
                guard
                    match.numberOfRanges > 1,
                    let swiftRange = Range(
                        match.range(at: 1),
                        in: text
                    )
                else {
                    return nil
                }

                return String(text[swiftRange])
            }
        )
    }

    private func isPlausibleExtension(
        _ value: String
    ) -> Bool {
        guard (1...10).contains(value.count) else {
            return false
        }

        return value.allSatisfy {
            $0.isLetter || $0.isNumber
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
                locale: Locale(
                    identifier: "tr_TR"
                )
            )
            .lowercased()
            .replacingOccurrences(
                of: "ı",
                with: "i"
            )
    }
}
