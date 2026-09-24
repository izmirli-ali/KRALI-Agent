#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const phase = process.env.KRALI_TEACHER_PHASE || "plan";
const worktree = process.env.KRALI_WORKTREE || "";
const taskFile = process.env.KRALI_DEV_TASK_FILE || "";
const resultFile = process.env.KRALI_TEACHER_RESULT_FILE || "";
const baselinePlanFile =
  process.env.KRALI_TEACHER_BASELINE_PLAN_FILE || "";
const apiKey = process.env.KRALI_OPENAI_TEACHER_API_KEY || "";
const model = process.env.KRALI_OPENAI_TEACHER_MODEL || "gpt-5.6-sol";
const appVersion = process.env.KRALI_APP_VERSION || "unknown";
const runID = process.env.KRALI_RUN_ID || "unknown";
const reasoningEffort = process.env.KRALI_OPENAI_TEACHER_REASONING || "medium";

function fail(message, code = 1) {
  process.stderr.write("openai_teacher_failed|" + message + "\n");
  process.exit(code);
}

function readJSON(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

function globRegex(pattern) {
  const normalized = String(pattern || "").replaceAll("\\", "/");
  let out = "^";
  for (let i = 0; i < normalized.length; i++) {
    const ch = normalized[i];
    if (ch === "*" && normalized[i + 1] === "*") {
      out += ".*";
      i += 1;
    } else if (ch === "*") {
      out += "[^/]*";
    } else if (ch === "?") {
      out += "[^/]";
    } else {
      out += ch.replace(/[.*+?^$()|[\]{}\\]/g, "\\$&");
    }
  }
  return new RegExp(out + "$");
}

function matchesAny(file, patterns) {
  return patterns.some((item) => globRegex(item).test(file));
}

function redact(text) {
  return String(text || "")
    .split(/\r?\n/)
    .map((line) => {
      if (/api[_-]?key|authorization\s*:|bearer\s+|password|secret|private[_-]?key|access[_-]?token/i.test(line)) {
        return "[REDACTED_SENSITIVE_LINE]";
      }
      return line;
    })
    .join("\n");
}

function changedFiles() {
  const result = spawnSync(
    "git",
    ["-C", worktree, "status", "--porcelain", "--untracked-files=all"],
    { encoding: "utf8" }
  );
  if (result.status !== 0) return [];
  return String(result.stdout || "")
    .split(/\r?\n/)
    .map((line) => line.slice(3).trim())
    .filter(Boolean)
    .map((file) => file.replaceAll("\\", "/"));
}

function collectCandidate(taskMetadata) {
  const allowed = Array.isArray(taskMetadata.allowedScope)
    ? taskMetadata.allowedScope.map(String)
    : [];
  const forbidden = Array.isArray(taskMetadata.forbiddenScope)
    ? taskMetadata.forbiddenScope.map(String)
    : [];

  const files = changedFiles().filter((file) => {
    if (matchesAny(file, forbidden)) return false;
    if (allowed.length === 0) return false;
    return matchesAny(file, allowed);
  });

  const diffResult = spawnSync(
    "git",
    ["-C", worktree, "diff", "--no-ext-diff", "--unified=3", "--", ...files],
    { encoding: "utf8", maxBuffer: 4 * 1024 * 1024 }
  );

  let diff = diffResult.status === 0
    ? String(diffResult.stdout || "")
    : "";

  const untracked = [];
  for (const file of files) {
    const full = path.resolve(worktree, file);
    const root = path.resolve(worktree) + path.sep;
    if (!full.startsWith(root)) continue;

    const tracked = spawnSync(
      "git",
      ["-C", worktree, "ls-files", "--error-unmatch", "--", file],
      { encoding: "utf8" }
    ).status === 0;

    if (!tracked && fs.existsSync(full)) {
      const stat = fs.statSync(full);
      if (stat.isFile() && stat.size <= 40000) {
        untracked.push({
          path: file,
          content: redact(fs.readFileSync(full, "utf8"))
        });
      }
    }
  }

  diff = redact(diff).slice(0, 70000);

  return {
    changedFiles: files.slice(0, 50),
    diff,
    untracked: untracked.slice(0, 12),
    deterministicEvidence: {
      buildPassed: process.env.KRALI_TEACHER_BUILD_PASSED === "1",
      taskVerificationPassed:
        process.env.KRALI_TEACHER_TASK_VERIFICATION_PASSED === "1"
    }
  };
}

function compactTask(payload) {
  const task = payload && typeof payload.developerTask === "object"
    ? payload.developerTask
    : {};
  const meta = payload && typeof payload.taskMetadata === "object"
    ? payload.taskMetadata
    : {};

  return {
    capabilityID: String(task.capabilityID || ""),
    capabilityName: String(task.capabilityName || ""),
    kind: String(task.kind || ""),
    learningPath: String(task.learningPath || ""),
    reason: String(task.reason || "").slice(0, 3000),
    researchGoal: String(task.researchGoal || "").slice(0, 3000),
    developerBrief: String(task.developerBrief || "").slice(0, 12000),
    candidateCapabilityIDs: Array.isArray(task.candidateCapabilityIDs)
      ? task.candidateCapabilityIDs.map(String).slice(0, 20)
      : [],
    allowedScope: Array.isArray(meta.allowedScope)
      ? meta.allowedScope.map(String)
      : [],
    forbiddenScope: Array.isArray(meta.forbiddenScope)
      ? meta.forbiddenScope.map(String)
      : [],
    verification:
      meta.verification && typeof meta.verification === "object"
        ? meta.verification
        : null,
    risk: String(meta.risk || "")
  };
}

const reviewSchema = {
  type: "object",
  properties: {
    phase: {
      type: "string",
      enum: ["plan", "final"]
    },
    verdict: {
      type: "string",
      enum: ["APPROVE", "REVISE", "ESCALATE"]
    },
    summary: { type: "string" },
    confidence: { type: "number" },
    subtasks: {
      type: "array",
      items: {
        type: "object",
        properties: {
          id: { type: "string" },
          title: { type: "string" },
          depends_on: {
            type: "array",
            items: { type: "string" }
          },
          scope: {
            type: "array",
            items: { type: "string" }
          },
          expected_result: { type: "string" },
          verification: { type: "string" }
        },
        required: [
          "id",
          "title",
          "depends_on",
          "scope",
          "expected_result",
          "verification"
        ],
        additionalProperties: false
      }
    },
    findings: {
      type: "array",
      items: {
        type: "object",
        properties: {
          severity: {
            type: "string",
            enum: ["low", "medium", "high", "critical"]
          },
          issue: { type: "string" },
          evidence: { type: "string" },
          recommended_fix: { type: "string" }
        },
        required: [
          "severity",
          "issue",
          "evidence",
          "recommended_fix"
        ],
        additionalProperties: false
      }
    },
    generalized_lessons: {
      type: "array",
      items: { type: "string" }
    }
  },
  required: [
    "phase",
    "verdict",
    "summary",
    "confidence",
    "subtasks",
    "findings",
    "generalized_lessons"
  ],
  additionalProperties: false
};

function extractOutputText(payload) {
  if (typeof payload?.output_text === "string" && payload.output_text.trim()) {
    return payload.output_text.trim();
  }

  for (const item of Array.isArray(payload?.output) ? payload.output : []) {
    for (const content of Array.isArray(item?.content) ? item.content : []) {
      if (
        (content?.type === "output_text" || content?.type === "text") &&
        typeof content?.text === "string"
      ) {
        return content.text.trim();
      }
    }
  }

  return "";
}

function selfTest() {
  const fake = {
    developerTask: {
      capabilityID: "developer.task.example",
      capabilityName: "Example",
      kind: "developerTask",
      learningPath: "primitivePatch",
      reason: "Generic reason",
      researchGoal: "Generic goal",
      developerBrief: "Generic brief",
      candidateCapabilityIDs: []
    },
    taskMetadata: {
      allowedScope: ["App/**"],
      forbiddenScope: ["Mentor/**"],
      risk: "low"
    }
  };

  const compact = compactTask(fake);
  const checks = [
    compact.capabilityID === "developer.task.example",
    globRegex("App/**").test("App/KRALIAgentNative/Test.swift"),
    !globRegex("App/**").test("Mentor/latest.json"),
    redact("Authorization: Bearer abc").includes("[REDACTED_SENSITIVE_LINE]"),
    extractOutputText({
      output: [
        {
          content: [
            { type: "output_text", text: "{\"ok\":true}" }
          ]
        }
      ]
    }) === "{\"ok\":true}",
    reviewSchema.additionalProperties === false
  ];

  if (!checks.every(Boolean)) {
    fail("self-test", 2);
  }

  process.stdout.write(
    "openai_teacher_self_test_ok\n" +
    "teacher_tools=disabled\n" +
    "raw_user_content=excluded\n"
  );
}

if (process.argv.includes("--self-test")) {
  selfTest();
  process.exit(0);
}

if (phase !== "plan" && phase !== "final") {
  fail("invalid-phase", 3);
}

if (!taskFile || !fs.existsSync(taskFile)) {
  process.stdout.write("openai_teacher_skipped|no-controlled-task\n");
  process.exit(10);
}

if (!apiKey) {
  process.stdout.write("openai_teacher_skipped|api-key-missing\n");
  process.exit(10);
}

if (!worktree || !fs.existsSync(worktree)) {
  fail("worktree-missing", 4);
}

const payload = readJSON(taskFile);
if (!payload) {
  fail("task-json-invalid", 5);
}

const task = compactTask(payload);
const taskMetadata =
  payload.taskMetadata && typeof payload.taskMetadata === "object"
    ? payload.taskMetadata
    : {};

const baselinePlan =
  phase === "plan" &&
  baselinePlanFile &&
  fs.existsSync(baselinePlanFile)
    ? readJSON(baselinePlanFile)?.review || null
    : null;

const bundle = {
  appVersion,
  runID,
  phase,
  task,
  baselinePlan,
  candidate: phase === "final"
    ? collectCandidate(taskMetadata)
    : null
};

const systemPrompt = [
  "You are KRALI OpenAI Teacher, a senior software architect and reviewer.",
  "You are advisory only. You have no tools and no authority to mutate files, run shell commands, approve external actions, merge branches, or bypass human approval.",
  "Review only the compact controlled-task package supplied by the orchestrator.",
  "Do not request the full repository or raw user messages.",
  "For plan phase: KRALI may already provide a baselinePlan. Review that plan as a senior architect. Preserve good decomposition, revise only where dependencies/scope/verification are weak, and return the complete improved subtask graph. If no baselinePlan exists, create one.",
  "For final phase: review the candidate diff for correctness, regressions, scope discipline, backward compatibility, safety, and whether tests actually prove the requested behavior.",
  "Do not provide hidden chain-of-thought. Return only the required structured review.",
  "Generalized lessons must describe reusable engineering principles, never copy raw task content."
].join("\n");

const requestBody = {
  model,
  store: false,
  reasoning: {
    effort: reasoningEffort
  },
  input: [
    {
      role: "system",
      content: [
        {
          type: "input_text",
          text: systemPrompt
        }
      ]
    },
    {
      role: "user",
      content: [
        {
          type: "input_text",
          text: JSON.stringify(bundle)
        }
      ]
    }
  ],
  text: {
    format: {
      type: "json_schema",
      name: "krali_teacher_review",
      strict: true,
      schema: reviewSchema
    }
  },
  max_output_tokens: 5000
};

const controller = new AbortController();
const timeout = setTimeout(
  () => controller.abort(),
  Math.max(
    15000,
    Math.min(
      Number(process.env.KRALI_OPENAI_TEACHER_TIMEOUT_MS || 90000),
      180000
    )
  )
);

let response;
try {
  response = await fetch(
    "https://api.openai.com/v1/responses",
    {
      method: "POST",
      headers: {
        "Authorization": "Bearer " + apiKey,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(requestBody),
      signal: controller.signal
    }
  );
} catch (error) {
  clearTimeout(timeout);
  fail("transport:" + error.message, 20);
}
clearTimeout(timeout);

let apiPayload;
try {
  apiPayload = await response.json();
} catch {
  fail("response-json-invalid", 21);
}

if (!response.ok) {
  const message = String(
    apiPayload?.error?.message ||
    apiPayload?.message ||
    ("http-" + response.status)
  ).slice(0, 800);
  fail("api:" + message, 22);
}

const outputText = extractOutputText(apiPayload);
if (!outputText) {
  fail("empty-output", 23);
}

let review;
try {
  review = JSON.parse(outputText);
} catch {
  fail("structured-output-invalid", 24);
}

if (review.phase !== phase) {
  fail("phase-mismatch", 25);
}

const artifact = {
  createdAt: new Date().toISOString(),
  provider: "openai-responses",
  model,
  phase,
  appVersion,
  runID,
  safety: {
    advisoryOnly: true,
    toolsEnabled: false,
    mutationAuthority: false,
    mergeAuthority: false,
    rawUserContentIncluded: false
  },
  review
};

if (resultFile) {
  fs.mkdirSync(path.dirname(resultFile), { recursive: true });
  fs.writeFileSync(
    resultFile,
    JSON.stringify(artifact, null, 2) + "\n",
    "utf8"
  );
}

process.stdout.write(
  "openai_teacher_ok|" +
  phase +
  "|" +
  String(review.verdict || "UNKNOWN") +
  "\n"
);
