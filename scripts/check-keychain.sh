#!/usr/bin/env bash
set -euo pipefail

if [[ "${RAYBRIDGE_SKIP_KEYCHAIN_PREFLIGHT:-0}" == "1" ]]; then
  exit 0
fi

python3 - <<'PY'
import os
import subprocess
import sys

cmd = [
    "security",
    "find-generic-password",
    "-s",
    "Raycast",
    "-a",
    "database_key",
    "-w",
]
raw_timeout = os.getenv("RAYBRIDGE_KEYCHAIN_TIMEOUT_SECONDS", "60")
try:
    timeout_seconds = float(raw_timeout)
except ValueError:
    print(
        "Invalid RAYBRIDGE_KEYCHAIN_TIMEOUT_SECONDS value; falling back to 60 seconds.",
        file=sys.stderr,
    )
    timeout_seconds = 60
timeout = None if timeout_seconds <= 0 else timeout_seconds

try:
    subprocess.run(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=timeout,
        check=True,
    )
except subprocess.TimeoutExpired:
    print(
        "RayBridge is waiting on macOS Keychain access to Raycast. "
        "Approve the prompt for your terminal app and re-run. "
        "You can increase wait time with RAYBRIDGE_KEYCHAIN_TIMEOUT_SECONDS.",
        file=sys.stderr,
    )
    sys.exit(1)
except FileNotFoundError:
    print("The macOS security CLI is unavailable on this system.", file=sys.stderr)
    sys.exit(1)
except subprocess.CalledProcessError:
    print(
        "Could not read Raycast's database_key from macOS Keychain. "
        "Open Raycast once, approve the Keychain prompt, then re-run.",
        file=sys.stderr,
    )
    sys.exit(1)
PY
