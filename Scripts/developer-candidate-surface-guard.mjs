#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

function argValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? String(process.argv[index + 1] || "") : "";
}

const root = path.resolve(
  argValue("--root") || process.env.KRALI_WORKTREE || process.cwd()
);
const taskFile =
  argValue("--task") || process.env.KRALI_DEV_TASK_FILE || "";
const baseRef =
  argValue("--base") ||
  process.env.KRALI_SURFACE_GUARD_BASE ||
  "HEAD";

function runGit(args) {
  return spawnSync("git", ["-C", root, ...args], {
    encoding: "utf8",
    maxBuffer: 8 * 1024 * 1024,
  });
}

function lineCount(text) {
  if (!text) return 0;
  return String(text).split(/\r?\n/).length;
}

function extractSurface(file, source) {
  const ext = path.extname(file).toLowerCase();
  const types = new Set();
  const functions = new Set();

  for (const rawLine of String(source || "").split(/\r?\n/)) {
    const line = rawLine.trim();

    if (ext === ".swift") {
      const typeMatch = line.match(
        /^(?:(?:public|internal|private|fileprivate|open|final|indirect|nonisolated)\s+)*(?:actor|class|struct|enum|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)\b/
      );
      if (typeMatch) types.add(typeMatch[1]);

      const fnMatch = line.match(
        /^(?:(?:public|internal|private|fileprivate|open|final|static|class|override|mutating|nonmutating|nonisolated)\s+)*func\s+([A-Za-z_][A-Za-z0-9_]*)\b/
      );
      if (fnMatch) functions.add(fnMatch[1]);
    } else if (
      [".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx"].includes(ext)
    ) {
      const classMatch = line.match(
        /^(?:export\s+(?:default\s+)?)?class\s+([A-Za-z_$][A-Za-z0-9_$]*)\b/
      );
      if (classMatch) types.add(classMatch[1]);

      const fnMatch = line.match(
        /^(?:export\s+(?:default\s+)?)?(?:async\s+)?function\s+([A-Za-z_$][A-Za-z0-9_$]*)\b/
      );
      if (fnMatch) functions.add(fnMatch[1]);
    }
  }

  return { types, functions };
}

function setDifference(left, right) {
  return [...left].filter((item) => !right.has(item));
}

function evaluateFile({
  file,
  baseSource,
  currentSource,
  additions,
  deletions,
  learningPath,
}) {
  const baseLines = lineCount(baseSource);
  const currentLines = lineCount(currentSource);
  const before = extractSurface(file, baseSource);
  const after = extractSurface(file, currentSource);

  const removedTypes = setDifference(before.types, after.types);
  const removedFunctions = setDifference(
    before.functions,
    after.functions
  );
  const baseSymbolCount =
    before.types.size + before.functions.size;
  const removedSymbolCount =
    removedTypes.length + removedFunctions.length;

  const reasons = [];

  if (learningPath === "primitivePatch") {
    if (
      baseLines >= 80 &&
      deletions >= Math.max(40, Math.ceil(baseLines * 0.25)) &&
      deletions > Math.max(10, additions * 1.8)
    ) {
      reasons.push("primitive_patch_large_destructive_diff");
    }

    if (removedTypes.length > 0) {
      reasons.push("primitive_patch_removed_named_type");
    }

    if (
      removedSymbolCount >= 3 &&
      (
        baseSymbolCount === 0 ||
        removedSymbolCount / baseSymbolCount >= 0.25
      )
    ) {
      reasons.push("primitive_patch_api_surface_drop");
    }
  } else {
    if (
      baseLines >= 120 &&
      currentLines < baseLines * 0.4 &&
      deletions >= 100
    ) {
      reasons.push("severe_file_rewrite");
    }

    if (
      removedTypes.length >= 3 &&
      removedTypes.length >= Math.ceil(before.types.size * 0.5)
    ) {
      reasons.push("severe_type_surface_drop");
    }
  }

  return {
    file,
    baseLines,
    currentLines,
    additions,
    deletions,
    removedTypes,
    removedFunctions: removedFunctions.slice(0, 20),
    reasons,
  };
}

function taskLearningPath() {
  if (!taskFile || !fs.existsSync(taskFile)) {
    return String(process.env.KRALI_LEARNING_PATH || "integration");
  }

  try {
    const payload = JSON.parse(fs.readFileSync(taskFile, "utf8"));
    return String(
      payload?.developerTask?.learningPath ||
      payload?.gap?.learningPath ||
      process.env.KRALI_LEARNING_PATH ||
      "integration"
    );
  } catch {
    return String(process.env.KRALI_LEARNING_PATH || "integration");
  }
}

function taskAllowsDestructiveChange() {
  if (!taskFile || !fs.existsSync(taskFile)) return false;

  try {
    const payload = JSON.parse(fs.readFileSync(taskFile, "utf8"));
    return payload?.taskMetadata?.allowDestructiveChange === true;
  } catch {
    return false;
  }
}

function changedExistingFiles() {
  const result = runGit([
    "diff",
    "--name-only",
    "--diff-filter=M",
    baseRef,
    "--",
  ]);

  if (result.status !== 0) return [];

  return String(result.stdout || "")
    .split(/\r?\n/)
    .map((value) => value.trim())
    .filter(Boolean);
}

function numstat(file) {
  const result = runGit([
    "diff",
    "--numstat",
    baseRef,
    "--",
    file,
  ]);

  if (result.status !== 0) {
    return { additions: 0, deletions: 0 };
  }

  const first = String(result.stdout || "")
    .split(/\r?\n/)
    .find(Boolean);

  if (!first) return { additions: 0, deletions: 0 };

  const [a, d] = first.split("\t");
  return {
    additions: Number.isFinite(Number(a)) ? Number(a) : 0,
    deletions: Number.isFinite(Number(d)) ? Number(d) : 0,
  };
}

function sourceAtHead(file) {
  const result = runGit(["show", baseRef + ":" + file]);
  return result.status === 0 ? String(result.stdout || "") : null;
}

function currentSource(file) {
  const full = path.resolve(root, file);
  const rootPrefix = root.endsWith(path.sep) ? root : root + path.sep;

  if (
    !full.startsWith(rootPrefix) ||
    !fs.existsSync(full) ||
    !fs.statSync(full).isFile()
  ) {
    return null;
  }

  return fs.readFileSync(full, "utf8");
}

function runGuard() {
  if (taskAllowsDestructiveChange()) {
    return {
      ok: true,
      bypassed: true,
      learningPath: taskLearningPath(),
      findings: [],
    };
  }

  const learningPath = taskLearningPath();
  const codeExtensions = new Set([
    ".swift",
    ".mjs",
    ".js",
    ".cjs",
    ".ts",
    ".tsx",
    ".jsx",
    ".py",
    ".sh",
    ".command",
  ]);

  const findings = [];

  for (const file of changedExistingFiles()) {
    if (!codeExtensions.has(path.extname(file).toLowerCase())) {
      continue;
    }

    const baseSource = sourceAtHead(file);
    const current = currentSource(file);

    if (baseSource == null || current == null) continue;

    const stats = numstat(file);
    const finding = evaluateFile({
      file,
      baseSource,
      currentSource: current,
      additions: stats.additions,
      deletions: stats.deletions,
      learningPath,
    });

    if (finding.reasons.length > 0) {
      findings.push(finding);
    }
  }

  return {
    ok: findings.length === 0,
    bypassed: false,
    learningPath,
    findings,
  };
}

function selfTest() {
  const original = [
    "struct AgentLearningJob {}",
    "enum AgentLearningJobState {}",
    "struct AgentLearningQueueStore {}",
    ...Array.from({ length: 100 }, (_, i) =>
      "func existing" + i + "() {}"
    ),
  ].join("\n");

  const destructive = [
    "struct AgentLearningJob {}",
    "func newAPI() {}",
  ].join("\n");

  const additive = original + "\nfunc newAPI() {}\n";

  const bad = evaluateFile({
    file: "AgentLearningQueue.swift",
    baseSource: original,
    currentSource: destructive,
    additions: 2,
    deletions: 101,
    learningPath: "primitivePatch",
  });

  const good = evaluateFile({
    file: "AgentLearningQueue.swift",
    baseSource: original,
    currentSource: additive,
    additions: 1,
    deletions: 0,
    learningPath: "primitivePatch",
  });

  if (
    bad.reasons.length === 0 ||
    !bad.removedTypes.includes("AgentLearningQueueStore") ||
    good.reasons.length !== 0
  ) {
    process.stderr.write(
      "developer_candidate_surface_guard_self_test_failed\n"
    );
    process.exit(2);
  }

  process.stdout.write(
    "developer_candidate_surface_guard_self_test_ok\n" +
    "primitive_patch_rewrite=blocked\n" +
    "api_surface_regression=blocked\n"
  );
}

if (process.argv.includes("--self-test")) {
  selfTest();
  process.exit(0);
}

if (!fs.existsSync(path.join(root, ".git"))) {
  const probe = runGit(["rev-parse", "--git-dir"]);
  if (probe.status !== 0) {
    process.stderr.write(
      "candidate_surface_guard_failed|not-a-git-worktree\n"
    );
    process.exit(3);
  }
}

const result = runGuard();

if (!result.ok) {
  process.stdout.write(
    "candidate_surface_regression|" +
      JSON.stringify(result) +
      "\n"
  );
  process.exit(30);
}

process.stdout.write(
  "candidate_surface_guard_passed|" +
    JSON.stringify({
      learningPath: result.learningPath,
      bypassed: result.bypassed,
    }) +
    "\n"
);
