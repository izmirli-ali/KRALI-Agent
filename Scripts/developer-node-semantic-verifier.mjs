import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

function normalize(value) {
  return String(value || "").trim().replaceAll("\\", "/").replace(/^\.\//, "");
}

function glob(pattern) {
  let output = "^";
  const value = normalize(pattern);
  for (let i = 0; i < value.length; i += 1) {
    const ch = value[i];
    if (ch === "*" && value[i + 1] === "*") { output += ".*"; i += 1; }
    else if (ch === "*") output += "[^/]*";
    else if (ch === "?") output += "[^/]";
    else output += ch.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }
  return new RegExp(output + "$");
}

function withinScope(file, scope) {
  return Array.isArray(scope) && scope.some((item) => glob(item).test(file));
}

function commandParts(command) {
  if (typeof command !== "string" || !command.trim() || /[|;&<>`$()]/.test(command)) return null;
  const parts = command.trim().split(/\s+/);
  if (parts.length !== 2 || parts[0] !== "node") return null;
  const script = normalize(parts[1]);
  if (!script || path.isAbsolute(script) || script.split("/").includes("..") || !/\.m?js$/.test(script)) return null;
  return { executable: parts[0], script };
}

export function validateSemanticVerificationContract(contract, { scope = [] } = {}) {
  if (!contract || typeof contract !== "object" || Array.isArray(contract)) return { ok: false, reason: "missing-contract" };
  if (contract.type === "command") {
    const parsed = commandParts(contract.command);
    if (!parsed || !withinScope(parsed.script, scope)) return { ok: false, reason: "command-outside-active-scope" };
    if (contract.expectedOutput != null && (typeof contract.expectedOutput !== "string" || !contract.expectedOutput.trim())) return { ok: false, reason: "expected-output-invalid" };
    return { ok: true, normalized: { type: "command", command: "node " + parsed.script, expectedOutput: String(contract.expectedOutput || "") } };
  }
  if (contract.type === "source") {
    if (!Array.isArray(contract.assertions) || contract.assertions.length === 0) return { ok: false, reason: "source-assertions-missing" };
    const assertions = [];
    for (const raw of contract.assertions) {
      const file = normalize(raw?.path);
      const contains = raw?.contains;
      const notContains = raw?.notContains;
      if (!file || path.isAbsolute(file) || file.split("/").includes("..") || !withinScope(file, scope) || (typeof contains !== "string" && typeof notContains !== "string") || (typeof contains === "string" && typeof notContains === "string") || (!(contains || notContains))) return { ok: false, reason: "source-assertion-invalid" };
      assertions.push(typeof contains === "string" ? { path: file, contains } : { path: file, notContains });
    }
    return { ok: true, normalized: { type: "source", assertions } };
  }
  return { ok: false, reason: "verification-type-invalid" };
}

export function runSemanticVerification(contract, { root, scope = [] } = {}) {
  const validated = validateSemanticVerificationContract(contract, { scope });
  if (!validated.ok) return { ok: false, reason: validated.reason };
  const normalized = validated.normalized;
  if (normalized.type === "source") {
    for (const assertion of normalized.assertions) {
      const full = path.resolve(root, assertion.path);
      const prefix = path.resolve(root) + path.sep;
      if (!full.startsWith(prefix) || !fs.existsSync(full) || !fs.statSync(full).isFile()) return { ok: false, reason: "source-file-unavailable:" + assertion.path };
      const content = fs.readFileSync(full, "utf8");
      if (assertion.contains != null && !content.includes(assertion.contains)) return { ok: false, reason: "source-text-missing:" + assertion.path };
      if (assertion.notContains != null && content.includes(assertion.notContains)) return { ok: false, reason: "source-text-forbidden:" + assertion.path };
    }
    return { ok: true, type: "source" };
  }
  const parsed = commandParts(normalized.command);
  const result = spawnSync(process.execPath, [parsed.script], { cwd: root, encoding: "utf8", timeout: 120000, maxBuffer: 4 * 1024 * 1024, shell: false });
  const output = String(result.stdout || "") + String(result.stderr || "");
  if (result.error || result.status !== 0) return { ok: false, reason: "command-failed", output: output.slice(-4000) };
  if (normalized.expectedOutput && !output.includes(normalized.expectedOutput)) return { ok: false, reason: "expected-output-missing", output: output.slice(-4000) };
  return { ok: true, type: "command", output: output.slice(-4000) };
}
