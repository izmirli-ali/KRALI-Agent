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
  "teacher subtasks are validated"
);
requireText(
  agent,
  "subtaskScopeWithinParent",
  "subtask scope cannot widen parent scope"
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
  'KRALI_TEACHER_PLAN_FILE="$OPENAI_TEACHER_PLAN_RESULT"',
  "runner passes teacher plan file"
);
requireText(
  runner,
  "echo 32",
  "teacher graph receives expanded bounded iteration budget"
);
requireText(
  runner,
  "echo 720000",
  "teacher graph receives expanded bounded watchdog"
);

process.stdout.write(
  "developer_task_graph_self_test_ok\n" +
  "scope_gate=active_subtask\n" +
  "completion_gate=all_nodes_verified\n"
);
