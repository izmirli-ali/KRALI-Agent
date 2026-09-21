import Foundation

struct AgentWorkspaceIndexSnapshot {
    let files: [FileRecord]
    let folders: [FolderRecord]
    let reachedSafetyLimit: Bool
}

struct AgentWorkspaceIndexer {
    func index(
        root: URL,
        maxItems: Int = 5000
    ) -> AgentWorkspaceIndexSnapshot {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .creationDateKey,
            .contentModificationDateKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [
                .skipsHiddenFiles,
                .skipsPackageDescendants
            ]
        ) else {
            return AgentWorkspaceIndexSnapshot(
                files: [],
                folders: [],
                reachedSafetyLimit: false
            )
        }

        var records: [FileRecord] = []
        var folders: [FolderRecord] = []
        var reachedSafetyLimit = false

        for case let url as URL in enumerator {
            if records.count + folders.count >= maxItems {
                reachedSafetyLimit = true
                break
            }

            guard
                let values = try? url.resourceValues(
                    forKeys: Set(keys)
                )
            else {
                continue
            }

            let name = url.lastPathComponent
            let relativePath =
                url.path.replacingOccurrences(
                    of: root.path + "/",
                    with: ""
                )

            if values.isDirectory == true {
                folders.append(
                    FolderRecord(
                        url: url,
                        name: name,
                        relativePath: relativePath,
                        creationDate: values.creationDate,
                        modificationDate:
                            values.contentModificationDate
                    )
                )
                continue
            }

            guard values.isRegularFile == true else {
                continue
            }

            let ext = url.pathExtension.lowercased()

            records.append(
                FileRecord(
                    url: url,
                    name: name,
                    relativePath: relativePath,
                    fileExtension: ext,
                    isScreenshot:
                        isScreenshotFileName(
                            name,
                            extension: ext
                        ),
                    creationDate: values.creationDate,
                    modificationDate:
                        values.contentModificationDate
                )
            )
        }

        return AgentWorkspaceIndexSnapshot(
            files: records.sorted {
                $0.relativePath.localizedStandardCompare(
                    $1.relativePath
                ) == .orderedAscending
            },
            folders: folders.sorted {
                $0.relativePath.localizedStandardCompare(
                    $1.relativePath
                ) == .orderedAscending
            },
            reachedSafetyLimit: reachedSafetyLimit
        )
    }

    private func isScreenshotFileName(
        _ name: String,
        extension ext: String
    ) -> Bool {
        let imageExtensions = Set([
            "png", "jpg", "jpeg", "heic",
            "tif", "tiff", "webp"
        ])

        guard imageExtensions.contains(ext) else {
            return false
        }

        let normalized = name
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

        let patterns = [
            "ekran resmi",
            "ekran goruntusu",
            "screenshot",
            "screen shot"
        ]

        return patterns.contains {
            normalized.contains($0)
        }
    }
}
