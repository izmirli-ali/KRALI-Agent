import Foundation

enum AgentExecutionProfile: String, Codable {
    case developmentResearchMode
    case full

    static let computerControlCapabilityIDs: Set<String> = [
        "browser.control",
        "desktop.app",
        "app.workflow",
        "desktop.control",
        "system.open.url",
        "perception.screen"
    ]

    var pausedCapabilityIDs: Set<String> {
        switch self {
        case .developmentResearchMode:
            return Self.computerControlCapabilityIDs
        case .full:
            return []
        }
    }

    var allowsComputerControl: Bool {
        pausedCapabilityIDs
            .isDisjoint(
                with:
                    Self.computerControlCapabilityIDs
            )
    }

    func applies(to capability: AgentCapability) -> AgentCapability {
        guard pausedCapabilityIDs.contains(capability.id) else { return capability }
        return AgentCapability(id: capability.id, name: capability.name, summary: capability.summary, risk: capability.risk, isAvailable: false, requiresWorkspace: capability.requiresWorkspace)
    }

    func isPaused(_ id: String) -> Bool { pausedCapabilityIDs.contains(id) }
}
