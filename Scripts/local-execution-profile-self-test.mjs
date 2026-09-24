#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);

function read(relative) {
  return fs.readFileSync(path.join(root, relative), "utf8");
}

function requireText(text, needle, label) {
  if (!text.includes(needle)) {
    throw new Error(
      "local_execution_profile_invariant_missing|" +
      label +
      "|" +
      needle
    );
  }
}

const runner = read("Scripts/run-developer-agent.command");
const agent = read("Scripts/ollama-developer-agent.mjs");
const decomposer = read("Scripts/developer-task-decomposer.mjs");

requireText(
  runner,
  'decomposer_timeout_ms="210000"',
  "local decomposer receives expanded timeout"
);
requireText(
  runner,
  'decomposer_compact="1"',
  "local decomposer uses compact task context"
);
requireText(
  runner,
  'agent_profile="local-fallback"',
  "local agent receives dedicated execution profile"
);
requireText(
  runner,
  'agent_request_timeout_ms="180000"',
  "local request base timeout is expanded"
);
requireText(
  runner,
  'agent_structured_timeout_ms="240000"',
  "local structured controller timeout is expanded"
);
requireText(
  runner,
  'echo 900000',
  "single-task local watchdog is expanded"
);
requireText(
  runner,
  'echo 1500000',
  "task-graph local watchdog is expanded"
);
requireText(
  runner,
  'agent_request_timeout_retries="1"',
  "slow local requests do not burn the watchdog on repeated timeout retries"
);
requireText(
  runner,
  "list_existing_local_models_by_size",
  "already-installed models can be ranked by size"
);
requireText(
  runner,
  'if [ "$candidate" = "$LOCAL_FALLBACK_MODEL" ]; then',
  "coding model is excluded from lightweight dynamic controller scan"
);
requireText(
  runner,
  'probe_existing_local_controller_model "$LOCAL_FALLBACK_MODEL"',
  "coding model remains final structured-controller fallback"
);

const controllerBlockIndex = runner.indexOf(
  "local controller_candidates=("
);
const knownLightIndex = runner.indexOf(
  '"qwen2.5-coder:7b-instruct"',
  controllerBlockIndex
);
const dynamicIndex = runner.indexOf(
  "done < <(list_existing_local_models_by_size)",
  controllerBlockIndex
);
const codingFallbackIndex = runner.indexOf(
  'probe_existing_local_controller_model "$LOCAL_FALLBACK_MODEL"',
  controllerBlockIndex
);

if (
  controllerBlockIndex < 0 ||
  knownLightIndex < 0 ||
  dynamicIndex < 0 ||
  codingFallbackIndex < 0 ||
  !(knownLightIndex < dynamicIndex && dynamicIndex < codingFallbackIndex)
) {
  throw new Error(
    "local_execution_profile_controller_order_invalid"
  );
}

requireText(
  agent,
  'executionProfile === "local-fallback"',
  "native agent recognizes local fallback profile"
);
requireText(
  agent,
  "Math.max(requestTimeoutMs, 240000)",
  "implementation requests can run long enough on slow local models"
);
requireText(
  agent,
  'keep_alive: localFallbackProfile ? "15m" : undefined',
  "local model stays warm across tool iterations"
);
requireText(
  agent,
  "num_ctx: localFallbackProfile ? 8192 : undefined",
  "local fallback context is bounded"
);
requireText(
  agent,
  "LOCAL FALLBACK PERFORMANCE PROFILE",
  "local agent prompt discourages redundant inspection"
);

requireText(
  decomposer,
  "KRALI_TASK_DECOMPOSER_COMPACT",
  "decomposer exposes compact mode"
);
requireText(
  decomposer,
  "compactMode ? 8000 : 16000",
  "compact mode trims developer brief"
);
requireText(
  decomposer,
  "compactMode ? 800 : 1200",
  "compact mode trims generation budget"
);
requireText(
  decomposer,
  "300000",
  "decomposer timeout clamp allows slow local inference"
);

process.stdout.write(
  "local_execution_profile_self_test_ok\n" +
  "local_decomposer=compact_slow_model\n" +
  "local_agent_watchdog=tuned\n" +
  "controller_preference=smallest_proven_first\n"
);
