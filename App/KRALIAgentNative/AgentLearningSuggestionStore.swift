import Foundation

enum AgentLearningSuggestionState: String, Codable, Hashable, Sendable {
    case proposed, deferred, suppressed, approved, completed
}

/// Compact, privacy-preserving proposal metadata. It intentionally carries no
/// user prompt, file contents, screenshots, web dumps or other raw evidence.
struct AgentLearningSuggestion: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let fingerprint: String
    let capabilityID: String
    let capabilityName: String
    let kind: CapabilityGapKind
    let reason: String
    let researchGoal: String
    let learningPath: CapabilityLearningPath?
    var occurrenceCount: Int
    let createdAt: Date
    var updatedAt: Date
    var state: AgentLearningSuggestionState
    let appVersion: String
    let provenanceID: String
}

struct AgentLearningSuggestionStore {
    private let key = "krali.learning.suggestions.v1"

    func load() -> [AgentLearningSuggestion] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let suggestions = try? JSONDecoder().decode([AgentLearningSuggestion].self, from: data) else { return [] }
        return suggestions
    }

    func save(_ suggestions: [AgentLearningSuggestion]) {
        guard let data = try? JSONEncoder().encode(suggestions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func observe(gaps: [CapabilityGapResolution], existing: [AgentLearningSuggestion], appVersion: String) -> [AgentLearningSuggestion] {
        var suggestions = existing
        for gap in gaps where !gap.reason.localizedCaseInsensitiveContains("foreground") {
            let fingerprint = fingerprint(for: gap.capabilityID, kind: gap.kind)
            if let index = suggestions.firstIndex(where: { $0.fingerprint == fingerprint }) {
                suggestions[index].occurrenceCount += 1
                suggestions[index].updatedAt = Date()
                if suggestions[index].state == .deferred && suggestions[index].occurrenceCount >= 3 {
                    suggestions[index].state = .proposed
                }
                continue
            }
            suggestions.append(makeSuggestion(gap: gap, fingerprint: fingerprint, appVersion: appVersion, provenanceID: "capability-gap"))
        }
        save(suggestions)
        return suggestions
    }

    /// Guarantees a useful first-run UI without reviving a previously suppressed card.
    func restoreVisibleSuggestions(existing: [AgentLearningSuggestion], appVersion: String) -> [AgentLearningSuggestion] {
        guard !existing.contains(where: { $0.state == .proposed || $0.state == .approved }) else { return existing }
        var suggestions = existing
        for fallback in fallbackGaps where !suggestions.contains(where: { $0.fingerprint == fallback.fingerprint }) {
            suggestions.append(makeSuggestion(gap: fallback.gap, fingerprint: fallback.fingerprint, appVersion: appVersion, provenanceID: "fallback-v1"))
        }
        save(suggestions)
        return suggestions
    }

    func update(_ suggestions: [AgentLearningSuggestion], id: UUID, state: AgentLearningSuggestionState) -> [AgentLearningSuggestion] {
        var updated = suggestions
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return updated }
        updated[index].state = state
        updated[index].updatedAt = Date()
        save(updated)
        return updated
    }

    private func fingerprint(for capabilityID: String, kind: CapabilityGapKind) -> String { "learning-suggestion-v1|\(capabilityID)|\(kind)" }

    private func makeSuggestion(gap: CapabilityGapResolution, fingerprint: String, appVersion: String, provenanceID: String) -> AgentLearningSuggestion {
        let now = Date()
        return AgentLearningSuggestion(id: UUID(), fingerprint: fingerprint, capabilityID: gap.capabilityID, capabilityName: gap.capabilityName, kind: gap.kind, reason: gap.reason, researchGoal: gap.researchGoal, learningPath: gap.learningPath, occurrenceCount: 1, createdAt: now, updatedAt: now, state: .proposed, appVersion: appVersion, provenanceID: provenanceID)
    }

    private var fallbackGaps: [(fingerprint: String, gap: CapabilityGapResolution)] {
        let gap = CapabilityGapResolution(capabilityID: "research.quality", capabilityName: "Araştırma kalitesi", kind: .knowledge, reason: "Kaynak değerlendirme ve öneri görünürlüğü düzenli olarak doğrulanmalı.", candidateCapabilityIDs: [], researchGoal: "Araştırma bulgularını kaynak ve risk bilgisiyle değerlendiren kontrollü bir akış tasarla.", developerBrief: "Bounded research-quality proposal only. Do not merge, push, control apps, or perform external actions.", learningPath: nil)
        return [(fingerprint(for: gap.capabilityID, kind: gap.kind), gap)]
    }
}
