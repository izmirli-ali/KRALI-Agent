#!/usr/bin/env node
import fs from "node:fs";

function read(path) {
  return fs.readFileSync(path, "utf8");
}

function ok(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const engine = read("App/KRALIAgentNative/AgentEngine.swift");
const queue = read("App/KRALIAgentNative/AgentLearningQueue.swift");
const suggestions = read("App/KRALIAgentNative/AgentDevelopmentSuggestionStore.swift");
const bridge = read("App/KRALIAgentNative/AgentDeveloperBridge.swift");
const runner = read("Scripts/run-developer-agent.command");
const profile = read("App/KRALIAgentNative/AgentExecutionProfile.swift");

ok(
  suggestions.includes("AgentDevelopmentSuggestionStore") &&
  suggestions.includes("observeCapabilityGaps") &&
  suggestions.includes("observeArena"),
  "development suggestion authority store exists"
);

for (const forbiddenRaw of [
  "sourceGoals",
  "currentTaskInput",
  "userInput",
  "rawContent",
  "messageText",
  "mailBody",
  "webContent",
  "screenshot"
]) {
  ok(
    !suggestions.includes(forbiddenRaw),
    "suggestion persistence contains forbidden raw field: " + forbiddenRaw
  );
}

ok(
  queue.includes("$0.userApproved == true") &&
  queue.includes("AgentSourceRevisionPolicy") &&
  queue.includes("$0.sourceRevision"),
  "queue requires explicit approval and exact source revision"
);

ok(
  queue.includes("copy.sourceGoals = nil") &&
  queue.includes("copy.evidenceSnapshots = nil"),
  "legacy raw learning evidence is scrubbed on save"
);

ok(
  queue.includes("sourceRevision: String") &&
  !queue.includes("sourceGoals:\n                        job.sourceGoals"),
  "new immutable job briefs carry revision, not raw source goals"
);

const enqueueCalls = [...engine.matchAll(/learningQueueStore\.enqueue\(/g)];
ok(
  enqueueCalls.length === 1,
  "only explicit development approval may enqueue learning work"
);

ok(
  engine.includes("func approveDevelopmentSuggestion") &&
  engine.includes("func deferDevelopmentSuggestion") &&
  engine.includes("func suppressDevelopmentSuggestion"),
  "explicit suggestion actions exist"
);

ok(
  suggestions.includes("func retry(") &&
  suggestions.includes("original.state == .failed || original.state == .readyForReview") &&
  suggestions.includes("user-retry:") &&
  engine.includes("func retryDevelopmentSuggestion") &&
  !engine.slice(engine.indexOf("func retryDevelopmentSuggestion"), engine.indexOf("func developmentProgress")).includes("runDeveloperAgent"),
  "retry creates a current-revision proposal without starting a developer task"
);

ok(
  engine.includes("status.isCandidateReady\n                                ? .readyForReview\n                                : .failed") &&
  !engine.includes("diagnosisReady"),
  "read-only Cursor Architect diagnosis cannot be presented as a verified candidate"
);

ok(
  engine.includes("reconcileUnverifiedReviewSuggestions") &&
  engine.includes("candidateBranch == nil") &&
  engine.includes("reconciled[index].state = .failed"),
  "unverified persisted review cards are made retryable on launch"
);

ok(
  engine.includes("observeCapabilityGaps") &&
  engine.includes('"runtime-gap"') &&
  engine.includes('"problem-solver-gap"'),
  "runtime and fallback gaps become suggestions"
);

const arenaBlock = engine.slice(
  engine.indexOf("let arenaNeedsDevelopment"),
  engine.indexOf("func runScreenPerceptionProbe")
);
ok(
  arenaBlock.includes("observeArena") &&
  !arenaBlock.includes("runDeveloperAgent()"),
  "Arena may suggest but cannot auto-run Developer Agent"
);

ok(
  bridge.includes("var isCandidateReady") &&
  bridge.includes("var isReviewableFailure") &&
  bridge.includes("var isReadyForReview: Bool {\n        isCandidateReady"),
  "candidate ready is distinct from reviewable failure"
);

ok(
  bridge.includes('"KRALI_SOURCE_REVISION"') &&
  bridge.includes("exactSourceRevision"),
  "Developer Bridge passes validated exact source revision"
);

ok(
  runner.includes('SOURCE_REVISION="\${KRALI_SOURCE_REVISION:-}"') &&
  runner.includes("git cat-file -e") &&
  runner.includes('"$WORKTREE" "$SOURCE_REVISION"'),
  "runner verifies and uses exact source revision"
);

ok(
  !runner.includes('"$WORKTREE" origin/main') &&
  !runner.includes("git pull --ff-only") &&
  !runner.includes("git fetch origin main"),
  "runner has no main/pull fallback base"
);

ok(
  engine.includes("handleDeveloperTaskChatCommand") &&
  engine.includes("developerTask:\n                task"),
  "explicit registered developer task command remains available"
);

for (const id of [
  "browser.control",
  "desktop.app",
  "desktop.control",
  "app.workflow",
  "system.open.url",
  "perception.screen"
]) {
  ok(
    profile.includes('"' + id + '"'),
    "paused computer-control capability remains declared: " + id
  );
}

ok(
  !runner.includes("git merge ") &&
  !runner.includes("push origin main") &&
  !runner.includes("push origin develop"),
  "runner has no autonomous protected-branch release path"
);

console.log("development_authority_self_test_ok");
console.log("auto_development_gate=manual");
console.log("exact_source_revision=required");
console.log("raw_content_persistence=blocked");
console.log("arena_auto_development=blocked");
