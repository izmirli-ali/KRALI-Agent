import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";

const worktree = process.env.KRALI_WORKTREE || "";
const promptFile = process.env.KRALI_PROMPT_FILE || "";
const model = process.env.KRALI_DEV_MODEL || "";
const architectModel =
  process.env.KRALI_ARCHITECT_MODEL || model;
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
const runtimeSourceHints = (() => {
  try {
    const value = JSON.parse(
      process.env.KRALI_RUNTIME_SOURCE_HINTS || "[]"
    );

    return Array.isArray(value)
      ? value
          .map((item) => String(item || "").trim())
          .filter(Boolean)
          .slice(0, 6)
      : [];
  } catch {
    return [];
  }
})();
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

function firstPromptValue(
  text,
  labels
) {
  const lines =
    String(text || "").split("\n");

  for (const label of labels) {
    const prefix =
      String(label || "") + ":";

    for (
      let index = 0;
      index < lines.length;
      index += 1
    ) {
      const line =
        String(lines[index] || "");
      const trimmed = line.trim();

      if (
        trimmed.toLocaleLowerCase("tr-TR")
          .startsWith(
            prefix.toLocaleLowerCase("tr-TR")
          )
      ) {
        const inline =
          trimmed.slice(prefix.length)
            .trim();

        if (inline) {
          return inline;
        }

        for (
          let next = index + 1;
          next < Math.min(
            lines.length,
            index + 8
          );
          next += 1
        ) {
          const candidate =
            String(
              lines[next] || ""
            ).trim();

          if (
            candidate &&
            !/^[A-Za-zÇĞİÖŞÜçğıöşü][^:]{0,80}:$/.test(
              candidate
            )
          ) {
            return candidate.replace(
              /^\d+\.\s*/,
              ""
            );
          }
        }
      }
    }
  }

  return "";
}

function runtimeFailureFromPrompt(
  text
) {
  const lines =
    String(text || "").split("\n");

  const candidates =
    lines
      .map((line) =>
        String(line || "").trim()
      )
      .filter((line) =>
        /başarısız\s*:|bulunamadı|runtime capability gap|postcondition|\bfailed\b|\berror\b/i.test(
          line
        )
      )
      .filter((line) =>
        !/^[-*]\s/.test(line)
      );

  return (
    candidates.find((line) =>
      /başarısız\s*:|bulunamadı/i.test(
        line
      )
    ) ||
    candidates[0] ||
    runtimeSourceHints[0] ||
    ""
  );
}

function mutationProblemContext() {
  return {
    objective: truncate(
      firstPromptValue(
        prompt,
        [
          "Kullanıcı hedefi",
          "Bu öğrenme işine kanıt sağlayan kullanıcı hedefleri"
        ]
      ),
      420
    ),
    runtime_failure: truncate(
      runtimeFailureFromPrompt(
        prompt
      ),
      520
    ),
    failure_reason: truncate(
      firstPromptValue(
        prompt,
        [
          "Sorun",
          "Neden"
        ]
      ),
      520
    ),
    expected_postcondition: truncate(
      firstPromptValue(
        prompt,
        [
          "Kabul kriteri",
          "Araştırma hedefi"
        ]
      ),
      620
    ),
  };
}

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

function clipExactSource(
  value,
  limit = 16000
) {
  const text = String(value ?? "");

  if (text.length <= limit) {
    return text;
  }

  const lines = text.split("\n");
  const selected = [];
  let used = 0;

  for (const line of lines) {
    const cost =
      line.length +
      (selected.length > 0 ? 1 : 0);

    if (
      selected.length > 0 &&
      used + cost > limit
    ) {
      break;
    }

    if (
      selected.length === 0 &&
      cost > limit
    ) {
      return "";
    }

    selected.push(line);
    used += cost;
  }

  return selected.join("\n");
}

function clipDiagnosticOutput(
  value,
  limit = 24000
) {
  const text = String(value ?? "");

  if (text.length <= limit) {
    return text;
  }

  const outputLines =
    text.split("\n");

  const primaryErrors =
    outputLines
      .filter((line) =>
        /(?:^|\s)(?:fatal\s+)?error:/i.test(
          line
        )
      )
      .slice(-30);

  const buildFailures =
    outputLines
      .filter((line) =>
        /Command .* failed|BUILD FAILED|The following build commands failed/i.test(
          line
        )
      )
      .slice(-12);

  const compileStages =
    outputLines
      .filter((line) =>
        /SwiftCompile|CompileSwift/i.test(
          line
        )
      )
      .slice(-8);

  const diagnosticLines = [
    ...primaryErrors,
    ...buildFailures,
    ...(primaryErrors.length === 0
      ? compileStages
      : []),
  ].join("\n");

  const reserved =
    Math.min(
      Math.max(
        diagnosticLines.length + 800,
        5000
      ),
      Math.floor(limit * 0.55)
    );

  const tailBudget =
    Math.max(
      4000,
      limit - reserved
    );

  const tail =
    text.slice(-tailBudget);

  return [
    diagnosticLines
      ? "KRALI_DIAGNOSTICS\n" +
        diagnosticLines
      : "",
    "KRALI_OUTPUT_TAIL\n" + tail,
  ]
    .filter(Boolean)
    .join("\n");
}

function definitionSourceRange(
  relativePath,
  definitionLine,
  maxLines = 260
) {
  const { absolute } =
    safeRelativePath(
      relativePath
    );

  const lines =
    fs.readFileSync(
      absolute,
      "utf8"
    ).split("\n");

  const startIndex =
    Math.max(
      0,
      Number(definitionLine) - 1
    );
  const maxIndex =
    Math.min(
      lines.length - 1,
      startIndex + maxLines - 1
    );

  let blockComment = false;
  let quote = "";
  let escaped = false;
  let depth = 0;
  let sawOpeningBrace = false;

  for (
    let index = startIndex;
    index <= maxIndex;
    index += 1
  ) {
    const line = lines[index];

    for (
      let offset = 0;
      offset < line.length;
      offset += 1
    ) {
      const char = line[offset];
      const next =
        line[offset + 1] || "";

      if (blockComment) {
        if (
          char === "*" &&
          next === "/"
        ) {
          blockComment = false;
          offset += 1;
        }
        continue;
      }

      if (quote) {
        if (escaped) {
          escaped = false;
          continue;
        }

        if (char === "\\") {
          escaped = true;
          continue;
        }

        if (char === quote) {
          quote = "";
        }
        continue;
      }

      if (
        char === "/" &&
        next === "/"
      ) {
        break;
      }

      if (
        char === "/" &&
        next === "*"
      ) {
        blockComment = true;
        offset += 1;
        continue;
      }

      if (
        char === "\"" ||
        char === "'"
      ) {
        quote = char;
        continue;
      }

      if (char === "{") {
        depth += 1;
        sawOpeningBrace = true;
        continue;
      }

      if (
        char === "}" &&
        sawOpeningBrace
      ) {
        depth -= 1;

        if (depth === 0) {
          return {
            start_line:
              startIndex + 1,
            end_line:
              index + 1,
            mode:
              "brace",
          };
        }
      }
    }
  }

  const definitionIndent =
    (lines[startIndex].match(
      /^\s*/
    )?.[0] || "").length;

  let sawBodyLine = false;

  for (
    let index = startIndex + 1;
    index <= maxIndex;
    index += 1
  ) {
    const line = lines[index];

    if (!line.trim()) {
      continue;
    }

    const indent =
      (line.match(
        /^\s*/
      )?.[0] || "").length;

    if (
      sawBodyLine &&
      indent <= definitionIndent &&
      !/^\s*[})\]]/.test(line)
    ) {
      return {
        start_line:
          startIndex + 1,
        end_line:
          index,
        mode:
          "indent",
      };
    }

    if (indent > definitionIndent) {
      sawBodyLine = true;
    }
  }

  return {
    start_line:
      startIndex + 1,
    end_line:
      maxIndex + 1,
    mode:
      "bounded",
  };
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
        content: clipExactSource(
          content,
          24000
        ),
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

      const combinedOutput =
        (result.stdout || "") +
        "\n" +
        (result.stderr || "");

      return {
        ok: result.status === 0,
        exit_code: result.status ?? 1,
        output:
          result.status === 0
            ? truncate(
                combinedOutput,
                24000
              )
            : clipDiagnosticOutput(
                combinedOutput,
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
          old_text: {
            type: "string",
            minLength: 80,
            description:
              "Exact source block copied verbatim from the verified read. Use a sufficiently long unique anchor, preferably multiple complete lines."
          },
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
        "Apply a complete unified diff inside the isolated candidate worktree. Prefer --- a/path and +++ b/path headers; a headerless @@ hunk is accepted only when exactly one verified target exists.",
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
  "For runtime failures, prefer the defining provider/resolver/error source over orchestration call sites. Search an exact runtime error fragment or the provider/resolver symbol before browsing folders.",
  "Do not call list_files repeatedly. Once a capability/error clue exists, use search_codebase and then read_file on the defining source.",
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
let lastStructuredOutcome = null;
let lastMutationSnapshot = null;
let lastMutationFingerprint = "";
let lastAppliedMutationDecision = null;
let lastFailedReplaceMutation = null;
const failedMutationFingerprints = new Set();
const failedDiffFingerprints = new Set();
let runtimeBootstrapTarget = null;
let rootCauseDiagnosis = null;

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
    return 1;
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
      if (!implementationSearchCompleted) {
        return name === "search_codebase";
      }

      if (!implementationReadCompleted) {
        return name === "read_file";
      }

      return mutationToolNames.has(name);
    }

    return true;
  });
}

function currentBaseHead() {
  const result = runGit(["rev-parse", "HEAD"]);
  return result.status === 0
    ? result.stdout.trim()
    : "";
}

function persistCheckpoint(reason = "progress") {
  if (!checkpointFile) return;

  const status = candidateStatus();
  const payload = {
    version: 5,
    baseHead: currentBaseHead(),
    gapLabel,
    reason,
    model,
    architectModel,
    controllerModel,
    rootCauseDiagnosis,
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
      ![1, 2, 3, 4, 5].includes(Number(payload.version || 0))
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

  if (name === "read_file") {
    checkpointEvidence.push({
      tool: name,
      args: {
        path: String(args?.path || result?.path || ""),
        start_line:
          args?.start_line ?? result?.start_line ?? null,
        end_line:
          args?.end_line ?? result?.end_line ?? null,
      },
      result: {
        ok: true,
        path: String(result?.path || args?.path || ""),
        start_line: result?.start_line ?? null,
        end_line: result?.end_line ?? null,
        total_lines: result?.total_lines ?? null,
        content: clipExactSource(
          String(result?.content || ""),
          14000
        ),
      },
    });
  } else {
    checkpointEvidence.push({
      tool: name,
      args: truncate(
        JSON.stringify(args || {}),
        1600
      ),
      result: truncate(
        JSON.stringify(result),
        5000
      ),
    });
  }

  checkpointEvidence = checkpointEvidence.slice(-12);
}

function resumeCheckpointContext() {
  const checkpoint = loadCheckpoint();
  if (!checkpoint) return;

  const checkpointBaseHead =
    typeof checkpoint.baseHead === "string"
      ? checkpoint.baseHead.trim()
      : "";
  const liveBaseHead = currentBaseHead();
  const staleCheckpoint =
    !checkpointBaseHead ||
    !liveBaseHead ||
    checkpointBaseHead !== liveBaseHead;

  if (staleCheckpoint) {
    checkpointEvidence = [];
    implementationSearchCompleted = false;
    implementationReadCompleted = false;
    implementationTargetPaths = [];
    sawMutatingTool = false;
    sawGitDiff = false;
    buildCheckPassed = false;
    inspectionToolCalls = maxInspectionTools;
    implementationPhaseAnnounced = true;

    stage(
      "local_agent_checkpoint_stale",
      gapLabel +
        " checkpoint source provenance eski • recordedHead=" +
        (checkpointBaseHead || "<none>") +
        " • liveHead=" +
        (liveBaseHead || "<unknown>") +
        " • source hedefleri yeniden doğrulanacak"
    );

    try {
      fs.unlinkSync(checkpointFile);
    } catch {}

    return;
  }

  const evidence = Array.isArray(checkpoint.evidence)
    ? checkpoint.evidence.slice(-10)
    : [];

  if (evidence.length === 0) return;

  checkpointEvidence = evidence;

  if (
    Number(checkpoint.version || 0) >= 5 &&
    checkpoint.rootCauseDiagnosis &&
    typeof checkpoint.rootCauseDiagnosis === "object"
  ) {
    rootCauseDiagnosis = {
      root_cause:
        String(
          checkpoint.rootCauseDiagnosis.root_cause || ""
        ),
      strategy:
        String(
          checkpoint.rootCauseDiagnosis.strategy || ""
        ),
      confidence:
        Number(
          checkpoint.rootCauseDiagnosis.confidence || 0
        ),
      target_symbol:
        String(
          checkpoint.rootCauseDiagnosis.target_symbol || ""
        ),
      target_path:
        String(
          checkpoint.rootCauseDiagnosis.target_path || ""
        ),
      alternatives_considered:
        Array.isArray(
          checkpoint.rootCauseDiagnosis.alternatives_considered
        )
          ? checkpoint.rootCauseDiagnosis.alternatives_considered
          : [],
    };
  }

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
      rootCauseDiagnosis
        ? (
            "Root Cause Architect checkpoint: " +
            truncate(
              JSON.stringify(rootCauseDiagnosis),
              3600
            )
          )
        : "",
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

function currentCandidateDiff(limit = 12000) {
  const status = candidateStatus();
  if (!status?.ok || !status.dirty) {
    return "";
  }

  const diff = runGit([
    "diff",
    "--no-ext-diff",
    "--",
  ]);

  if (diff.status !== 0) {
    return "";
  }

  return truncate(diff.stdout, limit);
}


function normalizeRepoRelativePath(value) {
  return String(value || "")
    .trim()
    .replace(/\\/g, "/")
    .replace(/^\.\//, "")
    .replace(/^[ab]\//, "");
}

function canonicalizeUnifiedPatch(
  patchValue,
  verifiedTargets = []
) {
  let patch = String(patchValue || "")
    .trim()
    .replace(/^\`\`\`(?:diff|patch)?\s*/i, "")
    .replace(/\s*\`\`\`$/, "")
    .trim();

  const paths = [];
  for (const line of patch.split("\n")) {
    if (
      !line.startsWith("+++ ") &&
      !line.startsWith("--- ")
    ) {
      continue;
    }

    let value = line.slice(4).trim().split("\t")[0];
    if (!value || value === "/dev/null") {
      continue;
    }

    value = normalizeRepoRelativePath(value);
    if (value) paths.push(value);
  }

  if (
    paths.length === 0 &&
    verifiedTargets.length === 1 &&
    patch.startsWith("@@")
  ) {
    const target = normalizeRepoRelativePath(
      verifiedTargets[0]
    );

    patch =
      "--- a/" +
      target +
      "\n+++ b/" +
      target +
      "\n" +
      patch;
  }

  return patch;
}

function mutationPathsForTool(name, args = {}) {
  if (
    name === "replace_text" ||
    name === "write_file"
  ) {
    const target = normalizeRepoRelativePath(
      args.path
    );
    return target ? [target] : [];
  }

  if (name === "apply_patch") {
    const patch = String(args.patch || "");
    const paths = [];

    for (const line of patch.split("\n")) {
      if (
        !line.startsWith("+++ ") &&
        !line.startsWith("--- ")
      ) {
        continue;
      }

      let value = line.slice(4).trim().split("\t")[0];
      if (!value || value === "/dev/null") {
        continue;
      }

      value = normalizeRepoRelativePath(value);
      if (value) {
        paths.push(value);
      }
    }

    return [...new Set(paths)];
  }

  return [];
}

function captureMutationSnapshot(name, args = {}) {
  const files = [];

  for (const target of mutationPathsForTool(name, args)) {
    try {
      const { absolute, relative } =
        safeRelativePath(target);
      assertMutablePath(relative);

      const exists = fs.existsSync(absolute);
      const isFile =
        exists && fs.statSync(absolute).isFile();

      files.push({
        relative,
        existed: isFile,
        content: isFile
          ? fs.readFileSync(absolute, "utf8")
          : null,
      });
    } catch {
      return null;
    }
  }

  return {
    tool: name,
    files,
    flags: {
      sawMutatingTool,
      sawGitDiff,
      buildCheckPassed,
    },
  };
}

function restoreMutationSnapshot(snapshot) {
  if (!snapshot || !Array.isArray(snapshot.files)) {
    return false;
  }

  try {
    for (const item of snapshot.files) {
      const { absolute, relative } =
        safeRelativePath(item.relative);
      assertMutablePath(relative);

      if (item.existed) {
        fs.mkdirSync(path.dirname(absolute), {
          recursive: true,
        });
        fs.writeFileSync(
          absolute,
          String(item.content ?? ""),
          "utf8"
        );
      } else if (fs.existsSync(absolute)) {
        const stat = fs.statSync(absolute);
        if (stat.isFile()) {
          fs.unlinkSync(absolute);
        }
      }
    }

    sawMutatingTool =
      snapshot.flags?.sawMutatingTool === true;
    sawGitDiff =
      snapshot.flags?.sawGitDiff === true;
    buildCheckPassed =
      snapshot.flags?.buildCheckPassed === true;

    return true;
  } catch {
    return false;
  }
}

function isEligibleImplementationTargetPath(value) {
  const normalized = normalizeRepoRelativePath(value);

  if (
    !normalized ||
    normalized === "VERSION" ||
    normalized.startsWith("Mentor/") ||
    normalized.startsWith(".git/")
  ) {
    return false;
  }

  const extension = path.extname(normalized).toLowerCase();
  const implementationExtensions = new Set([
    ".swift",
    ".mjs",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
    ".py",
    ".sh",
    ".command",
    ".json",
    ".yml",
    ".yaml",
    ".toml",
  ]);

  return implementationExtensions.has(extension);
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
                normalizeRepoRelativePath(
                  String(line || "").split(":")[0]
                )
              )
              .filter(
                isEligibleImplementationTargetPath
              )
          ),
        ].slice(0, 8);

        stage(
          "local_agent_target_found",
          gapLabel +
            " hedef kaynak bulundu • paths=" +
            implementationTargetPaths.length +
            " • targets=" +
            truncate(
              JSON.stringify(
                implementationTargetPaths
              ),
              1200
            )
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
        implementationTargetPaths = [
          normalizeRepoRelativePath(readPath)
        ];
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

function mutationFingerprint(
  name,
  args = {}
) {
  if (!mutationToolNames.has(name)) {
    return "";
  }

  const normalized =
    name === "replace_text"
      ? {
          name,
          path:
            normalizeRepoRelativePath(
              args.path
            ),
          old_text:
            String(
              args.old_text || ""
            ),
          new_text:
            String(
              args.new_text ?? ""
            ),
        }
      : name === "apply_patch"
        ? {
            name,
            patch:
              String(
                args.patch || ""
              )
                .replace(/\r\n/g, "\n")
                .trim(),
          }
        : {
            name,
            path:
              normalizeRepoRelativePath(
                args.path
              ),
            content:
              String(
                args.content || ""
              ),
          };

  return crypto
    .createHash("sha256")
    .update(
      JSON.stringify(normalized)
    )
    .digest("hex");
}

function diffFingerprint(
  diffText
) {
  const normalized =
    String(diffText || "")
      .replace(/\r\n/g, "\n")
      .replace(
        /^index\s+[0-9a-f]+\.\.[0-9a-f]+.*$/gm,
        ""
      )
      .trim();

  if (!normalized) {
    return "";
  }

  return crypto
    .createHash("sha256")
    .update(normalized)
    .digest("hex");
}

function summarizeBuildFailure(
  buildResult,
  failedCandidateDiff,
  mutationRolledBack
) {
  const rawOutput = String(
    buildResult?.output || ""
  );

  const outputLines =
    rawOutput.split("\n");

  const primaryCompilerErrors =
    outputLines
      .filter((line) =>
        /(?:^|\s)(?:fatal\s+)?error:/i.test(
          line
        )
      )
      .slice(-30);

  const secondaryBuildFailures =
    outputLines
      .filter((line) =>
        /Command .* failed|BUILD FAILED|The following build commands failed/i.test(
          line
        )
      )
      .slice(-12);

  const compilerStageLines =
    outputLines
      .filter((line) =>
        /SwiftCompile|CompileSwift/i.test(
          line
        )
      )
      .slice(-8);

  const compilerLines =
    primaryCompilerErrors.length > 0
      ? [
          ...primaryCompilerErrors,
          ...secondaryBuildFailures,
        ]
      : [
          ...secondaryBuildFailures,
          ...compilerStageLines,
        ];

  return {
    ok: false,
    exit_code:
      buildResult?.exit_code ?? 1,
    compiler_errors: compilerLines,
    output_tail: truncate(
      rawOutput.slice(-7000),
      7000
    ),
    failed_candidate_diff: truncate(
      failedCandidateDiff || "",
      7000
    ),
    mutation_rolled_back:
      mutationRolledBack === true,
  };
}

function parseCheckpointJSON(
  value,
  fallback = null
) {
  if (
    value &&
    typeof value === "object"
  ) {
    return value;
  }

  try {
    return JSON.parse(
      String(value || "")
    );
  } catch {
    return fallback;
  }
}

function compactControllerEvidence(
  ultraCompact = false
) {
  const lastRead = [...checkpointEvidence]
    .reverse()
    .find(
      (item) =>
        item &&
        item.tool === "read_file"
    );

  const rollbackRepair =
    lastStructuredOutcome?.tool === "build_check" &&
    lastStructuredOutcome?.result?.ok === false &&
    lastStructuredOutcome?.result?.mutation_rolled_back === true;

  const initialMutation =
    developmentPhase() === "implementation" &&
    implementationReadCompleted &&
    !sawMutatingTool &&
    !rollbackRepair;

  const parsedReadArgs =
    lastRead
      ? parseCheckpointJSON(
          lastRead.args,
          {}
        )
      : {};

  const parsedReadResult =
    lastRead
      ? parseCheckpointJSON(
          lastRead.result,
          {}
        )
      : {};

  const verifiedReadContent =
    String(
      parsedReadResult?.content || ""
    );

  const exactSourceContent =
    verifiedReadContent
      .split("\n")
      .map((line) =>
        line.replace(
          /^\s*\d+\s*\|\s?/,
          ""
        )
      )
      .join("\n");

  return {
    implementationSearchCompleted,
    implementationReadCompleted,
    implementationTargetPaths:
      implementationTargetPaths.slice(0, 8),
    failedMutationFingerprints:
      [...failedMutationFingerprints]
        .slice(-6)
        .map((value) =>
          value.slice(0, 12)
        ),
    failedDiffFingerprints:
      [...failedDiffFingerprints]
        .slice(-6)
        .map((value) =>
          value.slice(0, 12)
        ),
    rollbackRepair,
    initialMutation,
    candidateDiff: currentCandidateDiff(
      rollbackRepair
        ? 4000
        : initialMutation
          ? 0
          : 12000
    ),
    lastVerifiedRead: lastRead
      ? {
          path:
            String(
              parsedReadResult?.path ||
              parsedReadArgs?.path ||
              ""
            ),
          start_line:
            parsedReadResult?.start_line ??
            parsedReadArgs?.start_line ??
            null,
          end_line:
            parsedReadResult?.end_line ??
            parsedReadArgs?.end_line ??
            null,
          content: clipExactSource(
            exactSourceContent,
            ultraCompact
              ? 2200
              : rollbackRepair
                ? 6200
                : initialMutation
                  ? 5200
                  : 10000
          ),
        }
      : null,
    lastStructuredOutcome:
      initialMutation
        ? null
        : lastStructuredOutcome
          ? rollbackRepair
            ? {
                tool: "build_check",
                args: {},
                result: {
                  ok: false,
                  compiler_errors:
                    Array.isArray(
                      lastStructuredOutcome.result?.compiler_errors
                    )
                      ? lastStructuredOutcome.result.compiler_errors.slice(-20)
                      : [],
                  output_tail: truncate(
                    lastStructuredOutcome.result?.output_tail || "",
                    ultraCompact
                      ? 1800
                      : 3200
                  ),
                  failed_candidate_diff: truncate(
                    lastStructuredOutcome.result?.failed_candidate_diff || "",
                    ultraCompact
                      ? 2200
                      : 4200
                  ),
                  mutation_rolled_back: true,
                },
              }
            : {
                tool: lastStructuredOutcome.tool,
                args: truncate(
                  JSON.stringify(
                    lastStructuredOutcome.args || {}
                  ),
                  ultraCompact
                    ? 500
                    : 1800
                ),
                result: truncate(
                  JSON.stringify(
                    lastStructuredOutcome.result || {}
                  ),
                  ultraCompact
                    ? 1200
                    : 4000
                ),
              }
          : null,
  };
}

async function prepareDecisionModel(
  targetModel
) {
  if (
    !model ||
    !targetModel ||
    model === targetModel
  ) {
    return true;
  }

  const controller = new AbortController();
  const timer = setTimeout(
    () => controller.abort(),
    10000
  );

  try {
    const psResponse = await fetch(
      baseUrl + "/api/ps",
      {
        method: "GET",
        signal: controller.signal,
      }
    );

    if (psResponse.ok) {
      const psPayload = await psResponse.json();
      const loadedModels =
        Array.isArray(psPayload?.models)
          ? psPayload.models
          : [];
      const primaryLoaded =
        loadedModels.some((item) => {
          const loadedName = String(
            item?.name || item?.model || ""
          );
          return (
            loadedName === model ||
            loadedName.startsWith(
              model + ":"
            )
          );
        });

      if (!primaryLoaded) {
        clearTimeout(timer);
        stage(
          "local_agent_controller_preparing",
          gapLabel +
            " ana model bellekte değil; karar modeli korunuyor • decisionModel=" +
            targetModel
        );
        return true;
      }
    }

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
          " ana model belleği boşaltılamadı; karar modeli yine denenecek • HTTP " +
          response.status
      );
      return false;
    }

    stage(
      "local_agent_controller_preparing",
      gapLabel +
        " ana model belleği karar modeli için boşaltıldı • " +
        model +
        " → " +
        targetModel
    );
    return true;
  } catch {
    clearTimeout(timer);
    stage(
      "local_agent_controller_preparing",
      gapLabel +
        " ana model bellek bırakma isteği zaman aşımına uğradı; karar modeli yine denenecek"
    );
    return false;
  }
}

async function requestStructuredToolDecision(
  assistantText,
  blockers,
  ultraCompactRetry = false,
  validationRetry = 0
) {
  if (structuredActions >= maxStructuredActions) {
    return rejectStructuredDecision(
      "structured action limiti doldu"
    );
  }

  const phase = developmentPhase();

  let toolContracts = toolsForCurrentPhase()
    .map((tool) => ({
      name: tool.function.name,
      description: tool.function.description,
      parameters: tool.function.parameters,
    }));

  const previousStructuredError = String(
    lastStructuredOutcome?.result?.error || ""
  );

  const exactReplaceFailure =
    phase === "implementation" &&
    lastStructuredOutcome?.tool === "replace_text" &&
    lastStructuredOutcome?.result?.ok === false &&
    (
      previousStructuredError.includes("old_text") ||
      previousStructuredError.includes("eşleş")
    );

  const rollbackRepair =
    lastStructuredOutcome?.tool === "build_check" &&
    lastStructuredOutcome?.result?.ok === false &&
    lastStructuredOutcome?.result?.mutation_rolled_back === true;

  const initialMutation =
    phase === "implementation" &&
    implementationReadCompleted &&
    !sawMutatingTool &&
    !rollbackRepair;

  if (
    rollbackRepair ||
    initialMutation ||
    exactReplaceFailure
  ) {
    const replaceContract = toolContracts.find(
      (tool) => tool.name === "replace_text"
    );

    if (replaceContract) {
      toolContracts = [replaceContract];
    }
  }

  const controllerEvidence =
    compactControllerEvidence(
      ultraCompactRetry
    );

  const fixedReplaceMode =
    phase === "implementation" &&
    toolContracts.length === 1 &&
    toolContracts[0]?.name === "replace_text" &&
    implementationTargetPaths.length === 1;

  const fixedRepairMode =
    fixedReplaceMode &&
    rollbackRepair &&
    lastFailedReplaceMutation?.old_text &&
    lastFailedReplaceMutation?.path;

  const decisionModel =
    fixedReplaceMode &&
    architectModel
      ? architectModel
      : controllerModel;

  const fixedReplacePath =
    fixedRepairMode
      ? normalizeRepoRelativePath(
          lastFailedReplaceMutation.path
        )
      : fixedReplaceMode
        ? normalizeRepoRelativePath(
            implementationTargetPaths[0]
          )
        : "";

  const fixedRepairOldText =
    fixedRepairMode
      ? String(
          lastFailedReplaceMutation.old_text || ""
        )
      : "";

  const decisionFormat = fixedReplaceMode
    ? fixedRepairMode
      ? {
          type: "object",
          additionalProperties: false,
          required: [
            "new_text",
          ],
          properties: {
            new_text: {
              type: "string",
              minLength: 1,
            },
          },
        }
      : {
          type: "object",
          additionalProperties: false,
          required: [
            "old_text",
            "new_text",
          ],
          properties: {
            old_text: {
              type: "string",
              minLength: 80,
            },
            new_text: {
              type: "string",
              minLength: 1,
            },
          },
        }
    : {
    type: "object",
    additionalProperties: false,
    required: [
      "name",
      "arguments",
      "reason",
    ],
    properties: {
      name: {
        type: "string",
        enum: toolContracts.map(
          (tool) => tool.name
        ),
      },
      arguments:
        toolContracts.length === 1
          ? toolContracts[0].parameters
          : {
              type: "object",
            },
      reason: {
        type: "string",
      },
    },
  };

  const controllerSystemPrompt =
    fixedReplaceMode
      ? fixedRepairMode
        ? [
            "You are KRALI Exact Repair Architect.",
            "Return JSON matching the supplied schema and nothing else.",
            "The target path, tool, and exact old_text are already fixed by KRALI.",
            "Return only a corrected new_text replacement for fixed_old_text.",
            "Do not choose or invent an old_text anchor.",
            "Use compiler_errors and failed_candidate_diff as authoritative evidence for why the previous replacement failed.",
            "new_text must compile against the visible verified source and must materially differ from both fixed_old_text and previous_failed_new_text.",
            "Do not repeat the previous failed semantic change through different formatting.",
            "Use problem evidence to repair behavior generically; do not hard-code the concrete app, brand, filename, or exact user phrase.",
            "Do not include path, tool name, old_text, reason, markdown, prose, or code fences.",
          ].join("\n")
        : [
            "You are KRALI Exact Mutation Architect.",
            "Return JSON matching the supplied schema and nothing else.",
            "The target path and tool are already fixed by KRALI.",
            "Your only job is to choose one exact old_text block and its corrected new_text.",
            "old_text must be copied verbatim from lastVerifiedRead.content.",
            "Use a unique multi-line source block; do not invent text outside the visible source.",
            "new_text must be a meaningful generic repair for the runtime failure.",
            "Use root_cause_diagnosis as the architect-selected explanation and strategy. Do not reselect a different source target.",
            "Use problem.objective, problem.runtime_failure, problem.failure_reason, and problem.expected_postcondition to infer the missing behavior. The source may be syntactically valid but behaviorally incomplete.",
            "Returning unchanged source is invalid. old_text and new_text must differ in behaviorally meaningful code.",
            "Do not hard-code the concrete app, brand, filename, or exact user phrase from problem evidence; generalize the fix to the capability class.",
            "Do not include path, tool name, reason, markdown, prose, or code fences.",
            "If build failure evidence exists, repair that failure against the clean verified source and do not repeat the failed diff.",
            "failedMutationFingerprints and failedDiffFingerprints identify strategies already proven to fail. Produce a materially different semantic change, not a cosmetically different anchor for the same failed edit.",
          ].join("\n")
      : [
          "You are KRALI Tool Continuation Controller.",
          "Your output is constrained by a runtime JSON schema.",
          "Return exactly one NEXT tool decision; no prose outside the schema.",
          "This is a controller protocol, not a conversational answer.",
          "Do not claim success. Do not explain source code.",
          "Choose only from the supplied tool contracts.",
          "Arguments must satisfy that tool's schema.",
          "Respect the supplied development phase and available tool contracts.",
          "During inspection, select the minimum real inspection tool needed.",
          "During implementation, obey the supplied tool contracts exactly. If only mutation tools are supplied, choose a minimal mutation tool now; do not answer with prose.",
          "lastVerifiedRead.content contains only exact source characters copied from disk; it never contains truncation markers or synthetic suffixes. For replace_text, copy old_text exactly from this source window; never invent or extend beyond the visible source.",
          "A replace_text old_text must be a sufficiently long unique source block, preferably at least 3 complete lines. Never use a short identifier fragment, partial token, prefix completion, or typo-like replacement.",
          "new_text must be a meaningful logic change, not merely completion of a truncated identifier that already exists in source.",
          "If lastStructuredOutcome contains a failed real tool result, repair that exact failure with the next minimal mutation instead of repeating the same arguments.",
          "If replace_text failed because old_text was not found or was ambiguous, stay with replace_text when that is the supplied tool: choose a longer exact unique block from lastVerifiedRead.content.",
          "candidateDiff is the current real worktree diff. Use it together with source evidence to repair only the defect introduced by the candidate.",
          "If lastStructuredOutcome is a failed build_check, compiler_errors, output_tail, and failed_candidate_diff are authoritative. If mutation_rolled_back is true, the bad mutation is no longer present. Use the supplied replace_text tool against clean lastVerifiedRead source to produce an alternative unique multi-line repair. Do not reapply the failed diff.",
          "During verification, prefer git_diff and build_check when no compiler failure is already known; mutate when build evidence shows a fix is needed.",
          "Never request a tool that is absent from the supplied tool contracts.",
        ].join("\n");

  await prepareDecisionModel(
    decisionModel
  );

  const effectiveBlockers =
    blockers
      .slice(
        0,
        ultraCompactRetry
          ? 2
          : initialMutation
            ? 4
            : 8
      )
      .map((value) =>
        truncate(
          value,
          ultraCompactRetry
            ? 180
            : initialMutation
              ? 260
              : 400
        )
      );

  const fixedReplacePayload =
    fixedReplaceMode
      ? {
          mode:
            fixedRepairMode
              ? "exact_repair_new_text"
              : "exact_replace",
          target: fixedReplacePath,
          root_cause_diagnosis:
            rootCauseDiagnosis,
          fixed_old_text:
            fixedRepairMode
              ? fixedRepairOldText
              : undefined,
          previous_failed_new_text:
            fixedRepairMode
              ? String(
                  lastFailedReplaceMutation?.new_text || ""
                )
              : undefined,
          problem:
            mutationProblemContext(),
          failure: {
            blockers: effectiveBlockers,
            assistantText: truncate(
              assistantText || "",
              ultraCompactRetry
                ? 220
                : 420
            ),
            rollbackRepair,
            previousStructuredError: truncate(
              previousStructuredError,
              500
            ),
          },
          evidence: {
            lastVerifiedRead:
              controllerEvidence.lastVerifiedRead,
            lastStructuredOutcome:
              controllerEvidence.lastStructuredOutcome,
            failedMutationFingerprints:
              controllerEvidence.failedMutationFingerprints,
            failedDiffFingerprints:
              controllerEvidence.failedDiffFingerprints,
          },
        }
      : null;

  const controllerInputChars =
    JSON.stringify(
      fixedReplaceMode
        ? fixedReplacePayload
        : {
            blockers: effectiveBlockers,
            controllerEvidence,
            toolContracts,
          }
    ).length;

  stage(
    "local_agent_controller_preparing",
    gapLabel +
      " structured controller girdisi hazır • mode=" +
      (fixedRepairMode
        ? "exact_repair_new_text"
        : fixedReplaceMode
          ? "exact_replace"
          : "general") +
      " • problem=" +
      (fixedReplaceMode
        ? (
            mutationProblemContext()
              .runtime_failure
              ? "runtime_evidence"
              : "missing"
          )
        : "n/a") +
      " • chars=" +
      controllerInputChars +
      " • decisionModel=" +
      decisionModel +
      " • role=" +
      (
        fixedReplaceMode
          ? "architect-mutation"
          : "controller"
      )
  );

  const controller = new AbortController();
  const remainingControllerBudget =
    Math.max(
      1000,
      hardTimeoutMs - (Date.now() - startedAt)
    );
  const requestedControllerBudget =
    initialMutation
      ? (
          ultraCompactRetry
            ? 90000
            : 70000
        )
      : structuredRequestTimeoutMs;
  const timer = setTimeout(
    () => controller.abort(),
    Math.min(
      requestedControllerBudget,
      remainingControllerBudget
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
        model: decisionModel,
        stream: false,
        format: decisionFormat,
        messages: [
          {
            role: "system",
            content: controllerSystemPrompt,
          },
          {
            role: "user",
            content: JSON.stringify(
              fixedReplaceMode
                ? fixedReplacePayload
                : {
              gap: gapLabel,
              requireChange,
              blockers: effectiveBlockers,
              assistantText: truncate(
                assistantText || "",
                ultraCompactRetry
                  ? 350
                  : initialMutation
                    ? 650
                    : 1200
              ),
              phase,
              recoveryHints: {
                exactReplaceFailure,
                rollbackRepair,
                initialMutation,
                validationRetry,
                previousStructuredError: truncate(
                  previousStructuredError,
                  ultraCompactRetry
                    ? 350
                    : 800
                ),
              },
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
            }
            ),
          },
        ],
        keep_alive: "2m",
        options: {
          temperature: 0,
          num_ctx:
            fixedReplaceMode
              ? (
                  ultraCompactRetry
                    ? 8192
                    : 24576
                )
              : ultraCompactRetry
                ? 3072
                : 4096,
          num_predict:
            fixedReplaceMode
              ? (
                  ultraCompactRetry
                    ? 900
                    : 1200
                )
              : ultraCompactRetry
                ? 512
                : initialMutation
                  ? 640
                  : 1024,
        },
      }),
    });
  } catch {
    clearTimeout(timer);

    if (
      initialMutation &&
      !ultraCompactRetry &&
      (
        hardTimeoutMs -
        (Date.now() - startedAt)
      ) > 25000
    ) {
      stage(
        "local_agent_controller_compact_retry",
        gapLabel +
          " ilk mutation karar isteği zaman aşımına uğradı • ultra-kompakt retry • decisionModel=" +
          decisionModel
      );

      return requestStructuredToolDecision(
        assistantText,
        blockers,
        true,
        validationRetry
      );
    }

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

  const name =
    fixedReplaceMode
      ? "replace_text"
      : String(
          decision?.name || ""
        );

  const args =
    fixedReplaceMode
      ? {
          path: fixedReplacePath,
          old_text:
            fixedRepairMode
              ? fixedRepairOldText
              : String(
                  decision?.old_text || ""
                ),
          new_text:
            String(
              decision?.new_text ?? ""
            ),
          replace_all: false,
        }
      : decision?.arguments &&
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
      const verifiedTargets =
        implementationTargetPaths.map(
          normalizeRepoRelativePath
        );

      args.patch = canonicalizeUnifiedPatch(
        args.patch,
        verifiedTargets
      );

      const patchPaths =
        mutationPathsForTool(
          "apply_patch",
          args
        );

      if (
        patchPaths.length === 0 ||
        patchPaths.some(
          (targetPath) =>
            !verifiedTargets.includes(
              normalizeRepoRelativePath(
                targetPath
              )
            )
        )
      ) {
        return rejectStructuredDecision(
          "apply_patch doğrulanmış target seti dışında • patchPaths=" +
            truncate(
              JSON.stringify(patchPaths),
              800
            ) +
            " • verifiedTargets=" +
            truncate(
              JSON.stringify(
                verifiedTargets
              ),
              800
            )
        );
      }
    }
  }

  if (
    phase === "implementation" &&
    name === "replace_text"
  ) {
    const targetPath =
      normalizeRepoRelativePath(
        args.path
      );
    const oldText =
      String(args.old_text || "");
    const newText =
      String(args.new_text ?? "");

    let source = "";
    try {
      const { absolute } =
        safeRelativePath(
          targetPath
        );
      source =
        fs.readFileSync(
          absolute,
          "utf8"
        );
    } catch {}

    const occurrences =
      oldText
        ? source.split(oldText).length - 1
        : 0;

    const verifiedRead =
      compactControllerEvidence(
        ultraCompactRetry
      )?.lastVerifiedRead?.content || "";

    const copiedFromVerifiedRead =
      Boolean(
        oldText &&
        verifiedRead.includes(
          oldText
        )
      );

    const meaningfulChange =
      Boolean(
        oldText &&
        newText !== oldText &&
        !(
          oldText.length < 120 &&
          (
            newText.startsWith(oldText) ||
            oldText.startsWith(newText)
          )
        )
      );

    const differsFromPreviousFailed =
      !fixedRepairMode ||
      newText !==
        String(
          lastFailedReplaceMutation?.new_text ?? ""
        );

    if (
      oldText.length < 80 ||
      occurrences !== 1 ||
      !copiedFromVerifiedRead ||
      !meaningfulChange ||
      !differsFromPreviousFailed
    ) {
      const validationReason = [
        "replace_text anchor doğrulanmadı",
        "length=" + oldText.length,
        "occurrences=" + occurrences,
        "copiedFromVerifiedRead=" +
          String(copiedFromVerifiedRead),
        "meaningfulChange=" +
          String(meaningfulChange),
        "differsFromPreviousFailed=" +
          String(
            differsFromPreviousFailed
          ),
      ].join(" • ");

      stage(
        "local_agent_replace_anchor_rejected",
        gapLabel +
          " " +
          validationReason +
          " • decisionModel=" +
          decisionModel
      );

      if (
        validationRetry < 2 &&
        (
          hardTimeoutMs -
          (Date.now() - startedAt)
        ) > 25000
      ) {
        return requestStructuredToolDecision(
          [
            assistantText,
            "Previous replace_text decision was rejected before execution.",
            validationReason,
            fixedRepairMode
              ? "The old_text anchor is fixed by KRALI. Return only a materially different new_text that repairs the compiler/runtime evidence."
              : "Choose a longer exact unique multi-line old_text copied verbatim from lastVerifiedRead.content and make a meaningful logic change.",
          ].join("\n"),
          blockers,
          ultraCompactRetry,
          validationRetry + 1
        );
      }

      return rejectStructuredDecision(
        validationReason
      );
    }

    const fingerprint =
      mutationFingerprint(
        name,
        args
      );

    if (
      fingerprint &&
      failedMutationFingerprints.has(
        fingerprint
      )
    ) {
      const repeatReason =
        "önceden build FAIL alan mutation tekrarlandı • fingerprint=" +
        fingerprint.slice(0, 12);

      stage(
        "local_agent_repeated_failed_mutation_rejected",
        gapLabel +
          " " +
          repeatReason +
          " • decisionModel=" +
          decisionModel
      );

      if (
        validationRetry < 2 &&
        (
          hardTimeoutMs -
          (Date.now() - startedAt)
        ) > 25000
      ) {
        return requestStructuredToolDecision(
          [
            assistantText,
            "Previous mutation is a known failed strategy and was rejected before execution.",
            repeatReason,
            "Produce a materially different repair strategy using exact verified source. Do not repeat the failed semantic change.",
          ].join("\n"),
          blockers,
          ultraCompactRetry,
          validationRetry + 1
        );
      }

      return rejectStructuredDecision(
        repeatReason
      );
    }
  }

  structuredActions += 1;

  return {
    name,
    args,
    reason:
      fixedReplaceMode
        ? ""
        : truncate(
            decision?.reason || "",
            500
          ),
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
  const mutationSnapshot = isMutation
    ? captureMutationSnapshot(
        decision.name,
        decision.args
      )
    : null;
  const mutationDecisionFingerprint =
    isMutation
      ? mutationFingerprint(
          decision.name,
          decision.args
        )
      : "";

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

  lastStructuredOutcome = {
    tool: decision.name,
    args: decision.args,
    result,
  };

  if (isMutation && result?.ok) {
    lastMutationSnapshot = mutationSnapshot;
    lastMutationFingerprint =
      mutationDecisionFingerprint;
    lastAppliedMutationDecision = {
      name: decision.name,
      args: {
        ...decision.args,
      },
      fingerprint:
        mutationDecisionFingerprint,
    };
  }

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
    const safeArgs = truncate(
      JSON.stringify(decision.args || {}),
      1800
    );
    const safeError = truncate(
      result?.error ||
        result?.output ||
        "bilinmeyen structured tool hatası",
      1800
    );

    stage(
      "local_agent_structured_failure",
      gapLabel +
        " structured tool başarısız • tool=" +
        decision.name +
        " • error=" +
        safeError +
        " • args=" +
        safeArgs
    );

    persistCheckpoint(
      "structured_tool_failed:" +
        decision.name
    );
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

function handoffStructuredCandidateIfReady(
  trigger
) {
  const status = candidateStatus();

  if (
    !sawMutatingTool ||
    status?.ok !== true ||
    status.dirty !== true
  ) {
    return false;
  }

  if (!sawGitDiff) {
    stage(
      "local_agent_structured_tool",
      gapLabel +
        " candidate preflight diff doğrulaması çalışıyor • trigger=" +
        trigger
    );

    const diffResult = executeTool(
      "git_diff",
      {}
    );

    recordToolEvidence(
      "git_diff",
      diffResult,
      {}
    );

    lastStructuredOutcome = {
      tool: "git_diff",
      args: {},
      result: diffResult,
    };

    if (!diffResult?.ok) {
      persistCheckpoint(
        "structured_candidate_diff_failed:" + trigger
      );
      return false;
    }

    const currentDiffFingerprint =
      diffFingerprint(
        diffResult.output || ""
      );

    if (
      currentDiffFingerprint &&
      failedDiffFingerprints.has(
        currentDiffFingerprint
      )
    ) {
      let repeatedDiffRolledBack = false;

      if (lastMutationSnapshot) {
        repeatedDiffRolledBack =
          restoreMutationSnapshot(
            lastMutationSnapshot
          );
      }

      if (lastMutationFingerprint) {
        failedMutationFingerprints.add(
          lastMutationFingerprint
        );
      }

      lastMutationSnapshot = null;
      lastMutationFingerprint = "";
      sawMutatingTool = false;
      sawGitDiff = false;
      buildCheckPassed = false;

      const repeatReason =
        "önceden build FAIL alan candidate diff tekrarlandı • fingerprint=" +
        currentDiffFingerprint.slice(
          0,
          12
        ) +
        " • rollback=" +
        String(
          repeatedDiffRolledBack
        );

      stage(
        "local_agent_repeated_failed_diff_rejected",
        gapLabel +
          " " +
          repeatReason +
          " • trigger=" +
          trigger
      );

      lastStructuredOutcome = {
        tool: "git_diff",
        args: {},
        result: {
          ok: false,
          repeated_failed_diff: true,
          diff_fingerprint:
            currentDiffFingerprint.slice(
              0,
              12
            ),
          mutation_rolled_back:
            repeatedDiffRolledBack,
          failed_candidate_diff:
            truncate(
              diffResult.output || "",
              4200
            ),
        },
      };

      persistCheckpoint(
        "repeated_failed_diff_rejected:" +
          trigger
      );
      return false;
    }
  }

  if (!buildCheckPassed) {
    stage(
      "local_agent_structured_tool",
      gapLabel +
        " candidate preflight build_check çalışıyor • trigger=" +
        trigger
    );

    const buildResult = executeTool(
      "build_check",
      {}
    );

    recordToolEvidence(
      "build_check",
      buildResult,
      {}
    );

    const failedCandidateDiff =
      buildResult?.ok
        ? ""
        : currentCandidateDiff(12000);

    if (!buildResult?.ok) {
      const failedDiffFingerprint =
        diffFingerprint(
          failedCandidateDiff
        );

      if (failedDiffFingerprint) {
        failedDiffFingerprints.add(
          failedDiffFingerprint
        );

        stage(
          "local_agent_failed_diff_recorded",
          gapLabel +
            " build FAIL candidate diff fingerprint kaydedildi • fingerprint=" +
            failedDiffFingerprint.slice(
              0,
              12
            ) +
            " • trigger=" +
            trigger
        );
      }
    }

    let mutationRolledBack = false;

    if (!buildResult?.ok && lastMutationSnapshot) {
      if (
        lastAppliedMutationDecision?.name ===
          "replace_text" &&
        lastAppliedMutationDecision?.args?.old_text
      ) {
        lastFailedReplaceMutation = {
          path:
            String(
              lastAppliedMutationDecision.args.path || ""
            ),
          old_text:
            String(
              lastAppliedMutationDecision.args.old_text || ""
            ),
          new_text:
            String(
              lastAppliedMutationDecision.args.new_text ?? ""
            ),
          fingerprint:
            String(
              lastAppliedMutationDecision.fingerprint || ""
            ),
        };

        stage(
          "local_agent_repair_anchor_preserved",
          gapLabel +
            " build FAIL sonrası exact repair anchor korundu • path=" +
            lastFailedReplaceMutation.path +
            " • oldLength=" +
            lastFailedReplaceMutation.old_text.length +
            " • trigger=" +
            trigger
        );
      }

      if (lastMutationFingerprint) {
        failedMutationFingerprints.add(
          lastMutationFingerprint
        );

        stage(
          "local_agent_failed_mutation_recorded",
          gapLabel +
            " build FAIL mutation fingerprint kaydedildi • fingerprint=" +
            lastMutationFingerprint.slice(
              0,
              12
            ) +
            " • trigger=" +
            trigger
        );
      }

      mutationRolledBack =
        restoreMutationSnapshot(
          lastMutationSnapshot
        );

      if (mutationRolledBack) {
        stage(
          "local_agent_mutation_rolled_back",
          gapLabel +
            " başarısız preflight sonrası son mutation geri alındı • trigger=" +
            trigger
        );
      }

      lastMutationSnapshot = null;
      lastMutationFingerprint = "";
      lastAppliedMutationDecision = null;
    }

    const buildEvidence = buildResult?.ok
      ? buildResult
      : summarizeBuildFailure(
          buildResult,
          failedCandidateDiff,
          mutationRolledBack
        );

    lastStructuredOutcome = {
      tool: "build_check",
      args: {},
      result: buildEvidence,
    };

    messages.push({
      role: "user",
      content: [
        "KRALI structured candidate preflight gerçek build_check çalıştırdı.",
        "Result: " +
          truncate(
            JSON.stringify(buildEvidence),
            18000
          ),
        buildResult?.ok
          ? "Build PASS. Candidate handoff edilebilir."
          : mutationRolledBack
            ? "Build FAIL. Hatalı son mutation güvenli biçimde geri alındı. failed_candidate_diff ve compiler çıktısını kullanarak temiz kaynak üzerinde alternatif minimum repair mutation üret. Aynı başarısız mutation'ı tekrarlama."
            : "Build FAIL. candidateDiff ve compiler çıktısını birlikte kullan; yeni inspection yapmadan minimum repair mutation uygula. Aynı build_check'i source değiştirmeden tekrar etme.",
      ].join("\n"),
    });

    if (!buildResult?.ok) {
      stage(
        "local_agent_structured_tool",
        gapLabel +
          " candidate preflight build başarısız • sıcak controller ile repair gerekli • rollback=" +
          String(mutationRolledBack) +
          " • compilerErrors=" +
          truncate(
            JSON.stringify(
              buildEvidence.compiler_errors || []
            ),
            1400
          ) +
          " • failedDiff=" +
          truncate(
            buildEvidence.failed_candidate_diff || "",
            1800
          ) +
          " • trigger=" +
          trigger
      );
      persistCheckpoint(
        "structured_candidate_preflight_failed:" + trigger
      );
      return false;
    }
  }

  stage(
    "local_agent_candidate_handoff",
    gapLabel +
      " structured controller candidate build PASS • trigger=" +
      trigger +
      " • recovery pipeline'ına doğrulanmış candidate devrediliyor"
  );

  persistCheckpoint(
    "structured_candidate_handoff:" + trigger
  );

  fail(
    "Structured controller candidate üretti ve preflight build geçti; recovery pipeline'ına devrediliyor.",
    28,
    "local_agent_candidate_handoff"
  );
}

function bootstrapRuntimeFailureSourceEvidence() {
  if (
    !requireChange ||
    implementationSearchCompleted ||
    runtimeSourceHints.length === 0
  ) {
    return false;
  }

  implementationPhaseAnnounced = true;
  inspectionToolCalls = Math.max(
    inspectionToolCalls,
    maxInspectionTools
  );

  for (const hint of runtimeSourceHints) {
    const args = {
      query: hint,
      max_results: 40,
    };

    const result = executeTool(
      "search_codebase",
      args
    );

    if (!result?.ok) {
      continue;
    }

    const eligibleMatches = Array.isArray(
      result.matches
    )
      ? result.matches.filter((line) => {
          const matchPath =
            normalizeRepoRelativePath(
              String(line || "").split(":")[0]
            );

          return isEligibleImplementationTargetPath(
            matchPath
          );
        })
      : [];

    if (eligibleMatches.length === 0) {
      continue;
    }

    result.matches = eligibleMatches;

    const firstMatch =
      String(eligibleMatches[0] || "");
    const matchParts =
      firstMatch.split(":");
    const matchPath =
      normalizeRepoRelativePath(
        matchParts.shift() || ""
      );
    const matchLine =
      Number(matchParts.shift() || 0);

    runtimeBootstrapTarget = {
      path: matchPath,
      line:
        Number.isFinite(matchLine)
          ? matchLine
          : 0,
      hint,
    };

    recordToolEvidence(
      "search_codebase",
      result,
      args
    );

    stage(
      "local_agent_diagnostic_source_bootstrap",
      gapLabel +
        " runtime hata metninden source bootstrap bulundu • hint=" +
        truncate(hint, 180) +
        " • targets=" +
        truncate(
          JSON.stringify(
            implementationTargetPaths
          ),
          1000
        )
    );

    messages.push({
      role: "user",
      content: [
        "KRALI runtime failure source bootstrap gerçek code search kanıtı üretti.",
        "Hata ipucu: " + hint,
        "Eşleşen implementation targets: " +
          JSON.stringify(
            implementationTargetPaths
          ),
        "Genel repo keşfi yapma. Önce bu hata tanımını içeren minimum kaynağı read_file ile doğrula.",
      ].join("\n"),
    });

    return true;
  }

  return false;
}

function sourceLinesFromReadResult(
  readResult
) {
  return String(
    readResult?.content || ""
  )
    .split("\n")
    .map((raw) => {
      const match = raw.match(
        /^\s*(\d+)\s*\|\s?(.*)$/
      );

      if (!match) {
        return null;
      }

      return {
        line: Number(match[1]),
        text: match[2],
      };
    })
    .filter(Boolean);
}

function runtimeDependencySymbols(
  readResult,
  errorLine
) {
  const lines =
    sourceLinesFromReadResult(
      readResult
    );

  if (lines.length === 0) {
    return [];
  }

  const errorIndex =
    lines.findIndex(
      (item) =>
        item.line === errorLine
    );

  const contextIndex =
    errorIndex >= 0
      ? errorIndex
      : Math.floor(
          lines.length / 2
        );

  let failureToken = "";

  for (
    let index = Math.max(
      0,
      contextIndex - 4
    );
    index <= Math.min(
      lines.length - 1,
      contextIndex + 4
    );
    index += 1
  ) {
    const caseMatch =
      lines[index].text.match(
        /\bcase\s+([A-Za-z_][A-Za-z0-9_]*)/
      );

    if (caseMatch) {
      failureToken = caseMatch[1];
      break;
    }
  }

  let emissionIndex = -1;

  if (failureToken) {
    emissionIndex =
      lines.findIndex(
        (item, index) =>
          index !== contextIndex &&
          item.text.includes(
            failureToken
          ) &&
          /\b(?:throw|raise|return|fail|reject)\b/i.test(
            item.text
          )
      );
  }

  if (emissionIndex < 0) {
    emissionIndex =
      lines.findIndex(
        (item, index) =>
          index > contextIndex &&
          /\b(?:throw|raise|fail|reject)\b/i.test(
            item.text
          )
      );
  }

  const anchorIndex =
    emissionIndex >= 0
      ? emissionIndex
      : contextIndex;

  const ignored = new Set([
    "if",
    "for",
    "while",
    "switch",
    "guard",
    "return",
    "throw",
    "raise",
    "catch",
    "await",
    "try",
    "print",
    "init",
    "super",
    "self",
    "Task",
    "String",
    "URL",
    "Set",
    "Array",
    "Dictionary",
    "Int",
    "Double",
    "Bool",
  ]);

  const scores = new Map();

  const start =
    Math.max(
      0,
      anchorIndex - 28
    );
  const end =
    Math.min(
      lines.length - 1,
      anchorIndex + 12
    );

  for (
    let index = start;
    index <= end;
    index += 1
  ) {
    const item = lines[index];
    const callPattern =
      /\b([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
    let match;

    while (
      (match =
        callPattern.exec(
          item.text
        ))
    ) {
      const symbol = match[1];

      if (
        ignored.has(symbol) ||
        symbol === failureToken
      ) {
        continue;
      }

      const distance =
        Math.abs(
          index - anchorIndex
        );
      const beforeBonus =
        index <= anchorIndex
          ? 12
          : 0;
      const lowerCaseBonus =
        /^[a-z_]/.test(symbol)
          ? 8
          : 0;
      const controlFlowBonus =
        /\b(?:guard|if|let|var)\b/.test(
          item.text
        )
          ? 4
          : 0;

      const score =
        100 -
        distance * 3 +
        beforeBonus +
        lowerCaseBonus +
        controlFlowBonus;

      if (
        !scores.has(symbol) ||
        score >
          scores.get(symbol)
      ) {
        scores.set(
          symbol,
          score
        );
      }
    }
  }

  return [
    ...scores.entries(),
  ]
    .sort(
      (a, b) =>
        b[1] - a[1]
    )
    .map(
      ([symbol]) => symbol
    )
    .slice(0, 10);
}

function findDefinitionForSymbol(
  symbol
) {
  const definitionQueries = [
    "func " + symbol + "(",
    "function " + symbol + "(",
    "def " + symbol + "(",
    "struct " + symbol,
    "class " + symbol,
    "actor " + symbol,
    "enum " + symbol,
    "protocol " + symbol,
    "const " + symbol + " =",
    "let " + symbol + " =",
    "var " + symbol + " =",
  ];

  for (
    const query of
      definitionQueries
  ) {
    const args = {
      query,
      max_results: 30,
    };

    const result =
      executeTool(
        "search_codebase",
        args
      );

    if (
      !result?.ok ||
      !Array.isArray(
        result.matches
      )
    ) {
      continue;
    }

    const eligible =
      result.matches.filter(
        (line) => {
          const matchPath =
            normalizeRepoRelativePath(
              String(line || "")
                .split(":")[0]
            );

          return isEligibleImplementationTargetPath(
            matchPath
          );
        }
      );

    if (
      eligible.length === 0
    ) {
      continue;
    }

    result.matches = eligible;

    return {
      args,
      result,
      symbol,
      match:
        String(
          eligible[0] || ""
        ),
    };
  }

  return null;
}

function exactSourceFromReadResult(
  readResult
) {
  return sourceLinesFromReadResult(
    readResult
  )
    .map((item) => item.text)
    .join("\n");
}

function dependencySymbolsFromDefinition(
  symbol,
  readResult
) {
  const source =
    exactSourceFromReadResult(
      readResult
    );

  const ignored = new Set([
    symbol,
    "if",
    "for",
    "while",
    "switch",
    "guard",
    "return",
    "throw",
    "catch",
    "await",
    "try",
    "print",
    "init",
    "super",
    "self",
    "Task",
    "String",
    "URL",
    "Set",
    "Array",
    "Dictionary",
    "Int",
    "Double",
    "Float",
    "Bool",
    "Date",
    "Data",
    "Optional",
    "Result",
    "Foundation",
  ]);

  const ordered = [];

  function add(value) {
    const clean =
      String(value || "").trim();

    if (
      !clean ||
      ignored.has(clean) ||
      ordered.includes(clean)
    ) {
      return;
    }

    ordered.push(clean);
  }

  const callPattern =
    /\b([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
  let match;

  while (
    (match =
      callPattern.exec(source))
  ) {
    add(match[1]);
  }

  const typePattern =
    /\b([A-Z][A-Za-z0-9_]{2,})\b/g;

  while (
    (match =
      typePattern.exec(source))
  ) {
    add(match[1]);
  }

  return ordered.slice(0, 18);
}

function definitionEvidenceForSymbol(
  symbol
) {
  const found =
    findDefinitionForSymbol(
      symbol
    );

  if (!found) {
    return null;
  }

  const parts =
    found.match.split(":");
  const definitionPath =
    normalizeRepoRelativePath(
      parts.shift() || ""
    );
  const definitionLine =
    Number(
      parts.shift() || 0
    );

  if (
    !definitionPath ||
    !Number.isFinite(
      definitionLine
    ) ||
    definitionLine <= 0
  ) {
    return null;
  }

  const sourceRange =
    definitionSourceRange(
      definitionPath,
      definitionLine
    );

  const readArgs = {
    path: definitionPath,
    start_line:
      sourceRange.start_line,
    end_line:
      sourceRange.end_line,
  };

  const readResult =
    executeTool(
      "read_file",
      readArgs
    );

  if (!readResult?.ok) {
    return null;
  }

  return {
    id:
      symbol +
      "@" +
      definitionPath +
      ":" +
      definitionLine,
    symbol,
    path: definitionPath,
    line: definitionLine,
    start_line:
      sourceRange.start_line,
    end_line:
      sourceRange.end_line,
    range_mode:
      sourceRange.mode,
    read_args: readArgs,
    read_result: readResult,
    source:
      exactSourceFromReadResult(
        readResult
      ),
  };
}

function collectDependencyNeighborhood(
  primary
) {
  const records = [primary];
  const seen = new Set([
    primary.id,
    primary.symbol,
  ]);

  const dependencies =
    dependencySymbolsFromDefinition(
      primary.symbol,
      primary.read_result
    );

  for (
    const symbol of dependencies
  ) {
    if (records.length >= 8) {
      break;
    }

    if (seen.has(symbol)) {
      continue;
    }

    const evidence =
      definitionEvidenceForSymbol(
        symbol
      );

    if (!evidence) {
      continue;
    }

    if (
      seen.has(evidence.id)
    ) {
      continue;
    }

    seen.add(symbol);
    seen.add(evidence.id);
    records.push(evidence);
  }

  return records;
}

async function requestRootCauseDiagnosis(
  primary,
  neighborhood
) {
  if (
    !architectModel ||
    neighborhood.length === 0
  ) {
    return null;
  }

  const candidateIDs =
    neighborhood.map(
      (item) => item.id
    );

  const schema = {
    type: "object",
    additionalProperties: false,
    required: [
      "root_cause",
      "target_id",
      "strategy",
      "confidence",
      "alternatives_considered",
    ],
    properties: {
      root_cause: {
        type: "string",
        minLength: 20,
        maxLength: 1400,
      },
      target_id: {
        type: "string",
        enum: candidateIDs,
      },
      strategy: {
        type: "string",
        minLength: 20,
        maxLength: 1400,
      },
      confidence: {
        type: "number",
        minimum: 0,
        maximum: 1,
      },
      alternatives_considered: {
        type: "array",
        minItems: 2,
        maxItems: 5,
        items: {
          type: "string",
          maxLength: 500,
        },
      },
    },
  };

  const evidence = {
    problem:
      mutationProblemContext(),
    runtime_source_hints:
      runtimeSourceHints.slice(0, 6),
    primary_symbol:
      primary.id,
    candidates:
      neighborhood.map(
        (item) => ({
          id: item.id,
          symbol: item.symbol,
          path: item.path,
          start_line:
            item.start_line,
          end_line:
            item.end_line,
          source: clipExactSource(
            item.source,
            6500
          ),
        })
      ),
  };

  stage(
    "local_agent_root_cause_analyzing",
    gapLabel +
      " dependency neighborhood architect tarafından analiz ediliyor • candidates=" +
      neighborhood.length +
      " • architect=" +
      architectModel
  );

  const controller =
    new AbortController();
  const timer = setTimeout(
    () => controller.abort(),
    Math.min(
      Number(
        process.env.KRALI_ARCHITECT_TIMEOUT_MS ||
          "90000"
      ),
      Math.max(
        1000,
        hardTimeoutMs -
          (Date.now() - startedAt)
      )
    )
  );

  try {
    const response = await fetch(
      baseUrl + "/api/chat",
      {
        method: "POST",
        headers: {
          "content-type":
            "application/json",
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: architectModel,
          stream: false,
          format: schema,
          keep_alive: "10m",
          options: {
            temperature: 0.1,
            num_predict: 1200,
          },
          messages: [
            {
              role: "system",
              content: [
                "You are KRALI Root Cause Architect.",
                "Do not write code and do not propose a patch.",
                "The first symbol in a runtime call chain is only a diagnostic entry point, not automatically the mutation target.",
                "Compare the supplied dependency neighborhood and select the source definition whose behavior most plausibly causes the observed runtime failure.",
                "Prefer the deepest reusable cause over a caller-level workaround.",
                "Do not hard-code the concrete app, brand, filename, or exact test phrase.",
                "Consider at least two plausible strategies before choosing.",
                "Return only JSON matching the schema.",
              ].join("\n"),
            },
            {
              role: "user",
              content:
                JSON.stringify(
                  evidence
                ),
            },
          ],
        }),
      }
    );

    clearTimeout(timer);

    if (!response.ok) {
      stage(
        "local_agent_root_cause_inconclusive",
        gapLabel +
          " architect HTTP " +
          response.status +
          " • kör mutation yapılmayacak"
      );
      return null;
    }

    const payload =
      await response.json();
    const content =
      String(
        payload?.message?.content || ""
      ).trim();

    const diagnosis =
      JSON.parse(content);

    const target =
      neighborhood.find(
        (item) =>
          item.id ===
          diagnosis.target_id
      );

    if (!target) {
      stage(
        "local_agent_root_cause_inconclusive",
        gapLabel +
          " architect geçersiz mutation target seçti • kör mutation yapılmayacak"
      );
      return null;
    }

    return {
      ...diagnosis,
      target,
    };
  } catch (error) {
    clearTimeout(timer);

    stage(
      "local_agent_root_cause_inconclusive",
      gapLabel +
        " architect diagnosis tamamlanamadı • " +
        truncate(
          error instanceof Error
            ? error.message
            : String(error),
          500
        ) +
        " • kör mutation yapılmayacak"
    );

    return null;
  }
}

async function resolveRuntimeFailureDependency(
  errorReadResult
) {
  const symbols =
    runtimeDependencySymbols(
      errorReadResult,
      runtimeBootstrapTarget?.line ||
        0
    );

  for (
    const symbol of symbols
  ) {
    const primary =
      definitionEvidenceForSymbol(
        symbol
      );

    if (!primary) {
      continue;
    }

    const neighborhood =
      collectDependencyNeighborhood(
        primary
      );

    stage(
      "local_agent_dependency_neighborhood_verified",
      gapLabel +
        " runtime dependency neighborhood doğrulandı • entry=" +
        primary.symbol +
        " • candidates=" +
        neighborhood.length
    );

    const diagnosis =
      await requestRootCauseDiagnosis(
        primary,
        neighborhood
      );

    if (!diagnosis) {
      continue;
    }

    const target =
      diagnosis.target;

    implementationSearchCompleted =
      true;
    implementationReadCompleted =
      true;
    implementationTargetPaths = [
      target.path,
    ];

    recordCheckpointEvidence(
      "read_file",
      target.read_args,
      target.read_result
    );

    rootCauseDiagnosis = {
      root_cause:
        String(
          diagnosis.root_cause || ""
        ),
      strategy:
        String(
          diagnosis.strategy || ""
        ),
      confidence:
        Number(
          diagnosis.confidence || 0
        ),
      target_symbol:
        target.symbol,
      target_path:
        target.path,
      alternatives_considered:
        Array.isArray(
          diagnosis.alternatives_considered
        )
          ? diagnosis.alternatives_considered
          : [],
    };

    stage(
      "local_agent_root_cause_selected",
      gapLabel +
        " architect gerçek mutation target seçti • entry=" +
        primary.symbol +
        " • target=" +
        target.symbol +
        " • path=" +
        target.path +
        " • range=" +
        target.start_line +
        "-" +
        target.end_line +
        " • confidence=" +
        rootCauseDiagnosis.confidence.toFixed(
          2
        ) +
        " • architect=" +
        architectModel
    );

    messages.push({
      role: "user",
      content: [
        "KRALI Root Cause Architect dependency neighborhood içinden gerçek mutation target seçti.",
        "Target: " +
          target.symbol +
          " @ " +
          target.path +
          ":" +
          target.line,
        "Root cause: " +
          rootCauseDiagnosis.root_cause,
        "Strategy: " +
          rootCauseDiagnosis.strategy,
        "Bu exact source controller için doğrulandı. Patch bu target dışına taşmamalı.",
      ].join("\n"),
    });

    persistCheckpoint(
      "root_cause_target_selected"
    );

    return true;
  }

  return false;
}
async function runRuntimeFailureBootstrapFastPath() {
  if (!bootstrapRuntimeFailureSourceEvidence()) {
    return false;
  }

  if (
    !runtimeBootstrapTarget?.path ||
    !runtimeBootstrapTarget?.line
  ) {
    persistCheckpoint(
      "runtime_failure_bootstrap_target_missing"
    );
    return false;
  }

  const errorReadArgs = {
    path: runtimeBootstrapTarget.path,
    start_line: Math.max(
      1,
      runtimeBootstrapTarget.line - 35
    ),
    end_line:
      runtimeBootstrapTarget.line + 90,
  };

  const errorReadResult = executeTool(
    "read_file",
    errorReadArgs
  );

  if (!errorReadResult?.ok) {
    persistCheckpoint(
      "runtime_failure_bootstrap_error_read_failed"
    );
    return false;
  }

  recordToolEvidence(
    "read_file",
    errorReadResult,
    errorReadArgs
  );

  stage(
    "local_agent_diagnostic_error_window",
    gapLabel +
      " runtime hata noktası çevresi okundu • path=" +
      runtimeBootstrapTarget.path +
      " • line=" +
      runtimeBootstrapTarget.line
  );

  // Error declaration/throw site is evidence, not automatically the fix site.
  // Resolve the nearest implementation call chain deterministically first;
  // only fall back to the conversational agent if no source definition can be found.
  const dependencyResolved =
    await resolveRuntimeFailureDependency(
      errorReadResult
    );

  if (
    !dependencyResolved ||
    !implementationReadCompleted
  ) {
    persistCheckpoint(
      "runtime_failure_dependency_resolution_incomplete"
    );
    return false;
  }

  for (let attempt = 1; attempt <= 3; attempt++) {
    const {
      blockers,
    } = currentCandidateBlockers();

    const continued =
      await runStructuredContinuation(
        attempt === 1
          ? "Runtime failure'ın implementation sembolü doğrulandı. Yeni inspection yapmadan minimum generic exact replacement mutation üret."
          : "Önceki mutation veya build gerçek tool kanıtıyla başarısız oldu. lastStructuredOutcome ve lastVerifiedRead kanıtına göre aynı başarısız değişikliği tekrarlamadan minimum repair mutation üret.",
        blockers.length > 0
          ? blockers
          : [
              "doğrulanmış implementation source sonrası minimum mutation gerekli",
            ],
        attempt === 1
          ? "runtime_failure_bootstrap_mutation"
          : "runtime_failure_bootstrap_repair_" + attempt
      );

    if (!continued) {
      persistCheckpoint(
        "runtime_failure_bootstrap_controller_unavailable"
      );
      return false;
    }

    if (
      handoffStructuredCandidateIfReady(
        attempt === 1
          ? "runtime_failure_bootstrap"
          : "runtime_failure_bootstrap_repair_" + attempt
      )
    ) {
      return true;
    }
  }

  persistCheckpoint(
    "runtime_failure_bootstrap_no_candidate"
  );

  return false;
}

async function runVerifiedResumeFastPath() {
  if (
    !resumedFromCheckpoint ||
    developmentPhase() !== "implementation" ||
    !implementationReadCompleted
  ) {
    return false;
  }

  stage(
    "local_agent_verified_resume_controller",
    gapLabel +
      " doğrulanmış implementation checkpoint'i bulundu • ana model atlanıyor • controller=" +
      controllerModel
  );

  persistCheckpoint(
    "verified_resume_controller"
  );

  for (let attempt = 1; attempt <= 3; attempt++) {
    const {
      blockers,
    } = currentCandidateBlockers();

    const continued =
      await runStructuredContinuation(
        attempt === 1
          ? "Doğrulanmış implementation checkpoint'inden devam ediliyor. Hedef kaynak zaten okundu; yeni inspection yapmadan minimum generic mutation uygula."
          : "Önceki structured mutation veya candidate preflight gerçek tool kanıtıyla başarısız oldu. lastStructuredOutcome hata kanıtını, lastVerifiedRead kaynağını ve varsa candidateDiff'i kullan. Aynı başarısız argümanları tekrarlama; yeni inspection yapmadan minimum repair mutation uygula.",
        blockers.length > 0
          ? blockers
          : [
              "doğrulanmış source evidence sonrası minimum mutation gerekli",
            ],
        attempt === 1
          ? "verified_resume"
          : "verified_resume_mutation_repair_" + attempt
      );

    if (!continued) {
      persistCheckpoint(
        "verified_resume_controller_unavailable"
      );
      fail(
        "Doğrulanmış implementation checkpoint'inde structured controller güvenli devam kararı üretemedi.",
        25,
        "local_agent_tool_protocol_failed"
      );
    }

    if (
      handoffStructuredCandidateIfReady(
        attempt === 1
          ? "verified_resume"
          : "verified_resume_mutation_repair_" + attempt
      )
    ) {
      return true;
    }

    if (lastStructuredOutcome?.result?.ok === true) {
      break;
    }
  }

  persistCheckpoint(
    "verified_resume_no_candidate"
  );

  fail(
    "Structured controller doğrulanmış implementation checkpoint'inden candidate üretemedi.",
    25,
    "local_agent_tool_protocol_failed"
  );
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

await runRuntimeFailureBootstrapFastPath();
await runVerifiedResumeFastPath();

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

          handoffStructuredCandidateIfReady(
            "implementation_timeout"
          );

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
