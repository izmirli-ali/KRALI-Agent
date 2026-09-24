#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
script = (root / "Scripts/publish-mentor-trace.command").read_text(encoding="utf-8")

expected = 'git -C "$ROOT" fetch origin "${SYNC_BRANCH}:refs/remotes/origin/${SYNC_BRANCH}"'
unsafe = 'git -C "$ROOT" fetch origin "$SYNC_BRANCH:refs/remotes/origin/$SYNC_BRANCH"'

assert expected in script, (
    "Mentor diagnostics fetch refspec must brace SYNC_BRANCH before ':' for zsh"
)
assert unsafe not in script, (
    "unbraced zsh refspec can be parsed as a parameter modifier and corrupt the remote ref"
)

print("mentor_sync_refspec_ok")
