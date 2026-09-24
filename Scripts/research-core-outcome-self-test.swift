import Foundation

enum AgentCapabilityRisk: String, Hashable {
    case reasoning
    case readOnly
    case reversibleWrite
    case external
}

struct AgentCapability: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let risk: AgentCapabilityRisk
    let isAvailable: Bool
    let requiresWorkspace: Bool
}

enum AgentGoalOutcome: String, Hashable {
    case research
    case explain
    case open
}

struct AgentGoalProfile: Hashable {
    let summary: String
    let outcomes: Set<AgentGoalOutcome>
    let requiredCapabilityIDs: Set<String>
    let isCompound: Bool
}

struct AgentSemanticMission {
    let outcomes: [String]
}

@main
struct ResearchCoreOutcomeSelfTest {
    static func check(
        _ value: @autoclosure () -> Bool,
        _ label: String
    ) {
        guard value() else {
            fputs("FAIL: \(label)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let profile =
            AgentExecutionProfile
                .developmentResearchMode

        let goal = AgentGoalProfile(
            summary: "public web hedefini araştır",
            outcomes: [
                .research,
                .explain
            ],
            requiredCapabilityIDs: [
                "core.reasoning",
                "context.local",
                "research.web",
                "browser.control"
            ],
            isCompound: true
        )

        let planner = AgentOutcomePlanner()
        let contract = planner.makeContract(
            userInput:
                "https://example.com sitesini detaylı incele ve araştır",
            goal: goal,
            mission: nil,
            profile: profile
        )

        check(
            contract.requirements.count == 1,
            "research core produces one public-information requirement"
        )

        guard
            let requirement =
                contract.requirements.first
        else {
            fputs("FAIL: missing requirement\n", stderr)
            exit(1)
        }

        check(
            requirement.kind ==
                .retrievePublicInformation,
            "URL research is information retrieval, not GUI navigation"
        )
        check(
            requirement.preferredCapabilityIDs ==
                ["research.web"],
            "research.web is the only preferred research capability"
        )
        check(
            requirement.acceptableCapabilityIDs ==
                ["research.web"],
            "computer-control fallbacks removed from research contract"
        )
        check(
            contract.instrumentalCapabilityIDs
                .isDisjoint(
                    with:
                        AgentExecutionProfile
                            .computerControlCapabilityIDs
                ),
            "computer-control capabilities are not instrumental research dependencies"
        )

        let resolution = planner.resolve(
            contract: contract,
            capabilities: [
                AgentCapability(
                    id: "research.web",
                    name: "Web araştırma",
                    summary: "public web research",
                    risk: .external,
                    isAvailable: true,
                    requiresWorkspace: false
                )
            ]
        )

        check(
            resolution.isFullyCovered,
            "research.web alone fully covers public research"
        )
        check(
            resolution.chosenStrategies.count == 1,
            "one research strategy selected"
        )
        check(
            resolution.chosenStrategies.first?
                .capabilityIDs ==
                ["research.web"],
            "selected research strategy uses research.web only"
        )
        check(
            resolution.chosenStrategies
                .allSatisfy {
                    Set($0.capabilityIDs)
                        .isDisjoint(
                            with:
                                AgentExecutionProfile
                                    .computerControlCapabilityIDs
                        )
                },
            "selected strategies contain no computer control"
        )

        print("research_core_outcome_self_test_ok")
    }
}
