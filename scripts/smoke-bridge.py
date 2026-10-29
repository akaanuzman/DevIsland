#!/usr/bin/env python3
"""Exercise the shipped executable and real socket/spool, without touching ~/.claude."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor

root = Path(__file__).resolve().parent.parent
bridge = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "dist/Dev Island.app/Contents/Helpers/dev-island-bridge"
with tempfile.TemporaryDirectory(prefix="di-", dir="/tmp") as directory:
    home = Path(directory)
    env = {**os.environ, "DEV_ISLAND_HOME": directory}
    payload = {
        "session_id": "smoke-session", "cwd": "/Projects/Smoke", "hook_event_name": "PreToolUse",
        "tool_name": "AskUserQuestion", "tool_use_id": "question-1",
        "prompt": "SECRET_PROMPT", "tool_input": {"questions": [{"question": "SECRET_QUESTION"}]},
    }
    started = time.monotonic()
    result = subprocess.run([str(bridge), "--claude-hook"], input=json.dumps(payload).encode(), env=env, capture_output=True, timeout=2)
    offline_ms = (time.monotonic() - started) * 1000
    assert result.returncode == 0 and not result.stdout and not result.stderr
    files = list((home / "queue").glob("*.json"))
    assert len(files) == 1
    persisted = files[0].read_text()
    assert "SECRET_QUESTION" not in persisted and "SECRET_PROMPT" not in persisted
    assert json.loads(persisted)["kind"] == "question"
    assert files[0].stat().st_mode & 0o777 == 0o600
    receiver = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    receiver.bind(str(home / "events.sock"))
    receiver.settimeout(2)
    def send_session(i):
        message = {**payload, "session_id": f"parallel-{i}"}
        started = time.monotonic()
        result = subprocess.run([str(bridge), "--claude-hook"], input=json.dumps(message).encode(), env=env, capture_output=True, timeout=2)
        assert result.returncode == 0 and not result.stdout and not result.stderr
        return (time.monotonic() - started) * 1000
    started = time.monotonic()
    with ThreadPoolExecutor(max_workers=10) as pool:
        durations = list(pool.map(send_session, range(10)))
    received = set()
    for _ in range(10):
        event = json.loads(receiver.recv(32768))
        assert event["preview"] == "SECRET_QUESTION"
        received.add(event["sessionID"])
    assert received == {f"parallel-{i}" for i in range(10)}
    concurrent_wall_ms = (time.monotonic() - started) * 1000
    live_mean_ms = sum(durations) / 10
    receiver.close()
    for malformed in [b"not json", b"{}", b"[1,2,3]", b"x" * (2 * 1024 * 1024 + 1)]:
        result = subprocess.run([str(bridge), "--claude-hook"], input=malformed, env=env, capture_output=True, timeout=2)
        assert result.returncode == 0 and not result.stdout and not result.stderr
    print(json.dumps({"passed": True, "offline_bridge_ms": round(offline_ms, 2), "live_bridge_mean_ms": round(live_mean_ms, 2),
                      "concurrent_wall_ms": round(concurrent_wall_ms, 2), "concurrent_processes": 10, "sessions": 10,
                      "checks": ["app-absent fail-open", "real Unix socket", "metadata-only disk queue", "0600 files", "malformed input", "bounded large input", "silent exit 0"]}, indent=2))
