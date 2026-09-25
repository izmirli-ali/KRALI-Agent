#!/bin/zsh
set -euo pipefail

ROOT="${KRALI_REPO_ROOT:-$PWD}"
cd "$ROOT"

python3 Scripts/self-development-research-policy-self-test.py

TMP_BIN="$(mktemp /tmp/krali-research-quality.XXXXXX)"
trap '/bin/rm -f "$TMP_BIN"' EXIT

xcrun swiftc   App/KRALIAgentNative/AgentExecutionProfile.swift   App/KRALIAgentNative/AgentResearchQueryPlanner.swift   App/KRALIAgentNative/AgentWebResearch.swift   App/KRALIAgentNative/AgentDevelopmentResearch.swift   Scripts/development-research-quality-self-test.swift   -o "$TMP_BIN"

"$TMP_BIN"

echo "research_development_verifier_ok"
