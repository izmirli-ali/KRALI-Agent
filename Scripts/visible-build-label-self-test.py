#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
update = (root / "App/KRALIAgentNative/UpdateController.swift").read_text()
view = (root / "App/KRALIAgentNative/ContentView.swift").read_text()

assert 'forInfoDictionaryKey: "CFBundleVersion"' in update
assert '@Published var currentBuild: String' in update
assert 'build \\(updater.currentBuild)' in view
assert view.count('build \\(updater.currentBuild)') >= 2

print("visible_build_label_ok")
