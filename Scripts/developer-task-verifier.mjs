#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const taskFile = process.env.KRALI_DEV_TASK_FILE || "";
const worktree = process.env.KRALI_WORKTREE || "";

function fail(message, code = 1) {
  process.stderr.write("task_verification_failed|" + message + "\n");
  process.exit(code);
}

function globRegex(pattern) {
  const normalized = String(pattern || "").replaceAll("\\", "/");
  let out = "^";
  for (let i = 0; i < normalized.length; i++) {
    const ch = normalized[i];
    if (ch === "*" && normalized[i + 1] === "*") {
      out += ".*";
      i++;
    } else if (ch === "*") {
      out += "[^/]*";
    } else if (ch === "?") {
      out += "[^/]";
    } else {
      out += ch.replace(/[.*+?^\${}()|[\]\\]/g, "\\$&");
    }
  }
  return new RegExp(out + "$");
}

function matchesAny(file, patterns) {
  return patterns.some((pattern) => globRegex(pattern).test(file));
}

function changedPaths() {
  const commands = [
    ["git", ["-C", worktree, "diff", "--name-only"]],
    ["git", ["-C", worktree, "diff", "--cached", "--name-only"]],
    ["git", ["-C", worktree, "ls-files", "--others", "--exclude-standard"]]
  ];
  const files = new Set();

  for (const [cmd, args] of commands) {
    const result = spawnSync(cmd, args, { encoding: "utf8" });
    if (result.status !== 0) {
      fail("git-status-probe-failed", 11);
    }

    for (const line of String(result.stdout || "").split(/\r?\n/)) {
      const value = line.trim();
      if (value) {
        files.add(value.replaceAll("\\", "/"));
      }
    }
  }

  return [...files];
}

function validateScope(meta) {
  const allowed = Array.isArray(meta.allowedScope)
    ? meta.allowedScope.map(String)
    : [];
  const forbidden = Array.isArray(meta.forbiddenScope)
    ? meta.forbiddenScope.map(String)
    : [];

  const violations = changedPaths().filter((file) => {
    if (matchesAny(file, forbidden)) return true;
    return allowed.length > 0 && !matchesAny(file, allowed);
  });

  if (violations.length > 0) {
    fail("scope-violation:" + violations.join(","), 12);
  }
}

if (process.argv.includes("--self-test")) {
  const checks = [
    globRegex("DeveloperAgent/Tests/ui-regression/**")
      .test("DeveloperAgent/Tests/ui-regression/result.json"),
    !globRegex("DeveloperAgent/Tests/ui-regression/**")
      .test("App/KRALIAgentNative/ContentView.swift"),
    globRegex("Scripts/example.mjs").test("Scripts/example.mjs")
  ];

  if (checks.every(Boolean)) {
    process.stdout.write("developer_task_verifier_self_test_ok\n");
    process.exit(0);
  }

  fail("self-test", 2);
}

if (!taskFile || !fs.existsSync(taskFile)) {
  process.stdout.write("task_verification_not_required|no-task-file\n");
  process.exit(0);
}

if (!worktree || !fs.existsSync(worktree)) {
  fail("worktree-missing", 3);
}

let payload;
try {
  payload = JSON.parse(fs.readFileSync(taskFile, "utf8"));
} catch (error) {
  fail("task-json-invalid:" + error.message, 4);
}

const meta =
  payload.taskMetadata &&
  typeof payload.taskMetadata === "object"
    ? payload.taskMetadata
    : {};

const verification =
  meta.verification &&
  typeof meta.verification === "object"
    ? meta.verification
    : null;

if (!verification) {
  process.stdout.write("task_verification_not_required|no-contract\n");
  process.exit(0);
}

const command = Array.isArray(verification.command)
  ? verification.command.map(String)
  : [];

if (command.length === 0 || command.some((part) => !part.trim())) {
  fail("verification-command-invalid", 5);
}

const expectedExit = Number.isInteger(verification.requireExitCode)
  ? verification.requireExitCode
  : 0;

const requiredArtifacts = Array.isArray(verification.requiredArtifacts)
  ? verification.requiredArtifacts.map(String)
  : [];

const requiredStdout = Array.isArray(verification.requiredStdout)
  ? verification.requiredStdout.map(String)
  : [];

const timeoutSeconds = Math.min(
  Math.max(Number(verification.timeoutSeconds || 120), 1),
  300
);

for (const artifact of requiredArtifacts) {
  if (
    path.isAbsolute(artifact) ||
    artifact.split(/[\\/]+/).includes("..")
  ) {
    fail("artifact-path-invalid:" + artifact, 6);
  }
}

const safeEnv = {
  PATH: process.env.PATH || "/usr/bin:/bin:/usr/sbin:/sbin",
  HOME: process.env.HOME || "",
  TMPDIR: process.env.TMPDIR || "/tmp",
  LANG: process.env.LANG || "en_US.UTF-8",
  LC_ALL: process.env.LC_ALL || "",
  KRALI_TASK_VERIFICATION: "1"
};

process.stdout.write(
  "task_verification_running|command=" +
  JSON.stringify(command) +
  "\n"
);

const result = spawnSync(
  command[0],
  command.slice(1),
  {
    cwd: worktree,
    env: safeEnv,
    encoding: "utf8",
    timeout: timeoutSeconds * 1000,
    maxBuffer: 8 * 1024 * 1024,
    shell: false
  }
);

const stdout = String(result.stdout || "");
const stderr = String(result.stderr || "");

if (stdout) process.stdout.write(stdout);
if (stderr) process.stderr.write(stderr);

if (result.error) {
  fail("command-error:" + result.error.message, 20);
}

if (result.status !== expectedExit) {
  fail(
    "exit-code:" +
    String(result.status) +
    " expected=" +
    expectedExit,
    21
  );
}

for (const marker of requiredStdout) {
  if (!stdout.includes(marker)) {
    fail("stdout-marker-missing:" + marker, 22);
  }
}

for (const artifact of requiredArtifacts) {
  const full = path.resolve(worktree, artifact);
  const root = path.resolve(worktree) + path.sep;

  if (!full.startsWith(root) || !fs.existsSync(full)) {
    fail("artifact-missing:" + artifact, 23);
  }
}

validateScope(meta);

process.stdout.write(
  "task_verification_passed|exit=" +
  expectedExit +
  "|artifacts=" +
  requiredArtifacts.join(",") +
  "\n"
);
