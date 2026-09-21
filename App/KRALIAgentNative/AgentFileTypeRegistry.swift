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
            tokens.filter {
                knownExtensions.contains($0)
            }
        )

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
        knownExtensions.contains(token)
    }

    func displayLabel(
        for extensions: Set<String>
    ) -> String? {
        guard !extensions.isEmpty else {
            return nil
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
