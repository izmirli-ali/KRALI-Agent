import Foundation

enum AgentCapabilityRisk { case reasoning }
struct AgentCapability {
    let id: String; let name: String; let summary: String; let risk: AgentCapabilityRisk; let isAvailable: Bool; let requiresWorkspace: Bool
}

@main struct DevelopmentResearchProfileSelfTest {
    static func check(_ value: Bool, _ name: String) { if !value { fputs("FAIL: \(name)\n", stderr); exit(1) } }
    static func main() {
        let profile = AgentExecutionProfile.developmentResearchMode
        check(profile.isPaused("browser.control"), "browser paused")
        check(profile.isPaused("desktop.app"), "desktop paused")
        check(profile.isPaused("app.workflow"), "workflow paused")
        check(profile.isPaused("desktop.control"), "desktop control paused")
        check(profile.isPaused("system.open.url"), "url opening paused")
        check(profile.isPaused("perception.screen"), "screen perception paused")
        check(!profile.allowsComputerControl, "research mode blocks computer control")
        check(!profile.isPaused("research.web"), "research retained")
        check(!profile.isPaused("files.search"), "read-only files retained")
        let full = AgentExecutionProfile.full
        check(!full.isPaused("desktop.app"), "future re-enable")
        check(full.allowsComputerControl, "full mode can re-enable later")
        print("development_research_profile_self_test_ok")
        print("paused=browser.control,desktop.app,app.workflow")
        print("research_web=available")
        print("computer_control_request=paused_not_gap")
    }
}
