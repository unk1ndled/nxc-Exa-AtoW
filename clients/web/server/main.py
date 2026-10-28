import base64
import json
import logging
import os
import secrets
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path, PurePosixPath
from urllib.parse import quote

import httpx
from dotenv import load_dotenv
from fastapi import (
    BackgroundTasks,
    Depends,
    FastAPI,
    Header,
    HTTPException,
    UploadFile,
)
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from kernel_client import execute_code as _exec
from kernel_client import restart_kernel as _restart
from session_manager import SessionManager

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(name)s  %(message)s")
logger = logging.getLogger(__name__)

MAX_SESSIONS = int(os.getenv("MAX_SESSIONS", "1"))
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin")
EXPERIMENTER_TOKENS_FILE = Path(
    os.getenv("EXPERIMENTER_TOKENS_FILE", "experimenter_tokens.json")
)

manager = SessionManager(max_sessions=MAX_SESSIONS)


# ---------------------------------------------------------------------------
# Token store
# ---------------------------------------------------------------------------
# `_tokens` maps a raw bearer token to its principal record.
# - Admin tokens are minted by /auth/login (env username/password) and live in
#   memory only; admins re-log in after a server restart.
# - Experimenter tokens are minted by an admin from /maintainer and persisted
#   to EXPERIMENTER_TOKENS_FILE so existing experimenters survive restarts.

_tokens: dict[str, dict] = {}


def _load_experimenter_tokens() -> None:
    if not EXPERIMENTER_TOKENS_FILE.exists():
        return
    try:
        data = json.loads(EXPERIMENTER_TOKENS_FILE.read_text())
    except Exception:
        logger.exception("Failed to read %s; starting empty", EXPERIMENTER_TOKENS_FILE)
        return
    for entry in data:
        _tokens[entry["token"]] = {
            "role": "experimenter",
            "id": entry["id"],
            "label": entry["label"],
            "created_at": entry["created_at"],
        }


def _save_experimenter_tokens() -> None:
    data = [
        {
            "token": t,
            "id": v["id"],
            "label": v["label"],
            "created_at": v["created_at"],
        }
        for t, v in _tokens.items()
        if v["role"] == "experimenter"
    ]
    tmp = EXPERIMENTER_TOKENS_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2))
    os.chmod(tmp, 0o600)
    tmp.replace(EXPERIMENTER_TOKENS_FILE)


_load_experimenter_tokens()


@asynccontextmanager
async def lifespan(_: FastAPI):
    logger.info(
        "Server starting — max sessions: %d, experimenter tokens loaded: %d",
        MAX_SESSIONS,
        sum(1 for v in _tokens.values() if v["role"] == "experimenter"),
    )
    yield
    logger.info("Server shutting down — stopping all containers")
    manager.stop_all()


app = FastAPI(title="Exa-AToW Notebook API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class LoginRequest(BaseModel):
    username: str
    password: str


class ExecuteRequest(BaseModel):
    code: str
    timeout: int = 60


class SessionRequest(BaseModel):
    client_id: str | None = None


class MkdirRequest(BaseModel):
    path: str


class TokenMintRequest(BaseModel):
    label: str


# ---------------------------------------------------------------------------
# Auth helpers / dependencies
# ---------------------------------------------------------------------------


def _parse_bearer(authorization: str | None) -> str | None:
    if not authorization or not authorization.startswith("Bearer "):
        return None
    return authorization[7:]


def _resolve_principal(authorization: str | None) -> dict:
    token = _parse_bearer(authorization)
    if not token or token not in _tokens:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return {**_tokens[token], "token": token}


def principal(authorization: str | None = Header(default=None)) -> dict:
    """Any authenticated principal (admin OR experimenter)."""
    return _resolve_principal(authorization)


def require_admin(authorization: str | None = Header(default=None)) -> dict:
    p = _resolve_principal(authorization)
    if p["role"] != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return p


def require_experimenter(authorization: str | None = Header(default=None)) -> dict:
    p = _resolve_principal(authorization)
    if p["role"] not in ("admin", "experimenter"):
        raise HTTPException(status_code=403, detail="Experimenter role required")
    return p


def _owned_session(session_id: str, p: dict) -> dict:
    session = manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if p["role"] != "admin" and session.get("owner_token") != p["token"]:
        # Don't leak existence of someone else's session.
        raise HTTPException(status_code=404, detail="Session not found")
    return session


def _require_ready_owned(session_id: str, p: dict) -> dict:
    session = _owned_session(session_id, p)
    if session["status"] != "ready":
        raise HTTPException(
            status_code=503,
            detail=f"Session is '{session['status']}' — wait for 'ready'.",
        )
    return session


def _safe_subpath(path: str) -> str:
    """Reject absolute paths and `..` traversal.

    Jupyter's contents API has its own checks, but we filter at the edge so a
    malformed `path` query param can never reach the upstream URL.
    """
    if path == "":
        return ""
    p = PurePosixPath(path)
    if p.is_absolute() or any(part in ("..", "") for part in p.parts):
        raise HTTPException(status_code=400, detail="Invalid path")
    if any(ord(ch) < 0x20 or ch == "\x7f" for ch in path):
        raise HTTPException(status_code=400, detail="Invalid path")
    return str(p)


# ---------------------------------------------------------------------------
# Auth endpoints
# ---------------------------------------------------------------------------


@app.post("/auth/login")
async def login(body: LoginRequest):
    """Admin login via env credentials. Issues an in-memory admin token."""
    if body.username != ADMIN_USERNAME or body.password != ADMIN_PASSWORD:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = secrets.token_urlsafe(32)
    _tokens[token] = {
        "role": "admin",
        "id": "admin",
        "label": "admin",
        "created_at": time.time(),
    }
    return {"token": token, "role": "admin"}


@app.get("/auth/verify")
async def verify(p: dict = Depends(principal)):
    """Return 200 + role/label if the bearer token is valid."""
    return {"ok": True, "role": p["role"], "label": p.get("label")}


@app.post("/auth/logout")
async def logout(authorization: str | None = Header(default=None)):
    """Revoke the bearer token (works for both admin and experimenter tokens)."""
    token = _parse_bearer(authorization)
    if token and token in _tokens:
        was_experimenter = _tokens[token]["role"] == "experimenter"
        _tokens.pop(token, None)
        if was_experimenter:
            _save_experimenter_tokens()
    return {"ok": True}


# ---------------------------------------------------------------------------
# Admin: experimenter token management
# ---------------------------------------------------------------------------


@app.post("/admin/experimenter-tokens", status_code=201)
async def mint_experimenter_token(
    body: TokenMintRequest, _: dict = Depends(require_admin)
):
    """Admin mints a new experimenter invite token. Token is shown once."""
    label = body.label.strip()[:64] or "experimenter"
    token = secrets.token_urlsafe(32)
    tid = uuid.uuid4().hex[:8]
    _tokens[token] = {
        "role": "experimenter",
        "id": tid,
        "label": label,
        "created_at": time.time(),
    }
    _save_experimenter_tokens()
    return {"id": tid, "label": label, "token": token, "created_at": _tokens[token]["created_at"]}


@app.get("/admin/experimenter-tokens")
async def list_experimenter_tokens(_: dict = Depends(require_admin)):
    """List existing experimenter tokens (without the secret)."""
    return [
        {"id": v["id"], "label": v["label"], "created_at": v["created_at"]}
        for v in _tokens.values()
        if v["role"] == "experimenter"
    ]


@app.delete("/admin/experimenter-tokens/{token_id}", status_code=204)
async def revoke_experimenter_token(token_id: str, _: dict = Depends(require_admin)):
    """Revoke an experimenter token by id. Sessions owned by it stay live until
    the user stops them or the container exits; new calls will 401."""
    targets = [
        t for t, v in _tokens.items()
        if v["role"] == "experimenter" and v["id"] == token_id
    ]
    if not targets:
        raise HTTPException(status_code=404, detail="Token not found")
    for t in targets:
        _tokens.pop(t, None)
    _save_experimenter_tokens()


@app.delete("/admin/sessions", status_code=200)
async def kill_all_sessions(_: dict = Depends(require_admin)):
    """Hard-stop every live container immediately. Admin-only emergency action."""
    count = len(manager.sessions)
    manager.stop_all()
    return {"stopped": count}


# ---------------------------------------------------------------------------
# Sessions
# ---------------------------------------------------------------------------


@app.post("/sessions", status_code=201)
async def create_session(
    body: SessionRequest,
    background_tasks: BackgroundTasks,
    p: dict = Depends(require_experimenter),
):
    """Provision (or reuse) a kernel session owned by the calling principal."""

    cid = body.client_id

    if cid:
        existing = manager.get_session_by_client(cid)
        # Only reuse the session if it actually belongs to this caller.
        if existing and existing["status"] in ("ready", "starting"):
            if p["role"] == "admin" or existing.get("owner_token") == p["token"]:
                logger.info("Reusing session %s for client %s", existing["id"], cid)
                return {
                    "id": existing["id"],
                    "status": existing["status"],
                    "reused": True,
                }
        manager.clear_client(cid)

    try:
        session = manager.create_session(client_id=cid)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))

    session["owner_token"] = p["token"]
    session["owner_id"] = p["id"]
    background_tasks.add_task(manager.wait_for_ready, session["id"])
    return {"id": session["id"], "status": "starting", "reused": False}


@app.get("/sessions")
async def list_sessions(p: dict = Depends(require_experimenter)):
    """Admins see all sessions; experimenters see only their own."""
    rows = manager.list_sessions()
    if p["role"] == "admin":
        return rows
    own = {
        sid for sid, s in manager.sessions.items()
        if s.get("owner_token") == p["token"]
    }
    return [r for r in rows if r["id"] in own]


@app.get("/sessions/{session_id}")
async def get_session(session_id: str, p: dict = Depends(require_experimenter)):
    session = _owned_session(session_id, p)
    return {
        "id": session["id"],
        "status": session["status"],
        "port": session["port"],
        "error": session.get("error"),
    }


@app.delete("/sessions/{session_id}", status_code=204)
async def delete_session(session_id: str, p: dict = Depends(require_experimenter)):
    _owned_session(session_id, p)
    manager.stop_session(session_id)


# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------


@app.post("/sessions/{session_id}/execute")
async def execute(
    session_id: str,
    req: ExecuteRequest,
    p: dict = Depends(require_experimenter),
):
    session = _require_ready_owned(session_id, p)
    try:
        outputs = await _exec(
            base_url=session["base_url"],
            token=session["token"],
            kernel_id=session["kernel_id"],
            code=req.code,
            timeout=req.timeout,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
    return {"outputs": outputs}


@app.post("/sessions/{session_id}/restart")
async def restart(session_id: str, p: dict = Depends(require_experimenter)):
    session = _require_ready_owned(session_id, p)
    try:
        await _restart(
            base_url=session["base_url"],
            token=session["token"],
            kernel_id=session["kernel_id"],
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
    return {"ok": True}


# ---------------------------------------------------------------------------
# File management
# ---------------------------------------------------------------------------


@app.post("/sessions/{session_id}/upload")
async def upload_file(
    session_id: str,
    file: UploadFile,
    path: str = "",
    p: dict = Depends(require_experimenter),
):
    session = _require_ready_owned(session_id, p)
    safe_path = _safe_subpath(path)
    raw = await file.read()
    dest = f"{safe_path}/{file.filename}".lstrip("/") if safe_path else file.filename
    # Re-validate the assembled destination so a sneaky filename can't smuggle
    # traversal segments past the earlier check.
    _safe_subpath(dest)
    payload = {
        "type": "file",
        "format": "base64",
        "content": base64.b64encode(raw).decode(),
    }
    async with httpx.AsyncClient() as client:
        resp = await client.put(
            f"{session['base_url']}/api/contents/{quote(dest, safe='/')}",
            headers={"Authorization": f"token {session['token']}"},
            json=payload,
            timeout=30.0,
        )
    if resp.status_code not in (200, 201):
        raise HTTPException(status_code=502, detail="Jupyter rejected the file upload.")
    return {"filename": file.filename, "path": dest, "size": len(raw)}


@app.get("/sessions/{session_id}/files")
async def list_files(
    session_id: str,
    path: str = "",
    p: dict = Depends(require_experimenter),
):
    session = _require_ready_owned(session_id, p)
    safe_path = _safe_subpath(path)
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{session['base_url']}/api/contents/{quote(safe_path, safe='/')}",
            headers={"Authorization": f"token {session['token']}"},
            timeout=10.0,
        )
    if resp.status_code == 404:
        raise HTTPException(status_code=404, detail="Path not found")
    resp.raise_for_status()
    data = resp.json()
    items = sorted(
        [
            {
                "name": item["name"],
                "type": item["type"],
                "path": item["path"],
                "size": item.get("size"),
            }
            for item in (data.get("content") or [])
            if item["type"] in ("file", "directory")
        ],
        key=lambda x: (x["type"] != "directory", x["name"].lower()),
    )
    return {"path": safe_path, "items": items}


@app.post("/sessions/{session_id}/mkdir", status_code=201)
async def make_dir(
    session_id: str,
    body: MkdirRequest,
    p: dict = Depends(require_experimenter),
):
    session = _require_ready_owned(session_id, p)
    safe_path = _safe_subpath(body.path)
    if not safe_path:
        raise HTTPException(status_code=400, detail="Path required")
    async with httpx.AsyncClient() as client:
        resp = await client.put(
            f"{session['base_url']}/api/contents/{quote(safe_path, safe='/')}",
            headers={"Authorization": f"token {session['token']}"},
            json={"type": "directory"},
            timeout=10.0,
        )
    if resp.status_code not in (200, 201):
        raise HTTPException(status_code=502, detail="Failed to create directory.")
    return {"path": safe_path}


@app.delete("/sessions/{session_id}/files", status_code=204)
async def delete_path(
    session_id: str,
    path: str,
    p: dict = Depends(require_experimenter),
):
    session = _require_ready_owned(session_id, p)
    safe_path = _safe_subpath(path)
    if not safe_path:
        raise HTTPException(status_code=400, detail="Path required")
    async with httpx.AsyncClient() as client:
        resp = await client.delete(
            f"{session['base_url']}/api/contents/{quote(safe_path, safe='/')}",
            headers={"Authorization": f"token {session['token']}"},
            timeout=10.0,
        )
    if resp.status_code not in (200, 204):
        raise HTTPException(status_code=502, detail="Failed to delete path.")
