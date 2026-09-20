import Foundation

struct AgentRouteBuilder {
    func build(
        goal: AgentGoalProfile,
        capabilities: [AgentCapability],
        learningPlans: [CapabilityLearningPlan],
        requiresVerification: Bool
    ) -> [String] {
        var route = ["Core", "Goal", "Context"]

        let actionCapabilities = capabilities.filter {
            $0.id != "core.reasoning" &&
            $0.id != "context.local"
        }

        if !actionCapabilities.isEmpty {
            route.append("Plan")
        }

        let stages = actionCapabilities.compactMap(stageName(for:))
        for stage in stages where !route.contains(stage) {
            route.append(stage)
        }

        if !learningPlans.isEmpty {
            route.append("Learn")
        }

        if requiresVerification {
            route.append("Verify")
        }

        route.append("Response")
        return route
    }

    private func stageName(
        for capability: AgentCapability
    ) -> String? {
        if capability.id.hasPrefix("files.") {
            return "Files"
        }

        if capability.id == "perception.media" {
            return "Perception"
        }

        if capability.id == "research.web" {
            return "Research"
        }

        if capability.id == "browser.control" {
            return "Browser"
        }

        if capability.id == "perception.screen" {
            return "Screen"
        }

        if capability.id == "desktop.control" {
            return "Desktop"
        }

        if capability.id == "photoshop.control" {
            return "Photoshop"
        }

        if capability.id == "premiere.control" {
            return "Premiere"
        }

        if capability.id == "mail.work" {
            return "Mail"
        }

        if capability.id == "memory.local" {
            return "Memory"
        }

        if capability.id.hasPrefix("speech.") {
            return "Speech"
        }

        return nil
    }
}
