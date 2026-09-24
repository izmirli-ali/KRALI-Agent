#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const taskFile = process.env.KRALI_DEV_TASK_FILE || "";
const resultFile = process.env.KRALI_TASK_DECOMPOSER_RESULT_FILE || "";
const baseUrl =
  (process.env.KRALI_OLLAMA_BASE_URL || "http://127.0.0.1:11434")
    .replace(/\/$/, "");
const model =
  process.env.KRALI_DECOMPOSER_MODEL ||
  process.env.KRALI_CONTROLLER_MODEL ||
  process.env.KRALI_DEV_MODEL ||
  "";
const appVersion = process.env.KRALI_APP_VERSION || "unknown";
const runID = process.env.KRALI_RUN_ID || "unknown";
const timeoutMs = Math.max(
  15000,
  Math.min(
    Number(process.env.KRALI_TASK_DECOMPOSER_TIMEOUT_MS || 70000),
    120000
  )
);

function fail(message, code = 1) {
  process.stderr.write(
    "developer_task_decomposer_failed|" + message + "\n"
  );
  process.exit(code);
}

function normalizeScope(value) {
  return String(value || "")
    .trim()
    .replaceAll("\\", "/")
    .replace(/^\.\//, "");
}

function globToRegExp(pattern) {
  const normalized = normalizeScope(pattern);
  let output = "^";

  for (let index = 0; index < normalized.length; index += 1) {
    const char = normalized[index];

    if (char === "*" && normalized[index + 1] === "*") {
      output += ".*";
      index += 1;
    } else if (char === "*") {
      output += "[^/]*";
    } else if (char === "?") {
      output += "[^/]";
    } else {
      output += /[.*+?^$()|[\]{}\\]/.test(char)
        ? "\\" + char
        : char;
    }
  }

  return new RegExp(output + "$");
}

function matchesAnyGlob(value, patterns) {
  return patterns.some((pattern) =>
    globToRegExp(pattern).test(value)
  );
}

function compactTask(payload) {
  const task =
    payload && typeof payload.developerTask === "object"
      ? payload.developerTask
      : {};
  const meta =
    payload && typeof payload.taskMetadata === "object"
      ? payload.taskMetadata
      : {};

  return {
    capabilityID: String(task.capabilityID || ""),
    capabilityName: String(task.capabilityName || ""),
    kind: String(task.kind || ""),
    learningPath: String(task.learningPath || ""),
    reason: String(task.reason || "").slice(0, 3200),
    researchGoal: String(task.researchGoal || "").slice(0, 3200),
    developerBrief: String(task.developerBrief || "").slice(0, 16000),
    allowedScope: Array.isArray(meta.allowedScope)
      ? meta.allowedScope.map(normalizeScope).filter(Boolean)
      : [],
    forbiddenScope: Array.isArray(meta.forbiddenScope)
      ? meta.forbiddenScope.map(normalizeScope).filter(Boolean)
      : [],
    verification:
      meta.verification && typeof meta.verification === "object"
        ? meta.verification
        : null,
    risk: String(meta.risk || ""),
  };
}

const schema = {
  type: "object",
  additionalProperties: false,
  required: ["summary", "subtasks"],
  properties: {
    summary: { type: "string" },
    subtasks: {
      type: "array",
      minItems: 1,
      maxItems: 6,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "id",
          "title",
          "depends_on",
          "scope",
          "expected_result",
          "verification",
        ],
        properties: {
          id: { type: "string" },
          title: { type: "string" },
          depends_on: {
            type: "array",
            items: { type: "string" },
          },
          scope: {
            type: "array",
            minItems: 1,
            items: { type: "string" },
          },
          expected_result: { type: "string" },
          verification: { type: "string" },
        },
      },
    },
  },
};

function validatePlan(plan, task) {
  if (
    !plan ||
    !Array.isArray(plan.subtasks) ||
    plan.subtasks.length < 1 ||
    plan.subtasks.length > 6
  ) {
    return { ok: false, reason: "subtasks-invalid" };
  }

  const nodes = plan.subtasks.map((raw, order) => ({
    id: String(raw?.id || "").trim(),
    title: String(raw?.title || "").trim(),
    depends_on: Array.isArray(raw?.depends_on)
      ? raw.depends_on
          .map((value) => String(value || "").trim())
          .filter(Boolean)
      : [],
    scope: Array.isArray(raw?.scope)
      ? raw.scope
          .map(normalizeScope)
          .filter(Boolean)
      : [],
    expected_result: String(raw?.expected_result || "").trim(),
    verification: String(raw?.verification || "").trim(),
    order,
  }));

  if (
    nodes.some(
      (node) =>
        !node.id ||
        !node.title ||
        !node.expected_result ||
        !node.verification ||
        node.scope.length === 0
    )
  ) {
    return { ok: false, reason: "node-fields-missing" };
  }

  const ids = new Set(nodes.map((node) => node.id));
  if (ids.size !== nodes.length) {
    return { ok: false, reason: "duplicate-id" };
  }

  for (const node of nodes) {
    if (
      node.depends_on.includes(node.id) ||
      node.depends_on.some((id) => !ids.has(id))
    ) {
      return { ok: false, reason: "dependency-invalid" };
    }

    for (const scope of node.scope) {
      if (
        !scope ||
        scope.startsWith("/") ||
        scope.split("/").includes("..") ||
        matchesAnyGlob(scope, task.forbiddenScope)
      ) {
        return { ok: false, reason: "scope-forbidden" };
      }

      const wildcard = /[*?]/.test(scope);
      const withinParent = wildcard
        ? task.allowedScope.includes(scope)
        : matchesAnyGlob(scope, task.allowedScope);

      if (!withinParent) {
        return {
          ok: false,
          reason: "scope-outside-parent:" + scope,
        };
      }
    }
  }

  const byID = new Map(nodes.map((node) => [node.id, node]));
  const visiting = new Set();
  const visited = new Set();

  function visit(id) {
    if (visiting.has(id)) return false;
    if (visited.has(id)) return true;

    visiting.add(id);
    const node = byID.get(id);

    for (const dependency of node.depends_on) {
      if (!visit(dependency)) return false;
    }

    visiting.delete(id);
    visited.add(id);
    return true;
  }

  for (const node of nodes) {
    if (!visit(node.id)) {
      return { ok: false, reason: "dependency-cycle" };
    }
  }

  return { ok: true, nodes };
}

function extractContent(payload) {
  return String(payload?.message?.content || "").trim();
}

function parseJSONContent(content) {
  try {
    return JSON.parse(content);
  } catch {}

  const first = content.indexOf("{");
  const last = content.lastIndexOf("}");

  if (first < 0 || last <= first) return null;

  try {
    return JSON.parse(content.slice(first, last + 1));
  } catch {
    return null;
  }
}

function selfTest() {
  const task = {
    allowedScope: [
      "App/**",
      "Scripts/example-self-test.mjs",
    ],
    forbiddenScope: ["Mentor/**"],
  };

  const good = {
    summary: "split",
    subtasks: [
      {
        id: "store",
        title: "Store",
        depends_on: [],
        scope: ["App/Test.swift"],
        expected_result: "store exists",
        verification: "build_check",
      },
      {
        id: "verify",
        title: "Verifier",
        depends_on: ["store"],
        scope: ["Scripts/example-self-test.mjs"],
        expected_result: "policy test exists",
        verification: "node self-test",
      },
    ],
  };

  const bad = {
    summary: "bad",
    subtasks: [
      {
        id: "bad",
        title: "Bad",
        depends_on: [],
        scope: ["Mentor/latest.json"],
        expected_result: "bad",
        verification: "bad",
      },
    ],
  };

  const checks = [
    validatePlan(good, task).ok === true,
    validatePlan(bad, task).ok === false,
    globToRegExp("App/**").test("App/Foo.swift"),
    !globToRegExp("App/**").test("Mentor/Foo.swift"),
    parseJSONContent('prefix {"summary":"x","subtasks":[]} suffix')
      ?.summary === "x",
  ];

  if (!checks.every(Boolean)) {
    fail("self-test", 2);
  }

  process.stdout.write(
    "developer_task_decomposer_self_test_ok\n" +
    "planner_authority=advisory_graph_only\n" +
    "scope_widening=forbidden\n"
  );
}

if (process.argv.includes("--self-test")) {
  selfTest();
  process.exit(0);
}

if (!taskFile || !fs.existsSync(taskFile)) {
  fail("task-file-missing", 3);
}

if (!resultFile) {
  fail("result-file-missing", 4);
}

if (!model) {
  fail("model-missing", 5);
}

let payload;
try {
  payload = JSON.parse(fs.readFileSync(taskFile, "utf8"));
} catch {
  fail("task-json-invalid", 6);
}

const task = compactTask(payload);

if (task.allowedScope.length === 0) {
  fail("allowed-scope-empty", 7);
}

const systemPrompt = [
  "You are KRALI Developer Task Decomposer.",
  "You plan only; you do not write code, use tools, approve actions, merge branches, or change task authority.",
  "Split the controlled developer task into the smallest dependency-ordered implementation subtasks that can each be independently build-checked.",
  "Every subtask must require a real code/file mutation. Do NOT create a verification-only final node; parent task verification runs after the graph.",
  "Prefer 2-5 subtasks for multi-surface work. Use one subtask only when the task is truly atomic.",
  "Subtask scope must be a strict subset of the parent allowedScope. Never add paths not permitted by parent allowedScope and never include forbiddenScope.",
  "Preserve existing APIs unless the task explicitly requires breaking/replacing them. For primitivePatch work, prefer surgical extension over rewrites.",
  "Order dependencies so data/model foundations precede wiring and wiring precedes UI.",
  "Verification is a short intent description for that node; deterministic build_check is still mandatory after every node.",
  "Do not include raw user data. Return only JSON matching the schema.",
].join("\n");

const controller = new AbortController();
const timer = setTimeout(() => controller.abort(), timeoutMs);

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
      keep_alive: "2m",
      options: {
        temperature: 0.02,
        num_ctx: 6144,
        num_predict: 1200,
      },
      messages: [
        {
          role: "system",
          content: systemPrompt,
        },
        {
          role: "user",
          content: JSON.stringify({ task }),
        },
      ],
    }),
  });
} catch (error) {
  clearTimeout(timer);
  const name =
    error instanceof Error ? error.name : "unknown";
  if (name === "AbortError") {
    fail("transport-timeout", 28);
  }
  fail("transport:" + name, 20);
}
clearTimeout(timer);

if (!response.ok) {
  if (response.status === 429) {
    fail("http-429", 29);
  }
  fail("http-" + response.status, 21);
}

let responsePayload;
try {
  responsePayload = await response.json();
} catch {
  fail("response-json-invalid", 22);
}

const content = extractContent(responsePayload);
const plan = parseJSONContent(content);

if (!plan) {
  fail("structured-plan-invalid", 23);
}

const validated = validatePlan(plan, task);
if (!validated.ok) {
  fail("plan-validation:" + validated.reason, 24);
}

const artifact = {
  createdAt: new Date().toISOString(),
  provider: "krali-structured-controller",
  model,
  appVersion,
  runID,
  review: {
    phase: "plan",
    verdict: "APPROVE",
    summary: String(plan.summary || "KRALI baseline task decomposition"),
    confidence: 0,
    subtasks: validated.nodes.map((node) => ({
      id: node.id,
      title: node.title,
      depends_on: node.depends_on,
      scope: node.scope,
      expected_result: node.expected_result,
      verification: node.verification,
    })),
    findings: [],
    generalized_lessons: [],
  },
  authority: {
    plannerOnly: true,
    mutationAuthority: false,
    approvalAuthority: false,
    mergeAuthority: false,
  },
};

fs.mkdirSync(path.dirname(resultFile), { recursive: true });
fs.writeFileSync(
  resultFile,
  JSON.stringify(artifact, null, 2) + "\n",
  "utf8"
);

process.stdout.write(
  "developer_task_decomposer_ok|nodes=" +
    validated.nodes.length +
    "\n"
);
