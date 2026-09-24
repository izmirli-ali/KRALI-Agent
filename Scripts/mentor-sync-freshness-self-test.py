#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
engine = (root / "App/KRALIAgentNative/AgentEngine.swift").read_text(encoding="utf-8")
view = (root / "App/KRALIAgentNative/ContentView.swift").read_text(encoding="utf-8")

reset_start = engine.index("private func resetTransientTaskStateForNewInput()")
reset_end = engine.index("private func problemSolverObservations()", reset_start)
reset_body = engine[reset_start:reset_end]
assert "inspectorState.mentorTraceReady = false" in reset_body, (
    "new task must invalidate the previously ready Mentor trace"
)
assert "Yeni görev için güncel Mentor kaydı bekleniyor." in reset_body, (
    "new task must expose a freshness-waiting status"
)

sync_start = engine.index("func syncMentorTrace()")
sync_end = engine.index("private func synthesisOutputMeetsGoal(", sync_start)
sync_body = engine[sync_start:sync_end]
assert "guard !busy else" in sync_body, (
    "Mentor sync must reject uploads while a task is active"
)
assert "eski Mentor kaydı gönderilmedi." in sync_body, (
    "busy rejection must explicitly state that stale trace was not uploaded"
)

button_start = view.index("engine.syncMentorTrace()")
button_end = view.index('.help("Son görevin Mentor kaydını gönder")', button_start)
button_body = view[button_start:button_end]
assert "engine.busy" in button_body, (
    "Mentor upload button must be disabled while KRALI is busy"
)

print("mentor_sync_freshness_ok")
