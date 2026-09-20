import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const sdkHost = process.env.KRALI_CLINE_SDK_HOST;
const worktree = process.env.KRALI_WORKTREE;
const promptFile = process.env.KRALI_PROMPT_FILE;
const settingsFile =
  process.env.KRALI_CLINE_SETTINGS ||
  path.join(process.env.HOME || "", ".cline/data/settings/providers.json");
const requestedProvider = process.env.KRALI_DEV_PROVIDER || "ollama";
const requestedModel = process.env.KRALI_DEV_MODEL || "";
const ollamaBaseUrl =
  process.env.KRALI_OLLAMA_BASE_URL ||
  "http://127.0.0.1:11434";
const statusFile = process.env.KRALI_STATUS_FILE || "";
const branchName = process.env.KRALI_BRANCH || "";
const gapLabel = process.env.KRALI_GAP_LABEL || "Capability";
const appVersion = process.env.KRALI_APP_VERSION || "unknown";
const runID = process.env.KRALI_RUN_ID || "";
const requireToolUse =
  process.env.KRALI_REQUIRE_TOOL_USE === "1";
const timeoutMs = Number(process.env.KRALI_SDK_TIMEOUT_MS || "480000");

let currentState = "sdk_fallback_running";
let currentMessage = gapLabel + " ClineCore SDK üzerinden öğreniliyor";

function persistStatus(state, message) {
  currentState = state;
  currentMessage = message;

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

  if (statusFile) {
    try {
      fs.writeFileSync(statusFile, line, "utf8");
    } catch {}
  }
}

function setStage(state, message) {
  persistStatus(state, message);

  process.stdout.write(
    "KRALI_STAGE " + state + " • " + message + "\n"
  );
}

const idleTimeoutMs = Math.min(
  Math.max(90000, Math.floor(timeoutMs / 3)),
  180000
);
const hardTimeoutMs = Math.max(timeoutMs, 720000);

let idleWatchdog = null;
let hardWatchdog = null;

function armIdleWatchdog() {
  if (idleWatchdog) clearTimeout(idleWatchdog);

  idleWatchdog = setTimeout(() => {
    setStage(
      "sdk_watchdog_timeout",
      gapLabel +
        " SDK oturumunda uzun süre etkinlik görülmedi; recovery gerekiyor"
    );
    process.exit(124);
  }, idleTimeoutMs);
}

function touchActivity() {
  persistStatus(
    currentState,
    currentMessage
  );
  armIdleWatchdog();
}

armIdleWatchdog();

hardWatchdog = setTimeout(() => {
  setStage(
    "sdk_watchdog_timeout",
    gapLabel +
      " SDK oturumu toplam zaman sınırını aştı; recovery gerekiyor"
  );
  process.exit(124);
}, hardTimeoutMs);

if (!sdkHost || !worktree || !promptFile) {
  console.error("KRALI SDK fallback: gerekli environment bilgisi eksik.");
  process.exit(2);
}

const sdkEntry = path.join(
  sdkHost,
  "node_modules",
  "@cline",
  "sdk",
  "dist",
  "index.js"
);

if (!fs.existsSync(sdkEntry)) {
  console.error(
    "KRALI SDK fallback: @cline/sdk ESM entry bulunamadı: " + sdkEntry
  );
  process.exit(3);
}

setStage(
  "sdk_importing",
  gapLabel + " için Cline SDK yükleniyor"
);

const { ClineCore } = await import(pathToFileURL(sdkEntry).href);

setStage(
  "sdk_import_ready",
  "Cline SDK yüklendi; provider ayarları doğrulanıyor"
);

function findProvider(value, providerId) {
  if (!value || typeof value !== "object") return null;

  if (value.provider === providerId) {
    return value;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      const match = findProvider(item, providerId);
      if (match) return match;
    }
    return null;
  }

  for (const item of Object.values(value)) {
    const match = findProvider(item, providerId);
    if (match) return match;
  }

  return null;
}

let providerId = requestedProvider;
let providerSettings = null;
let modelId = requestedModel;
let providerBaseUrl = undefined;
let providerApiKey = undefined;

if (providerId === "ollama") {
  providerId = "openai-compatible";
  providerBaseUrl =
    ollamaBaseUrl.replace(/\/$/, "") +
    "/v1";
  providerApiKey = "ollama";

  if (!modelId) {
    setStage(
      "sdk_provider_failed",
      "Ollama için yerel model seçilmedi"
    );
    console.error(
      "KRALI SDK fallback: Ollama için modelId gerekli."
    );
    process.exit(4);
  }

  setStage(
    "sdk_provider_ready",
    "Yerel Ollama OpenAI-compatible adapter hazır: " +
      modelId
  );
} else {
  try {
    providerSettings = findProvider(
      JSON.parse(fs.readFileSync(settingsFile, "utf8")),
      providerId
    );
  } catch {}

  modelId =
    modelId ||
    providerSettings?.model ||
    providerSettings?.modelId ||
    providerSettings?.apiModelId ||
    providerSettings?.actModeApiModelId ||
    providerSettings?.planModeApiModelId ||
    "";

  if (!modelId) {
    setStage(
      "sdk_provider_failed",
      providerId + " için kayıtlı model bulunamadı"
    );
    console.error(
      "KRALI SDK fallback: " +
        providerId +
        " için kayıtlı model bulunamadı."
    );
    process.exit(4);
  }

  providerBaseUrl =
    providerSettings?.baseUrl ||
    providerSettings?.apiBaseUrl ||
    undefined;
  providerApiKey =
    providerSettings?.apiKey ||
    providerSettings?.key ||
    undefined;

  setStage(
    "sdk_provider_ready",
    providerId + " provider ve model ayarı hazır"
  );
}

const prompt = fs.readFileSync(promptFile, "utf8");

const deniedFragments = [
  "sudo ",
  "rm -rf",
  "git push",
  "git reset --hard",
  "git clean",
  "osascript ",
  "spctl --global-disable",
];

function isSafeApproval(request) {
  const toolName = String(request?.toolName || "").toLowerCase();
  const serialized = JSON.stringify(request?.input ?? request ?? {})
    .toLowerCase();
  const worktreeLower = worktree.toLowerCase();

  if (deniedFragments.some((part) => serialized.includes(part))) {
    return false;
  }

  const suspiciousPaths = [
    "/system/",
    "/library/",
    "/usr/bin/",
    "/usr/sbin/",
    "/private/etc/",
  ];

  if (
    suspiciousPaths.some((part) => serialized.includes(part)) &&
    !serialized.includes(worktreeLower)
  ) {
    return false;
  }

  const mutatingTools = new Set([
    "run_commands",
    "bash",
    "editor",
    "apply_patch",
    "write_file",
  ]);

  if (mutatingTools.has(toolName)) {
    if (
      serialized.includes("../") ||
      serialized.includes("~/.") ||
      serialized.includes("$home") ||
      serialized.includes("/users/") &&
        !serialized.includes(worktreeLower)
    ) {
      return false;
    }
  }

  return true;
}

setStage(
  "sdk_runtime_starting",
  "ClineCore local runtime başlatılıyor"
);

const cline = await ClineCore.create({
  clientName: "krali-developer-agent",
  backendMode: "local",
  capabilities: {
    requestToolApproval: async (request) => ({
      approved: isSafeApproval(request),
    }),
  },
});

setStage(
  "sdk_runtime_ready",
  "ClineCore runtime hazır; agent session başlatılıyor"
);

let sawAgentEvent = false;
let sawToolEvent = false;

const unsubscribe = cline.subscribe((event) => {
  try {
    touchActivity();

    if (
      event?.type === "chunk" &&
      (event?.payload?.type === "text" ||
       event?.payload?.type === "reasoning")
    ) {
      return;
    }

    if (event?.type === "agent_event") {
      const inner = event?.payload?.event;

      if (!sawAgentEvent) {
        sawAgentEvent = true;
        setStage(
          "sdk_session_running",
          gapLabel + " için model oturumu aktif"
        );
      }

      if (
        inner?.type === "content_start" &&
        inner?.contentType === "tool"
      ) {
        sawToolEvent = true;
        setStage(
          "sdk_tools_running",
          gapLabel +
            " için araç çalışıyor: " +
            String(inner?.toolName || "tool")
        );
        return;
      }

      if (
        inner?.type === "content_update" &&
        inner?.contentType === "tool"
      ) {
        if (!sawToolEvent) {
          sawToolEvent = true;
        }
        setStage(
          "sdk_tools_running",
          gapLabel +
            " araç çıktısı güncelleniyor: " +
            String(inner?.toolName || "tool")
        );
        return;
      }

      if (
        inner?.type === "content_end" &&
        inner?.contentType === "tool"
      ) {
        setStage(
          "sdk_tool_completed",
          gapLabel +
            " araç adımı tamamlandı: " +
            String(inner?.toolName || "tool")
        );
        return;
      }

      if (inner?.type === "error") {
        setStage(
          "sdk_failed",
          "ClineCore agent hatası: " +
            String(inner?.error?.message || "unknown").slice(0, 180)
        );
      }
    }

    if (event?.type === "hook") {
      if (!sawToolEvent) {
        sawToolEvent = true;
        setStage(
          "sdk_tools_running",
          gapLabel + " için tool hook çalışıyor"
        );
      }
      return;
    }

    if (event?.type === "ended") {
      setStage(
        "sdk_session_ended",
        gapLabel +
          " SDK session sona erdi: " +
          String(event?.payload?.finishReason || "unknown")
      );
    }
  } catch {}
});

try {
  setStage(
    "sdk_session_starting",
    gapLabel + " için ClineCore session isteği gönderildi"
  );

  const session = await cline.start({
    prompt,
    interactive: true,
    config: {
      providerId,
      modelId,
      ...(providerApiKey ? { apiKey: providerApiKey } : {}),
      ...(providerBaseUrl ? { baseUrl: providerBaseUrl } : {}),
      cwd: worktree,
      workspaceRoot: worktree,
      mode: "act",
      maxIterations: Number(
        process.env.KRALI_SDK_MAX_ITERATIONS ||
          (
            requestedProvider === "ollama"
              ? "36"
              : "24"
          )
      ),
      enableTools: true,
      enableSpawnAgent: false,
      enableAgentTeams: false,
      disableMcpSettingsTools: true,
      systemPrompt:
        "You are KRALI Developer Agent. Work only inside the supplied candidate worktree. Never push or merge main. Prefer minimum generic fixes. Do not modify VERSION, updater/signing settings or Mentor JSON files. Preserve user approval gates and objective verification.",
    },
    toolPolicies: {
      "*": { autoApprove: false },
      ask_question: { enabled: false },
      read_files: { autoApprove: true },
      search_codebase: { autoApprove: true },
      fetch_web_content: { autoApprove: true },
      run_commands: { autoApprove: false },
      bash: { autoApprove: false },
      editor: { autoApprove: false },
      apply_patch: { autoApprove: false },
    },
  });

  const result = session?.result;

  if (result?.text) {
    process.stdout.write(result.text + "\n");
  }

  const finishReason =
    String(result?.finishReason || "");

  if (
    !result ||
    ["error", "aborted", "mistake_limit"].includes(
      finishReason
    )
  ) {
    setStage(
      "sdk_failed",
      gapLabel +
        " SDK oturumu başarısız: " +
        (finishReason || "unknown")
    );
    console.error(
      "KRALI SDK fallback başarısız. finishReason=" +
        (finishReason || "unknown")
    );
    process.exitCode = 20;
  } else if (
    requireToolUse &&
    !sawToolEvent
  ) {
    const echoedToolJSON =
      /"name"\s*:\s*"(?:read_files|search_codebase|run_commands|apply_patch|editor)"/i
        .test(String(result?.text || ""));

    setStage(
      "sdk_tool_protocol_failed",
      gapLabel +
        " model gerçek tool event üretmedi" +
        (echoedToolJSON
          ? "; tool çağrısını metin/JSON olarak taklit etti"
          : "")
    );

    console.error(
      "KRALI SDK local tool protocol failed: no real tool event"
    );
    process.exitCode = 25;
  } else {
    setStage(
      "sdk_session_completed",
      gapLabel +
        " SDK oturumu gerçek tool akışıyla tamamlandı; candidate değişiklikler kontrol ediliyor"
    );
  }
} catch (error) {
  const message =
    error instanceof Error ? error.message : String(error);

  setStage(
    "sdk_failed",
    "ClineCore SDK hatası: " + message.slice(0, 180)
  );

  console.error(
    "KRALI SDK fallback exception: " + message
  );
  process.exitCode = 20;
} finally {
  if (idleWatchdog) clearTimeout(idleWatchdog);
  if (hardWatchdog) clearTimeout(hardWatchdog);
  try {
    unsubscribe();
  } catch {}
  await cline.dispose("KRALI Developer Agent finished");
}
