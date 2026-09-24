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
      "provider_failover_invariant_missing|" +
        label +
        "|" +
        needle
    );
  }
}

function functionBody(text, name, nextName) {
  const start = text.indexOf(name + "() {");
  if (start < 0) {
    throw new Error(
      "provider_failover_function_missing|" + name
    );
  }

  const next = nextName
    ? text.indexOf(nextName + "() {", start + 1)
    : -1;

  return text.slice(
    start,
    next > start ? next : text.length
  );
}

const runner = read(
  "Scripts/run-developer-agent.command"
);
const decomposer = read(
  "Scripts/developer-task-decomposer.mjs"
);

requireText(
  runner,
  'LOCAL_OLLAMA_BASE_URL=',
  "local endpoint preserved before remote proxy override"
);
requireText(
  runner,
  "prepare_existing_local_fallback",
  "side-effect-free local fallback probe exists"
);
requireText(
  runner,
  "REMOTE_CIRCUIT_OPEN=1",
  "remote circuit breaker is explicit"
);
requireText(
  runner,
  'REMOTE_PROVIDER_MODE=0',
  "successful fallback switches inference mode to local"
);
requireText(
  runner,
  'OLLAMA_BASE_URL="$LOCAL_OLLAMA_BASE_URL"',
  "successful fallback restores local endpoint"
);
requireText(
  runner,
  'MODEL="$LOCAL_FALLBACK_MODEL"',
  "successful fallback uses proven installed tool model"
);
requireText(
  runner,
  'CONTROLLER_MODEL="$LOCAL_FALLBACK_CONTROLLER_MODEL"',
  "successful fallback uses proven installed structured model"
);
requireText(
  runner,
  'DECOMPOSER_EXIT" -eq 29',
  "decomposer quota failure triggers failover"
);
requireText(
  runner,
  'DECOMPOSER_EXIT" -eq 28',
  "decomposer timeout triggers failover"
);
requireText(
  runner,
  "cloudflare_provider_transport\\|timeout",
  "coding provider repeated timeout triggers failover"
);
requireText(
  runner,
  "run_native_developer_agent_once",
  "remote and local retries share one native safety contract"
);
requireText(
  runner,
  'KRALI_CHECKPOINT_FILE="$CHECKPOINT_FILE"',
  "local retry preserves same checkpoint"
);
requireText(
  runner,
  'KRALI_CANDIDATE_REPAIR_ATTEMPTS="$RECOVERY_REPAIR_ATTEMPTS"',
  "recovery repair budget can be disabled when provider failover is unavailable"
);
requireText(
  runner,
  'RECOVERY_REPAIR_ATTEMPTS="0"',
  "provider-unavailable recovery performs deterministic verification only"
);
requireText(
  runner,
  "provider_failover_unavailable",
  "terminal provider-unavailable state is observable"
);
requireText(
  decomposer,
  'fail("transport-timeout", 28)',
  "decomposer transport timeout has a dedicated exit"
);
requireText(
  decomposer,
  'fail("http-429", 29)',
  "decomposer quota response has a dedicated exit"
);

const localProbeBody = functionBody(
  runner,
  "prepare_existing_local_fallback",
  "activate_local_fallback"
);

const forbiddenSideEffects = [
  "require_system_effect_approval",
  "brew install",
  "brew upgrade",
  "ollama pull",
  '" pull ',
  "nohup",
  " serve",
];

for (const forbidden of forbiddenSideEffects) {
  if (localProbeBody.includes(forbidden)) {
    throw new Error(
      "provider_failover_side_effect_forbidden|" +
        forbidden
    );
  }
}

for (const required of [
  "command -v ollama",
  "$LOCAL_OLLAMA_BASE_URL/api/tags",
  'show "$candidate"',
  "probe_existing_local_tool_model",
  "probe_existing_local_controller_model",
]) {
  requireText(
    localProbeBody,
    required,
    "local fallback only probes existing runtime/model state"
  );
}

process.stdout.write(
  "provider_failover_self_test_ok\n" +
  "remote_quota_circuit_breaker=enabled\n" +
  "remote_timeout_circuit_breaker=enabled\n" +
  "local_fallback_side_effects=forbidden\n"
);
