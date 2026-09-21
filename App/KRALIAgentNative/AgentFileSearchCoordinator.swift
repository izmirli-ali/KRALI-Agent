import Foundation

enum AgentFileSearchOutcomeStatus:
    String,
    Hashable,
    Sendable {
    case matched
    case noResults
    case workspaceMissing
    case unsupportedScope
    case inaccessibleScope

    var isExpectedBoundary: Bool {
        switch self {
        case .workspaceMissing,
             .unsupportedScope,
             .inaccessibleScope:
            return true

        case .matched,
             .noResults:
            return false
        }
    }
}

struct AgentFileSearchOutcome:
    Hashable {
    let status: AgentFileSearchOutcomeStatus
    let query: AgentFileQuery
    let rootPath: String?
    let rootName: String?
    let resultCount: Int
    let files: [FileRecord]
    let reachedSafetyLimit: Bool
    let title: String
    let message: String
}

@MainActor
final class AgentFileSearchCoordinator {
    private struct CachedIndex {
        let createdAt: Date
        let snapshot: AgentWorkspaceIndexSnapshot
    }

    private let fileManager = FileManager.default
    private let indexer = AgentWorkspaceIndexer()
    private let freshness: TimeInterval = 45
    private var cache: [String: CachedIndex] = [:]

    func search(
        query: AgentFileQuery,
        decision: AgentDecision,
        selectedWorkspace: URL?,
        previousResults: [FileRecord]
    ) -> AgentFileSearchOutcome {
        guard let root = resolveRoot(
            for: query.scope,
            selectedWorkspace: selectedWorkspace
        ) else {
            if query.scope == .wholeComputer {
                return boundary(
                    status: .unsupportedScope,
                    query: query,
                    title: query.scope.title,
                    message:
                        "Tüm Mac araması henüz güvenli ve performanslı bir indeks katmanına bağlı değil. Masaüstü, İndirilenler, Belgeler veya seçili çalışma alanı gibi daha dar bir kapsam seç."
                )
            }

            return boundary(
                status: .workspaceMissing,
                query: query,
                title: query.scope.title,
                message:
                    "Bu arama için kullanılabilir bir çalışma alanı bulunamadı."
            )
        }

        guard fileManager.fileExists(
            atPath: root.path
        ) else {
            return boundary(
                status: .inaccessibleScope,
                query: query,
                title: query.scope.title,
                message:
                    "“" +
                    query.scope.title +
                    "” kapsamına erişemiyorum. Klasör mevcut değil veya erişim izni yok."
            )
        }

        let sourceFiles: [FileRecord]
        let reachedSafetyLimit: Bool

        if decision.usePreviousResults,
           !query.scopeIsExplicit,
           !previousResults.isEmpty {
            sourceFiles = previousResults
            reachedSafetyLimit = false
        } else {
            let snapshot = cachedIndex(
                for: root
            )
            sourceFiles = snapshot.files
            reachedSafetyLimit =
                snapshot.reachedSafetyLimit
        }

        var results = filterByLegacyTarget(
            sourceFiles,
            target: decision.target
        )

        if !query.extensions.isEmpty {
            results = results.filter {
                query.extensions.contains(
                    $0.fileExtension.lowercased()
                )
            }
        }

        if !query.filenameQuery.isEmpty {
            let tokens = query.filenameQuery
                .split(whereSeparator: {
                    $0.isWhitespace
                })
                .map(String.init)

            results = results.filter { file in
                let name = normalize(file.name)
                let path = normalize(
                    file.relativePath
                )

                return tokens.allSatisfy {
                    name.contains($0) ||
                    path.contains($0)
                }
            }
        }

        if let range = decision.dateRange {
            results = results.filter { file in
                switch decision.dateField {
                case .created:
                    guard let date =
                        file.creationDate
                    else {
                        return false
                    }
                    return range.contains(date)

                case .modified:
                    guard let date =
                        file.modificationDate
                    else {
                        return false
                    }
                    return range.contains(date)

                case .either:
                    let created =
                        file.creationDate
                            .map(range.contains) ??
                        false
                    let modified =
                        file.modificationDate
                            .map(range.contains) ??
                        false
                    return created || modified
                }
            }
        }

        if decision.sortMode == .newestFirst {
            results.sort {
                let left =
                    $0.modificationDate ??
                    $0.creationDate ??
                    .distantPast
                let right =
                    $1.modificationDate ??
                    $1.creationDate ??
                    .distantPast
                return left > right
            }
        }

        if let resultLimit =
            query.resultLimit,
           resultLimit > 0,
           results.count >
            resultLimit {
            results =
                Array(
                    results.prefix(
                        resultLimit
                    )
                )
        }

        let title = makeTitle(
            query: query,
            decision: decision
        )

        if results.isEmpty {
            return AgentFileSearchOutcome(
                status: .noResults,
                query: query,
                rootPath: root.path,
                rootName: root.lastPathComponent,
                resultCount: 0,
                files: [],
                reachedSafetyLimit:
                    reachedSafetyLimit,
                title: title,
                message:
                    "“" +
                    root.lastPathComponent +
                    "” içinde " +
                    title +
                    " için eşleşme bulamadım."
            )
        }

        let preview = results
            .prefix(5)
            .map(\.name)
            .joined(separator: ", ")
        let extra =
            results.count > 5
            ? " ve " +
                String(results.count - 5) +
                " dosya daha"
            : ""

        let safetyNote =
            reachedSafetyLimit
            ? " Not: İndeks güvenlik sınırına ulaştı; sonuçlar ilk 5000 öğelik güvenli taramaya dayanıyor."
            : ""

        return AgentFileSearchOutcome(
            status: .matched,
            query: query,
            rootPath: root.path,
            rootName: root.lastPathComponent,
            resultCount: results.count,
            files: results,
            reachedSafetyLimit:
                reachedSafetyLimit,
            title: title,
            message:
                "“" +
                root.lastPathComponent +
                "” içinde " +
                title +
                " için " +
                String(results.count) +
                " eşleşme buldum: " +
                preview +
                extra +
                "." +
                safetyNote
        )
    }

    func invalidate(
        root: URL?
    ) {
        guard let root else {
            cache.removeAll()
            return
        }

        cache.removeValue(
            forKey:
                root.standardizedFileURL.path
        )
    }

    private func resolveRoot(
        for scope: AgentFileSearchScope,
        selectedWorkspace: URL?
    ) -> URL? {
        let home =
            fileManager
                .homeDirectoryForCurrentUser

        switch scope {
        case .selectedWorkspace:
            return selectedWorkspace

        case .desktop:
            return home.appendingPathComponent(
                "Desktop",
                isDirectory: true
            )

        case .downloads:
            return home.appendingPathComponent(
                "Downloads",
                isDirectory: true
            )

        case .documents:
            return home.appendingPathComponent(
                "Documents",
                isDirectory: true
            )

        case .wholeComputer:
            return nil
        }
    }

    private func cachedIndex(
        for root: URL
    ) -> AgentWorkspaceIndexSnapshot {
        let key =
            root.standardizedFileURL.path

        if let cached = cache[key],
           Date().timeIntervalSince(
                cached.createdAt
           ) < freshness {
            return cached.snapshot
        }

        let snapshot = indexer.index(
            root: root
        )

        cache[key] = CachedIndex(
            createdAt: Date(),
            snapshot: snapshot
        )

        return snapshot
    }

    private func filterByLegacyTarget(
        _ files: [FileRecord],
        target: AgentTargetKind
    ) -> [FileRecord] {
        let imageExtensions = Set([
            "png", "jpg", "jpeg", "heic",
            "tif", "tiff", "webp", "gif"
        ])
        let videoExtensions = Set([
            "mov", "mp4", "m4v", "avi",
            "mkv", "webm", "mts", "m2ts"
        ])
        let projectExtensions = Set([
            "prproj", "aep", "psd", "ai",
            "indd", "fcpxml"
        ])
        let documentExtensions = Set([
            "pdf", "doc", "docx", "txt",
            "rtf", "md", "pages", "numbers",
            "key"
        ])

        switch target {
        case .screenshot:
            return files.filter(\.isScreenshot)

        case .pdf:
            return files.filter {
                $0.fileExtension == "pdf"
            }

        case .video:
            return files.filter {
                videoExtensions.contains(
                    $0.fileExtension
                )
            }

        case .image:
            return files.filter {
                imageExtensions.contains(
                    $0.fileExtension
                )
            }

        case .project:
            return files.filter {
                projectExtensions.contains(
                    $0.fileExtension
                )
            }

        case .document:
            return files.filter {
                documentExtensions.contains(
                    $0.fileExtension
                )
            }

        case .folder:
            return []

        case .any:
            return files
        }
    }

    private func makeTitle(
        query: AgentFileQuery,
        decision: AgentDecision
    ) -> String {
        var parts: [String] = []

        if let typeLabel =
            query.extensionDisplayLabel {
            parts.append(
                typeLabel + " dosyaları"
            )
        } else if !query.filenameQuery.isEmpty {
            parts.append(
                "“" +
                query.filenameQuery +
                "”"
            )
        } else {
            parts.append(decision.goal)
        }

        if query.scopeIsExplicit {
            parts.append(
                "• " + query.scope.title
            )
        }

        return parts.joined(separator: " ")
    }

    private func boundary(
        status: AgentFileSearchOutcomeStatus,
        query: AgentFileQuery,
        title: String,
        message: String
    ) -> AgentFileSearchOutcome {
        AgentFileSearchOutcome(
            status: status,
            query: query,
            rootPath: nil,
            rootName: nil,
            resultCount: 0,
            files: [],
            reachedSafetyLimit: false,
            title: title,
            message: message
        )
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
