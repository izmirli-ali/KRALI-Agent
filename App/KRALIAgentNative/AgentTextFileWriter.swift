import Foundation

struct TextFileWriteResult: Hashable, Sendable {
    let url: URL
    let byteCount: Int
}

enum TextFileWriteError: LocalizedError {
    case targetNotDirectory
    case targetOutsideWorkspace
    case emptyContent
    case couldNotAllocateName

    var errorDescription: String? {
        switch self {
        case .targetNotDirectory:
            return "Hedef konum bir klasör değil."
        case .targetOutsideWorkspace:
            return "Hedef klasör izin verilen çalışma alanının dışında."
        case .emptyContent:
            return "Yazılacak metin boş."
        case .couldNotAllocateName:
            return "Çakışmasız dosya adı üretilemedi."
        }
    }
}

actor AgentTextFileWriter {
    private let fileManager = FileManager.default

    func write(
        content: String,
        to targetFolder: URL,
        workspaceRoot: URL?,
        preferredStem: String
    ) throws -> TextFileWriteResult {
        let trimmed =
            content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmed.isEmpty else {
            throw TextFileWriteError.emptyContent
        }

        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(
                atPath: targetFolder.path,
                isDirectory: &isDirectory
            ),
            isDirectory.boolValue
        else {
            throw TextFileWriteError.targetNotDirectory
        }

        if let workspaceRoot {
            let rootPath =
                workspaceRoot
                    .standardizedFileURL
                    .path
            let targetPath =
                targetFolder
                    .standardizedFileURL
                    .path

            let rootPrefix =
                rootPath.hasSuffix("/")
                    ? rootPath
                    : rootPath + "/"

            guard
                targetPath == rootPath ||
                targetPath.hasPrefix(
                    rootPrefix
                )
            else {
                throw TextFileWriteError
                    .targetOutsideWorkspace
            }
        }

        let stem =
            sanitizedStem(
                preferredStem
            )

        guard let outputURL =
            availableURL(
                in: targetFolder,
                stem: stem
            )
        else {
            throw TextFileWriteError
                .couldNotAllocateName
        }

        let data =
            Data(
                (
                    trimmed +
                    "\n"
                )
                .utf8
            )

        try data.write(
            to: outputURL,
            options: [.atomic]
        )

        return TextFileWriteResult(
            url: outputURL,
            byteCount: data.count
        )
    }

    private func sanitizedStem(
        _ raw: String
    ) -> String {
        let folded =
            raw
                .folding(
                    options: [
                        .diacriticInsensitive
                    ],
                    locale:
                        Locale(
                            identifier: "tr_TR"
                        )
                )

        let allowed =
            CharacterSet
                .alphanumerics
                .union(
                    CharacterSet(
                        charactersIn:
                            "-_ "
                    )
                )

        let cleaned = folded
            .unicodeScalars
            .map {
                allowed.contains($0)
                    ? String($0)
                    : " "
            }
            .joined()
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of: " ",
                with: "-"
            )

        return cleaned.isEmpty
            ? "KRALI-Cikti"
            : String(
                cleaned.prefix(70)
            )
    }

    private func availableURL(
        in folder: URL,
        stem: String
    ) -> URL? {
        let first =
            folder
                .appendingPathComponent(
                    stem
                )
                .appendingPathExtension(
                    "txt"
                )

        if !fileManager.fileExists(
            atPath: first.path
        ) {
            return first
        }

        for suffix in 2...999 {
            let candidate =
                folder
                    .appendingPathComponent(
                        stem +
                        "-" +
                        String(suffix)
                    )
                    .appendingPathExtension(
                        "txt"
                    )

            if !fileManager.fileExists(
                atPath: candidate.path
            ) {
                return candidate
            }
        }

        return nil
    }
}
