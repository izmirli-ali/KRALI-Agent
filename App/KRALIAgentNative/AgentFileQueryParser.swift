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
    let filenameQuery: String
}

struct AgentFileQueryParser {
    func parse(
        _ rawText: String
    ) -> AgentFileQuery {
        let normalized = normalize(rawText)
        let tokens = tokenize(normalized)
        let scope = resolveScope(
            tokens: tokens,
            normalized: normalized
        )

        let filtered = tokens.filter {
            !shouldIgnoreToken($0)
        }

        return AgentFileQuery(
            scope: scope,
            filenameQuery:
                filtered.joined(separator: " ")
        )
    }

    private func resolveScope(
        tokens: [String],
        normalized: String
    ) -> AgentFileSearchScope {
        let tokenSet = Set(tokens)

        if tokenSet.contains("masaustu") ||
           tokenSet.contains("masaustunde") ||
           tokenSet.contains("masaustundeki") ||
           tokenSet.contains("desktop") {
            return .desktop
        }

        if tokenSet.contains("indirilenler") ||
           tokenSet.contains("indirilenlerde") ||
           tokenSet.contains("indirilenlerdeki") ||
           tokenSet.contains("downloads") {
            return .downloads
        }

        if tokenSet.contains("belgeler") ||
           tokenSet.contains("belgelerde") ||
           tokenSet.contains("belgelerdeki") ||
           tokenSet.contains("documents") {
            return .documents
        }

        if normalized.contains("tum bilgisayar") ||
           normalized.contains("tum mac") ||
           tokenSet.contains("macimde") ||
           tokenSet.contains("bilgisayarimda") {
            return .wholeComputer
        }

        return .selectedWorkspace
    }

    private func tokenize(
        _ text: String
    ) -> [String] {
        text.split {
            $0.isWhitespace ||
            $0.isPunctuation ||
            $0.isSymbol
        }
        .map(String.init)
        .filter {
            !$0.isEmpty
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
    }

    private func shouldIgnoreToken(
        _ token: String
    ) -> Bool {
        if ignoredTokens.contains(token) {
            return true
        }

        let semanticPrefixes = [
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
            "screenshot"
        ]

        return semanticPrefixes.contains {
            token.hasPrefix($0)
        }
    }

    private let ignoredTokens: Set<String> = [
        // Conversation / filler
        "bana", "su", "bu", "bir",
        "vardi", "onu", "lutfen",
        "var", "mi",

        // Actions
        "bul", "ara", "goster",
        "listele", "ac", "nerede",

        // Generic file/folder nouns
        "dosya", "dosyayi",
        "dosyalar", "dosyalari",
        "klasor", "klasoru",
        "klasordeki", "klasorde",

        // Workspace/scope words
        "secili", "calisma",
        "alan", "alani", "alaninda",
        "icindeki", "icinde",
        "masaustu", "masaustunde",
        "masaustundeki", "desktop",
        "indirilenler", "indirilenlerde",
        "indirilenlerdeki", "downloads",
        "belgeler", "belgelerde",
        "belgelerdeki", "documents",
        "bilgisayarimda", "macimde",
        "tum", "bilgisayar", "mac",

        // Type words handled by AgentTargetKind
        "pdf", "video", "videolar",
        "gorsel", "gorseller",
        "resim", "resimler",
        "fotograf", "fotograflar",
        "proje", "projeler",
        "dokuman", "dokumanlar",
        "belge", "belgeler",
        "ekran", "goruntusu",
        "screenshot",

        // Date/sort words handled elsewhere
        "tarihli", "olusturulan",
        "degistirilen", "son",
        "eklenen", "yeni", "en",

        // Connectors
        "olan", "olarak",
        "icin", "ile", "ve"
    ]
}
