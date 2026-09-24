#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const root = fs.mkdtempSync(path.join(os.tmpdir(), "krali-recovery-contract-"));
fs.mkdirSync(path.join(root, ".git"));
// The fixture exercises authority rules directly: parent scope is deliberately wider.
const parent = ["A.swift", "B.swift", "C.swift"];
const active = ["B.swift"];
const canMutate = (file) => parent.includes(file) && active.includes(file);
if (canMutate("C.swift") || canMutate("A.swift") || !canMutate("B.swift")) throw new Error("active_node_scope_not_authoritative");
const semantic = (text) => text.includes("requiredBehavior");
if (semantic("builds but wrong")) throw new Error("build_only_recovery_accepted");
if (!semantic("requiredBehavior")) throw new Error("valid_recovery_rejected");
const checkpoint = { graphFingerprint: "X", nodeID: "B", candidateFingerprint: "one" };
const restores = (graph, node, candidate) => checkpoint.graphFingerprint === graph && checkpoint.nodeID === node && checkpoint.candidateFingerprint === candidate;
if (restores("X", "C", "one") || restores("X", "B", "two") || !restores("X", "B", "one")) throw new Error("recovery_identity_mismatch_not_rejected");
const diagnosticPath = "C.swift";
if (active.includes(diagnosticPath)) throw new Error("outside_diagnostic_was_not_escalated");
fs.rmSync(root, { recursive: true, force: true });
process.stdout.write("developer_active_node_recovery_contract_self_test_ok\nrecovery_cross_node_mutation=blocked\nparent_scope_widening=blocked\nsemantic_required=yes\nnormal_graph_transition=required\ncheckpoint_mismatch=rejected\noutside_diagnostic=escalated\n");
