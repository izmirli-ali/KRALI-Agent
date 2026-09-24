#!/usr/bin/env node
import fs from "node:fs";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";

function arg(name) { const i = process.argv.indexOf(name); return i < 0 ? "" : String(process.argv[i + 1] || ""); }
function fail(reason) { process.stderr.write("recovery_contract_failed|" + reason + "\n"); process.exit(1); }
const planFile = arg("--plan");
const checkpointFile = arg("--checkpoint");
const worktree = arg("--worktree");
if (!planFile || !checkpointFile || !worktree || !fs.existsSync(planFile) || !fs.existsSync(checkpointFile)) fail("recovery_active_node_unproven");
let plan, checkpoint;
try { plan = JSON.parse(fs.readFileSync(planFile, "utf8")); checkpoint = JSON.parse(fs.readFileSync(checkpointFile, "utf8")); } catch { fail("recovery_context_unreadable"); }
const nodes = plan?.review?.subtasks;
const graph = checkpoint?.developerTaskGraph;
const activeID = String(graph?.activeID || "");
const node = Array.isArray(nodes) ? nodes.find((item) => String(item?.id || "") === activeID) : null;
if (!graph?.fingerprint || !activeID || !node || !Array.isArray(node.scope) || node.scope.length === 0) fail("recovery_active_node_unproven");
const diff = spawnSync("git", ["-C", worktree, "diff", "--binary", "--no-ext-diff"], { encoding: "utf8" });
const fingerprint = diff.status === 0 && String(diff.stdout || "").trim() ? crypto.createHash("sha256").update(diff.stdout).digest("hex") : null;
if (checkpoint.candidateIdentity !== fingerprint) fail("recovery_candidate_identity_mismatch");
const nodeState = checkpoint.nodeExecutionState;
if (!nodeState || nodeState.graphFingerprint !== graph.fingerprint || nodeState.nodeID !== activeID || nodeState.candidateFingerprint !== fingerprint) fail("recovery_node_evidence_mismatch");
process.stdout.write(JSON.stringify({ graphFingerprint: graph.fingerprint, activeNodeID: activeID, scope: node.scope, candidateFingerprint: fingerprint }) + "\n");
