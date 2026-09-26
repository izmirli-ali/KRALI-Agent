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
const perception = read("App/KRALIAgentNative/AgentScreenPerception.swift");
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

for (const field of [
  "captureScope",
  "capturedApplicationBundleIdentifier",
  "capturedWindowTitle",
  "capturedWindowID",
  "recognizedText"
]) {
  ok(perception.includes(field), `Screen perception evidence field is missing: ${field}`);
}

ok(
  workflow.includes("node Scripts/system-integrity-self-test.mjs"),
  "CI does not run the system integrity self-test."
);

console.log("System integrity self-test passed.");
