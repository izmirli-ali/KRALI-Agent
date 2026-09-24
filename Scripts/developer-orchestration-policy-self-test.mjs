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

function assertContains(text, needle, label) {
  if (!text.includes(needle)) {
    throw new Error(
      "Missing orchestration invariant: " +
        label +
        " • " +
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

assertContains(
  agent,
  "taskMutationScopeDecision",
  "target selection uses task mutation scope"
);
assertContains(
  agent,
  "local_agent_create_target_ready",
  "create-only developer tasks supported"
);
assertContains(
  agent,
  "implementationTargetPaths.length > 0",
  "read verification cannot treat empty target list as valid"
);
assertContains(
  agent,
  "maxImplementationRejectionGrace",
  "rejected implementation inspection has separate grace budget"
);
assertContains(
  runner,
  "PRE_CURSOR_DIRTY_RAW",
  "Cursor dirty detection distinguishes raw status"
);
assertContains(
  runner,
  '.krali-developer-agent-prompt.txt',
  "Cursor dirty detection knows prompt artifact"
);
assertContains(
  runner,
  '.build-check/',
  "Cursor dirty detection knows build-check artifact"
);
assertContains(
  runner,
  "Cursor Architect atlandı • reasons=",
  "Cursor skip reason is observable"
);

assertContains(
  agent,
  "outside_active_subtask_scope",
  "Developer task graph narrows mutation scope per active subtask"
);
assertContains(
  agent,
  "developer task graph tamamlanmadı",
  "completion gate requires all developer subtasks verified"
);
assertContains(
  agent,
  "local_agent_task_graph_advanced",
  "verified developer subtask advances dependency graph"
);
assertContains(
  runner,
  "KRALI_DEVELOPER_TASK_PLAN_FILE",
  "Selected baseline/Teacher-reviewed plan is passed into native Developer Agent"
);
assertContains(
  runner,
  "developer-task-decomposer.mjs",
  "controlled tasks receive KRALI baseline decomposition"
);
assertContains(
  runner,
  "KRALI_TEACHER_BASELINE_PLAN_FILE",
  "OpenAI Teacher reviews KRALI baseline graph"
);
assertContains(
  agent,
  "developer-candidate-surface-guard.mjs",
  "native build_check enforces destructive surface guard"
);
assertContains(
  runner,
  'KRALI_SURFACE_GUARD_SCRIPT="$ROOT/Scripts/developer-candidate-surface-guard.mjs"',
  "native agent receives trusted main-repo surface guard path"
);
assertContains(
  runner,
  'KRALI_DEVELOPER_TASK_FALLBACK_PLAN_FILE="$BASELINE_TASK_PLAN_RESULT"',
  "invalid Teacher graph falls back to KRALI baseline graph"
);
const recovery = read(
  "Scripts/recover-developer-candidate.command"
);
assertContains(
  recovery,
  "RECOVERY_BASE_COMMIT",
  "recovery surface guard compares against stable pre-candidate base"
);
assertContains(
  recovery,
  "KRALI_SURFACE_GUARD_BASE",
  "repair agent inherits stable surface-guard base"
);

assertContains(
  runner,
  "prepare_existing_local_fallback",
  "remote provider failure can use already-ready local Ollama without installation"
);
assertContains(
  runner,
  "REMOTE_CIRCUIT_OPEN=1",
  "quota/timeout failure opens a per-run remote circuit breaker"
);
assertContains(
  runner,
  "local_fallback_retrying",
  "native Developer Agent resumes same run on local fallback"
);
assertContains(
  runner,
  'RECOVERY_REPAIR_ATTEMPTS="0"',
  "provider-unavailable candidate recovery does not repeatedly call failed AI providers"
);

assertContains(
  runner,
  'agent_profile="local-fallback"',
  "local provider failover receives a dedicated execution budget"
);
assertContains(
  runner,
  'decomposer_timeout_ms="210000"',
  "local fallback decomposer receives slow-model timeout budget"
);
assertContains(
  agent,
  "LOCAL FALLBACK PERFORMANCE PROFILE",
  "local fallback prompt discourages redundant inspections"
);

process.stdout.write(
  "developer_orchestration_policy_ok\n"
);
