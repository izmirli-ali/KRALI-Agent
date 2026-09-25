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
  engine.includes("verification.state != .attention"),
  "engine promotes only non-attention research proposals to suggestions"
);

ok(
  /if\s+suggestion\.source\s*==\s*\.capabilityGap/.test(engine) &&
  /guard\s+suggestion\.source\s*==\s*\.research\s+else/.test(engine) &&
  engine.includes("boundedDevelopmentTaskCompiler"),
  "approval path supports capability gaps plus bounded research suggestions only"
);

ok(
  sidebar.includes('sectionLabel("GELİŞTİRME ÖNERİLERİ")') &&
  sidebar.includes('Button("Geliştir")') &&
  sidebar.includes('Button("Şimdilik geliştirme")') &&
  sidebar.includes("suppressDevelopmentSuggestion"),
  "sidebar exposes multiple suggestion controls"
);

ok(
  store.includes("func seededFallbackSuggestions") &&
  store.includes("KRALİ araştırma kalitesini iyileştir") &&
  store.includes("KRALİ arayüz önerilerini iyileştir") &&
  store.includes("KRALİ eğitim raporu analizini iyileştir") &&
  engine.includes("seededFallbackSuggestions") &&
  engine.includes("if developmentSuggestions.isEmpty"),
  "empty suggestion storage must receive deterministic, non-executing fallback cards"
);

ok(
  sidebar.includes("ProgressView(") &&
  sidebar.includes('"İnceleme gerekiyor"') &&
  sidebar.includes("candidateBranch"),
  "sidebar shows deterministic progress and review-required candidate state"
);

ok(
  sidebar.includes("canDevelopSuggestion") &&
  sidebar.includes("bounded scope"),
  "sidebar enables only suggestions accepted by the bounded compiler"
);

ok(
  bridge.includes("fraction: 0.95") &&
  bridge.includes('title: "Candidate hazır"'),
  "candidate-ready progress is 95 percent"
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

console.log("development_suggestions_ui_self_test_ok");
console.log("research_to_suggestion=bounded_after_approval");
console.log("candidate_progress=95");
console.log("release_progress=100");
