"""
Thin async client for the Jupyter Kernel Messaging Protocol (v5).
Connects over WebSocket, sends an execute_request, and collects outputs
until the matching execute_reply arrives.
"""

import asyncio
import json
import re
import uuid

import httpx
import websockets

_ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*[mGKHF]")


def _strip_ansi(text: str) -> str:
    return _ANSI_ESCAPE.sub("", text)


async def execute_code(
    base_url: str,
    token: str,
    kernel_id: str,
    code: str,
    timeout: int = 60,
) -> list[dict]:
    ws_url = base_url.replace("http://", "ws://").replace("https://", "wss://")
    uri = f"{ws_url}/api/kernels/{kernel_id}/channels?token={token}"

    msg_id = uuid.uuid4().hex
    session_id = uuid.uuid4().hex

    execute_request = {
        "header": {
            "msg_id": msg_id,
            "msg_type": "execute_request",
            "session": session_id,
            "username": "exa-atow",
            "version": "5.3",
            "date": "",
        },
        "parent_header": {},
        "metadata": {},
        "content": {
            "code": code,
            "silent": False,
            "store_history": True,
            "user_expressions": {},
            "allow_stdin": False,
            "stop_on_error": True,
        },
        "buffers": [],
        "channel": "shell",
    }

    outputs: list[dict] = []

    async def _collect(ws) -> list[dict]:
        collected: list[dict] = []
        async for raw in ws:
            msg = json.loads(raw)
            # Only process replies to *our* request
            # The WebSocket connection is shared if two cells are executed close together, replies from both can arrive on the same connection .
            if msg.get("parent_header", {}).get("msg_id") != msg_id:
                continue

            msg_type: str = msg.get("msg_type", "")
            content: dict = msg.get("content", {})

            if msg_type == "stream":
                collected.append(
                    {
                        "type": "stream",
                        "name": content.get("name", "stdout"),
                        "text": content.get("text", ""),
                    }
                )
            elif msg_type == "execute_result":
                collected.append(
                    {
                        "type": "result",
                        "text": content.get("data", {}).get("text/plain", ""),
                    }
                )
            elif msg_type == "display_data":
                collected.append(
                    {
                        "type": "result",
                        "text": content.get("data", {}).get(
                            "text/plain", "[display data]"
                        ),
                    }
                )
            elif msg_type == "error":
                tb = "\n".join(content.get("traceback", []))
                collected.append({"type": "error", "text": _strip_ansi(tb)})
            elif msg_type == "execute_reply":
                break  # done

        return collected

    async with websockets.connect(uri, ping_interval=20) as ws:
        await ws.send(json.dumps(execute_request))
        try:
            outputs = await asyncio.wait_for(_collect(ws), timeout=timeout)
        except asyncio.TimeoutError:
            outputs = [
                {"type": "error", "text": f"Execution timed out after {timeout}s."}
            ]

    return outputs


async def restart_kernel(base_url: str, token: str, kernel_id: str) -> None:
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{base_url}/api/kernels/{kernel_id}/restart",
            headers={"Authorization": f"token {token}"},
            timeout=15.0,
        )
        resp.raise_for_status()
