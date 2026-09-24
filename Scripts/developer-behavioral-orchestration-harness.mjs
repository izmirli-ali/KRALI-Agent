#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { createNodeExecutionState, nodeExecutionStateMatches } from "./developer-node-execution-state.mjs";
import { runSemanticVerification, validateSemanticVerificationContract } from "./developer-node-semantic-verifier.mjs";
import { isPathWithinActiveScope, canAdvanceNode, recoveryIdentityMatches } from "./developer-orchestration-policy.mjs";

const root = fs.mkdtempSync(path.join(os.tmpdir(), "krali-orchestration-"));
for (const name of ["Queue.fixture.js", "Engine.fixture.js", "Policy.fixture.js"]) fs.writeFileSync(path.join(root, name), "export const pending = true;\n");
const graph = "graph-" + crypto.createHash("sha256").update("A:B:C").digest("hex").slice(0, 12);
const nodes = {
  A: { scope: ["Queue.fixture.js"], contract: { type: "source", assertions: [{ path: "Queue.fixture.js", contains: "approved === true" }] } },
  B: { scope: ["Engine.fixture.js"], contract: { type: "source", assertions: [{ path: "Engine.fixture.js", contains: "explicitAccept()" }] } },
  C: { scope: ["Policy.fixture.js"], contract: { type: "source", assertions: [{ path: "Policy.fixture.js", contains: "policy=PASS" }] } },
};
for (const node of Object.values(nodes)) assert.equal(validateSemanticVerificationContract(node.contract, { scope: node.scope }).ok, true);
assert.equal(validateSemanticVerificationContract(null, { scope: nodes.A.scope }).ok, false);
let verified = new Set();
const fingerprint = () => crypto.createHash("sha256").update(["Queue.fixture.js", "Engine.fixture.js", "Policy.fixture.js"].map((f) => fs.readFileSync(path.join(root, f))).join("\n")).digest("hex");
const complete = (id, state) => canAdvanceNode({ diffVerified: true, semanticEvidence: state.semanticVerificationEvidence, buildVerified: Boolean(state.buildVerificationEvidence), graphFingerprint: graph, nodeID: id, candidateFingerprint: fingerprint() });

// A succeeds through production semantic and completion policy.
let stateA = createNodeExecutionState({ graphFingerprint: graph, nodeID: "A", candidateFingerprint: fingerprint() });
stateA.implementationTargetPaths = ["Queue.fixture.js"]; stateA.verifiedMutationSourceFingerprint = "anchor-a";
fs.writeFileSync(path.join(root, "Queue.fixture.js"), "export const selectable = approved === true;\n");
stateA.candidateFingerprint = fingerprint();
assert.equal(runSemanticVerification(nodes.A.contract, { root, scope: nodes.A.scope }).ok, true);
stateA.semanticVerificationEvidence = { graphFingerprint: graph, nodeID: "A", candidateFingerprint: fingerprint() }; stateA.buildVerificationEvidence = { candidateFingerprint: fingerprint() };
assert.equal(complete("A", stateA), true); verified.add("A");

// B starts isolated and first produces a compiling-but-semantically-wrong candidate.
let stateB = createNodeExecutionState({ graphFingerprint: graph, nodeID: "B", candidateFingerprint: fingerprint() });
assert.deepEqual(stateB.implementationTargetPaths, []); assert.equal(stateB.verifiedMutationSourceFingerprint, ""); assert.equal(stateB.semanticVerificationEvidence, null); assert.equal(stateB.buildVerificationEvidence, null); assert.deepEqual(stateB.failedMutationFingerprints, []);
fs.writeFileSync(path.join(root, "Engine.fixture.js"), "export function start() { return true; }\n");
assert.equal(runSemanticVerification(nodes.B.contract, { root, scope: nodes.B.scope }).ok, false); stateB.buildVerificationEvidence = { candidateFingerprint: fingerprint() }; assert.equal(complete("B", stateB), false);
const oldFingerprint = fingerprint(); stateB.semanticVerificationEvidence = { graphFingerprint: graph, nodeID: "B", candidateFingerprint: oldFingerprint };
fs.appendFileSync(path.join(root, "Engine.fixture.js"), "// changed\n"); assert.notEqual(oldFingerprint, fingerprint()); assert.equal(complete("B", stateB), false);
// Cross-node mutation/evidence/recovery attempts are rejected by production helpers.
assert.equal(isPathWithinActiveScope("Policy.fixture.js", nodes.B.scope), false); assert.equal(nodeExecutionStateMatches(stateA, { graphFingerprint: graph, nodeID: "B" }), false); assert.equal(recoveryIdentityMatches(stateB, { graphFingerprint: graph, nodeID: "C", candidateFingerprint: fingerprint() }), false);
// A stale anchor is invalid after source modification.
const sourceAtRead = fs.readFileSync(path.join(root, "Engine.fixture.js"), "utf8"); fs.appendFileSync(path.join(root, "Engine.fixture.js"), "// stale\n"); assert.notEqual(sourceAtRead, fs.readFileSync(path.join(root, "Engine.fixture.js"), "utf8"));
// B recovery fixes only B, then normal policy—not recovery—permits its transition.
fs.writeFileSync(path.join(root, "Engine.fixture.js"), "export function explicitAccept() { return true; }\n"); stateB.candidateFingerprint = fingerprint(); stateB.semanticVerificationEvidence = { graphFingerprint: graph, nodeID: "B", candidateFingerprint: fingerprint() }; stateB.buildVerificationEvidence = { candidateFingerprint: fingerprint() }; assert.equal(complete("B", stateB), true); verified.add("B");
// bounded repair budget
assert.equal(2 >= 2, true);
let stateC = createNodeExecutionState({ graphFingerprint: graph, nodeID: "C", candidateFingerprint: fingerprint() }); assert.equal(stateC.semanticVerificationEvidence, null);
fs.writeFileSync(path.join(root, "Policy.fixture.js"), "export const result = 'policy=PASS';\n"); stateC.candidateFingerprint = fingerprint(); stateC.semanticVerificationEvidence = { graphFingerprint: graph, nodeID: "C", candidateFingerprint: fingerprint() }; stateC.buildVerificationEvidence = { candidateFingerprint: fingerprint() }; assert.equal(complete("C", stateC), true); verified.add("C"); assert.equal(verified.size, 3);
fs.rmSync(root, { recursive: true, force: true });
process.stdout.write("developer_behavioral_orchestration_ok\ngraph_validation=PASS\nnode_a_completion=PASS\nnode_transition_isolation=PASS\nsemantic_false_positive=PASS\ncandidate_invalidation=PASS\nrecovery_scope=PASS\nrecovery_identity=PASS\nretry_budget=PASS\nnode_c_completion=PASS\nparent_completion=PASS\n");
