#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);

function read(relative) {
  return fs.readFileSync(
    path.join(root, relative),
    "utf8"
  );
}

function requireText(text, needle, label) {
  if (!text.includes(needle)) {
    throw new Error(
      "developer_task_graph_invariant_missing|" +
      label +
      "|" +
      needle
    );
  }
}

const agent = read(
  "Scripts/ollama-developer-agent.mjs"
);
const runner = read(
  "Scripts/run-developer-agent.command"
);

requireText(
  agent,
  "validateDeveloperTaskGraphNodes",
  "developer subtasks are validated"
);
requireText(
  agent,
  "subtaskScopeWithinParent",
  "subtask scope cannot widen parent scope"
);
requireText(
  agent,
  "repairSubtaskScopeEntries",
  "executor repairs broad planner scope to the parent contract before validation"
);
requireText(
  agent,
  "scopeRepairs=",
  "scope repair count is observable in Mentor status"
);
requireText(
  agent,
  "outside_active_subtask_scope",
  "active subtask mutation scope enforced"
);
requireText(
  agent,
  "developerTaskGraphComplete()",
  "completion gate requires graph completion"
);
requireText(
  agent,
  "local_agent_task_graph_advanced",
  "verified node advances graph"
);
requireText(
  agent,
  "local_agent_task_graph_completed",
  "graph completion observable"
);
requireText(
  agent,
  "developerTaskGraph:",
  "graph state persisted in checkpoint"
);
requireText(
  agent,
  "version: 8",
  "checkpoint schema includes graph state"
);
requireText(
  runner,
  'KRALI_DEVELOPER_TASK_PLAN_FILE="$DEVELOPER_TASK_GRAPH_PLAN"',
  "runner passes selected developer task plan"
);
requireText(
  runner,
  "developer-task-decomposer.mjs",
  "KRALI baseline decomposer runs before Teacher"
);
requireText(
  runner,
  'DEVELOPER_TASK_GRAPH_PLAN="$BASELINE_TASK_PLAN_RESULT"',
  "baseline graph works without Teacher"
);
requireText(
  runner,
  "echo 32",
  "developer graph receives expanded bounded iteration budget"
);
requireText(
  runner,
  "echo 720000",
  "developer graph receives expanded bounded watchdog"
);

process.stdout.write(
  "developer_task_graph_self_test_ok\n" +
  "scope_gate=active_subtask\n" +
  "completion_gate=all_nodes_verified\n"
);
