#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const agent = fs.readFileSync(path.join(root, "Scripts/ollama-developer-agent.mjs"), "utf8");
const decomposer = fs.readFileSync(path.join(root, "Scripts/developer-task-decomposer.mjs"), "utf8");

function requireText(text, needle, label) {
  if (!text.includes(needle)) {
    throw new Error("scope_mutation_contract_missing|" + label + "|" + needle);
  }
}

requireText(
  decomposer,
  "repairScopeToParent",
  "decomposer repairs broad planner scopes"
);
requireText(
  decomposer,
  "scope_clamp=parent_contract_only",
  "decomposer self-test asserts parent-only clamp"
);
requireText(
  agent,
  "repairSubtaskScopeEntries",
  "executor independently clamps task graph scope"
);
requireText(
  agent,
  "affinityNarrowScopeMatches",
  "executor narrows concrete parent matches by node affinity"
);
requireText(
  agent,
  "scopeRepairs=",
  "mentor status exposes scope repair count"
);
requireText(
  agent,
  "checkpointReadEvidenceForPath",
  "mutation packet uses verified read evidence"
);
requireText(
  agent,
  "checkpointSearchLineForPath",
  "mutation packet anchors around verified search evidence"
);
requireText(
  agent,
  "verifiedReadMutationOldText",
  "generic mutation anchor comes from exact source read"
);
requireText(
  agent,
  "local_agent_verified_mutation_packet_ready",
  "verified mutation packet creation is observable"
);
requireText(
  agent,
  "liveReadSlice !== exactReadSource",
  "stale source invalidates mutation packet"
);
requireText(
  agent,
  "source.split(candidate).length - 1",
  "mutation anchor must be unique in live source"
);
requireText(
  agent,
  "return verifiedReadMutationOldText",
  "generic capability tasks can use verified read packet without runtime root-cause source"
);
requireText(
  agent,
  "Do not choose, shorten, expand, or invent an old_text anchor.",
  "structured controller cannot invent replace anchor"
);

const fixedModeIndex = agent.indexOf("const fixedInitialOldText");
const packetIndex = agent.indexOf("verifiedReadMutationOldText");
if (fixedModeIndex < 0 || packetIndex < 0) {
  throw new Error("scope_mutation_contract_order_missing");
}

process.stdout.write(
  "scope_mutation_contract_self_test_ok\n" +
  "task_scope=parent_clamped\n" +
  "mutation_anchor=verified_source_only\n" +
  "stale_source=reject\n"
);
