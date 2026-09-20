import Foundation

struct AgentMissionNormalizer {
    private let languageResolver =
        AgentNaturalLanguageResolver()

    func normalize(
        _ mission: AgentSemanticMission,
        userInput: String,
        capabilities: [AgentCapability]
    ) -> AgentSemanticMission {
        let corpus = normalizeText(userInput)
        let knownIDs = Set(
            capabilities.map(\.id)
        )

        let appOpen =
            containsAny(
                corpus,
                [
                    "uygulamasini ac",
                    "uygulamayi ac",
                    "uygulamasını aç",
                    "uygulamayı aç",
                    "uygulamasini one getir",
                    "uygulamasını öne getir",
                    "uygulamaya gec",
                    "uygulamaya geç"
                ]
            ) ||
            (
                corpus.contains("uygulama") &&
                containsAny(
                    corpus,
                    [
                        " ac", " aç",
                        "one getir",
                        "öne getir"
                    ]
                )
            )

        let appContentRead =
            appOpen &&
            containsAny(
                corpus,
                [
                    "oku",
                    "incele",
                    "kontrol et",
                    "su anda acik",
                    "şu anda açık",
                    "mevcut acik",
                    "mevcut açık",
                    "icerigi",
                    "içeriği",
                    "ne caliyor",
                    "ne çalıyor",
                    "hangisi acik",
                    "hangisi açık",
                    "son gelen"
                ]
            )

        let research =
            containsAny(
                corpus,
                [
                    "arastir",
                    "araştır",
                    "internetten bul",
                    "webden bul",
                    "web'den bul",
                    "kaynak bul",
                    "sozlerini bul",
                    "sözlerini bul"
                ]
            )

        let analyze =
            containsAny(
                corpus,
                [
                    "analiz et",
                    "incele",
                    "ozetle",
                    "özetle",
                    "degerlendir",
                    "değerlendir",
                    "ne yapmamiz",
                    "ne yapmamız",
                    "yorumla",
                    "cikarim",
                    "çıkarım"
                ]
            )

        let textWrite =
            containsAny(
                corpus,
                [
                    "txt",
                    "metin dosyasi",
                    "metin dosyası",
                    "text file",
                    "dosyaya yaz",
                    "dosyaya kaydet",
                    "dosya olarak kaydet",
                    "dosya olarak ekle",
                    "dosya olustur",
                    "dosya oluştur"
                ]
            )

        let namedLocalTarget =
            textWrite &&
            containsAny(
                corpus,
                [
                    "klasor",
                    "klasör",
                    "masaustu",
                    "masaüstü",
                    "indirilenler",
                    "desktop",
                    "downloads"
                ]
            )

        let explicitMove =
            containsAny(
                corpus,
                [
                    "tasi",
                    "taşı",
                    "toparla",
                    "ayri klasore",
                    "ayrı klasöre",
                    "yerini degistir",
                    "yerini değiştir"
                ]
            )

        let explicitReveal =
            containsAny(
                corpus,
                [
                    "finder'da goster",
                    "finderda goster",
                    "finder'da göster",
                    "finderda göster",
                    "finder'da ac",
                    "finderda ac",
                    "finder'da aç",
                    "finderda aç"
                ]
            )

        let mailDomain =
            containsAny(
                corpus,
                [
                    "mail",
                    "e-posta",
                    "eposta",
                    "gmail"
                ]
            )

        let mailRead =
            mailDomain &&
            containsAny(
                corpus,
                [
                    "son gelen",
                    "oku",
                    "incele",
                    "kontrol et",
                    "icerigi",
                    "içeriği"
                ]
            )

        let mailDraft =
            mailDomain &&
            containsAny(
                corpus,
                [
                    "cevap",
                    "taslak",
                    "yanit",
                    "yanıt"
                ]
            )

        let mailSend =
            mailDomain &&
            containsAny(
                corpus,
                [
                    "gonder",
                    "gönder"
                ]
            )

        let compoundFacetCount = [
            appOpen,
            appContentRead,
            research,
            analyze,
            textWrite,
            namedLocalTarget,
            mailRead,
            mailDraft,
            mailSend
        ]
        .filter { $0 }
        .count

        guard compoundFacetCount >= 2 else {
            return pruneImpossibleExtras(
                mission,
                corpus: corpus,
                explicitMove: explicitMove,
                explicitReveal: explicitReveal
            )
        }

        var steps: [AgentSemanticMissionStep] = []
        var outcomes = Set<String>()

        func append(
            title: String,
            purpose: String,
            capabilityID: String,
            operation: String,
            dependsOn: [Int]
        ) {
            guard knownIDs.contains(capabilityID) else {
                return
            }

            steps.append(
                AgentSemanticMissionStep(
                    title: title,
                    purpose: purpose,
                    capabilityID: capabilityID,
                    operation: operation,
                    dependsOn: dependsOn
                )
            )
        }

        append(
            title: "Görev bağlamını hazırla",
            purpose:
                "Yalnızca bu kullanıcı hedefiyle ilgili bağlamı hazırla; eski görev hedeflerini yeni göreve taşıma.",
            capabilityID: "context.local",
            operation: "context.resolve",
            dependsOn: []
        )

        var latestDataStep: Int? =
            steps.isEmpty ? nil : steps.count - 1

        if appOpen {
            append(
                title: "Kaynak uygulamayı aç veya öne getir",
                purpose:
                    "Kullanıcının adlandırdığı uygulamayı çöz ve görünür foreground durumuna getir.",
                capabilityID: "desktop.app",
                operation: "app.open",
                dependsOn:
                    latestDataStep.map { [$0] } ?? []
            )

            if !steps.isEmpty {
                latestDataStep =
                    steps.count - 1
            }

            outcomes.insert("open")
        }

        if mailRead {
            append(
                title: "İletiyi oku",
                purpose:
                    "Kullanıcının istediği mail içeriğini salt-okunur biçimde al.",
                capabilityID: "mail.work",
                operation: "mail.read",
                dependsOn:
                    latestDataStep.map { [$0] } ?? []
            )

            if !steps.isEmpty {
                latestDataStep =
                    steps.count - 1
            }

            outcomes.insert("communicate")
        } else if appContentRead {
            append(
                title: "Uygulamadaki mevcut içeriği oku",
                purpose:
                    "Aktif uygulamadaki kullanıcı hedefiyle ilgili görünür içeriği ekran kanıtından çıkar.",
                capabilityID: "perception.screen",
                operation: "screen.read",
                dependsOn:
                    latestDataStep.map { [$0] } ?? []
            )

            if !steps.isEmpty {
                latestDataStep =
                    steps.count - 1
            }

            outcomes.insert("analyze")
        }

        if research {
            append(
                title: "Gerekli dış bilgiyi araştır",
                purpose:
                    "Önceki adımda çözülen gerçek hedef/veriyi kullanarak dış kaynaklardan gerekli bilgiyi araştır.",
                capabilityID: "research.web",
                operation: "web.research",
                dependsOn:
                    latestDataStep.map { [$0] } ?? []
            )

            if !steps.isEmpty {
                latestDataStep =
                    steps.count - 1
            }

            outcomes.insert("research")
        }

        if analyze {
            var dependencies: [Int] = []
            if let latestDataStep {
                dependencies = [latestDataStep]
            }

            append(
                title: "Toplanan veriyi analiz et",
                purpose:
                    "Önceki adımların gerçek çıktısını birlikte değerlendir ve sonraki adımın kullanabileceği sonucu üret.",
                capabilityID: "core.reasoning",
                operation: "content.analyze",
                dependsOn: dependencies
            )

            if !steps.isEmpty {
                latestDataStep =
                    steps.count - 1
            }

            outcomes.insert("analyze")
            outcomes.insert("explain")
        }

        if mailDraft {
            append(
                title: "Cevap taslağı oluştur",
                purpose:
                    "Analiz sonucuna uygun bir cevap taslağı hazırla; henüz dış dünyaya gönderme.",
                capabilityID: "mail.work",
                operation: "mail.draft",
                dependsOn:
                    latestDataStep.map { [$0] } ?? []
            )

            if !steps.isEmpty {
                latestDataStep =
                    steps.count - 1
            }

            outcomes.insert("compose")
            outcomes.insert("communicate")
        }

        var targetFolderStep: Int?
        if namedLocalTarget {
            append(
                title: "Hedef klasörü çöz",
                purpose:
                    "Kullanıcının adlandırdığı yerel hedef klasörü salt-okunur olarak bul.",
                capabilityID: "files.search",
                operation: "files.search.target-folder",
                dependsOn: []
            )

            if !steps.isEmpty {
                targetFolderStep =
                    steps.count - 1
            }

            outcomes.insert("locate")
        }

        if textWrite {
            var dependencies: [Int] = []

            if let latestDataStep {
                dependencies.append(
                    latestDataStep
                )
            }

            if let targetFolderStep,
               !dependencies.contains(
                    targetFolderStep
               ) {
                dependencies.append(
                    targetFolderStep
                )
            }

            append(
                title: "Metin çıktısını dosyaya yaz",
                purpose:
                    "Analiz/üretim çıktısını çözülen hedef klasöre yeni bir metin dosyası olarak yaz.",
                capabilityID: "files.write.text",
                operation: "file.write.text",
                dependsOn:
                    dependencies.sorted()
            )

            outcomes.insert("compose")
            outcomes.insert("organize")
        }

        if mailSend {
            append(
                title: "Gönder",
                purpose:
                    "Hazırlanan taslağı yalnız kullanıcı onayından sonra dış dünyaya gönder.",
                capabilityID: "mail.work",
                operation: "mail.send",
                dependsOn:
                    latestDataStep.map { [$0] } ?? []
            )

            outcomes.insert("communicate")
        }

        if explicitMove {
            append(
                title: "Dosya konumunu düzenle",
                purpose:
                    "Kullanıcının açıkça istediği taşıma/düzenleme işlemini geri alınabilir biçimde uygula.",
                capabilityID:
                    "files.move.reversible",
                operation:
                    "files.move.reversible",
                dependsOn:
                    latestDataStep.map { [$0] } ?? []
            )

            outcomes.insert("organize")
        }

        if explicitReveal {
            append(
                title: "Sonucu Finder'da göster",
                purpose:
                    "Kullanıcının açıkça istediği dosya/klasörü Finder'da görünür hale getir.",
                capabilityID:
                    "files.reveal",
                operation:
                    "files.reveal",
                dependsOn:
                    latestDataStep.map { [$0] } ?? []
            )

            outcomes.insert("open")
        }

        guard !steps.isEmpty else {
            return mission
        }

        let required =
            Array(
                Set(
                    steps.map(\.capabilityID) +
                    ["core.reasoning"]
                )
            )
            .filter {
                knownIDs.contains($0)
            }
            .sorted()

        return AgentSemanticMission(
            objective: userInput,
            outcomes:
                outcomes.sorted(),
            steps: steps,
            requiredCapabilityIDs:
                required,
            requiresUserInput:
                mission.requiresUserInput,
            userInputReason:
                mission.userInputReason,
            confidence:
                max(
                    mission.confidence,
                    0.88
                )
        )
    }

    private func pruneImpossibleExtras(
        _ mission: AgentSemanticMission,
        corpus: String,
        explicitMove: Bool,
        explicitReveal: Bool
    ) -> AgentSemanticMission {
        var forbidden = Set<String>()

        if !explicitMove {
            forbidden.insert(
                "files.move.reversible"
            )
        }

        if !explicitReveal {
            forbidden.insert(
                "files.reveal"
            )
        }

        let steps = mission.steps
            .enumerated()
            .filter {
                !forbidden.contains(
                    $0.element.capabilityID
                )
            }
            .map(\.element)

        let required =
            mission.requiredCapabilityIDs
                .filter {
                    !forbidden.contains($0)
                }

        return AgentSemanticMission(
            objective: mission.objective,
            outcomes: mission.outcomes,
            steps: steps,
            requiredCapabilityIDs: required,
            requiresUserInput:
                mission.requiresUserInput,
            userInputReason:
                mission.userInputReason,
            confidence:
                mission.confidence
        )
    }

    private func normalizeText(
        _ value: String
    ) -> String {
        value
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
    }

    private func containsAny(
        _ corpus: String,
        _ values: [String]
    ) -> Bool {
        values.contains {
            corpus.contains(
                normalizeText($0)
            )
        }
    }
}
