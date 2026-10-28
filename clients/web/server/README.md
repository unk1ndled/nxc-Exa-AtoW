# exa-atow-demo-server
A FastAPI service that provisions ephemeral Jupyter Docker containers and executes Python code via the Jupyter Kernel Messaging Protocol (KMP) over WebSockets.
### Prerequisites
* **Python 3.11+**
* **Docker** (User running the server requires Docker daemon permissions)
### Quick Start
From the repository root: `just web-install` once, then `just web-dev` (see
[`../README.md`](../README.md)). It serves this API on port 9000; 8000 and
8001 are taken by the tunnelled ebuffer and ebservice APIs.
### Architecture & Core Modules
For contributors extending the backend, the logic is strictly divided into three components:
* **`main.py`**: FastAPI application, REST routing, and dependency injection.
* **`session_manager.py`**: Interfaces with the `docker` Python SDK.
* Spawns `quay.io/jupyter/base-notebook:latest` containers with a randomized `JUPYTER_TOKEN` and maps container port `8888` to a random host port.
* Handles the `wait_for_ready` async background task, which polls the container's `/api/kernels` endpoint to create a kernel and record the `kernel_id`.
* Enforces the `MAX_SESSIONS` limit (defaults to `1`, returns HTTP 503 if exceeded).
* Maintains an internal `_client_map` (`client_id → session_id`) for session reuse. Stale bindings are purged automatically when a session is stopped.
* **`kernel_client.py`**: Implements the execution subset of the Jupyter KMP.
* Opens an async WebSocket connection to `ws://host:port/api/kernels/{kernel_id}/channels?token=...`.
* Transmits `execute_request` payloads and aggregates `stream` (stdout/stderr), `execute_result`, and `error` messages until an `execute_reply` is received.
### API Contract
* **`POST /sessions`**
* **Payload (optional):** `{ "client_id": "<uuid>" }`
* **Action:** If `client_id` maps to a live session (`starting` or `ready`), returns it immediately — no container is spawned. Otherwise starts a new Docker container, schedules readiness polling, and binds it to the provided `client_id` for future calls.
* **Response (201):** `{ "id": "<session_id>", "status": "starting|ready", "reused": true|false }`
* When `reused: true` and `status: "ready"`, the client can skip polling entirely.
* **`GET /sessions`**
* **Response (200):** `[{ "id": "...", "status": "...", "port": int, "error": null }]`
* **`GET /sessions/{session_id}`**
* **Response (200):** `{ "id": "...", "status": "<starting|ready|error|stopped>", "port": int, "error": str | null }`
* **`POST /sessions/{session_id}/execute`**
* **Payload:** `{ "code": "print('hello')", "timeout": 60 }`
* **Action:** Blocks until KMP execution completes or times out.
* **Response (200):** `{ "outputs": [ { "type": "stream", "text": "hello\n" } ] }` (Types: `stream`, `result`, `error`).
* **`POST /sessions/{session_id}/restart`**
* **Response (200):** `{ "ok": true }`
* **`DELETE /sessions/{session_id}`**
* **Action:** Stops and forcefully removes the Docker container. Also removes the `client_id` binding so the next `POST /sessions` with the same `client_id` provisions a fresh kernel.
* **Response (204):** No Content.
### Security Note (To be secured)
This service currently executes unauthenticated, arbitrary Python code inside local containers. It lacks API authentication or rate-limiting. **Do not deploy this service to a public network** without placing it behind an authenticated API gateway and adjusting Docker resource limits.
