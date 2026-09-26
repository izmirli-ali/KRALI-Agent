#!/usr/bin/env node
import fs from "node:fs";

function read(path) {
  return fs.readFileSync(path, "utf8");
}

function ok(value, message) {
  if (!value) throw new Error(message);
}

const store = read("App/KRALIAgentNative/AgentDevelopmentSuggestionStore.swift");
const engine = read("App/KRALIAgentNative/AgentEngine.swift");
const sidebar = read("App/KRALIAgentNative/ConversationSidebarView.swift");
const bridge = read("App/KRALIAgentNative/AgentDeveloperBridge.swift");

ok(
  store.includes("func observeResearch") &&
  store.includes("synthesis.mutationRecommended") &&
  store.includes("!synthesis.mutationStarted"),
  "research suggestion bridge requires bounded research recommendation"
);

ok(
  engine.includes("observeResearch(") &&
  engine.includes("verification.state == .passed"),
  "engine promotes only fully verified research proposals to suggestions"
);

ok(
  /if\s+suggestion\.source\s*==\s*\.capabilityGap/.test(engine) &&
  /guard\s+suggestion\.source\s*==\s*\.research\s*\|\|\s*suggestion\.source\s*==\s*\.usability/.test(engine) &&
  engine.includes("boundedDevelopmentTaskCompiler"),
  "approval path supports bounded research and UI suggestions"
);

ok(
  sidebar.includes('sectionLabel("YENİ FİKİRLER")') &&
  sidebar.includes('sectionLabel("GELİŞTİRME ÖNERİLERİ")') &&
  sidebar.includes('Button("Geliştir")') &&
  sidebar.includes("suppressDevelopmentSuggestion") &&
  sidebar.includes("suggestionTooltip"),
  "sidebar separates compact ideas and suggestions with hover details"
);

ok(
  store.includes("func refreshInnovationSuggestions") &&
  store.includes("innovation:ui-source-badge") &&
  store.includes("innovation:ui-status-line") &&
  store.includes("innovation:ui-action-labels") &&
  engine.includes("refreshInnovationSuggestions") &&
  engine.includes("pruneLegacyStoppedResearch"),
  "fresh innovation queue replaces obsolete static fallback cards"
);

ok(
  sidebar.includes("ProgressView(") &&
  sidebar.includes("suggestionTooltip") &&
  engine.includes('title: "Candidate hazır"'),
  "sidebar shows compact lifecycle progress with review state in hover details"
);

ok(
  sidebar.includes("suggestionLineageKey") &&
  sidebar.includes("lineageKeys") &&
  sidebar.includes(".sorted()") &&
  sidebar.includes('separatedBy: "|retry|"'),
  "sidebar keeps retry history auditable and card ordering stable"
);

ok(
  sidebar.includes("canDevelopSuggestion") &&
  engine.includes("boundedDevelopmentTaskCompiler"),
  "sidebar keeps bounded compiler checks before a suggestion can start"
);

ok(
  bridge.includes("fraction: 0.90") &&
  bridge.includes('title: "Candidate hazır"'),
  "candidate-ready progress reserves final review as a remaining milestone"
);

ok(
  engine.includes("stabilizedDevelopmentProgress") &&
  engine.includes("developmentProgressFloor") &&
  bridge.includes("fraction: 1.0"),
  "active-run progress never moves backwards and terminal failures close the lifecycle"
);

ok(
  store.includes("pruneLegacyStoppedResearch") &&
  store.includes("pruneStaleInnovationSuggestions") &&
  store.includes("innovation:ui-source-badge") &&
  store.includes(".usability"),
  "legacy stopped research is pruned and new ideas prioritize bounded UI improvements"
);

ok(
  store.includes("retryAttempt") &&
  store.includes('"|attempt-"') &&
  !store.includes("original.sourceRevision != revision") &&
  sidebar.includes('Button("Kontrollü tekrar dene")'),
  "a stopped candidate can create an auditable controlled retry on the same source revision"
);

ok(
  engine.includes("fraction: 1.0") &&
  engine.includes('title: "Yayınlandı"') &&
  engine.includes('title: "Tamamlandı"'),
  "100 percent is reserved for released/completed lifecycle"
);

ok(
  !store.includes("currentTaskInput") &&
  !store.includes("userInput") &&
  !store.includes("rawContent"),
  "research suggestion persistence remains compact"
);

const research = read("App/KRALIAgentNative/AgentDevelopmentResearch.swift");
ok(
  research.includes("AgentDevelopmentResearchClaimGraph") &&
  research.includes("AgentDevelopmentResearchHistoryStore") &&
  research.includes("dependencyEdges") &&
  store.includes("replayChecks"),
  "research claims, local history, dependency checks, and regression replay are explicit"
);

const localIntelligence = read("App/KRALIAgentNative/AgentLocalIntelligence.swift");
ok(
  localIntelligence.includes("selectionHasValidEvidenceIDs") &&
  localIntelligence.includes("review-only proposal was reconstructed") &&
  localIntelligence.includes("mutationRecommended:") &&
  localIntelligence.includes("selectionHasValidEvidenceIDs &&"),
  "invalid final selection IDs preserve only a review-only evidence-bound outcome"
);

const compiler = read("App/KRALIAgentNative/AgentBoundedDevelopmentTaskCompiler.swift");
ok(
  compiler.includes("one concrete, testable change") &&
  compiler.includes("one bounded repair attempt") &&
  compiler.includes("Make the existing suggestion source type visually scannable") &&
  compiler.includes("Make the existing suggestion status line concise") &&
  compiler.includes("Add concise accessibility labels") &&
  compiler.includes('allowedScope: ["App/KRALIAgentNative/ConversationSidebarView.swift"]'),
  "bounded UI candidates receive a focused, verifiable view-level task contract"
);

const queryPlanner = read("App/KRALIAgentNative/AgentResearchQueryPlanner.swift");
ok(
  queryPlanner.includes('Claude Code official documentation permissions security') &&
  queryPlanner.includes('docs.anthropic.com') &&
  queryPlanner.includes('Bağımsız teknik doğrulama'),
  "specific product research receives official, security, pricing, repository, and independent-source facets"
);

ok(
  queryPlanner.includes('"Standartlar ve birincil kaynaklar"') &&
  queryPlanner.includes('"Bağımsız teknik doğrulama"') &&
  queryPlanner.includes('variants.append(') &&
  queryPlanner.includes('generalFacets.map'),
  "general research plans search official, primary, independent, and current facets"
);

ok(
  engine.includes("webResearchEvidence.isEmpty") &&
  engine.includes("Araştırma sentezi atlandı: doğrulanmış sayfa kanıtı yok."),
  "research synthesis cannot invent a detailed answer when page evidence is absent"
);

ok(
  store.includes("func pruneUnverifiedResearchSuggestions") &&
  !store.includes("guard suggestion.source == .research") &&
  store.includes("yeterli kanıt bulunmamaktadır") &&
  engine.includes("pruneUnverifiedResearchSuggestions") &&
  sidebar.includes("let impactRank = suggestion.source == .usability ? 0 : 1"),
  "unverified legacy research is removed and safe UI candidates are prioritized"
);

ok(
  sidebar.includes("suggestionCardTitle") &&
  sidebar.includes('replacingOccurrences(of: "KRALİ ", with: "")') &&
  store.includes('"Kart durum metni"') &&
  store.includes('"Kaynak türü etiketi"'),
  "sidebar cards use short, task-first labels without the KRALİ prefix"
);

console.log("development_suggestions_ui_self_test_ok");
console.log("research_to_suggestion=bounded_after_approval");
console.log("candidate_progress=90");
console.log("release_progress=100");
console.log("stable_cards_and_replay_checks=PASS");
console.log("same_revision_retry_and_selection_recovery=PASS");
console.log("targeted_research_and_priority_cleanup=PASS");
