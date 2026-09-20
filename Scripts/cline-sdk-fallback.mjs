import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const sdkHost = process.env.KRALI_CLINE_SDK_HOST;
const worktree = process.env.KRALI_WORKTREE;
const promptFile = process.env.KRALI_PROMPT_FILE;
const settingsFile =
  process.env.KRALI_CLINE_SETTINGS ||
  path.join(process.env.HOME || "", ".cline/data/settings/providers.json");
const requestedModel = process.env.KRALI_DEV_MODEL || "";

if (!sdkHost || !worktree || !promptFile) {
  console.error("KRALI SDK fallback: gerekli environment bilgisi eksik.");
  process.exit(2);
}

const requireFromHost = createRequire(path.join(sdkHost, "package.json"));
const sdkEntry = requireFromHost.resolve("@cline/sdk");
const { ClineCore } = await import(pathToFileURL(sdkEntry).href);

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

let providerSettings = null;
try {
  providerSettings = findProvider(
    JSON.parse(fs.readFileSync(settingsFile, "utf8")),
    "openai-codex"
  );
} catch {}

const modelId =
  requestedModel ||
  providerSettings?.model ||
  providerSettings?.modelId ||
  "gpt-5.6-terra";

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
  const serialized = JSON.stringify(request?.input ?? request ?? {})
    .toLowerCase();

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
    !serialized.includes(worktree.toLowerCase())
  ) {
    return false;
  }

  return true;
}

const cline = await ClineCore.create({
  clientName: "krali-developer-agent",
  backendMode: "local",
  capabilities: {
    requestToolApproval: async (request) => ({
      approved: isSafeApproval(request),
    }),
  },
});

try {
  const session = await cline.start({
    prompt,
    interactive: false,
    config: {
      providerId: "openai-codex",
      modelId,
      cwd: worktree,
      workspaceRoot: worktree,
      enableTools: true,
      enableSpawnAgent: false,
      enableAgentTeams: false,
      systemPrompt:
        "You are KRALI Developer Agent. Work only inside the supplied candidate worktree. Never push or merge main. Prefer minimum generic fixes. Do not modify VERSION, updater/signing settings or Mentor JSON files. Preserve user approval gates and objective verification.",
    },
    toolPolicies: {
      read_files: { autoApprove: true },
      search_codebase: { autoApprove: true },
      list_files: { autoApprove: true },
      fetch_web: { autoApprove: true },
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

  const finishReason = String(result?.finishReason || "");
  if (!result || ["error", "aborted", "mistake_limit"].includes(finishReason)) {
    console.error(
      "KRALI SDK fallback başarısız. finishReason=" +
        (finishReason || "unknown")
    );
    process.exitCode = 20;
  }
} catch (error) {
  console.error(
    "KRALI SDK fallback exception: " +
      (error instanceof Error ? error.message : String(error))
  );
  process.exitCode = 20;
} finally {
  await cline.dispose("KRALI Developer Agent finished");
}
