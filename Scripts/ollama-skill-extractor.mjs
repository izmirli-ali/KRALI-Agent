import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";

const worktree = process.env.KRALI_WORKTREE || "";
const gapSource = process.env.KRALI_GAP_SOURCE || "";
const model =
  process.env.KRALI_ARCHITECT_MODEL ||
  process.env.KRALI_DEV_MODEL ||
  "";
const baseUrl =
  (process.env.KRALI_OLLAMA_BASE_URL || "http://127.0.0.1:11434")
    .replace(/\/$/, "");
const targetFile = process.env.KRALI_SKILL_CANDIDATE_FILE || "";
const appVersion = process.env.KRALI_APP_VERSION || "unknown";
const branch = process.env.KRALI_BRANCH || "";
const runID = process.env.KRALI_RUN_ID || "";

function fail(message, code = 1) {
  console.error(message);
  process.exit(code);
}

if (!worktree || !model || !targetFile) {
  fail("KRALI skill extractor için worktree/model/target eksik.", 2);
}

function runGit(args) {
  return spawnSync(
    "/usr/bin/git",
    ["-C", worktree, ...args],
    {
      encoding: "utf8",
      maxBuffer: 8 * 1024 * 1024,
    }
  );
}

function readGap() {
  if (!gapSource || !fs.existsSync(gapSource)) {
    return {};
  }

  try {
    const payload = JSON.parse(
      fs.readFileSync(gapSource, "utf8")
    );

    return payload?.gap ||
      (Array.isArray(payload?.capabilityGaps)
        ? payload.capabilityGaps[0]
        : {}) ||
      {};
  } catch {
    return {};
  }
}

const diffResult = runGit([
  "diff",
  "--no-ext-diff",
  "--unified=3",
]);

if (diffResult.status !== 0) {
  fail("Skill çıkarımı için candidate diff okunamadı.", 3);
}

const diff = String(diffResult.stdout || "").trim();

if (!diff) {
  fail("Skill çıkarımı için candidate değişikliği yok.", 4);
}

const gap = readGap();
const diffHash = crypto
  .createHash("sha256")
  .update(diff)
  .digest("hex");

const compactDiff =
  diff.length <= 22000
    ? diff
    : diff.slice(0, 11000) +
      "\n...<middle omitted for transient skill extraction>...\n" +
      diff.slice(-11000);

const schema = {
  type: "object",
  additionalProperties: false,
  required: [
    "name",
    "skill_class",
    "trigger_pattern",
    "generalized_strategy",
    "preconditions",
    "procedure",
    "verification_contract",
    "failure_signals",
    "rollback_strategy",
    "source_symbols",
  ],
  properties: {
    name: { type: "string", minLength: 4, maxLength: 100 },
    skill_class: {
      type: "string",
      enum: [
        "strategy",
        "primitive",
        "integration",
        "verification",
        "recovery",
      ],
    },
    trigger_pattern: {
      type: "string",
      minLength: 12,
      maxLength: 500,
    },
    generalized_strategy: {
      type: "string",
      minLength: 20,
      maxLength: 1400,
    },
    preconditions: {
      type: "array",
      maxItems: 10,
      items: { type: "string", maxLength: 300 },
    },
    procedure: {
      type: "array",
      minItems: 1,
      maxItems: 12,
      items: { type: "string", maxLength: 400 },
    },
    verification_contract: {
      type: "array",
      minItems: 1,
      maxItems: 10,
      items: { type: "string", maxLength: 400 },
    },
    failure_signals: {
      type: "array",
      maxItems: 10,
      items: { type: "string", maxLength: 300 },
    },
    rollback_strategy: {
      type: "string",
      minLength: 8,
      maxLength: 600,
    },
    source_symbols: {
      type: "array",
      maxItems: 16,
      items: { type: "string", maxLength: 180 },
    },
  },
};

const systemPrompt = [
  "You are KRALI Skill Distiller.",
  "A candidate code change has already passed build/regression preflight.",
  "Your job is NOT to preserve the patch or code.",
  "Extract the smallest reusable, scenario-independent skill/strategy learned from the change.",
  "Never encode the concrete app name, user phrase, brand, filename, or test fixture as the skill unless it is an unavoidable provider identity.",
  "Prefer a strategy/recipe over a primitive patch when existing capabilities can be composed.",
  "Describe verification and rollback explicitly.",
  "Do not include raw source code, raw diff, or large data blobs.",
  "Return only JSON matching the schema.",
].join("\n");

const userPayload = {
  capability: {
    id: String(gap?.capabilityID || ""),
    name: String(gap?.capabilityName || ""),
    kind: String(gap?.kind || ""),
    reason: String(gap?.reason || ""),
    research_goal: String(gap?.researchGoal || ""),
    learning_path: String(gap?.learningPath || ""),
  },
  candidate_diff_transient: compactDiff,
};

const controller = new AbortController();
const timer = setTimeout(
  () => controller.abort(),
  Number(process.env.KRALI_SKILL_EXTRACT_TIMEOUT_MS || "90000")
);

let response;
try {
  response = await fetch(baseUrl + "/api/chat", {
    method: "POST",
    headers: {
      "content-type": "application/json",
    },
    signal: controller.signal,
    body: JSON.stringify({
      model,
      stream: false,
      format: schema,
      options: {
        temperature: 0.1,
        num_predict: 1400,
      },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: JSON.stringify(userPayload) },
      ],
    }),
  });
} catch (error) {
  clearTimeout(timer);
  fail(
    "Skill distillation isteği başarısız: " +
      (error instanceof Error ? error.message : String(error)),
    5
  );
}

clearTimeout(timer);

if (!response.ok) {
  fail("Skill distillation HTTP " + response.status, 6);
}

const payload = await response.json();
const content = String(payload?.message?.content || "").trim();

let learned;
try {
  learned = JSON.parse(content);
} catch {
  fail("Skill distillation JSON parse edilemedi.", 7);
}

const capabilityID = String(gap?.capabilityID || "unknown");
const identity = [
  capabilityID,
  String(learned.skill_class || ""),
  String(learned.trigger_pattern || ""),
  String(learned.generalized_strategy || ""),
].join("\n");

const skillID =
  capabilityID.replace(/[^a-zA-Z0-9._-]+/g, "_").slice(0, 64) +
  "-" +
  crypto
    .createHash("sha256")
    .update(identity)
    .digest("hex")
    .slice(0, 12);

const candidate = {
  schema_version: 1,
  id: skillID,
  state: "experimental",
  name: String(learned.name || "").trim(),
  capability_id: capabilityID,
  capability_name: String(gap?.capabilityName || ""),
  skill_class: String(learned.skill_class || "strategy"),
  trigger_pattern: String(learned.trigger_pattern || "").trim(),
  generalized_strategy: String(
    learned.generalized_strategy || ""
  ).trim(),
  preconditions: Array.isArray(learned.preconditions)
    ? learned.preconditions
    : [],
  procedure: Array.isArray(learned.procedure)
    ? learned.procedure
    : [],
  verification_contract: Array.isArray(
    learned.verification_contract
  )
    ? learned.verification_contract
    : [],
  failure_signals: Array.isArray(learned.failure_signals)
    ? learned.failure_signals
    : [],
  rollback_strategy: String(
    learned.rollback_strategy || ""
  ).trim(),
  source_symbols: Array.isArray(learned.source_symbols)
    ? learned.source_symbols
    : [],
  provenance: {
    app_version: appVersion,
    branch,
    run_id: runID,
    architect_model: model,
    candidate_diff_sha256: diffHash,
    raw_patch_retained: false,
  },
  validation: {
    build_passed: true,
    regression_passed: true,
    runtime_postcondition_verified: false,
    runtime_validation_summary: null,
  },
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
};

fs.mkdirSync(path.dirname(targetFile), { recursive: true });
fs.writeFileSync(
  targetFile,
  JSON.stringify(candidate, null, 2) + "\n",
  "utf8"
);

console.log(
  "skill_candidate_ready|" +
    candidate.id +
    "|" +
    targetFile
);
