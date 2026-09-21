import Foundation

enum AgentFileSearchScope: String, Hashable, Sendable {
    case selectedWorkspace
    case desktop
    case downloads
    case documents
    case wholeComputer

    var title: String {
        switch self {
        case .selectedWorkspace:
            return "Seçili çalışma alanı"
        case .desktop:
            return "Masaüstü"
        case .downloads:
            return "İndirilenler"
        case .documents:
            return "Belgeler"
        case .wholeComputer:
            return "Tüm Mac"
        }
    }
}

struct AgentFileQuery: Hashable, Sendable {
    let scope: AgentFileSearchScope
    let scopeIsExplicit: Bool
    let filenameQuery: String
    let extensions: Set<String>
    let hasSearchAction: Bool
    let mentionsFileEntity: Bool
    let extensionDisplayLabel: String?

    var hasTypeFilter: Bool {
        !extensions.isEmpty
    }

    var isFileSearchRequest: Bool {
        hasSearchAction &&
        (
            scopeIsExplicit ||
            mentionsFileEntity ||
            hasTypeFilter
        )
    }
}

struct AgentFileQueryParser {
    private let typeRegistry =
        AgentFileTypeRegistry()

    func parse(
        _ rawText: String
    ) -> AgentFileQuery {
        let normalized = normalize(rawText)
        let tokens = tokenize(normalized)

        let scopeResolution =
            resolveScope(
                tokens: tokens,
                normalized: normalized
            )

        let extensions =
            typeRegistry.requestedExtensions(
                rawText: rawText,
                tokens: tokens
            )

        let hasSearchAction =
            tokens.contains {
                searchActionTokens.contains($0)
            }

        let mentionsFileEntity =
            tokens.contains {
                isFileEntityToken($0)
            }

        let filtered = tokens.filter { token in
            !shouldIgnoreToken(
                token,
                requestedExtensions: extensions
            )
        }

        return AgentFileQuery(
            scope: scopeResolution.scope,
            scopeIsExplicit:
                scopeResolution.explicit,
            filenameQuery:
                filtered.joined(separator: " "),
            extensions: extensions,
            hasSearchAction: hasSearchAction,
            mentionsFileEntity:
                mentionsFileEntity,
            extensionDisplayLabel:
                typeRegistry.displayLabel(
                    for: extensions
                )
        )
    }

    func resolveTargetEntity(
        _ rawText: String
    ) -> AgentTargetKind {
        let normalized =
            normalize(rawText)
        let tokens =
            tokenize(normalized)
        let scope =
            resolveScope(
                tokens: tokens,
                normalized: normalized
            )

        if containsAny(
            normalized,
            [
                "ekran gorunt",
                "ekran resmi",
                "screenshot"
            ]
        ) {
            return .screenshot
        }

        if containsAny(
            normalized,
            ["pdf"]
        ) {
            return .pdf
        }

        if containsAny(
            normalized,
            [
                "video",
                "videolar",
                "cekim",
                "klip"
            ]
        ) {
            return .video
        }

        if containsAny(
            normalized,
            [
                "gorsel",
                "resim",
                "fotograf"
            ]
        ) {
            return .image
        }

        if containsAny(
            normalized,
            [
                "proje",
                "project"
            ]
        ) {
            return .project
        }

        if containsAny(
            normalized,
            [
                "belge",
                "dokuman"
            ]
        ) {
            return .document
        }

        let folderTargetPhrases = [
            "klasorleri bul",
            "klasor bul",
            "klasorunu bul",
            "klasoru bul",
            "klasorleri listele",
            "klasorleri goster",
            "hangi klasor",
            "hangi klasorler",
            "klasorler neler",
            "alt klasor",
            "folder bul",
            "list folders",
            "folders"
        ]

        if containsAny(
            normalized,
            folderTargetPhrases
        ) {
            return .folder
        }

        let genericFileEntity =
            tokens.contains(
                where: {
                    $0.hasPrefix("dosya") ||
                    $0.hasPrefix("file")
                }
            )

        // Scope phrases such as "İndirilenler klasöründe" or
        // "Masaüstü klasöründeki" describe WHERE. If scope is explicit,
        // a bare "klasör" token cannot become the target entity.
        if scope.explicit {
            return .any
        }

        if !genericFileEntity &&
           tokens.contains(
            where: {
                $0.hasPrefix("klasor") ||
                $0.hasPrefix("folder")
            }
           ) {
            return .folder
        }

        return .any
    }


    private func resolveScope(
        tokens: [String],
        normalized: String
    ) -> (
        scope: AgentFileSearchScope,
        explicit: Bool
    ) {
        let tokenSet = Set(tokens)

        if tokenSet.contains(where: {
            $0.hasPrefix("masaustu")
        }) ||
           tokenSet.contains("desktop") {
            return (.desktop, true)
        }

        if tokenSet.contains(where: {
            $0.hasPrefix("indirilenler")
        }) ||
           tokenSet.contains("downloads") {
            return (.downloads, true)
        }

        if tokenSet.contains(where: {
            $0.hasPrefix("belgeler")
        }) ||
           tokenSet.contains("documents") {
            return (.documents, true)
        }

        if normalized.contains("tum bilgisayar") ||
           normalized.contains("tum mac") ||
           tokenSet.contains("macimde") ||
           tokenSet.contains("bilgisayarimda") {
            return (.wholeComputer, true)
        }

        return (.selectedWorkspace, false)
    }

    private func tokenize(
        _ text: String
    ) -> [String] {
        let apostropheJoined = text
            .replacingOccurrences(
                of: "'",
                with: ""
            )
            .replacingOccurrences(
                of: "’",
                with: ""
            )

        return apostropheJoined.split {
            $0.isWhitespace ||
            $0.isPunctuation ||
            $0.isSymbol
        }
        .map(String.init)
        .filter {
            !$0.isEmpty
        }
    }

    private func containsAny(
        _ text: String,
        _ values: [String]
    ) -> Bool {
        values.contains {
            text.contains($0)
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

    private func shouldIgnoreToken(
        _ token: String,
        requestedExtensions: Set<String>
    ) -> Bool {
        if ignoredTokens.contains(token) {
            return true
        }

        if requestedExtensions.contains(token) ||
           typeRegistry.isKnownExtension(token) {
            return true
        }

        if semanticPrefixes.contains(
            where: {
                token.hasPrefix($0)
            }
        ) {
            return true
        }

        return false
    }

    private func isFileEntityToken(
        _ token: String
    ) -> Bool {
        semanticPrefixes.contains {
            token.hasPrefix($0)
        } ||
        typeRegistry.isKnownExtension(token)
    }

    private let searchActionTokens: Set<String> = [
        "bul", "ara", "goster",
        "listele", "getir", "cikar",
        "incele", "nerede", "hangileri",
        "neler", "bak"
    ]

    private let semanticPrefixes = [
        "dosya",
        "klasor",
        "masaustu",
        "indirilenler",
        "belgeler",
        "pdf",
        "video",
        "gorsel",
        "resim",
        "fotograf",
        "proje",
        "dokuman",
        "belge",
        "screenshot",
        "arsiv",
        "archive",
        "ses",
        "audio",
        "excel",
        "tablo",
        "font",
        "yazitipi"
    ]

    private let ignoredTokens: Set<String> = [
        // Conversation / filler
        "bana", "su", "bu", "bir",
        "vardi", "onu", "lutfen",
        "var", "mi",

        // Actions
        "bul", "ara", "goster",
        "listele", "ac", "nerede",
        "getir", "cikar", "incele",

        // Workspace/scope
        "secili", "calisma",
        "alan", "alani", "alaninda",
        "icindeki", "icinde",
        "desktop", "downloads",
        "documents", "bilgisayarimda",
        "macimde", "tum",
        "bilgisayar", "mac",

        // Type helpers
        "ekran", "goruntusu",
        "uzantili", "uzantisinda",
        "extension",

        // Date/sort words handled elsewhere
        "tarihli", "olusturulan",
        "degistirilen", "son",
        "eklenen", "yeni", "en",

        // Connectors
        "olan", "olarak",
        "icin", "ile", "ve"
    ]
}
