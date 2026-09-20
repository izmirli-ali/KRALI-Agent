import Foundation

enum CapabilityGapKind: String, Codable, Hashable, Sendable {
    case knowledge
    case strategy
    case code
    case integration
}

struct CapabilityGapResolution: Codable, Hashable, Sendable {
    let capabilityID: String
    let capabilityName: String
    let kind: CapabilityGapKind
    let reason: String
    let candidateCapabilityIDs: [String]
    let researchGoal: String
    let developerBrief: String
}

struct AgentCapabilityGapResolver {
    func resolve(
        graph: AgentTaskGraph,
        capabilities: [AgentCapability]
    ) -> [CapabilityGapResolution] {
        let registry =
            Dictionary(
                uniqueKeysWithValues:
                    capabilities.map {
                        ($0.id, $0)
                    }
            )

        let availableIDs =
            Set(
                capabilities
                    .filter(\.isAvailable)
                    .map(\.id)
            )

        var seen = Set<String>()
        var results: [CapabilityGapResolution] = []

        for step in graph.steps
            where !step.isAvailable {
            guard
                !seen.contains(
                    step.capabilityID
                )
            else {
                continue
            }

            seen.insert(
                step.capabilityID
            )

            guard let capability =
                registry[
                    step.capabilityID
                ]
            else {
                continue
            }

            let strategyCandidates =
                candidateStrategies(
                    for: step,
                    availableIDs:
                        availableIDs
                )

            let kind: CapabilityGapKind
            if !strategyCandidates.isEmpty {
                kind = .strategy
            } else if capability.risk ==
                .external {
                kind = .integration
            } else {
                kind = .code
            }

            let reason =
                "Task Graph step '\(step.title)' için " +
                step.capabilityID +
                " gerekiyor ancak provider available değil."

            let researchGoal =
                researchGoal(
                    for: capability,
                    step: step,
                    kind: kind
                )

            let developerBrief =
                buildDeveloperBrief(
                    graph: graph,
                    step: step,
                    capability: capability,
                    kind: kind,
                    strategyCandidates:
                        strategyCandidates
                )

            results.append(
                CapabilityGapResolution(
                    capabilityID:
                        capability.id,
                    capabilityName:
                        capability.name,
                    kind: kind,
                    reason: reason,
                    candidateCapabilityIDs:
                        strategyCandidates,
                    researchGoal:
                        researchGoal,
                    developerBrief:
                        developerBrief
                )
            )
        }

        return results
    }

    private func candidateStrategies(
        for step: AgentTaskGraphStep,
        availableIDs: Set<String>
    ) -> [String] {
        var candidates: [String] = []

        if step.capabilityID ==
            "browser.control" {
            if availableIDs.contains(
                "research.web"
            ) &&
               step.role ==
                .retrieve {
                candidates.append(
                    "research.web"
                )
            }
        }

        if step.capabilityID ==
            "app.workflow" {
            let observationStack = [
                "desktop.app",
                "perception.screen"
            ]

            if observationStack.allSatisfy({
                availableIDs.contains($0)
            }) {
                candidates.append(
                    contentsOf:
                        observationStack
                )
            }
        }

        if step.capabilityID ==
            "mail.work" {
            let genericUI = [
                "desktop.app",
                "desktop.control",
                "perception.screen"
            ]

            if genericUI.allSatisfy({
                availableIDs.contains($0)
            }) {
                candidates.append(
                    contentsOf:
                        genericUI
                )
            }
        }

        if step.capabilityID ==
            "photoshop.control" ||
           step.capabilityID ==
            "premiere.control" {
            let genericUI = [
                "desktop.app",
                "desktop.control",
                "perception.screen"
            ]

            if genericUI.allSatisfy({
                availableIDs.contains($0)
            }) {
                candidates.append(
                    contentsOf:
                        genericUI
                )
            }
        }

        return Array(
            Set(candidates)
        )
        .sorted()
    }

    private func researchGoal(
        for capability: AgentCapability,
        step: AgentTaskGraphStep,
        kind: CapabilityGapKind
    ) -> String {
        switch kind {
        case .knowledge:
            return
                "Bu step için gereken bilgiyi güvenilir kaynaklardan araştır ve görevin devamında kullanılabilecek doğrulanmış bilgi çıkar."

        case .strategy:
            return
                "Mevcut capability'leri kullanarak " +
                step.operation +
                " işlemini güvenli biçimde tamamlayan generic bir strategy/recipe araştır ve test planı çıkar."

        case .code:
            return
                capability.name +
                " provider'ını yerel, geri alınabilir ve doğrulanabilir biçimde eklemek için resmi platform API'lerini araştır."

        case .integration:
            return
                capability.name +
                " için resmi API/entegrasyon veya generic UI bridge seçeneklerini araştır; izin, güvenlik ve doğrulama sınırlarını çıkar."
        }
    }

    private func buildDeveloperBrief(
        graph: AgentTaskGraph,
        step: AgentTaskGraphStep,
        capability: AgentCapability,
        kind: CapabilityGapKind,
        strategyCandidates: [String]
    ) -> String {
        let strategies =
            strategyCandidates.isEmpty
                ? "Yok"
                : strategyCandidates
                    .joined(separator: ", ")

        return """
        KRALİ Capability Gap Developer Brief

        Kullanıcı hedefi:
        \(graph.objective)

        Eksik capability:
        \(capability.id) — \(capability.name)

        Gap türü:
        \(kind.rawValue)

        Blocked step:
        \(step.index): \(step.title)
        Operation: \(step.operation)
        Role: \(step.role.rawValue)

        Mevcut strategy adayları:
        \(strategies)

        Tasarım kuralları:
        - Uygulama/marka adına hard-code yazma; mümkün olduğunca generic capability veya strategy geliştir.
        - Mevcut provider başka bir işi yapılmış gibi göstermesin.
        - Dış dünyaya commit eden eylemlerde kullanıcı onay kapısı korunmalı.
        - Başarı gerçek observation/verification ile kanıtlanmalı.
        - Ana branch üzerinde doğrudan self-modification yapma; candidate branch/worktree kullan.
        - Build + Training Lab + ilgili runtime probe geçmeden capability available yapılmamalı.

        Kabul kriteri:
        Blocked step gerçek provider/strategy ile tamamlanmalı, evidence downstream step'e aktarılmalı ve verifier sahte PASS üretmemeli.
        """
    }
}
