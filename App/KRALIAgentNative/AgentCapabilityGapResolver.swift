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
    private let problemSolver =
        AgentProblemSolver()
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
                problemSolver
                    .candidateCapabilityIDs(
                        for: step,
                        availableCapabilities:
                            capabilities
                    )

            // Initial planning should prefer an executable generic strategy
            // before declaring a learning gap. Runtime failure resolution
            // can still escalate later if those strategies fail.
            if !strategyCandidates.isEmpty {
                continue
            }

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

    func resolveRuntimeFailures(
        graph: AgentTaskGraph,
        completedStepIndexes: Set<Int>,
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

        for step in graph.steps {
            guard
                step.isAvailable,
                !completedStepIndexes.contains(
                    step.index
                ),
                !step.requiresApproval,
                step.role != .reason,
                step.role != .verify
            else {
                continue
            }

            let dependenciesSatisfied =
                step.dependsOn.allSatisfy {
                    dependencyIndex in

                    if completedStepIndexes
                        .contains(
                            dependencyIndex
                        ) {
                        return true
                    }

                    return graph.steps
                        .first(
                            where: {
                                $0.index ==
                                    dependencyIndex
                            }
                        )?
                        .role == .reason
                }

            guard
                dependenciesSatisfied,
                !seen.contains(
                    step.capabilityID
                ),
                let capability =
                    registry[
                        step.capabilityID
                    ]
            else {
                continue
            }

            seen.insert(
                step.capabilityID
            )

            let strategyCandidates =
                problemSolver
                    .candidateCapabilityIDs(
                        for: step,
                        availableCapabilities:
                            capabilities
                    )

            let reason =
                "Provider available olmasına rağmen runtime step tamamlanamadı veya postcondition doğrulanamadı: " +
                step.capabilityID +
                " • " +
                step.operation

            let researchGoal =
                "Mevcut " +
                capability.name +
                " provider'ının neden runtime'da başarısız olduğunu kanıtla; önce mevcut provider/strategy'yi debug et, gerekirse generic recovery veya yeni provider stratejisi geliştir ve aynı postcondition'ı gerçek observation ile doğrula."

            let strategies =
                strategyCandidates.isEmpty
                    ? "Yok"
                    : strategyCandidates
                        .joined(separator: ", ")

            let developerBrief =
                """
                KRALİ Runtime Capability Failure Developer Brief

                Kullanıcı hedefi:
                \(graph.objective)

                Runtime'da başarısız capability:
                \(capability.id) — \(capability.name)

                Step:
                \(step.index): \(step.title)
                Operation: \(step.operation)
                Role: \(step.role.rawValue)

                Mevcut strategy adayları:
                \(strategies)

                Sorun:
                \(reason)

                Çözüm kuralları:
                - Önce problemi, gözlemleri ve başarısız postcondition'ı tanımla; doğrudan kod satırı aramaya başlama.
                - En az iki makul çözüm stratejisini değerlendir; mevcut capability kombinasyonu problemi çözebiliyorsa yeni provider yazma.
                - Capability zaten available ise önce mevcut provider'ı ve postcondition verifier'ı debug et.
                - Uygulama/marka adına hard-code yazma; hatayı genel resolver/provider/strategy seviyesinde çöz.
                - Başarı gerçek observation/verification ile kanıtlanmadan PASS üretme.
                - Dış dünyaya commit eden eylemlerde kullanıcı onayı korunmalı.
                - Candidate branch/worktree kullan; ana branch'i doğrudan değiştirme.
                - Build + regression + mümkünse runtime probe geçmeden düzeltmeyi available/healthy sayma.

                Kabul kriteri:
                Aynı sınıftaki bilinmeyen hedeflerde de provider doğru hedefi çözebilmeli; başarısız runtime step tamamlanmalı ve verifier gerçek evidence ile PASS verebilmeli.
                """

            results.append(
                CapabilityGapResolution(
                    capabilityID:
                        capability.id,
                    capabilityName:
                        capability.name,
                    kind: .strategy,
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

        Çözüm kuralları:
        - Önce problemi ve kabul kriterini tanımla; kod değişikliği yalnız seçilen çözüm stratejisi gerçekten gerektiriyorsa yapılmalı.
        - Mevcut capability'leri bileştirerek çözüm üretilebiliyorsa yeni provider yazma.
        - En az iki çözüm alternatifi değerlendir ve neden seçildiğini kaydet.
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
