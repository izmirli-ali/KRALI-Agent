export function createNodeExecutionState({ graphFingerprint, nodeID, candidateFingerprint = null } = {}) {
  return {
    version: 1,
    graphFingerprint: String(graphFingerprint || ""),
    nodeID: String(nodeID || ""),
    candidateFingerprint: candidateFingerprint || null,
    searchEvidence: [],
    readEvidence: [],
    implementationTargetPaths: [],
    createTargetPaths: [],
    verifiedMutationSourceFingerprint: "",
    semanticVerificationEvidence: null,
    buildVerificationEvidence: null,
    failedMutationFingerprints: [],
    failedDiffFingerprints: [],
    retry: { controllerTimeouts: 0, strategyEscalations: 0, implementationGrace: 0, stopReason: "" },
    activatedAt: new Date().toISOString(),
  };
}

export function nodeExecutionStateMatches(state, { graphFingerprint, nodeID, candidateFingerprint, candidateBound = false } = {}) {
  if (!state || state.version !== 1 || state.graphFingerprint !== graphFingerprint || state.nodeID !== nodeID) return false;
  return !candidateBound || Boolean(candidateFingerprint) && state.candidateFingerprint === candidateFingerprint;
}

export function compactNodeExecutionState(state) {
  return {
    ...state,
    searchEvidence: Array.isArray(state?.searchEvidence) ? state.searchEvidence.slice(-8) : [],
    readEvidence: Array.isArray(state?.readEvidence) ? state.readEvidence.slice(-8) : [],
    implementationTargetPaths: Array.isArray(state?.implementationTargetPaths) ? state.implementationTargetPaths.slice(0, 8) : [],
    createTargetPaths: Array.isArray(state?.createTargetPaths) ? state.createTargetPaths.slice(0, 8) : [],
    failedMutationFingerprints: Array.isArray(state?.failedMutationFingerprints) ? state.failedMutationFingerprints.slice(-12) : [],
    failedDiffFingerprints: Array.isArray(state?.failedDiffFingerprints) ? state.failedDiffFingerprints.slice(-12) : [],
  };
}
