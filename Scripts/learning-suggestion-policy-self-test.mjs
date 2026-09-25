import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = (path) => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
const store = source("App/KRALIAgentNative/AgentLearningSuggestionStore.swift");
const queue = source("App/KRALIAgentNative/AgentLearningQueue.swift");
const engine = source("App/KRALIAgentNative/AgentEngine.swift");
const sidebar = source("App/KRALIAgentNative/ConversationSidebarView.swift");

assert.match(store, /restoreVisibleSuggestions/);
assert.match(store, /case proposed, deferred, suppressed, approved, completed/);
assert.match(store, /fingerprint/);
assert.match(queue, /userApproved == true/);
assert.match(engine, /func acceptLearningSuggestion/);
assert.match(engine, /userApproved: true/);
assert.match(engine, /func deferLearningSuggestion/);
assert.match(engine, /func suppressLearningSuggestion/);
assert.match(sidebar, /GELİŞTİRME ÖNERİLERİ/);
assert.match(sidebar, /Geliştir/);
assert.match(sidebar, /Şimdilik geliştirme/);
assert.doesNotMatch(engine.match(/observeLearningSuggestions\(currentCapabilityGaps\)[\s\S]{0,300}/)?.[0] ?? "", /runDeveloperAgent/);
console.log("learning_suggestion_policy_self_test_ok");
