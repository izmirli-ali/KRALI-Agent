#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { runSemanticVerification, validateSemanticVerificationContract } from "./developer-node-semantic-verifier.mjs";

const root = fs.mkdtempSync(path.join(os.tmpdir(), "krali-semantic-node-"));
const source = path.join(root, "App");
fs.mkdirSync(source, { recursive: true });
const file = path.join(source, "approval.js");
const scope = ["App/approval.js"];
const contract = {
  type: "source",
  assertions: [{ path: "App/approval.js", contains: "userApproved === true" }],
};

function buildPasses() {
  return spawnSync(process.execPath, ["--check", file], { encoding: "utf8" }).status === 0;
}

function mayAdvance({ semantic, build }) {
  return semantic.ok === true && build === true;
}

// A real, valid JavaScript mutation and diff that omits the required approval behavior.
fs.writeFileSync(file, "export function nextQueued(job) { return job.state === 'queued'; }\n");
const wrongSemantic = runSemanticVerification(contract, { root, scope });
if (!buildPasses() || wrongSemantic.ok || mayAdvance({ semantic: wrongSemantic, build: true })) {
  throw new Error("semantic_false_positive_was_not_rejected");
}

// Corrected candidate proves its postcondition, then becomes eligible to advance.
fs.writeFileSync(file, "export function nextQueued(job) { return job.state === 'queued' && job.userApproved === true; }\n");
const correctSemantic = runSemanticVerification(contract, { root, scope });
if (!buildPasses() || !correctSemantic.ok || !mayAdvance({ semantic: correctSemantic, build: true })) {
  throw new Error("semantic_verified_candidate_did_not_advance");
}

if (validateSemanticVerificationContract(null, { scope }).ok) throw new Error("missing_contract_accepted");
if (validateSemanticVerificationContract({ type: "source", assertions: [{ path: "Outside.js", contains: "x" }] }, { scope }).ok) throw new Error("outside_scope_accepted");

const fingerprintA = "candidate-a";
const fingerprintB = "candidate-b";
const evidence = { nodeID: "approval", candidateFingerprint: fingerprintA };
if (evidence.candidateFingerprint === fingerprintB) throw new Error("stale_semantic_evidence_reused");

fs.rmSync(root, { recursive: true, force: true });
process.stdout.write(
  "developer_semantic_node_verification_self_test_ok\n" +
  "semantic_false_positive=blocked\n" +
  "candidate_fingerprint_stale=invalidated\n" +
  "active_scope=required\n"
);
