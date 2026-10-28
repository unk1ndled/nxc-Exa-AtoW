# exa-atow-demo-webapp
React + Vite frontend for Exa-AToW. Includes a marketing site and an interactive notebook sandbox (`/notebook`) that runs remote Python kernels via the Exa-AToW server.
### Environment
* **`VITE_API_URL`**: URL of the Exa-AToW backend (defaults to `http://localhost:9000`, the port `just web-dev` serves the server on).
### Quick Start
Requires **Bun** (recommended) or Node.js.
```bash
# From the repository root (runs both server and webapp):
just web-install
just web-dev
# Or, from the webapp directory:
bun install
bun run dev      # Starts Vite dev server
bun run build    # Builds production assets to dist/
bun run preview  # Previews production build
bun run lint     # Runs ESLint
```
### Core Architecture
* **`src/App.jsx`**: Layout composition and routing.
* **`src/pages/NotebookPage.jsx`**: Implements the notebook UI (markdown + code cells). Uses `@uiw/react-codemirror`. Manages remote session state (create, poll, execute, restart, stop).
### Session Lifecycle
The notebook maintains a stable client identity across page navigations using `localStorage`:
* A UUID is generated once under the key `atow_client_id` and sent as `client_id` on every `POST /sessions` call.
* On mount, the server checks whether a live session is already bound to that `client_id`. If so, it returns `{ reused: true, status: "ready" }` and the frontend skips the polling phase entirely — the kernel is immediately available.
* If the server returns `reused: false`, or the session is still booting, the client polls `GET /sessions/:id` every 2 seconds until the status reaches `ready` or `error`.
* Navigating away from `/notebook` does **not** terminate the session. The container keeps running and will be reused on the next visit.
* Clicking **stop session** calls `DELETE /sessions/:id` and rotates the `atow_client_id` in `localStorage`, so the next visit provisions a genuinely fresh kernel.
### API Contract
The notebook sandbox requires the following REST endpoints on the backend (`VITE_API_URL`):
* `POST /sessions` — Accepts `{ "client_id": "<uuid>" }`. Returns `{ "id": "...", "status": "starting|ready", "reused": true|false }`. When `reused: true` and `status: "ready"`, no polling is needed.
* `GET /sessions/:id` — Returns session status (`starting`, `ready`, `error`).
* `DELETE /sessions/:id` — Terminates the session and releases the `client_id` binding server-side.
* `POST /sessions/:id/execute` — Accepts `{ "code": "string" }`. Returns `{ "outputs": [...] }` (outputs expect `text` and optional `type`/`name` fields) or an error payload.
* `POST /sessions/:id/restart` — Restarts the kernel.
