#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
view = (root / "App/KRALIAgentNative/ContentView.swift").read_text()

assert '.id("chat-bottom-anchor")' in view
assert '.onAppear {' in view
assert 'proxy.scrollTo(' in view
assert '"chat-bottom-anchor",' in view
assert 'engine' in view and '.selectedConversationArchiveID' in view

count = view.count('"chat-bottom-anchor"')
assert count >= 4, f"expected repeated bottom-anchor use, got {count}"

print("chat_initial_scroll_bottom_ok")
