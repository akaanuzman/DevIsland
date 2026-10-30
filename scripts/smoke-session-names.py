#!/usr/bin/env python3
"""Exercise the shipped hook bridge against isolated naming metadata; never changes ~/.claude."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

bridge = Path(sys.argv[1] if len(sys.argv) > 1 else "dist/Dev Island.app/Contents/Helpers/dev-island-bridge").resolve()
with tempfile.TemporaryDirectory(prefix="di-name-", dir="/tmp") as temporary:
    root = Path(temporary)
    config = root / "claude"
    transcript = config / "projects" / "-Projects-Shared" / "one.jsonl"
    transcript.parent.mkdir(parents=True)
    registry = config / "sessions" / "1.json"
    registry.parent.mkdir(parents=True)
    registry.write_text(json.dumps({"sessionId": "one", "name": "improve-shop-experience", "nameSource": "auto", "cwd": "/Projects/Shared"}))
    transcript.write_text(json.dumps({"type": "agent-name", "sessionId": "one", "agentName": "improve-shop-experience"}) + "\n" + json.dumps({"type": "user", "sessionId": "one", "message": "DO-NOT-COPY-CONVERSATION"}) + "\n")
    cases = []
    def send(index, expected, **fields):
        home = root / str(index)
        payload = {"session_id": "one", "hook_event_name": "SessionStart", "cwd": "/out", "transcript_path": str(transcript), **fields}
        result = subprocess.run([str(bridge), "--claude-hook"], input=json.dumps(payload).encode(), capture_output=True,
                                env={**os.environ, "DEV_ISLAND_HOME": str(home), "CLAUDE_CONFIG_DIR": str(config)}, timeout=2)
        assert result.returncode == 0 and not result.stdout and not result.stderr
        files = list((home / "queue").glob("*.json"))
        assert len(files) == 1
        text = files[0].read_text()
        event = json.loads(text)
        assert event.get("sessionName", {}).get("value") == expected, event
        assert "transcript_path" not in text and "DO-NOT-COPY-CONVERSATION" not in text
        cases.append({"case": index, "sessionName": event.get("sessionName")})
    send("hook", "explicit-title", session_title="explicit-title")
    send("registry", "improve-shop-experience")
    with transcript.open("a") as stream:
        stream.write(json.dumps({"type": "custom-title", "sessionId": "one", "customTitle": "renamed-session"}) + "\n")
    send("rename", "renamed-session")
    send("wrong-session-path", None, session_id="two")
    outside = root / "two.jsonl"
    outside.write_text(json.dumps({"type": "agent-name", "sessionId": "two", "agentName": "unsafe"}))
    send("outside-root", None, session_id="two", transcript_path=str(outside))
    print(json.dumps({"passed": True, "cases": cases, "conversationPersisted": False}, indent=2))
