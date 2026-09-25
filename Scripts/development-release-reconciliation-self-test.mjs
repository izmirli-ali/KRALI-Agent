#!/usr/bin/env node
import fs from "node:fs";

function read(path) {
  return fs.readFileSync(path, "utf8");
}

function ok(value, message) {
  if (!value) throw new Error(message);
}

const verifier = read("App/KRALIAgentNative/AgentDevelopmentReleaseVerifier.swift");
const engine = read("App/KRALIAgentNative/AgentEngine.swift");
const sidebar = read("App/KRALIAgentNative/ConversationSidebarView.swift");

ok(
  verifier.includes("merge-base") &&
  verifier.includes("--is-ancestor") &&
  verifier.includes("rev-parse") &&
  verifier.includes("--verify"),
  "release verifier must use read-only git ancestry checks"
);

for (const forbidden of [
  "git fetch",
  "git pull",
  "git merge",
  "git push",
  "git checkout",
  "git reset"
]) {
  ok(
    !verifier.includes(forbidden),
    "release verifier contains mutating/network git behavior: " + forbidden
  );
}

ok(
  verifier.includes('branch.hasPrefix(\n                "krali-dev-agent/"') &&
  verifier.includes("!branch.contains(\"..\")") &&
  verifier.includes('"/usr/bin/git"'),
  "candidate branch validation or shell-free git execution missing"
);

ok(
  engine.includes("reconcileReleasedDevelopmentSuggestions") &&
  engine.includes("candidateIsIntegrated") &&
  engine.includes(".readyForReview") &&
  engine.includes(".released"),
  "Engine does not reconcile reviewed candidate lineage into released state"
);

const reconcile = engine.slice(
  engine.indexOf("private func reconcileReleasedDevelopmentSuggestions"),
  engine.indexOf("func canDevelopSuggestion")
);

ok(
  reconcile.includes(".readyForReview") &&
  reconcile.includes(".released") &&
  !reconcile.includes(".failed") &&
  !reconcile.includes(".proposed"),
  "release reconciliation must only promote ready-for-review suggestions"
);

ok(
  sidebar.includes("case .released") &&
  sidebar.includes("checkmark.circle.fill"),
  "sidebar does not render released state as completed"
);

console.log("development_release_reconciliation_self_test_ok");
console.log("release_detection=git_ancestry_read_only");
console.log("candidate_ready_not_release=PASS");
console.log("merged_candidate_current_build=100_percent");
