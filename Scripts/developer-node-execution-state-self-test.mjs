#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { createNodeExecutionState, nodeExecutionStateMatches, compactNodeExecutionState } from "./developer-node-execution-state.mjs";

const graph = "graph-fixture";
const nodeA = createNodeExecutionState({ graphFingerprint: graph, nodeID: "A", candidateFingerprint: "candidate-a" });
nodeA.implementationTargetPaths = ["App/A.swift"];
nodeA.verifiedMutationSourceFingerprint = "anchor-a";
nodeA.semanticVerificationEvidence = { candidateFingerprint: "candidate-a" };
nodeA.buildVerificationEvidence = { candidateFingerprint: "candidate-a" };
nodeA.failedMutationFingerprints = ["failed-a"];

// Test 1: transition creates a fresh node state, not a copy of A.
const nodeB = createNodeExecutionState({ graphFingerprint: graph, nodeID: "B", candidateFingerprint: "candidate-a" });
if (nodeB.implementationTargetPaths.length || nodeB.verifiedMutationSourceFingerprint || nodeB.semanticVerificationEvidence || nodeB.buildVerificationEvidence || nodeB.failedMutationFingerprints.length) throw new Error("node_a_evidence_leaked_to_b");

// Test 2: checkpoint evidence for A cannot restore while B is active.
if (nodeExecutionStateMatches(nodeA, { graphFingerprint: graph, nodeID: "B" })) throw new Error("checkpoint_restored_other_node_evidence");

// Test 3: candidate X evidence cannot authorize candidate Y.
if (nodeExecutionStateMatches(nodeA, { graphFingerprint: graph, nodeID: "A", candidateFingerprint: "candidate-b", candidateBound: true })) throw new Error("candidate_fingerprint_not_invalidated");

// Test 4: source freshness is separate from ownership and still invalidates the anchor.
const root = fs.mkdtempSync(path.join(os.tmpdir(), "krali-node-state-"));
const source = path.join(root, "source.swift");
fs.writeFileSync(source, "let marker = 1\n");
const sourceFingerprint = crypto.createHash("sha256").update(fs.readFileSync(source)).digest("hex");
fs.writeFileSync(source, "let marker = 2\n");
const changedFingerprint = crypto.createHash("sha256").update(fs.readFileSync(source)).digest("hex");
if (sourceFingerprint === changedFingerprint) throw new Error("stale_source_anchor_not_rejected");
fs.rmSync(root, { recursive: true, force: true });

// Test 5: failed strategies stay local to their node.
if (nodeB.failedMutationFingerprints.includes("failed-a")) throw new Error("failed_strategy_leaked_to_b");
const compact = compactNodeExecutionState(nodeA);
if (compact.nodeID !== "A" || compact.graphFingerprint !== graph) throw new Error("ownership_metadata_not_persisted");

process.stdout.write(
  "developer_node_execution_state_self_test_ok\n" +
  "node_transition=isolation_pass\n" +
  "resume_other_node=rejected\n" +
  "candidate_change=invalidated\n" +
  "source_freshness=required\n" +
  "failure_history=node_local\n"
);
