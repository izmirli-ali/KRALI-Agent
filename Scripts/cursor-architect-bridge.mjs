#!/usr/bin/env node

import fs from "fs";
import path from "path";
import { spawn } from "child_process";

const worktree = process.env.KRALI_WORKTREE || "";
const promptFile = process.env.KRALI_PROMPT_FILE || "";
const resultFile = process.env.KRALI_CURSOR_RESULT_FILE || "";
const agentBin =
  process.env.KRALI_CURSOR_AGENT_BIN ||
  path.join(process.env.HOME || "", ".local", "bin", "agent");
const failureState = process.env.KRALI_FAILURE_STATE || "unknown";
const failureMessage = process.env.KRALI_FAILURE_MESSAGE || "";
const gapLabel = process.env.KRALI_GAP_LABEL || "Unknown capability gap";
const runtimeHints = process.env.KRALI_RUNTIME_SOURCE_HINTS || "";
const appVersion = process.env.KRALI_APP_VERSION || "unknown";
const runID = process.env.KRALI_RUN_ID || "unknown";
const diagnosticFingerprint =
  process.env.KRALI_CURSOR_DIAGNOSTIC_FINGERPRINT || "";
const timeoutMs = Number(
  process.env.KRALI_CURSOR_ARCHITECT_TIMEOUT_MS || "180000"
);

const sandbox = {
  type: "workspace_readonly",
  networkPolicy: {
    default: "deny",
    allow: [],
    deny: []
  }
};

const cliConfig = {
  permissions: {
    allow: ["Read(**)"],
    deny: [
      "Write(**)",
      "Shell(*)",
      "WebFetch(*)",
      "Mcp(*:*)"
    ]
  }
};

if (process.argv.includes("--self-test")) {
  const deny = new Set(cliConfig.permissions.deny);
  const safe =
    sandbox.type === "workspace_readonly" &&
    sandbox.networkPolicy.default === "deny" &&
    cliConfig.permissions.allow.includes("Read(**)") &&
    deny.has("Write(**)") &&
    deny.has("Shell(*)") &&
    deny.has("WebFetch(*)") &&
    deny.has("Mcp(*:*)");

  if (!safe) {
    process.stderr.write("cursor_architect_safety_failed\n");
    process.exit(2);
  }

  process.stdout.write("cursor_architect_safety_ok\n");
  process.exit(0);
}

function fail(message, code = 1) {
  process.stderr.write(message + "\n");
  process.exit(code);
}

if (!worktree || !fs.existsSync(worktree)) {
  fail("Cursor Architect worktree bulunamadı.", 40);
}

if (!promptFile || !fs.existsSync(promptFile)) {
  fail("Cursor Architect prompt kaynağı bulunamadı.", 40);
}

if (!resultFile) {
  fail("Cursor Architect result hedefi tanımlı değil.", 40);
}

if (!fs.existsSync(agentBin)) {
  fail("Cursor CLI bulunamadı: " + agentBin, 40);
}

const originalPrompt = fs.readFileSync(promptFile, "utf8").slice(0, 24000);

const prompt = [
  "You are Cursor Architect, a READ-ONLY external diagnosis provider for the KRALI macOS agent project.",
  "",
  "Hard safety contract:",
  "- Do NOT modify, create, delete, rename, or move any file.",
  "- Do NOT run shell commands.",
  "- Do NOT use web fetch, MCP, browser, or external tools.",
  "- Do NOT create commits, branches, worktrees, PRs, or patches.",
  "- Inspect the current workspace using read/search/code-navigation only.",
  "- Do not solve by hard-coding app names, brands, or one user sentence.",
  "- Prefer generalized root-cause analysis tied to exact source symbols.",
  "",
  "Your task:",
  "A local KRALI Developer Agent stopped without a trustworthy candidate. Diagnose the most likely root cause and identify the smallest generic implementation target for a future developer agent. You are NOT the mutation agent.",
  "",
  "Failure state: " + failureState,
  "Failure message: " + failureMessage,
  "Gap label: " + gapLabel,
  runtimeHints ? "Runtime source hints: " + runtimeHints : "",
  "",
  "Existing Developer Agent brief/context:",
  originalPrompt,
  "",
  "Return ONLY valid JSON with this exact top-level shape:",
  "{",
  '  "summary": "short diagnosis",',
  '  "confidence": 0.0,',
  '  "rootCauseHypotheses": [',
  "    {",
  '      "hypothesis": "...",',
  '      "confidence": 0.0,',
  '      "evidence": ["..."],',
  '      "sourceTargets": [{"path":"...","symbols":["..."]}]',
  "    }",
  "  ],",
  '  "recommendedNextSteps": ["..."],',
  '  "testsRequired": ["..."],',
  '  "warnings": ["..."]',
  "}",
  "",
  "Do not wrap JSON in markdown fences."
].filter(Boolean).join("\n");

const cursorDir = path.join(worktree, ".cursor");
const sandboxPath = path.join(cursorDir, "sandbox.json");
const cliPath = path.join(cursorDir, "cli.json");

fs.mkdirSync(cursorDir, { recursive: true });

function snapshot(file) {
  if (!fs.existsSync(file)) return null;
  return fs.readFileSync(file);
}

const previousSandbox = snapshot(sandboxPath);
const previousCLI = snapshot(cliPath);

fs.writeFileSync(
  sandboxPath,
  JSON.stringify(sandbox, null, 2) + "\n"
);
fs.writeFileSync(
  cliPath,
  JSON.stringify(cliConfig, null, 2) + "\n"
);

function restore(file, previous) {
  try {
    if (previous === null) {
      fs.rmSync(file, { force: true });
    } else {
      fs.writeFileSync(file, previous);
    }
  } catch {}
}

function restoreConfigs() {
  restore(sandboxPath, previousSandbox);
  restore(cliPath, previousCLI);

  try {
    if (
      fs.existsSync(cursorDir) &&
      fs.readdirSync(cursorDir).length === 0
    ) {
      fs.rmdirSync(cursorDir);
    }
  } catch {}
}

const env = { ...process.env };
// v0.10.26 intentionally uses the interactive-account login only.
// Never auto-switch to an explicit API-key billing path.
delete env.CURSOR_API_KEY;
delete env.CURSOR_AUTH_TOKEN;

const args = [
  "--mode=ask",
  "--print",
  "--output-format",
  "text",
  "--sandbox",
  "enabled",
  "--workspace",
  worktree,
  prompt
];

let stdout = "";
let stderr = "";
let timedOut = false;

const child = spawn(agentBin, args, {
  cwd: worktree,
  env,
  stdio: ["ignore", "pipe", "pipe"]
});

child.stdout.on("data", (chunk) => {
  stdout += chunk.toString();
});

child.stderr.on("data", (chunk) => {
  stderr += chunk.toString();
});

const timer = setTimeout(() => {
  timedOut = true;
  try {
    child.kill("SIGTERM");
  } catch {}
}, Math.max(15000, timeoutMs));

child.on("error", (error) => {
  clearTimeout(timer);
  restoreConfigs();
  fail("Cursor Architect başlatılamadı: " + error.message, 40);
});

child.on("close", (code, signal) => {
  clearTimeout(timer);
  restoreConfigs();

  const combined = (stdout + "\n" + stderr).trim();
  const normalized = combined.toLowerCase();

  if (timedOut) {
    fail("Cursor Architect zaman aşımına uğradı.", 44);
  }

  if (
    /quota|usage limit|rate limit|upgrade plan|insufficient|credits exhausted|limit reached/.test(
      normalized
    )
  ) {
    fail("Cursor Architect ücretsiz kullanım limiti dolu veya rate-limit oluştu.", 42);
  }

  if (
    /not logged in|login required|authentication|unauthorized|sign in/.test(
      normalized
    )
  ) {
    fail("Cursor Architect kimlik doğrulaması hazır değil.", 43);
  }

  if (code !== 0) {
    fail(
      "Cursor Architect başarısız oldu (exit " +
        String(code) +
        (signal ? ", signal=" + signal : "") +
        "): " +
        combined.slice(-1200),
      45
    );
  }

  let text = stdout.trim();
  text = text
    .replace(/^\s*```(?:json)?\s*/i, "")
    .replace(/\s*```\s*$/i, "")
    .trim();

  let diagnosis;
  try {
    diagnosis = JSON.parse(text);
  } catch {
    diagnosis = {
      summary: text.slice(0, 4000),
      confidence: 0,
      rootCauseHypotheses: [],
      recommendedNextSteps: [],
      testsRequired: [],
      warnings: [
        "Cursor response was not valid JSON; raw text preserved in summary."
      ]
    };
  }

  const payload = {
    createdAt: new Date().toISOString(),
    provider: "cursor-cli",
    mode: "architect-readonly",
    appVersion,
    runID,
    diagnosticFingerprint,
    failureState,
    failureMessage,
    gapLabel,
    safety: {
      cliMode: "ask",
      nonInteractive: true,
      sandbox: "workspace_readonly",
      writesDenied: true,
      shellDenied: true,
      webFetchDenied: true,
      mcpDenied: true,
      explicitAPIKeyDisabled: true
    },
    diagnosis
  };

  fs.mkdirSync(path.dirname(resultFile), {
    recursive: true
  });
  fs.writeFileSync(
    resultFile,
    JSON.stringify(payload, null, 2) + "\n"
  );

  process.stdout.write(
    "cursor_architect_ok|" +
      (diagnosis.summary || "diagnosis ready")
        .toString()
        .replace(/[\r\n|]+/g, " ")
        .slice(0, 400) +
      "\n"
  );
});
