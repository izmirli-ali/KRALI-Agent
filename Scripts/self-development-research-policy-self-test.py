#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
router = (root / "App/KRALIAgentNative/AgentMissionRouter.swift").read_text()
engine = (root / "App/KRALIAgentNative/AgentEngine.swift").read_text()
intel = (root / "App/KRALIAgentNative/AgentLocalIntelligence.swift").read_text()
quality = (root / "App/KRALIAgentNative/AgentDevelopmentResearch.swift").read_text()
web_research = (root / "App/KRALIAgentNative/AgentWebResearch.swift").read_text()

assert "case research" in router
assert "researchScore >= 2" in router
assert "failureDiagnosisScore < 2" in router

assert "executeSelfDevelopmentResearchMission" in engine
assert "performWebResearch(" in engine
assert "allowInteractiveEscalation:" in engine
assert "synthesizeSelfDevelopmentResearch" in engine
assert '"research.web"' in engine
assert "Mutation Started: " in quality
assert "repositoryEvidence" in intel
assert "evidenceRecords" in intel
assert "case openReview" in web_research
assert "https://api2.openreview.net/notes/search" in web_research
assert "parseOpenReview" in web_research
assert 'domain: "openreview.net"' in web_research
assert "AgentDevelopmentResearchEvidenceAudit" in quality
assert "freshnessScore" in quality
assert "citationCount" in quality
assert "potentialContradictionCount" in quality
assert "complete impact map" in quality
assert "behavioralBenchmark.isEmpty" in quality
assert "AgentDevelopmentResearchQualityBenchmark" in quality
assert "AgentDevelopmentResearchImpactMap" in quality

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

reader = (root / "App/KRALIAgentNative/AgentWebSourceReader.swift").read_text()
quality = (root / "App/KRALIAgentNative/AgentDevelopmentResearch.swift").read_text()

assert "allowSnippetFallback: Bool = true" in reader
assert "allowSnippetEvidence:" in engine
assert "allowSnippetEvidence:" in engine and "false" in engine
assert "developmentPlan(text)" in engine
assert "AgentDevelopmentResearchVerifier" in quality
assert "qualifiesForTechnicalCoverage" in quality
assert "mutationStarted" in quality
assert "evidenceIDs" in quality
assert "repositoryEvidenceIDs" in quality
assert "DevelopmentResearchGeneratedApproach.self" in intel
assert "DevelopmentResearchGeneratedSelection.self" in intel
assert "developmentResearchSynthesisFailureReason" in intel
assert "synthesisFailure=" in engine
assert "Staged Evidence-Bound Development Research" in engine
print("development_research_quality_policy_ok")
print("staged_research_synthesis_policy_ok")
