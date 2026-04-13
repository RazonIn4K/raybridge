#!/usr/bin/env python3
"""Small helper for calling a streamable HTTP MCP server like RayBridge.

Examples:
  python3 call_raybridge.py list
  python3 call_raybridge.py call --mcp-tool my-extension --raycast-tool my-tool --input-json '{"query":"hello"}'
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_URL = "http://127.0.0.1:3000/mcp"
PROTOCOL_VERSION = "2024-11-05"


def parse_event_stream(text: str) -> List[Dict[str, Any]]:
    events: List[Dict[str, Any]] = []
    current: List[str] = []
    for raw_line in text.splitlines():
        line = raw_line.rstrip("\r")
        if not line:
            if current:
                payload = "\n".join(current).strip()
                current = []
                if payload:
                    try:
                        events.append(json.loads(payload))
                    except json.JSONDecodeError:
                        pass
            continue
        if line.startswith(":"):
            continue
        if line.startswith("data:"):
            current.append(line[5:].lstrip())
    if current:
        payload = "\n".join(current).strip()
        if payload:
            try:
                events.append(json.loads(payload))
            except json.JSONDecodeError:
                pass
    return events


def post_json(
    url: str,
    payload: Dict[str, Any],
    api_key: Optional[str] = None,
    session_id: Optional[str] = None,
) -> Tuple[Dict[str, Any], Optional[str]]:
    data = json.dumps(payload).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    if session_id:
        headers["mcp-session-id"] = session_id

    request = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request) as response:
            body = response.read().decode("utf-8")
            content_type = response.headers.get("Content-Type", "")
            returned_session_id = response.headers.get("mcp-session-id") or session_id
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {detail}") from exc

    parsed: Dict[str, Any]
    if "text/event-stream" in content_type:
        events = parse_event_stream(body)
        if not events:
            raise RuntimeError(f"Could not parse SSE response: {body}")
        parsed = events[-1]
    else:
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"Invalid JSON response: {body}") from exc

    return parsed, returned_session_id


def delete_session(url: str, api_key: Optional[str], session_id: Optional[str]) -> None:
    if not session_id:
        return
    headers = {}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    headers["mcp-session-id"] = session_id
    request = urllib.request.Request(url, headers=headers, method="DELETE")
    try:
        with urllib.request.urlopen(request):
            return
    except Exception:
        return


def initialize(url: str, api_key: Optional[str]) -> str:
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {},
            "clientInfo": {"name": "raybridge-helper", "version": "1.0.0"},
        },
    }
    response, session_id = post_json(url, payload, api_key=api_key)
    if "error" in response:
        raise RuntimeError(f"Initialize failed: {json.dumps(response, indent=2)}")
    if not session_id:
        raise RuntimeError("Initialize succeeded but no mcp-session-id header was returned.")
    return session_id


def list_tools(url: str, api_key: Optional[str], session_id: str) -> Dict[str, Any]:
    payload = {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
    response, _ = post_json(url, payload, api_key=api_key, session_id=session_id)
    return response


def call_tool(
    url: str,
    api_key: Optional[str],
    session_id: str,
    mcp_tool: str,
    raycast_tool: str,
    input_json: Dict[str, Any],
) -> Dict[str, Any]:
    payload = {
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {
            "name": mcp_tool,
            "arguments": {
                "tool_name": raycast_tool,
                "input": input_json,
            },
        },
    }
    response, _ = post_json(url, payload, api_key=api_key, session_id=session_id)
    return response


def main() -> int:
    parser = argparse.ArgumentParser(description="Call a RayBridge MCP server over HTTP.")
    parser.add_argument("--url", default=DEFAULT_URL, help=f"MCP endpoint (default: {DEFAULT_URL})")
    parser.add_argument("--api-key", default=None, help="Bearer token if MCP_API_KEY is enabled")

    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="List available MCP tools")

    call = sub.add_parser("call", help="Call a specific RayBridge tool")
    call.add_argument("--mcp-tool", required=True, help="The MCP tool name exposed by RayBridge (usually an extension name)")
    call.add_argument("--raycast-tool", required=True, help="The tool_name inside that Raycast extension")
    call.add_argument(
        "--input-json",
        default="{}",
        help='JSON object passed as the tool input, for example: {"query":"hello"}',
    )

    args = parser.parse_args()

    try:
        session_id = initialize(args.url, args.api_key)
        if args.command == "list":
            result = list_tools(args.url, args.api_key, session_id)
        else:
            try:
                input_obj = json.loads(args.input_json)
            except json.JSONDecodeError as exc:
                raise RuntimeError(f"Invalid --input-json: {exc}") from exc
            if not isinstance(input_obj, dict):
                raise RuntimeError("--input-json must decode to a JSON object")
            result = call_tool(
                args.url,
                args.api_key,
                session_id,
                args.mcp_tool,
                args.raycast_tool,
                input_obj,
            )
        print(json.dumps(result, indent=2))
        return 0
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    finally:
        try:
            delete_session(args.url, args.api_key, locals().get("session_id"))
        except Exception:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
