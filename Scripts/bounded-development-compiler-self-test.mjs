#!/usr/bin/env node
import fs from "node:fs";

function read(path) {
  return fs.readFileSync(path, "utf8");
}

function ok(value, message) {
  if (!value) {
    throw new Error(message);
  }
}

const compiler = read("App/KRALIAgentNative/AgentBoundedDevelopmentTaskCompiler.swift");
const engine = read("App/KRALIAgentNative/AgentEngine.swift");
const sidebar = read("App/KRALIAgentNative/ConversationSidebarView.swift");
const store = read("App/KRALIAgentNative/AgentDevelopmentSuggestionStore.swift");
const verifier = read("Scripts/research-development-verifier.command");
const bridge = read("App/KRALIAgentNative/AgentDeveloperBridge.swift");

for (const allowed of [
  "AgentResearchQueryPlanner.swift",
  "AgentDevelopmentResearch.swift",
  "AgentWebResearch.swift",
  "AgentWebSourceReader.swift",
  "AgentLocalIntelligence.swift"
]) {
  ok(
    compiler.includes(allowed),
    "research compiler allowed scope missing: " + allowed
  );
}

for (const protectedPath of [
  "AgentEngine.swift",
  "AgentMissionRouter.swift",
  "AgentExecutionProfile.swift",
  "AgentDeveloperBridge.swift",
  "AgentLearningQueue.swift",
  "AgentDevelopmentSuggestionStore.swift",
  "AgentDesktopControl.swift",
  "UpdateController.swift",
  "run-developer-agent.command"
]) {
  ok(
    compiler.includes(protectedPath),
    "protected path missing from bounded compiler policy: " + protectedPath
  );
}

const allowedBlock = compiler.slice(
  compiler.indexOf("private let researchAllowedScope"),
  compiler.indexOf("private let researchForbiddenScope")
);

ok(
  !allowedBlock.includes("AgentEngine.swift") &&
  !allowedBlock.includes("AgentMissionRouter.swift") &&
  !allowedBlock.includes("AgentDeveloperBridge.swift"),
  "bounded research allowed scope contains authority/runtime files"
);

ok(
  compiler.includes("suggestion.source == .research") &&
  compiler.includes("AgentSourceRevisionPolicy") &&
  compiler.includes("sourceRevision ==") &&
  compiler.includes("currentSourceRevision"),
  "research task compilation requires research source and exact revision"
);

for (const term of [
  "browser.control",
  "desktop.control",
  "app.workflow",
  "system.open.url",
  "perception.screen",
  "approval",
  "security",
  "merge",
  "release"
]) {
  ok(
    compiler.includes('"' + term + '"'),
    "protected semantic term missing: " + term
  );
}

ok(
  compiler.includes("Scripts/research-development-verifier.command") &&
  compiler.includes("requiresPhysicalAction") &&
  compiler.includes("requiresMainAccess"),
  "compiled task lacks deterministic verification/safety metadata"
);

ok(
  verifier.includes("self-development-research-policy-self-test.py") &&
  verifier.includes("development-research-quality-self-test.swift") &&
  verifier.includes("research_development_verifier_ok"),
  "bounded research verifier does not run research regressions"
);

ok(
  engine.includes("boundedDevelopmentTaskCompiler") &&
  engine.includes("try boundedDevelopmentTaskCompiler") &&
  engine.includes("developmentSuggestionID: id"),
  "approved research suggestion is not routed through bounded compiler"
);

ok(
  engine.includes("pendingDeveloperSuggestionID") &&
  engine.includes("developmentSuggestionID: UUID? = nil") &&
  engine.includes("updateSuggestionDevelopmentState"),
  "suggestion lifecycle is not preserved through Developer Agent"
);

ok(
  sidebar.includes("canDevelopSuggestion") &&
  !sidebar.includes(".disabled(\n                        !suggestion\n                            .isExecutableCapabilityGap"),
  "sidebar still gates Develop only on capability gaps"
);

ok(
  store.includes("func observeResearch") &&
  store.includes("updateSuggestionDevelopmentState"),
  "research suggestion lifecycle store hooks missing"
);

ok(
  bridge.includes("fraction: 0.95") &&
  bridge.includes('title: "Candidate hazır"') &&
  bridge.includes("Lead / ChatGPT incelemesi gerekiyor"),
  "candidate must stop at human review stage"
);

ok(
  !compiler.includes("git merge") &&
  !compiler.includes("push origin main") &&
  !compiler.includes("push origin develop"),
  "bounded compiler contains protected-branch release behavior"
);

console.log("bounded_development_compiler_self_test_ok");
console.log("dynamic_research_scope=fixed_allowlist");
console.log("research_suggestion_approval=required");
console.log("candidate_release=human_review_required");
