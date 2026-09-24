#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
router = (root / "App/KRALIAgentNative/AgentMissionRouter.swift").read_text()
engine = (root / "App/KRALIAgentNative/AgentEngine.swift").read_text()
intel = (root / "App/KRALIAgentNative/AgentLocalIntelligence.swift").read_text()

assert "case research" in router
assert "researchScore >= 2" in router
assert "failureDiagnosisScore < 2" in router

assert "executeSelfDevelopmentResearchMission" in engine
assert "performWebResearch(" in engine
assert "allowInteractiveEscalation:" in engine
assert "synthesizeSelfDevelopmentResearch" in engine
assert '"research.web"' in engine
assert '"Mutation Started' in intel
assert "repositoryEvidence" in intel
assert "researchEvidence" in intel

# Research and diagnosis must remain separate paths.
research_pos = engine.index("executeSelfDevelopmentResearchMission")
diagnosis_pos = engine.index("executeSelfDiagnosisMission")
assert research_pos < diagnosis_pos

# Diagnosis context must stay well below the previous 8192-token edge.
assert "goalCharacters: 700" in intel
assert "sourceCount: 5" in intel
assert "diagnosticCount: 1" in intel
assert "sourceExcerptCharacters: 380" in intel

print("self_development_research_policy_ok")
