import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";

const worktree = process.env.KRALI_WORKTREE || "";
const promptFile = process.env.KRALI_PROMPT_FILE || "";
const model = process.env.KRALI_DEV_MODEL || "";
const controllerModel =
  process.env.KRALI_CONTROLLER_MODEL || model;
const baseUrl =
  (process.env.KRALI_OLLAMA_BASE_URL || "http://127.0.0.1:11434")
    .replace(/\/$/, "");
const statusFile = process.env.KRALI_STATUS_FILE || "";
const branchName = process.env.KRALI_BRANCH || "";
const gapLabel = process.env.KRALI_GAP_LABEL || "Capability";
const appVersion = process.env.KRALI_APP_VERSION || "unknown";
const runID = process.env.KRALI_RUN_ID || "";
const checkpointFile =
  process.env.KRALI_CHECKPOINT_FILE || "";
const requireChange =
  (process.env.KRALI_REQUIRE_CHANGE || "0") === "1";
const maxCompletionRejections = Number(
  process.env.KRALI_LOCAL_AGENT_MAX_COMPLETION_REJECTIONS || "3"
);
const maxStructuredActions = Number(
  process.env.KRALI_LOCAL_AGENT_MAX_STRUCTURED_ACTIONS || "8"
);
const maxInspectionTools = Number(
  process.env.KRALI_LOCAL_AGENT_MAX_INSPECTIONS || "6"
);
const maxIterations = Number(
  process.env.KRALI_LOCAL_AGENT_MAX_ITERATIONS || "16"
);
const hardTimeoutMs = Number(
  process.env.KRALI_LOCAL_AGENT_TIMEOUT_MS || "420000"
);
const requestTimeoutMs = Number(
  process.env.KRALI_LOCAL_AGENT_REQUEST_TIMEOUT_MS || "90000"
);
const structuredRequestTimeoutMs = Number(
  process.env.KRALI_LOCAL_AGENT_STRUCTURED_TIMEOUT_MS || "60000"
);
const maxRequestTimeoutRetries = Number(
  process.env.KRALI_LOCAL_AGENT_REQUEST_TIMEOUT_RETRIES || "2"
);
const startedAt = Date.now();

function fail(message, code = 20, state = "local_agent_failed") {
  persistStatus(state, message);
  console.error(message);
  process.exit(code);
}

function persistStatus(state, message) {
  if (!statusFile) return;

  const line =
    state +
    "|" +
    message +
    "|" +
    branchName +
    "|" +
    worktree +
    "|@meta|app=" +
    appVersion +
    "|at=" +
    Math.floor(Date.now() / 1000) +
    "|run=" +
    runID +
    "\n";

  try {
    fs.writeFileSync(statusFile, line, "utf8");
  } catch {}
}

function stage(state, message) {
  persistStatus(state, message);
  process.stdout.write(
    "KRALI_LOCAL_STAGE " + state + " • " + message + "\n"
  );
}

if (!worktree || !promptFile || !model) {
  fail(
    "KRALI native local agent için worktree/prompt/model eksik.",
    2
  );
}

const root = fs.realpathSync(worktree);
const prompt = fs.readFileSync(promptFile, "utf8");

function safeRelativePath(input = "") {
  const value = String(input || "").trim();
  const candidate = path.resolve(root, value || ".");
  const relative = path.relative(root, candidate);

  if (
    relative.startsWith("..") ||
    path.isAbsolute(relative) && relative !== ""
  ) {
    throw new Error("Worktree dışı yol reddedildi: " + value);
  }

  return { absolute: candidate, relative };
}

function assertMutablePath(relative) {
  const normalized = String(relative || "")
    .replace(/\\/g, "/")
    .replace(/^\.\//, "");

  if (
    normalized === "VERSION" ||
    normalized.startsWith("Mentor/") ||
    normalized.startsWith(".git/")
  ) {
    throw new Error(
      "Korunan proje alanına yazma reddedildi: " + normalized
    );
  }
}

function truncate(value, limit = 16000) {
  const text = String(value ?? "");
  return text.length <= limit
    ? text
    : text.slice(0, limit) + "\n…[truncated]";
}

function runGit(args, options = {}) {
  const result = spawnSync(
    "/usr/bin/git",
    ["-C", root, ...args],
    {
      encoding: "utf8",
      timeout: options.timeout || 30000,
      input: options.input,
      maxBuffer: 8 * 1024 * 1024,
    }
  );

  return {
    status: result.status ?? 1,
    stdout: result.stdout || "",
    stderr: result.stderr || "",
  };
}

function executeTool(name, args = {}) {
  switch (name) {
    case "list_files": {
      const { absolute, relative } =
        safeRelativePath(args.path || ".");
      const maxEntries = Math.max(
        1,
        Math.min(Number(args.max_entries || 200), 500)
      );

      const entries = [];
      const queue = [{ dir: absolute, depth: 0 }];
      const maxDepth = Math.max(
        0,
        Math.min(Number(args.max_depth ?? 2), 4)
      );

      while (queue.length && entries.length < maxEntries) {
        const current = queue.shift();
        let children = [];

        try {
          children = fs.readdirSync(current.dir, {
            withFileTypes: true,
          });
        } catch (error) {
          return {
            ok: false,
            error: String(error),
          };
        }

        for (const child of children) {
          if (
            child.name === ".git" ||
            child.name === ".build-check" ||
            child.name === "node_modules"
          ) {
            continue;
          }

          const full = path.join(current.dir, child.name);
          const rel = path.relative(root, full);
          entries.push(
            (child.isDirectory() ? "DIR  " : "FILE ") + rel
          );

          if (
            child.isDirectory() &&
            current.depth < maxDepth &&
            entries.length < maxEntries
          ) {
            queue.push({
              dir: full,
              depth: current.depth + 1,
            });
          }

          if (entries.length >= maxEntries) break;
        }
      }

      return {
        ok: true,
        path: relative || ".",
        entries,
      };
    }

    case "search_codebase": {
      const query = String(args.query || "");
      if (!query) {
        return { ok: false, error: "query gerekli" };
      }

      const scoped = args.path
        ? safeRelativePath(args.path).relative
        : "";
      const maxResults = Math.max(
        1,
        Math.min(Number(args.max_results || 80), 200)
      );

      const gitArgs = [
        "grep",
        "-n",
        "-I",
        "-F",
        "-e",
        query,
      ];

      if (scoped) {
        gitArgs.push("--", scoped);
      }

      const result = runGit(gitArgs);

      if (result.status !== 0 && result.status !== 1) {
        return {
          ok: false,
          error: truncate(result.stderr, 4000),
        };
      }

      const lines = result.stdout
        .split("\n")
        .filter(Boolean)
        .slice(0, maxResults);

      return {
        ok: true,
        matches: lines,
      };
    }

    case "read_file": {
      const { absolute, relative } =
        safeRelativePath(args.path);

      if (!fs.existsSync(absolute)) {
        return {
          ok: false,
          error: "Dosya bulunamadı: " + relative,
        };
      }

      const stat = fs.statSync(absolute);
      if (!stat.isFile()) {
        return {
          ok: false,
          error: "Hedef dosya değil: " + relative,
        };
      }

      const lines = fs.readFileSync(absolute, "utf8").split("\n");
      const start = Math.max(
        1,
        Number(args.start_line || 1)
      );
      const end = Math.min(
        lines.length,
        Number(args.end_line || Math.min(lines.length, start + 399))
      );

      const content = lines
        .slice(start - 1, end)
        .map((line, index) =>
          String(start + index).padStart(5, " ") + " | " + line
        )
        .join("\n");

      return {
        ok: true,
        path: relative,
        start_line: start,
        end_line: end,
        total_lines: lines.length,
        content: truncate(content, 24000),
      };
    }

    case "replace_text": {
      const { absolute, relative } =
        safeRelativePath(args.path);
      assertMutablePath(relative);
      const oldText = String(args.old_text ?? "");
      const newText = String(args.new_text ?? "");

      if (!oldText) {
        return { ok: false, error: "old_text gerekli" };
      }

      const source = fs.readFileSync(absolute, "utf8");
      const occurrences = source.split(oldText).length - 1;

      if (occurrences === 0) {
        return {
          ok: false,
          error: "old_text dosyada bulunamadı",
        };
      }

      if (!args.replace_all && occurrences !== 1) {
        return {
          ok: false,
          error:
            "old_text " +
            occurrences +
            " kez bulundu; daha özgün eşleşme kullan",
        };
      }

      const updated = args.replace_all
        ? source.split(oldText).join(newText)
        : source.replace(oldText, newText);

      fs.writeFileSync(absolute, updated, "utf8");

      return {
        ok: true,
        path: relative,
        replacements: args.replace_all ? occurrences : 1,
      };
    }

    case "write_file": {
      const { absolute, relative } =
        safeRelativePath(args.path);
      assertMutablePath(relative);
      const content = String(args.content ?? "");

      if (content.length > 600000) {
        return {
          ok: false,
          error: "Dosya içeriği güvenli boyut sınırını aşıyor",
        };
      }

      fs.mkdirSync(path.dirname(absolute), {
        recursive: true,
      });
      fs.writeFileSync(absolute, content, "utf8");

      return {
        ok: true,
        path: relative,
        bytes: Buffer.byteLength(content),
      };
    }

    case "apply_patch": {
      const patch = String(args.patch || "");

      if (!patch.trim()) {
        return { ok: false, error: "patch gerekli" };
      }

      const pathLines = patch
        .split("\n")
        .filter((line) =>
          line.startsWith("+++ ") || line.startsWith("--- ")
        );

      for (const line of pathLines) {
        let value = line.slice(4).trim().split("\t")[0];
        if (value === "/dev/null") continue;
        value = value.replace(/^[ab]\//, "");

        if (
          value.startsWith("/") ||
          value.split("/").includes("..")
        ) {
          return {
            ok: false,
            error: "Worktree dışı patch yolu reddedildi: " + value,
          };
        }

        try {
          assertMutablePath(value);
        } catch (error) {
          return {
            ok: false,
            error:
              error instanceof Error
                ? error.message
                : String(error),
          };
        }
      }

      const check = runGit(
        ["apply", "--check", "--whitespace=nowarn", "-"],
        { input: patch }
      );

      if (check.status !== 0) {
        return {
          ok: false,
          error: truncate(check.stderr || check.stdout, 6000),
        };
      }

      const applied = runGit(
        ["apply", "--whitespace=nowarn", "-"],
        { input: patch }
      );

      return {
        ok: applied.status === 0,
        output: truncate(applied.stdout || applied.stderr, 6000),
      };
    }

    case "git_status": {
      const result = runGit(["status", "--short"]);
      return {
        ok: result.status === 0,
        output: truncate(result.stdout || result.stderr, 12000),
      };
    }

    case "git_diff": {
      const result = runGit(["diff", "--"]);
      return {
        ok: result.status === 0,
        output: truncate(result.stdout || result.stderr, 24000),
      };
    }

    case "build_check": {
      const script = path.join(root, "Scripts", "build-check.command");

      if (!fs.existsSync(script)) {
        return {
          ok: false,
          error: "Scripts/build-check.command bulunamadı",
        };
      }

      const result = spawnSync(
        "/bin/zsh",
        [script, root],
        {
          cwd: root,
          encoding: "utf8",
          timeout: 240000,
          maxBuffer: 12 * 1024 * 1024,
        }
      );

      return {
        ok: result.status === 0,
        exit_code: result.status ?? 1,
        output: truncate(
          (result.stdout || "") + "\n" + (result.stderr || ""),
          24000
        ),
      };
    }

    default:
      return {
        ok: false,
        error: "Bilinmeyen tool: " + name,
      };
  }
}

const tools = [
  {
    type: "function",
    function: {
      name: "list_files",
      description:
        "List files and folders inside the isolated KRALI candidate worktree.",
      parameters: {
        type: "object",
        properties: {
          path: { type: "string" },
          max_depth: { type: "integer" },
          max_entries: { type: "integer" },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "search_codebase",
      description:
        "Search tracked source files for an exact text fragment.",
      parameters: {
        type: "object",
        required: ["query"],
        properties: {
          query: { type: "string" },
          path: { type: "string" },
          max_results: { type: "integer" },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "read_file",
      description:
        "Read a bounded line range from one source file.",
      parameters: {
        type: "object",
        required: ["path"],
        properties: {
          path: { type: "string" },
          start_line: { type: "integer" },
          end_line: { type: "integer" },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "replace_text",
      description:
        "Safely replace an exact source fragment in one worktree file.",
      parameters: {
        type: "object",
        required: ["path", "old_text", "new_text"],
        properties: {
          path: { type: "string" },
          old_text: { type: "string" },
          new_text: { type: "string" },
          replace_all: { type: "boolean" },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "write_file",
      description:
        "Create or overwrite a file inside the isolated candidate worktree.",
      parameters: {
        type: "object",
        required: ["path", "content"],
        properties: {
          path: { type: "string" },
          content: { type: "string" },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "apply_patch",
      description:
        "Apply a unified diff inside the isolated candidate worktree.",
      parameters: {
        type: "object",
        required: ["patch"],
        properties: {
          patch: { type: "string" },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "git_status",
      description:
        "Show modified files in the candidate worktree.",
      parameters: {
        type: "object",
        properties: {},
      },
    },
  },
  {
    type: "function",
    function: {
      name: "git_diff",
      description:
        "Show the current candidate source diff.",
      parameters: {
        type: "object",
        properties: {},
      },
    },
  },
  {
    type: "function",
    function: {
      name: "build_check",
      description:
        "Run KRALI's bounded local build/regression check in the candidate worktree.",
      parameters: {
        type: "object",
        properties: {},
      },
    },
  },
];

const systemPrompt = [
  "You are KRALI Native Local Developer Agent.",
  "You run fully locally through Ollama and may use only the provided tools.",
  "Work only inside the isolated candidate worktree.",
  "Do not push, merge, checkout main, or alter external system state.",
  "Do not modify VERSION, Mentor JSON, billing, updater signing, or user credentials.",
  "Prefer a minimal generic fix; never hard-code one app, brand, or exact user prompt.",
  "Inspect relevant code before editing.",
  "If you edit code, inspect git_diff and run build_check before finishing.",
  "A capability gap is not resolved by merely explaining or summarizing source code.",
  "If you say you need to inspect, read, search, change, diff, or build something, call the matching tool in the SAME turn instead of describing the next step.",
  "Never say 'I will read more' or 'let me inspect' without a real tool call.",
  "For an active capability gap, a clean candidate worktree is not a successful completion.",
  "If a source change is required, use replace_text, write_file, or apply_patch instead of returning prose.",
  "A changed candidate may finish only after git_diff inspection and a successful build_check.",
  "Do not emit fake tool JSON in prose. Call tools through native function calling.",
].join("\n");

const messages = [
  { role: "system", content: systemPrompt },
  { role: "user", content: prompt },
];

let sawToolCall = false;
let sawMutatingTool = false;
let sawGitDiff = false;
let buildCheckPassed = false;
let completionRejections = 0;
let structuredActions = 0;
let inspectionToolCalls = 0;
let implementationPhaseAnnounced = false;
let consecutiveRequestTimeouts = 0;
let checkpointEvidence = [];
let resumedFromCheckpoint = false;
let implementationSearchCompleted = false;
let implementationReadCompleted = false;
let implementationTargetPaths = [];

const inspectionToolNames = new Set([
  "list_files",
  "search_codebase",
  "read_file",
]);
const mutationToolNames = new Set([
  "replace_text",
  "write_file",
  "apply_patch",
]);

function developmentPhase() {
  if (sawMutatingTool) return "verification";

  if (
    requireChange &&
    (
      implementationPhaseAnnounced ||
      inspectionToolCalls >= maxInspectionTools
    )
  ) {
    return "implementation";
  }

  return "inspection";
}

function inspectionWeight(name) {
  if (name === "list_files") {
    return 0;
  }

  if (
    name === "search_codebase" ||
    name === "read_file"
  ) {
    return 1;
  }

  return 0;
}

function toolsForCurrentPhase() {
  const phase = developmentPhase();

  return tools.filter((tool) => {
    const name = tool.function.name;

    if (phase === "verification") {
      return (
        mutationToolNames.has(name) ||
        name === "git_diff" ||
        name === "build_check" ||
        name === "git_status"
      );
    }

    if (phase === "implementation") {
      if (mutationToolNames.has(name)) {
        return true;
      }

      if (!implementationSearchCompleted) {
        return name === "search_codebase";
      }

      if (!implementationReadCompleted) {
        return name === "read_file";
      }

      return false;
    }

    return true;
  });
}

function persistCheckpoint(reason = "progress") {
  if (!checkpointFile) return;

  const status = candidateStatus();
  const payload = {
    version: 3,
    gapLabel,
    reason,
    model,
    controllerModel,
    phase: developmentPhase(),
    inspectionToolCalls,
    implementationPhaseAnnounced,
    sawMutatingTool,
    sawGitDiff,
    buildCheckPassed,
    candidateDirty: Boolean(status?.ok && status?.dirty),
    candidateIdentity: candidateIdentity(),
    implementationSearchCompleted,
    implementationReadCompleted,
    implementationTargetPaths: implementationTargetPaths.slice(0, 8),
    evidence: checkpointEvidence.slice(-12),
    savedAt: new Date().toISOString(),
  };

  try {
    fs.mkdirSync(path.dirname(checkpointFile), {
      recursive: true,
    });
    fs.writeFileSync(
      checkpointFile,
      JSON.stringify(payload, null, 2),
      "utf8"
    );
  } catch {}
}

function loadCheckpoint() {
  if (!checkpointFile) return null;

  try {
    if (!fs.existsSync(checkpointFile)) return null;
    const payload = JSON.parse(
      fs.readFileSync(checkpointFile, "utf8")
    );

    if (
      !payload ||
      ![1, 2, 3].includes(Number(payload.version || 0))
    ) {
      return null;
    }

    return payload;
  } catch {
    return null;
  }
}

function recordCheckpointEvidence(name, args, result) {
  if (!inspectionToolNames.has(name) || !result?.ok) {
    return;
  }

  checkpointEvidence.push({
    tool: name,
    args: truncate(JSON.stringify(args || {}), 1600),
    result: truncate(JSON.stringify(result), 5000),
  });

  checkpointEvidence = checkpointEvidence.slice(-12);
}

function resumeCheckpointContext() {
  const checkpoint = loadCheckpoint();
  if (!checkpoint) return;

  const evidence = Array.isArray(checkpoint.evidence)
    ? checkpoint.evidence.slice(-10)
    : [];

  if (evidence.length === 0) return;

  checkpointEvidence = evidence;

  if (
    Number(checkpoint.version || 0) >= 3 &&
    (
      checkpoint.phase === "implementation" ||
      checkpoint.phase === "verification"
    )
  ) {
    implementationSearchCompleted =
      checkpoint.implementationSearchCompleted === true;
    implementationReadCompleted =
      checkpoint.implementationReadCompleted === true;
    implementationTargetPaths =
      Array.isArray(checkpoint.implementationTargetPaths)
        ? checkpoint.implementationTargetPaths
            .map((value) => String(value || ""))
            .filter(Boolean)
            .slice(0, 8)
        : [];
  }

  const currentStatus = candidateStatus();
  const currentIdentity = candidateIdentity();
  const checkpointIdentity =
    typeof checkpoint.candidateIdentity === "string"
      ? checkpoint.candidateIdentity
      : null;

  const canResumeVerification =
    checkpoint.phase === "verification" &&
    checkpoint.candidateDirty === true &&
    currentStatus?.ok === true &&
    currentStatus.dirty === true &&
    Boolean(checkpointIdentity) &&
    Boolean(currentIdentity) &&
    checkpointIdentity === currentIdentity;

  let resumedPhase = String(
    checkpoint.phase || "inspection"
  );

  if (canResumeVerification) {
    sawMutatingTool = true;
    sawGitDiff = checkpoint.sawGitDiff === true;
    buildCheckPassed =
      checkpoint.buildCheckPassed === true;
    inspectionToolCalls = maxInspectionTools;
    implementationPhaseAnnounced = true;
    resumedPhase = "verification";
  } else if (
    checkpoint.phase === "implementation" ||
    checkpoint.phase === "verification"
  ) {
    // Diagnostic evidence is portable. Candidate execution state is not.
    // A clean/new worktree cannot inherit verification from an older patch.
    sawMutatingTool = false;
    sawGitDiff = false;
    buildCheckPassed = false;
    inspectionToolCalls = Math.max(
      0,
      maxInspectionTools - 1
    );
    implementationPhaseAnnounced = true;
    resumedPhase = "implementation";
  } else {
    inspectionToolCalls = Math.min(
      Number(
        checkpoint.inspectionToolCalls ||
          evidence.length
      ),
      Math.max(0, maxInspectionTools - 1)
    );
    resumedPhase = "inspection";
  }

  resumedFromCheckpoint = true;

  messages.push({
    role: "user",
    content: [
      "KRALI process-level developer checkpoint bulundu.",
      "Önceki oturum watchdog/timeout nedeniyle kapanmış olabilir.",
      "Aynı incelemeleri sıfırdan tekrar etme; aşağıdaki gerçek tool kanıtlarını başlangıç bağlamı olarak kullan.",
      "Checkpoint recorded phase: " +
        String(checkpoint.phase || "inspection"),
      "Effective resume phase: " + resumedPhase,
      "Checkpoint evidence:",
      truncate(JSON.stringify(evidence), 18000),
      resumedPhase === "implementation"
        ? (
            "Implementation navigation state: searchCompleted=" +
            String(implementationSearchCompleted) +
            ", readCompleted=" +
            String(implementationReadCompleted) +
            ", targetPaths=" +
            JSON.stringify(implementationTargetPaths)
          )
        : "",
      resumedPhase === "verification"
        ? "Aynı candidate diff kimliği doğrulandı. Verification adımlarından devam et."
        : resumedPhase === "implementation"
          ? (
              implementationReadCompleted
                ? "Teşhis ve hedef kaynak doğrulaması taşındı fakat candidate yürütme durumu taşınmadı. Artık inspection yapma; minimum generic patch üret."
                : implementationSearchCompleted
                  ? "Hedef kaynak önceki tool kanıtıyla bulundu. Yalnız bu hedef kaynağı read_file ile doğrula; ardından minimum generic patch üret."
                  : "Teşhis kanıtı taşındı fakat candidate yürütme durumu taşınmadı. Bir hedefli search_codebase ile kaynak noktasını bul; sonra yalnız o kaynağı doğrulayıp patch üret."
            )
          : "Kaldığın teşhis noktasından devam et; gereksiz repo taraması yapma.",
      "Önceki checkpoint bir öneri değil kanıt özetidir; source ile çelişirse source gerçeğini esas al."
    ].join("\n"),
  });

  stage(
    "local_agent_resumed",
    gapLabel +
      " process-level checkpoint yüklendi • evidence=" +
      evidence.length +
      " • recordedPhase=" +
      String(checkpoint.phase || "inspection") +
      " • effectivePhase=" +
      resumedPhase +
      " • candidateMatch=" +
      String(Boolean(canResumeVerification))
  );
}

function effectiveRequestTimeoutMs() {
  const phase = developmentPhase();

  if (phase === "implementation") {
    return Math.max(requestTimeoutMs, 120000);
  }

  if (phase === "verification") {
    return Math.max(requestTimeoutMs, 90000);
  }

  return Math.max(requestTimeoutMs, 105000);
}

const promptRelative = path
  .relative(root, path.resolve(promptFile))
  .replace(/\\/g, "/");

function candidateStatus() {
  const result = runGit([
    "status",
    "--short",
    "--untracked-files=all",
  ]);

  if (result.status !== 0) {
    return {
      ok: false,
      dirty: false,
      output: truncate(result.stderr || result.stdout, 4000),
    };
  }

  const lines = result.stdout
    .split("\n")
    .filter(Boolean)
    .filter((line) => {
      const normalized = line.replace(/\\/g, "/");
      return !normalized.endsWith(" " + promptRelative);
    });

  return {
    ok: true,
    dirty: lines.length > 0,
    output: lines.join("\n"),
  };
}

function candidateIdentity() {
  const status = candidateStatus();
  if (!status?.ok || !status.dirty) {
    return null;
  }

  const diff = runGit([
    "diff",
    "--binary",
    "--no-ext-diff",
  ]);

  if (
    diff.status !== 0 ||
    !diff.stdout.trim()
  ) {
    return null;
  }

  return crypto
    .createHash("sha256")
    .update(diff.stdout)
    .digest("hex");
}


function recordToolEvidence(name, result, args = {}) {
  if (result?.ok && inspectionToolNames.has(name)) {
    const weight = inspectionWeight(name);
    inspectionToolCalls += weight;
    recordCheckpointEvidence(name, args, result);

    if (
      developmentPhase() === "implementation" &&
      name === "search_codebase"
    ) {
      const matches = Array.isArray(result.matches)
        ? result.matches
        : [];

      if (matches.length > 0) {
        implementationSearchCompleted = true;
        implementationReadCompleted = false;
        implementationTargetPaths = [
          ...new Set(
            matches
              .map((line) =>
                String(line || "").split(":")[0]
              )
              .filter(Boolean)
          ),
        ].slice(0, 8);

        stage(
          "local_agent_target_found",
          gapLabel +
            " hedef kaynak bulundu • paths=" +
            implementationTargetPaths.length
        );
      }
    }

    if (
      developmentPhase() === "implementation" &&
      name === "read_file"
    ) {
      const readPath = String(
        result.path || args.path || ""
      );

      if (
        implementationSearchCompleted &&
        (
          implementationTargetPaths.length === 0 ||
          implementationTargetPaths.includes(readPath)
        )
      ) {
        implementationReadCompleted = true;
        stage(
          "local_agent_target_verified",
          gapLabel +
            " hedef kaynak bölgesi doğrulandı • mutation zorunlu"
        );
      }
    }

    if (
      requireChange &&
      inspectionToolCalls >= maxInspectionTools &&
      !sawMutatingTool &&
      !implementationPhaseAnnounced
    ) {
      implementationPhaseAnnounced = true;
      stage(
        "local_agent_implementation_phase",
        gapLabel +
          " hedefli inspection kanıtı tamamlandı • implementation zorunlu • " +
          inspectionToolCalls +
          "/" +
          maxInspectionTools
      );
    }
  }

  if (result?.ok && mutationToolNames.has(name)) {
    sawMutatingTool = true;
    sawGitDiff = false;
    buildCheckPassed = false;
    completionRejections = 0;
  }

  if (name === "git_diff" && result?.ok) {
    sawGitDiff = true;
  }

  if (name === "build_check") {
    buildCheckPassed = result?.ok === true;
  }

  persistCheckpoint(
    result?.ok ? "tool_completed:" + name : "tool_failed:" + name
  );
}

function rejectStructuredDecision(reason) {
  stage(
    "local_agent_controller_rejected",
    gapLabel +
      " structured controller kararı reddedildi • " +
      reason +
      " • controller=" +
      controllerModel
  );
  return null;
}

function compactControllerEvidence() {
  const lastRead = [...checkpointEvidence]
    .reverse()
    .find(
      (item) =>
        item &&
        item.tool === "read_file"
    );

  return {
    implementationSearchCompleted,
    implementationReadCompleted,
    implementationTargetPaths:
      implementationTargetPaths.slice(0, 8),
    lastVerifiedRead: lastRead
      ? {
          args: truncate(
            lastRead.args || "",
            1200
          ),
          result: truncate(
            lastRead.result || "",
            12000
          ),
        }
      : null,
  };
}

async function releasePrimaryModelForController() {
  if (
    !model ||
    !controllerModel ||
    model === controllerModel
  ) {
    return true;
  }

  const controller = new AbortController();
  const timer = setTimeout(
    () => controller.abort(),
    10000
  );

  try {
    const response = await fetch(
      baseUrl + "/api/chat",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        signal: controller.signal,
        body: JSON.stringify({
          model,
          messages: [],
          stream: false,
          keep_alive: 0,
        }),
      }
    );

    clearTimeout(timer);

    if (!response.ok) {
      stage(
        "local_agent_controller_preparing",
        gapLabel +
          " ana model belleği boşaltılamadı; controller yine denenecek • HTTP " +
          response.status
      );
      return false;
    }

    stage(
      "local_agent_controller_preparing",
      gapLabel +
        " ana model belleği controller için boşaltıldı • " +
        model +
        " → " +
        controllerModel
    );
    return true;
  } catch {
    clearTimeout(timer);
    stage(
      "local_agent_controller_preparing",
      gapLabel +
        " ana model bellek bırakma isteği zaman aşımına uğradı; controller yine denenecek"
    );
    return false;
  }
}

async function requestStructuredToolDecision(
  assistantText,
  blockers
) {
  if (structuredActions >= maxStructuredActions) {
    return rejectStructuredDecision(
      "structured action limiti doldu"
    );
  }

  const phase = developmentPhase();

  const toolContracts = toolsForCurrentPhase()
    .map((tool) => ({
      name: tool.function.name,
      description: tool.function.description,
      parameters: tool.function.parameters,
    }));

  const controllerEvidence =
    compactControllerEvidence();

  await releasePrimaryModelForController();

  const controllerInputChars =
    JSON.stringify({
      blockers,
      controllerEvidence,
      toolContracts,
    }).length;

  stage(
    "local_agent_controller_preparing",
    gapLabel +
      " structured controller girdisi hazır • chars=" +
      controllerInputChars +
      " • controller=" +
      controllerModel
  );

  const controller = new AbortController();
  const timer = setTimeout(
    () => controller.abort(),
    Math.min(
      structuredRequestTimeoutMs,
      Math.max(1000, hardTimeoutMs - (Date.now() - startedAt))
    )
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
        model: controllerModel,
        stream: false,
        format: "json",
        messages: [
          {
            role: "system",
            content: [
              "You are KRALI Tool Continuation Controller.",
              "Your only output is one valid JSON object. No markdown fences, no prose before or after JSON.",
              "Return exactly one JSON object describing the NEXT tool KRALI should execute.",
              "This is a controller protocol, not a conversational answer.",
              "Do not claim success. Do not explain source code.",
              "Choose only from the supplied tool contracts.",
              "Arguments must satisfy that tool's schema.",
              "Respect the supplied development phase and available tool contracts.",
              "During inspection, select the minimum real inspection tool needed.",
              "During implementation, obey the supplied tool contracts exactly. If only mutation tools are supplied, choose a minimal mutation tool now; do not answer with prose.",
              "During verification, prefer git_diff and build_check; mutate again only if evidence shows a fix is needed.",
              "Never request a tool that is absent from the supplied tool contracts.",
            ].join("\n"),
          },
          {
            role: "user",
            content: JSON.stringify({
              gap: gapLabel,
              requireChange,
              blockers: blockers
                .slice(0, 8)
                .map((value) =>
                  truncate(value, 400)
                ),
              assistantText: truncate(
                assistantText || "",
                1200
              ),
              phase,
              evidence: {
                sawMutatingTool,
                sawGitDiff,
                buildCheckPassed,
                structuredActions,
                ...controllerEvidence,
              },
              tools: toolContracts,
              outputContract: {
                name: "one exact tool name",
                arguments: "JSON object for that tool",
                reason: "short internal reason",
              },
            }),
          },
        ],
        keep_alive: "2m",
        options: {
          temperature: 0,
          num_ctx: 8192,
          num_predict: 2048,
        },
      }),
    });
  } catch {
    clearTimeout(timer);
    return rejectStructuredDecision(
      "controller isteği başarısız/zaman aşımı"
    );
  }

  clearTimeout(timer);

  if (!response.ok) {
    return rejectStructuredDecision(
      "controller HTTP " + response.status
    );
  }

  let payload;

  try {
    payload = await response.json();
  } catch {
    return rejectStructuredDecision(
      "controller response JSON parse edilemedi"
    );
  }

  const content = String(payload?.message?.content || "").trim();
  if (!content) {
    return rejectStructuredDecision(
      "controller boş cevap verdi"
    );
  }

  let decision;

  try {
    decision = JSON.parse(content);
  } catch {
    const first = content.indexOf("{");
    const last = content.lastIndexOf("}");

    if (first < 0 || last <= first) {
      return rejectStructuredDecision(
        "geçerli JSON object bulunamadı"
      );
    }

    try {
      decision = JSON.parse(
        content.slice(first, last + 1)
      );
    } catch {
      return rejectStructuredDecision(
        "controller JSON object parse edilemedi"
      );
    }
  }

  const name = String(decision?.name || "");
  const args =
    decision?.arguments &&
    typeof decision.arguments === "object" &&
    !Array.isArray(decision.arguments)
      ? decision.arguments
      : {};

  const allowed = toolContracts.some(
    (tool) => tool.name === name
  );

  if (!allowed) {
    return rejectStructuredDecision(
      "izin verilmeyen tool: " +
        (name || "<empty>")
    );
  }

  if (
    phase === "implementation" &&
    mutationToolNames.has(name) &&
    implementationTargetPaths.length > 0
  ) {
    if (
      name === "replace_text" ||
      name === "write_file"
    ) {
      const targetPath = String(args.path || "");

      if (
        !implementationTargetPaths.includes(
          targetPath
        )
      ) {
        return rejectStructuredDecision(
          "mutation target doğrulanmış path dışında"
        );
      }
    }

    if (name === "apply_patch") {
      const patch = String(args.patch || "");
      const patchPaths = [
        ...patch.matchAll(
          /^\+\+\+ b\/(.+)$/gm
        ),
      ].map((match) => match[1]);

      if (
        patchPaths.length === 0 ||
        patchPaths.some(
          (targetPath) =>
            !implementationTargetPaths.includes(
              targetPath
            )
        )
      ) {
        return rejectStructuredDecision(
          "apply_patch doğrulanmış target seti dışında"
        );
      }
    }
  }

  structuredActions += 1;

  return {
    name,
    args,
    reason: truncate(decision?.reason || "", 500),
  };
}

async function runStructuredContinuation(
  assistantText,
  blockers,
  trigger = "completion"
) {
  const decision = await requestStructuredToolDecision(
    assistantText,
    blockers
  );

  if (!decision) {
    return false;
  }

  sawToolCall = true;

  const phase = developmentPhase();
  const isMutation =
    mutationToolNames.has(decision.name);

  stage(
    isMutation
      ? "local_agent_structured_mutation"
      : "local_agent_structured_tool",
    gapLabel +
      " yapılandırılmış devam aracı çalışıyor: " +
      decision.name +
      " • trigger=" +
      trigger +
      " • phase=" +
      phase +
      " • controller=" +
      controllerModel
  );

  let result;

  try {
    result = executeTool(
      decision.name,
      decision.args
    );
  } catch (error) {
    result = {
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : String(error),
    };
  }

  recordToolEvidence(
    decision.name,
    result,
    decision.args
  );

  messages.push({
    role: "user",
    content: [
      "KRALI Tool Continuation Controller gerçek aracı çalıştırdı.",
      "Tool: " + decision.name,
      decision.reason
        ? "Reason: " + decision.reason
        : "",
      "Result: " +
        truncate(
          JSON.stringify(result),
          12000
        ),
      "Bu gerçek tool sonucuna göre devam et.",
      "Bir sonraki eylem gerekiyorsa native tool call kullan; düz metinle gelecek eylemi tarif etme.",
    ]
      .filter(Boolean)
      .join("\n"),
  });

  if (!result?.ok) {
    requestMoreWork([
      "yapılandırılmış tool başarısız: " +
        decision.name,
    ]);
  }

  return true;
}

function currentCandidateBlockers() {
  const status = candidateStatus();
  const blockers = [];

  if (!status.ok) {
    blockers.push(
      "candidate git status okunamadı"
    );
    return { status, blockers };
  }

  if (requireChange && !status.dirty) {
    blockers.push(
      "aktif capability gap için gerçek candidate değişikliği yok"
    );
  }

  if (status.dirty && !sawMutatingTool) {
    blockers.push(
      "candidate değişikliği için mutation tool kanıtı yok"
    );
  }

  if (status.dirty && !sawGitDiff) {
    blockers.push(
      "candidate diff henüz incelenmedi"
    );
  }

  if (status.dirty && !buildCheckPassed) {
    blockers.push(
      "candidate build_check PASS almadı"
    );
  }

  return { status, blockers };
}

function requestMoreWork(reasons) {
  completionRejections += 1;

  const detail = reasons.join("; ");
  stage(
    "local_agent_completion_rejected",
    gapLabel +
      " tamamlanma reddedildi • " +
      detail +
      " • deneme=" +
      completionRejections +
      "/" +
      maxCompletionRejections
  );

  if (completionRejections >= maxCompletionRejections) {
    fail(
      gapLabel +
        " yerel model açıklama ile erken tamamlanmaya devam etti: " +
        detail,
      27,
      "local_agent_completion_gate_failed"
    );
  }

  messages.push({
    role: "user",
    content: [
      "KRALI completion gate bu final cevabı reddetti.",
      "Aktif işi açıklamak veya özetlemek tamamlanma değildir.",
      "Araçlarla çalışmaya devam et.",
      "Gerekiyorsa minimum generic source değişikliğini replace_text, write_file veya apply_patch ile uygula.",
      "Candidate değişiklik varsa git_diff ile incele ve build_check PASS almadan bitirme.",
      "Şu anda kapanmamış koşullar: " + detail,
      "Bir sonraki cevabın düz metin final değil, gerekli tool çağrıları olmalı.",
    ].join("\n"),
  });
}

resumeCheckpointContext();

stage(
  "local_agent_starting",
  gapLabel +
    " native Ollama agent başlatılıyor: " +
    model +
    (resumedFromCheckpoint ? " • checkpoint resume" : "")
);

for (let iteration = 1; iteration <= maxIterations; iteration++) {
  const elapsed = Date.now() - startedAt;

  if (elapsed >= hardTimeoutMs) {
    persistCheckpoint("watchdog_timeout");
    fail(
      gapLabel + " native local agent toplam zaman sınırına ulaştı.",
      124,
      "local_agent_watchdog_timeout"
    );
  }

  stage(
    "local_agent_running",
    gapLabel +
      " yerel model çalışıyor • adım " +
      iteration +
      "/" +
      maxIterations
  );

  let response;
  const remainingMs =
    Math.max(
      1000,
      hardTimeoutMs - (Date.now() - startedAt)
    );
  const controller = new AbortController();
  const requestTimer = setTimeout(
    () => controller.abort(),
    Math.min(
      effectiveRequestTimeoutMs(),
      remainingMs
    )
  );

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
        messages,
        tools: toolsForCurrentPhase(),
        options: {
          temperature: 0.1,
        },
      }),
    });
  } catch (error) {
    clearTimeout(requestTimer);

    if (
      error instanceof Error &&
      error.name === "AbortError"
    ) {
      consecutiveRequestTimeouts += 1;

      if (
        developmentPhase() === "implementation" &&
        implementationReadCompleted
      ) {
        stage(
          "local_agent_timeout_controller",
          gapLabel +
            " implementation isteği zaman aşımına uğradı • doğrulanmış source evidence ile structured controller devralıyor • controller=" +
            controllerModel
        );

        persistCheckpoint(
          "implementation_timeout_controller"
        );

        const {
          blockers,
        } = currentCandidateBlockers();

        if (
          await runStructuredContinuation(
            "Ana Developer Agent implementation aşamasında zaman aşımına uğradı. Hedef kaynak daha önce doğrulandı; yeni inspection yapmadan güvenli minimum mutation ile devam et.",
            blockers.length > 0
              ? blockers
              : [
                  "doğrulanmış source evidence sonrası minimum mutation gerekli",
                ],
            "implementation_timeout"
          )
        ) {
          consecutiveRequestTimeouts = 0;

          const handoffStatus =
            candidateStatus();

          if (
            sawMutatingTool &&
            handoffStatus?.ok === true &&
            handoffStatus.dirty === true
          ) {
            stage(
              "local_agent_candidate_handoff",
              gapLabel +
                " structured controller gerçek candidate üretti • mevcut recovery/build pipeline'ına devrediliyor"
            );
            persistCheckpoint(
              "structured_candidate_handoff"
            );
            fail(
              "Structured controller candidate üretti; build ve recovery pipeline'ına devrediliyor.",
              28,
              "local_agent_candidate_handoff"
            );
          }

          continue;
        }

        persistCheckpoint(
          "implementation_timeout_controller_unavailable"
        );

        fail(
          "Implementation aşamasında ana model zaman aşımına uğradı ve structured controller güvenli devam kararı üretemedi.",
          25,
          "local_agent_tool_protocol_failed"
        );
      }

      if (
        consecutiveRequestTimeouts <=
        maxRequestTimeoutRetries
      ) {
        stage(
          "local_agent_request_retry",
          gapLabel +
            " model isteği zaman aşımına uğradı; mevcut context korunarak retry " +
            consecutiveRequestTimeouts +
            "/" +
            maxRequestTimeoutRetries
        );

        persistCheckpoint("request_timeout_retry");

        messages.push({
          role: "user",
          content: [
            "Önceki model isteği zaman aşımına uğradı.",
            "Mevcut tool sonuçlarını ve konuşma context'ini koru.",
            "Aynı problemi sıfırdan inceleme; kaldığın development phase'den devam et.",
            developmentPhase() === "implementation"
              ? (
                  implementationReadCompleted
                    ? "Inspection tamamlandı; şimdi minimum generic source değişikliğini uygula."
                    : implementationSearchCompleted
                      ? "İkinci arama yapma. Bulunan hedef kaynağı read_file ile doğrula; ardından minimum generic source değişikliğini uygula."
                      : "Genel repo keşfi kapalı. Bir hedefli search_codebase ile kaynak noktasını bul; ardından yalnız o kaynağı doğrulayıp patch üret."
                )
              : "Gerekli minimum sonraki tool adımını seç."
          ].join("\n"),
        });

        continue;
      }

      persistCheckpoint("request_timeout_limit");
      fail(
        "Ollama native agent model isteği art arda zaman aşımına uğradı.",
        124,
        "local_agent_watchdog_timeout"
      );
    }

    fail(
      "Ollama native agent bağlantı hatası: " +
        (error instanceof Error ? error.message : String(error))
    );
  }

  clearTimeout(requestTimer);
  consecutiveRequestTimeouts = 0;

  if (!response.ok) {
    fail(
      "Ollama native agent HTTP " + response.status
    );
  }

  const payload = await response.json();
  const message = payload?.message;

  if (!message) {
    fail("Ollama native agent geçerli message döndürmedi.");
  }

  const calls = Array.isArray(message.tool_calls)
    ? message.tool_calls
    : [];

  if (calls.length === 0) {
    messages.push(message);

    if (message.content) {
      process.stdout.write(message.content + "\n");
    }

    const {
      status,
      blockers,
    } = currentCandidateBlockers();

    if (blockers.length > 0) {
      const phase = developmentPhase();
      const trigger =
        !sawToolCall
          ? "native_tool_missing"
          : "completion_blocked";

      if (
        await runStructuredContinuation(
          message.content,
          blockers,
          trigger
        )
      ) {
        continue;
      }

      if (
        !sawToolCall &&
        (
          phase === "implementation" ||
          phase === "verification"
        )
      ) {
        persistCheckpoint(
          "structured_continuation_unavailable"
        );
        fail(
          "Yerel model native tool çağrısı üretmedi ve yapılandırılmış devam controller'ı güvenli tool kararı üretemedi.",
          25,
          "local_agent_tool_protocol_failed"
        );
      }

      if (!sawToolCall) {
        fail(
          "Yerel model gerçek tool çağrısı üretmedi.",
          25,
          "local_agent_tool_protocol_failed"
        );
      }

      requestMoreWork(blockers);
      continue;
    }

    if (!sawToolCall) {
      fail(
        "Yerel model gerçek veya yapılandırılmış tool çağrısı üretmeden tamamlanamaz.",
        25,
        "local_agent_tool_protocol_failed"
      );
    }

    stage(
      "local_agent_completed",
      status.dirty
        ? gapLabel + " candidate diff + build doğrulamasıyla tamamlandı"
        : gapLabel + " native local agent tamamlandı"
    );

    if (checkpointFile) {
      try {
        fs.rmSync(checkpointFile, { force: true });
      } catch {}
    }

    process.exit(0);
  }

  sawToolCall = true;
  messages.push(message);

  for (const call of calls) {
    const name = String(call?.function?.name || "");
    let args = call?.function?.arguments || {};

    if (typeof args === "string") {
      try {
        args = JSON.parse(args);
      } catch {
        args = {};
      }
    }

    stage(
      "local_agent_tool",
      gapLabel + " araç çalışıyor: " + name
    );

    let result;

    const phase = developmentPhase();
    const requestedPath = String(args.path || "");
    const implementationInspectionAllowed =
      phase === "implementation" &&
      !sawMutatingTool &&
      (
        (
          name === "search_codebase" &&
          !implementationSearchCompleted
        ) ||
        (
          name === "read_file" &&
          implementationSearchCompleted &&
          !implementationReadCompleted &&
          (
            implementationTargetPaths.length === 0 ||
            implementationTargetPaths.includes(requestedPath)
          )
        )
      );

    if (
      requireChange &&
      !sawMutatingTool &&
      phase === "implementation" &&
      inspectionToolNames.has(name) &&
      !implementationInspectionAllowed
    ) {
      stage(
        "local_agent_implementation_required",
        gapLabel +
          " tekrar/genel inspection reddedildi • implementation fazı aktif • " +
          name
      );
      result = {
        ok: false,
        error:
          implementationReadCompleted
            ? "Target source is already verified. Apply the minimum generic source mutation now."
            : implementationSearchCompleted
              ? (
                  implementationTargetPaths.length > 0
                    ? "Target search is complete. Read one identified target path only: " +
                      implementationTargetPaths.join(", ")
                    : "Target search is complete. Read the identified target source once, then mutate."
                )
              : "Broad discovery is disabled during implementation. Use one targeted search_codebase.",
      };
    } else {
      try {
        result = executeTool(name, args);
      } catch (error) {
        result = {
          ok: false,
          error:
            error instanceof Error
              ? error.message
              : String(error),
        };
      }
    }

    recordToolEvidence(name, result, args);

    messages.push({
      role: "tool",
      name,
      tool_name: name,
      content: JSON.stringify(result),
    });
  }
}

persistCheckpoint("iteration_limit");

fail(
  gapLabel +
    " native local agent iteration sınırına ulaştı.",
  20,
  "local_agent_iteration_limit"
);
