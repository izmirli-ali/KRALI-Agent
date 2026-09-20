import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const worktree = process.env.KRALI_WORKTREE || "";
const promptFile = process.env.KRALI_PROMPT_FILE || "";
const model = process.env.KRALI_DEV_MODEL || "";
const baseUrl =
  (process.env.KRALI_OLLAMA_BASE_URL || "http://127.0.0.1:11434")
    .replace(/\/$/, "");
const statusFile = process.env.KRALI_STATUS_FILE || "";
const branchName = process.env.KRALI_BRANCH || "";
const gapLabel = process.env.KRALI_GAP_LABEL || "Capability";
const appVersion = process.env.KRALI_APP_VERSION || "unknown";
const runID = process.env.KRALI_RUN_ID || "";
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
  process.env.KRALI_LOCAL_AGENT_TIMEOUT_MS || "300000"
);
const requestTimeoutMs = Number(
  process.env.KRALI_LOCAL_AGENT_REQUEST_TIMEOUT_MS || "60000"
);
const structuredRequestTimeoutMs = Number(
  process.env.KRALI_LOCAL_AGENT_STRUCTURED_TIMEOUT_MS || "45000"
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
  if (requireChange && inspectionToolCalls >= maxInspectionTools) {
    return "implementation";
  }
  return "inspection";
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


function recordToolEvidence(name, result) {
  if (result?.ok && inspectionToolNames.has(name)) {
    inspectionToolCalls += 1;

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
          " inspection bütçesi tamamlandı • implementation zorunlu • " +
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
}

async function requestStructuredToolDecision(
  assistantText,
  blockers
) {
  if (structuredActions >= maxStructuredActions) {
    return null;
  }

  const phase = developmentPhase();

  const toolContracts = tools
    .filter((tool) => {
      const name = tool.function.name;

      if (phase === "implementation") {
        return mutationToolNames.has(name);
      }

      if (phase === "verification") {
        return (
          mutationToolNames.has(name) ||
          name === "git_diff" ||
          name === "build_check" ||
          name === "git_status"
        );
      }

      return true;
    })
    .map((tool) => ({
      name: tool.function.name,
      description: tool.function.description,
      parameters: tool.function.parameters,
    }));

  const recentContext = messages
    .slice(-8)
    .map((item) => ({
      role: item.role,
      name: item.name || item.tool_name || "",
      content: truncate(
        typeof item.content === "string"
          ? item.content
          : JSON.stringify(item.content ?? ""),
        3500
      ),
    }));

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
        model,
        stream: false,
        format: "json",
        messages: [
          {
            role: "system",
            content: [
              "You are KRALI Tool Continuation Controller.",
              "Return exactly one JSON object describing the NEXT tool KRALI should execute.",
              "This is a controller protocol, not a conversational answer.",
              "Do not claim success. Do not explain source code.",
              "Choose only from the supplied tool contracts.",
              "Arguments must satisfy that tool's schema.",
              "Respect the supplied development phase and available tool contracts.",
              "During inspection, select the minimum real inspection tool needed.",
              "During implementation, inspection is closed: choose a minimal mutation tool now.",
              "During verification, prefer git_diff and build_check; mutate again only if evidence shows a fix is needed.",
              "Never request a tool that is absent from the supplied tool contracts.",
            ].join("\n"),
          },
          {
            role: "user",
            content: JSON.stringify({
              gap: gapLabel,
              requireChange,
              blockers,
              assistantText: truncate(assistantText || "", 4000),
              phase,
              evidence: {
                inspectionToolCalls,
                maxInspectionTools,
                sawMutatingTool,
                sawGitDiff,
                buildCheckPassed,
                structuredActions,
              },
              tools: toolContracts,
              recentContext,
              outputContract: {
                name: "one exact tool name",
                arguments: "JSON object for that tool",
                reason: "short internal reason",
              },
            }),
          },
        ],
        options: {
          temperature: 0,
        },
      }),
    });
  } catch {
    clearTimeout(timer);
    return null;
  }

  clearTimeout(timer);

  if (!response.ok) {
    return null;
  }

  let payload;

  try {
    payload = await response.json();
  } catch {
    return null;
  }

  const content = String(payload?.message?.content || "").trim();
  if (!content) {
    return null;
  }

  let decision;

  try {
    decision = JSON.parse(content);
  } catch {
    return null;
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
    return null;
  }

  structuredActions += 1;

  return {
    name,
    args,
    reason: truncate(decision?.reason || "", 500),
  };
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

stage(
  "local_agent_starting",
  gapLabel + " native Ollama agent başlatılıyor: " + model
);

for (let iteration = 1; iteration <= maxIterations; iteration++) {
  const elapsed = Date.now() - startedAt;

  if (elapsed >= hardTimeoutMs) {
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
    Math.min(requestTimeoutMs, remainingMs)
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
        tools,
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
      fail(
        "Ollama native agent model isteği zaman aşımına uğradı.",
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
    if (!sawToolCall) {
      fail(
        "Yerel model gerçek tool çağrısı üretmedi.",
        25,
        "local_agent_tool_protocol_failed"
      );
    }

    messages.push(message);

    if (message.content) {
      process.stdout.write(message.content + "\n");
    }

    const status = candidateStatus();
    const blockers = [];

    if (!status.ok) {
      blockers.push("candidate git status okunamadı");
    } else {
      if (requireChange && !status.dirty) {
        blockers.push("aktif capability gap için gerçek candidate değişikliği yok");
      }

      if (status.dirty && !sawMutatingTool) {
        blockers.push("candidate değişikliği için mutation tool kanıtı yok");
      }

      if (status.dirty && !sawGitDiff) {
        blockers.push("candidate diff henüz incelenmedi");
      }

      if (status.dirty && !buildCheckPassed) {
        blockers.push("candidate build_check PASS almadı");
      }
    }

    if (blockers.length > 0) {
      const decision = await requestStructuredToolDecision(
        message.content,
        blockers
      );

      if (decision) {
        stage(
          "local_agent_structured_tool",
          gapLabel +
            " yapılandırılmış devam aracı çalışıyor: " +
            decision.name
        );

        let result;

        try {
          result = executeTool(decision.name, decision.args);
        } catch (error) {
          result = {
            ok: false,
            error:
              error instanceof Error
                ? error.message
                : String(error),
          };
        }

        recordToolEvidence(decision.name, result);

        messages.push({
          role: "user",
          content: [
            "KRALI Tool Continuation Controller gerçek aracı çalıştırdı.",
            "Tool: " + decision.name,
            decision.reason
              ? "Reason: " + decision.reason
              : "",
            "Result: " + truncate(JSON.stringify(result), 12000),
            "Şimdi bu gerçek tool sonucuna göre devam et.",
            "Bir sonraki eylem gerekiyorsa onu native tool call ile çağır; düz metinle gelecek eylemi tarif etme.",
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

        continue;
      }

      requestMoreWork(blockers);
      continue;
    }

    stage(
      "local_agent_completed",
      status.dirty
        ? gapLabel + " candidate diff + build doğrulamasıyla tamamlandı"
        : gapLabel + " native local agent tamamlandı"
    );
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

    if (
      requireChange &&
      !sawMutatingTool &&
      inspectionToolNames.has(name) &&
      inspectionToolCalls >= maxInspectionTools
    ) {
      stage(
        "local_agent_implementation_required",
        gapLabel +
          " inspection aracı reddedildi • implementation fazı aktif • " +
          name
      );
      result = {
        ok: false,
        error:
          "Inspection budget exhausted. Implementation phase is active; use replace_text, write_file, or apply_patch.",
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

    recordToolEvidence(name, result);

    messages.push({
      role: "tool",
      name,
      tool_name: name,
      content: JSON.stringify(result),
    });
  }
}

fail(
  gapLabel +
    " native local agent iteration sınırına ulaştı.",
  20,
  "local_agent_iteration_limit"
);
