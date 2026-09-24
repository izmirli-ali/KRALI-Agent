function regex(pattern) {
  let output = "^";
  const value = String(pattern || "").replaceAll("\\", "/");
  for (let i = 0; i < value.length; i += 1) {
    const c = value[i];
    if (c === "*" && value[i + 1] === "*") { output += ".*"; i += 1; }
    else if (c === "*") output += "[^/]*";
    else output += c.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }
  return new RegExp(output + "$");
}
export function isPathWithinActiveScope(file, scope) { return Array.isArray(scope) && scope.some((item) => regex(item).test(file)); }
export function canAdvanceNode({ diffVerified, semanticEvidence, buildVerified, graphFingerprint, nodeID, candidateFingerprint }) {
  return Boolean(diffVerified && buildVerified && semanticEvidence && semanticEvidence.graphFingerprint === graphFingerprint && semanticEvidence.nodeID === nodeID && semanticEvidence.candidateFingerprint === candidateFingerprint);
}
export function recoveryIdentityMatches(state, { graphFingerprint, nodeID, candidateFingerprint }) {
  return Boolean(state && state.graphFingerprint === graphFingerprint && state.nodeID === nodeID && state.candidateFingerprint === candidateFingerprint);
}
