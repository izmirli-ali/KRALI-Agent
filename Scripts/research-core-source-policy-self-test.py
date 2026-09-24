#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
normalizer = (root / "App/KRALIAgentNative/AgentMissionNormalizer.swift").read_text()
local_intel = (root / "App/KRALIAgentNative/AgentLocalIntelligence.swift").read_text()
engine = (root / "App/KRALIAgentNative/AgentEngine.swift").read_text()

assert 'else if knownIDs.contains("research.web")' in normalizer
assert 'capabilityID: "research.web"' in normalizer
assert 'researchStepIndex == nil' in normalizer

assert 'if knownIDs.contains("browser.control")' in local_intel
assert 'else if knownIDs.contains("research.web")' in local_intel

assert 'researchCoreGoalProfile' in engine
assert 'executionProfile.allowsComputerControl' in engine
assert 'profile: executionProfile' in engine

print("research_core_source_policy_ok")
