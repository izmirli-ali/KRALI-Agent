#!/usr/bin/env node
import fs from "node:fs";

function read(path) {
  return fs.readFileSync(path, "utf8");
}

function ok(condition, message) {
  if (!condition) throw new Error(message);
}

const version = read("VERSION").trim();
const project = read("App/KRALIAgentNative.xcodeproj/project.pbxproj");
const engine = read("App/KRALIAgentNative/AgentEngine.swift");
const gate = read("App/KRALIAgentNative/AgentPublicResearchQualityGate.swift");
const compiler = read("App/KRALIAgentNative/AgentBoundedDevelopmentTaskCompiler.swift");
const missionNormalizer = read("App/KRALIAgentNative/AgentMissionNormalizer.swift");
const sourceReader = read("App/KRALIAgentNative/AgentWebSourceReader.swift");
const webResearch = read("App/KRALIAgentNative/AgentWebResearch.swift");
const executionProfile = read("App/KRALIAgentNative/AgentExecutionProfile.swift");
const suggestionStore = read("App/KRALIAgentNative/AgentDevelopmentSuggestionStore.swift");
const missionRouter = read("App/KRALIAgentNative/AgentMissionRouter.swift");
const contentView = read("App/KRALIAgentNative/ContentView.swift");
const workflow = read(".github/workflows/krali-ci.yml");
const marketingVersions = [...project.matchAll(/MARKETING_VERSION = ([^;]+);/g)].map((match) => match[1]);
const buildVersions = [...project.matchAll(/CURRENT_PROJECT_VERSION = (\d+);/g)].map((match) => match[1]);

ok(/^\d+\.\d+\.\d+$/.test(version), "VERSION must use semantic major.minor.patch format.");
ok(marketingVersions.length > 0 && marketingVersions.every((item) => item === version), "Xcode marketing version is inconsistent with VERSION.");
ok(buildVersions.length > 0 && buildVersions.every((item) => Number(item) > 0), "Xcode build version must be a positive integer.");

ok(
  project.includes("AgentPublicResearchQualityGate.swift in Sources") &&
    project.includes("AgentPublicResearchQualityGate.swift */ = {isa = PBXFileReference"),
  "Public research quality gate is not included in the Xcode target."
);
ok(
  engine.includes("AgentPublicResearchQualityGate().assess(") &&
    engine.includes("let qualityGate = AgentPublicResearchQualityGate()"),
  "Research quality gate is not wired into both public research paths."
);
ok(
  engine.includes("let hasEvidence = quality.isSufficient") &&
    engine.includes("guard quality.isSufficient else"),
  "Public research can be marked successful without quality.isSufficient."
);
ok(
  engine.includes("quality.shortfall") &&
    engine.includes("Kanıt yetersiz; kesin sonuç üretmedim."),
  "Research quality shortfalls are not visible to the user."
);

ok(
  missionNormalizer.includes("let explicitPublicResearch") &&
    missionNormalizer.includes("!explicitPublicResearch &&") &&
    missionNormalizer.includes('"desktop.control"') &&
    missionNormalizer.includes('"browser.control"'),
  "Explicit public research can still inherit stale Desktop, file-search, or browser-control steps."
);

ok(
  engine.includes("let researchQualityFailure") &&
    engine.includes("Araştırma kalite kapısı yetersiz kanıt tespit etti") &&
    engine.includes("reply:\n                    reply,"),
  "A research-quality shortfall can still become a browser/Desktop capability gap or hide its evidence report."
);

ok(
  sourceReader.includes("let evidence = await withTaskGroup(") &&
    sourceReader.includes("selectedSources") &&
    sourceReader.includes("domain-diverse pages concurrently"),
  "Research source reads lost their bounded parallel execution contract."
);

ok(
  webResearch.includes("let providerOutcomes = await withTaskGroup(") &&
    webResearch.includes("case arxiv") &&
    webResearch.includes("case crossref") &&
    webResearch.includes("case openReview"),
  "General, academic, and review research providers must run in the same bounded parallel search round."
);

ok(
  missionRouter.includes("func classifyCoreIntent") &&
    engine.includes("coreGoalProfile(") &&
    engine.includes("activeCoreIntent = coreIntentDecision.intent"),
  "Conversation, research, and development no longer have an explicit top-level routing contract."
);

ok(
  contentView.includes('Text("Çekirdek yetenekler")') &&
    contentView.includes('quickButton(\n                    "Detaylı araştır"') &&
    !contentView.includes('quickButton(\n                    "Ekran görüntülerini toparla"'),
  "The primary UI still exposes the retired Desktop/file workflow instead of the three core capabilities."
);

ok(
  engine.includes("executionProfile: AgentExecutionProfile = .conversationResearchCore") &&
    executionProfile.includes("case conversationResearchCore") &&
    executionProfile.includes("retiredAutomationCapabilityIDs") &&
    executionProfile.includes('"files.search"'),
  "The default core profile still exposes retired desktop or local-file automation."
);

ok(
  engine.includes("Retired local automation blocked in conversation research core"),
  "Retired local automation must also be blocked on direct intent execution."
);

ok(
  engine.includes("prunePausedCapabilitySuggestions") &&
    suggestionStore.includes("func prunePausedCapabilitySuggestions") &&
    suggestionStore.includes("profile.pausedCapabilityIDs"),
  "Persisted suggestions for retired automation must be removed from the development queue."
);

ok(
  gate.includes("independentDomainCount >= 2") &&
    gate.includes("highQualitySourceCount >= 1") &&
    gate.includes("requiresPreferredPrimarySource") &&
    gate.includes("potentialContradictionCount"),
  "Research quality gate lost its diversity, authority, primary-source, or contradiction safeguards."
);

ok(
  compiler.includes("protectedTerms") &&
    compiler.includes("approval") &&
    compiler.includes("computer-control") &&
    compiler.includes('allowedScope: ["App/KRALIAgentNative/ConversationSidebarView.swift"]'),
  "Bounded development compiler no longer protects approval/control scope or view-only usability scope."
);

ok(
  workflow.includes("node Scripts/system-integrity-self-test.mjs"),
  "CI does not run the system integrity self-test."
);

console.log("System integrity self-test passed.");
