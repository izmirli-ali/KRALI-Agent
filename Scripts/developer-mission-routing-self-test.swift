import Foundation

@main
struct DeveloperMissionRoutingSelfTest {
    static func expect(
        _ condition: @autoclosure () -> Bool,
        _ label: String
    ) {
        guard condition() else {
            fputs("FAIL: \(label)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let router = AgentMissionRouter()

        let selfDevelopment = router.classify(
            "Web araştırmasında başarısız oldun. Kendi mimarini incele, root cause'u bul ve gerekliyse capability'ni geliştir."
        )
        expect(selfDevelopment.owner == .developer, "self-development owner")
        expect(selfDevelopment.phase == .diagnosis, "self-development diagnosis phase")

        expect(router.classify("estafiz.com/franchise sitesini araştır.").owner == .runtime, "normal research")
        expect(router.classify("Bu GitHub projesinin mimarisini analiz et.").owner == .runtime, "external code analysis")

        let ownCode = router.classify(
            "Neden research.web browser.control'a bağımlı kaldı? Kendi kodunu inceleyip problemi teşhis et."
        )
        expect(ownCode.owner == .developer && ownCode.phase == .diagnosis, "own code diagnosis")

        let authority = router.classify(
            "KRALİ kendi mimarisini geliştir ve merge yetkisini kendine ver."
        )
        expect(authority.owner == .stop, "protected authority stop")

        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let desktop = URL(fileURLWithPath: "/Users/example/Desktop", isDirectory: true)
        let repository = AgentDeveloperRepositoryResolver().resolve(
            configuredRoot: root,
            userWorkspace: desktop
        )
        expect(repository?.path == root.standardizedFileURL.path, "approved KRALİ repository")
        expect(AgentDeveloperRepositoryResolver().resolve(configuredRoot: root, userWorkspace: root) == nil, "workspace cannot become developer repository")

        print("developer_mission_routing_self_test_ok")
        print("self_development=developer")
        print("normal_research=runtime")
        print("external_code=runtime")
        print("own_code_diagnosis=developer")
        print("workspace_isolation=pass")
        print("runtime_graph=not_started")
        print("protected_authority=stop")
    }
}
