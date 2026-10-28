import { useState, useCallback, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import CodeMirror from "@uiw/react-codemirror";
import { python } from "@codemirror/lang-python";
import { json } from "@codemirror/lang-json";
import Nav from "../components/Nav";
import Footer from "../components/Footer";
import { API_URL, authFetch } from "../notebook/api";
import { editorTheme } from "../notebook/editorTheme";
import CellOutput from "../notebook/CellOutput";
import MarkdownRenderer from "../notebook/MarkdownRenderer";
import SessionBar from "../notebook/SessionBar";
import FileExplorer from "../notebook/FileExplorer";
import { useNotebookSession } from "../hooks/useNotebookSession";
import { useAuth } from "../hooks/useAuth";
import ExperimenterTokens from "../components/ExperimenterTokens";
import KillAllSessions from "../components/KillAllSessions";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const DEFAULT_CONFIG = {
  ebuffUrl: "http://host.docker.internal:8000/api/v1",
  appmsUrl: "http://host.docker.internal:8001/api/v1",
  username: "admin",
  password: "admin",
  hpcConfig: "../../.vault/.secret_idris.ini",
};

function buildPreamble(cfg) {
  return `# -- injected by maintainer notebook --
EBUFF_BASE_URL = ${JSON.stringify(cfg.ebuffUrl)}
APPMS_BASE_URL = ${JSON.stringify(cfg.appmsUrl)}
_maintainer_username = ${JSON.stringify(cfg.username)}
_maintainer_password = ${JSON.stringify(cfg.password)}
CONFIG_HPC = ${JSON.stringify(cfg.hpcConfig)}
# --------------------------------------
`;
}

// ---------------------------------------------------------------------------
// Cell factory helpers
// ---------------------------------------------------------------------------

let _cellSeq = 0;
function _id() {
  return ++_cellSeq + "-" + Math.random().toString(36).slice(2);
}

function py(content, label = "") {
  return { id: _id(), kind: "python", label, content, state: "idle", outputs: [] };
}

function note(content) {
  return { id: _id(), kind: "note", content, state: "idle", outputs: [] };
}

function req(method = "GET", path = "/health", body = "") {
  return { id: _id(), kind: "request", method, path, body, state: "idle", output: null };
}

// ---------------------------------------------------------------------------
// Pre-built cell content — full maintainer workflow
// ---------------------------------------------------------------------------

function buildInitialCells() {
  return [
    note(
      "## Maintainer Notebook\n\nFull ebclient / ebservice workflow. Cells run against a live Jupyter kernel. The config panel (top-right) injects connection variables into every execution.\n\n### Flow\n\ninstall deps → imports → init API → declare microservice → create runtime → implement job class → run RuntimeService",
    ),

    note(
      "### Install dependencies\n\nRun this cell once to install `ebsclient` and `ebstemplate` into the active kernel environment.",
    ),

    py(
      `import subprocess, sys

packages = [
    "ebsclient",
    "ebstemplate",
]

for pkg in packages:
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", pkg],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        print(f"✓ {pkg} installed")
    else:
        print(f"✗ {pkg} FAILED\\n{result.stderr}")

print("dependency install complete")`,
      "install-deps",
    ),

    py(
      `import logging
from pathlib import Path
from time import sleep

from ebsclient import EbClientAPI, RuntimeService
from ebstemplate.scheduler import JobSchedulerTemplate

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)-5s] %(message)s",
)
print("imports OK")`,
      "imports",
    ),

    note(
      "### Init API client\n\nUses injected `EBUFF_BASE_URL`, `APPMS_BASE_URL`, credentials from the config panel.",
    ),

    py(
      `# Connectivity check — run this before initialising the API client.
# If either URL is unreachable the cell will tell you exactly which one
# and why, so you can fix the config panel before proceeding.
import socket
from urllib.parse import urlparse

def _check(label, url):
    p = urlparse(url)
    host = p.hostname
    port = p.port or (443 if p.scheme == "https" else 80)
    try:
        sock = socket.create_connection((host, port), timeout=3)
        sock.close()
        print(f"✓ {label} reachable  →  {url}")
        return True
    except OSError as exc:
        print(f"✗ {label} UNREACHABLE →  {url}")
        print(f"  {exc}")
        print(f"  → Is the service running? Check the config panel (top-right).")
        return False

ok_appms  = _check("appms   (APPMS_BASE_URL) ", APPMS_BASE_URL)
ok_ebuff  = _check("ebuffer (EBUFF_BASE_URL) ", EBUFF_BASE_URL)

if not (ok_appms and ok_ebuff):
    raise SystemExit("Fix the unreachable endpoint(s) above before running the next cell.")`,
      "connectivity-check",
    ),

    py(
      `api = EbClientAPI(
    username=_maintainer_username,
    password=_maintainer_password,
    ebservice_url=APPMS_BASE_URL,
    ebuffer_url=EBUFF_BASE_URL,
)
print(f"API client ready")
print(f"  ebuffer  : {EBUFF_BASE_URL}")
print(f"  appms    : {APPMS_BASE_URL}")`,
      "init-api",
    ),

    note(
      "### Declare microservice\n\nDeveloper side: declare the app interface — MIME type, argument and result names, ebin/ebout file lists.",
    ),

    py(
      `openqcd_ym1_data = {
    "name": "openqcd-ym1",
    "mime_type": "application/x-openqcd-ym1",
    "code": "",
    "argument_names": ["seed", "nth", "nstep"],
    "result_names": [],
    "ebin_names": ["ym1.in"],
    # Files ym1 writes for a run named "openqcd_ym1L8T16" (must match the
    # name= in OpenQCDJob._generate_ym1_in). This is the order download_data()
    # pulls them back on the user side.
    "ebout_names": [
        "openqcd_ym1L8T16.log",     # human-readable run log
        "openqcd_ym1L8T16.dat",     # per-trajectory observables (binary)
        "openqcd_ym1L8T16.ms.dat",  # Wilson-flow measurements (binary)
        "openqcd_ym1L8T16.par",     # parameter record (binary)
        "openqcd_ym1L8T16.rng",     # RNG state (for -a continuation)
        "openqcd_ym1L8T16n1",       # exported gauge config #1
        "openqcd_ym1L8T16n2",       # exported gauge config #2
    ],
    "runtime_uuid": "",
    "policy_uid": "",
    "tags": ["template::slurm"],
}

mservice = api.mservices.create(openqcd_ym1_data)
print(f"microservice created: {mservice}")`,
      "declare-service",
    ),

    note(
      "### Create runtime\n\nMaintainer side: bind an HPC target to the MIME type. One runtime per HPC center (idris / cines / tgcc / eskem).",
    ),

    py(
      `runtime = api.runtimes.create({
    "name": "openqcd-ym1-idris",
    "accepted_mime_type": "application/x-openqcd-ym1",
    "policy_uid": "",
    "tags": ["template::slurm"],
})
print(f"runtime created: {runtime}")`,
      "create-runtime",
    ),

    note(
      "### Implement job class\n\nSubclass `JobSchedulerTemplate`. Override `get_scheduler_core()` with the actual HPC command. Optionally override `preprocess()` to generate input files before submission.\n\n⚠️ **Rank count is compile-baked.** Our `ym1` is built with `NPROC=2`, so the runtime `.ini` must set `[RESOURCES] tasks = 2` (the profile then emits `--ntasks=2`). Any other value makes `ym1` abort in `check_machine()` → `STARTUP_ERROR`. To change it, rebuild openQCD with a new `global.h` and update `tasks` in lockstep.",
    ),

    py(
      `class OpenQCDJob(JobSchedulerTemplate):
    def get_scheduler_core(self) -> str:
        # Our nxc/slurm deployment puts ym1 on PATH (openqcdBins wrapper),
        # so we call it bare. runner is srun (.ini [SCHEDULER]) and launches
        # exactly --ntasks ranks. ym1's NPROC is compile-baked to 2, so the
        # runtime .ini MUST set [RESOURCES] tasks = 2, else ym1 aborts in
        # check_machine() -> STARTUP_ERROR.
        return f"{self.hpc_config.runner} ym1 -i {self.job_dir}/ym1.in"

    def _generate_ym1_in(self, input_file, output_file, variables, name="openqcd_ym1L8T16"):
        seds = [
            f"s|^name[[:space:]].*|name         {name}|",
            f"s|^log_dir[[:space:]].*|log_dir      {variables['workdir']}|",
            f"s|^dat_dir[[:space:]].*|dat_dir      {variables['workdir']}|",
            f"s|^init_dir[[:space:]].*|init_dir     {variables['workdir']}|",
            f"s|^cnfg_dir[[:space:]].*|cnfg_dir     {variables['workdir']}|",
            f"s|^local_dir[[:space:]].*|local_dir    {variables['workdir']}|",
        ]
        for key in ("seed", "nth", "nstep"):
            if variables.get(key) is not None:
                seds.append(f"s|^{key}[[:space:]].*|{key:<12}{variables[key]}|")

        sed_args = " ".join(f'-e "{e}"' for e in seds)
        cmd = f"sed {sed_args} {input_file} > {output_file}"
        return self.remote.run(cmd, timeout=self.hpc_config.timeout)

    def preprocess(self) -> bool:
        variables = {
            "workdir": self.job_dir,
            "seed":    self.job.arguments[0],
            "nth":     self.job.arguments[1],
            "nstep":   self.job.arguments[2],
        }
        source      = Path(self.app_dir) / "ym1.am"
        destination = Path(self.job_dir) / "ym1.in"
        self._generate_ym1_in(source, destination, variables)
        return False  # no custom scheduler header needed

print("OpenQCDJob defined")`,
      "job-class",
    ),

    note(
      "### Run RuntimeService\n\nStarts the polling loop. The service picks up pending jobs of the matching MIME type and dispatches them to the HPC via the job class above.\n\n**Interrupt the kernel to stop.** The `finally` block deletes runtime and service cleanly.",
    ),

    py(
      `rt_service = RuntimeService(
    runtime=runtime,
    RuntimeJobType=OpenQCDJob,
    hpc_config=CONFIG_HPC,
)

try:
    rt_service.start()
    print("RuntimeService started — polling for jobs…")
    while True:
        sleep(1)
except KeyboardInterrupt:
    print("\\nCtrl+C — shutting down…")
finally:
    rt_service.stop()
    for job in mservice.list_jobs():
        job.delete()
    runtime.delete()
    mservice.delete()
    print("Cleaned up.")`,
      "run-service",
    ),

    note(
      "### Introspection helpers\n\nList existing runtimes, microservices, and jobs without running the full loop.",
    ),

    py(
      `# List all runtimes
print("=== runtimes ===")
for rt in api.runtimes.list():
    print(f"  {rt}")

# List all microservices
print("\\n=== microservices ===")
for ms in api.mservices.list():
    print(f"  {ms}")

# List all jobs (across all services)
print("\\n=== jobs ===")
for ms in api.mservices.list():
    for job in ms.list_jobs():
        print(f"  [{ms.name}] {job}")`,
      "introspect",
    ),
  ];
}

// ---------------------------------------------------------------------------
// Note cell
// ---------------------------------------------------------------------------

function NoteCell({ cell, index, isActive, onActivate, onDelete }) {
  return (
    <div
      className={`group relative border rounded-sm transition-colors ${
        isActive ? "border-accent2" : "border-rule hover:border-muted"
      }`}
      onClick={onActivate}
    >
      <div className="flex items-center justify-between px-3 py-1.5 border-b border-rule bg-paper-alt">
        <div className="flex items-center gap-2">
          <span className="text-[10px] text-muted tracking-widest uppercase">
            note
          </span>
          <span className="text-[10px] text-muted opacity-40">[ {index} ]</span>
        </div>
        <button
          onClick={(e) => {
            e.stopPropagation();
            onDelete(cell.id);
          }}
          className="text-[10px] text-muted hover:text-accent1 transition-colors px-1 opacity-0 group-hover:opacity-100"
        >
          ✕
        </button>
      </div>
      <div className="px-4 py-3">
        <MarkdownRenderer content={cell.content} />
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Python cell
// ---------------------------------------------------------------------------

function PythonCell({ cell, index, isActive, onActivate, onChange, onRun, onDelete }) {
  return (
    <div
      className={`group relative border rounded-sm transition-colors ${
        isActive ? "border-accent1" : "border-rule hover:border-muted"
      }`}
      onClick={onActivate}
    >
      <div className="flex items-center justify-between px-3 py-1.5 border-b border-rule bg-paper-alt">
        <div className="flex items-center gap-2">
          <span className="text-[10px] text-muted tracking-widest uppercase">
            python
          </span>
          <span className="text-[10px] text-muted opacity-40">[ {index} ]</span>
          {cell.label && (
            <span className="text-[10px] text-accent2 opacity-70 tracking-wider">
              · {cell.label}
            </span>
          )}
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={(e) => {
              e.stopPropagation();
              onDelete(cell.id);
            }}
            className="text-[10px] text-muted hover:text-accent1 transition-colors px-1 opacity-0 group-hover:opacity-100"
          >
            ✕
          </button>
          <button
            onClick={(e) => {
              e.stopPropagation();
              onRun(cell.id);
            }}
            disabled={cell.state === "running"}
            className="flex items-center gap-1.5 text-[10px] tracking-wider text-muted hover:text-accent1 disabled:opacity-40 disabled:cursor-not-allowed transition-colors px-2 py-0.5 rounded-sm border border-transparent hover:border-accent1"
          >
            {cell.state === "running" ? (
              <span className="animate-pulse">◌ running</span>
            ) : (
              <>
                <span>▶</span> run
              </>
            )}
          </button>
        </div>
      </div>
      <div className="px-4 py-3">
        <CodeMirror
          value={cell.content}
          extensions={[python(), editorTheme]}
          onChange={(val) => onChange(cell.id, val)}
          basicSetup={{
            lineNumbers: false,
            foldGutter: false,
            highlightActiveLine: false,
            highlightActiveLineGutter: false,
            indentOnInput: true,
            tabSize: 4,
          }}
        />
      </div>
      <CellOutput outputs={cell.outputs} state={cell.state} />
    </div>
  );
}

// ---------------------------------------------------------------------------
// Request (HTTP) cell
// ---------------------------------------------------------------------------

const METHOD_COLOR = {
  GET: "text-accent2",
  POST: "text-green-400",
  DELETE: "text-accent1",
  PUT: "text-amber-400",
  PATCH: "text-amber-400",
};

function RequestCell({ cell, index, isActive, onActivate, onRun, onDelete, ebuffUrl, appmsUrl }) {
  const [method, setMethod] = useState(cell.method ?? "GET");
  const [path, setPath] = useState(cell.path ?? "/health");
  const [body, setBody] = useState(cell.body ?? "");
  const [baseTarget, setBaseTarget] = useState("ebuffer");

  const baseUrl = baseTarget === "ebuffer" ? ebuffUrl : appmsUrl;

  useEffect(() => {
    cell.method = method;
    cell.path = path;
    cell.body = body;
    cell.baseUrl = baseUrl;
  }, [method, path, body, baseUrl]);

  return (
    <div
      className={`group relative border rounded-sm transition-colors ${
        isActive ? "border-accent1" : "border-rule hover:border-muted"
      }`}
      onClick={onActivate}
    >
      <div className="flex items-center justify-between px-3 py-1.5 border-b border-rule bg-paper-alt">
        <div className="flex items-center gap-2">
          <span className="text-[10px] text-muted tracking-widest uppercase">
            request
          </span>
          <span className="text-[10px] text-muted opacity-40">[ {index} ]</span>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={(e) => {
              e.stopPropagation();
              onDelete(cell.id);
            }}
            className="text-[10px] text-muted hover:text-accent1 transition-colors px-1 opacity-0 group-hover:opacity-100"
          >
            ✕
          </button>
          <button
            onClick={(e) => {
              e.stopPropagation();
              onRun(cell.id, { method, path, body, baseUrl });
            }}
            disabled={cell.state === "running"}
            className="flex items-center gap-1.5 text-[10px] tracking-wider text-muted hover:text-accent1 disabled:opacity-40 disabled:cursor-not-allowed transition-colors px-2 py-0.5 rounded-sm border border-transparent hover:border-accent1"
          >
            {cell.state === "running" ? (
              <span className="animate-pulse">◌ running</span>
            ) : (
              <>
                <span>▶</span> send
              </>
            )}
          </button>
        </div>
      </div>

      {/* URL row */}
      <div className="flex items-center gap-2 px-4 py-2 border-b border-rule">
        <div className="flex rounded-sm border border-rule overflow-hidden text-[10px] tracking-wider">
          {["ebuffer", "appms"].map((t) => (
            <button
              key={t}
              onClick={(e) => {
                e.stopPropagation();
                setBaseTarget(t);
              }}
              className={`px-2 py-1 transition-colors ${
                baseTarget === t ? "bg-paper text-accent2" : "text-muted hover:text-ink"
              }`}
            >
              {t}
            </button>
          ))}
        </div>
        <select
          value={method}
          onChange={(e) => setMethod(e.target.value)}
          onClick={(e) => e.stopPropagation()}
          className={`bg-transparent border border-rule rounded-sm text-[11px] px-2 py-1 font-mono tracking-wider focus:outline-none focus:border-accent1 cursor-pointer ${
            METHOD_COLOR[method] ?? "text-muted"
          }`}
        >
          {["GET", "POST", "PUT", "PATCH", "DELETE"].map((m) => (
            <option key={m} value={m} className="bg-paper text-ink">
              {m}
            </option>
          ))}
        </select>
        <input
          value={path}
          onChange={(e) => setPath(e.target.value)}
          onClick={(e) => e.stopPropagation()}
          onKeyDown={(e) => {
            if (e.key === "Enter") onRun(cell.id, { method, path, body, baseUrl });
          }}
          className="flex-1 bg-transparent border border-rule rounded-sm text-[12px] px-3 py-1 font-mono text-ink focus:outline-none focus:border-accent1 placeholder:text-muted"
          placeholder="/runtimes"
          spellCheck={false}
        />
        <span className="text-[10px] text-muted opacity-40 font-mono truncate max-w-[160px]">
          {baseUrl}
        </span>
      </div>

      {/* Body */}
      {["POST", "PUT", "PATCH"].includes(method) && (
        <div className="px-4 py-3 border-b border-rule">
          <span className="block text-[10px] text-muted tracking-widest uppercase mb-2">
            body · json
          </span>
          <CodeMirror
            value={body}
            extensions={[json(), editorTheme]}
            onChange={(val) => setBody(val)}
            basicSetup={{
              lineNumbers: false,
              foldGutter: false,
              highlightActiveLine: false,
              highlightActiveLineGutter: false,
              indentOnInput: true,
              tabSize: 2,
            }}
          />
        </div>
      )}

      <CellOutput output={cell.output} state={cell.state} />
    </div>
  );
}

// ---------------------------------------------------------------------------
// Config panel
// ---------------------------------------------------------------------------

function ConfigPanel({ config, onChange, onClose }) {
  const [local, setLocal] = useState({ ...config });

  const field = (key, label, placeholder) => (
    <div key={key}>
      <label className="block text-[10px] text-muted tracking-widest uppercase mb-1">
        {label}
      </label>
      <input
        value={local[key]}
        onChange={(e) => setLocal((p) => ({ ...p, [key]: e.target.value }))}
        className="w-full bg-paper border border-rule rounded-sm text-[12px] px-3 py-1.5 font-mono text-ink focus:outline-none focus:border-accent1 placeholder:text-muted"
        placeholder={placeholder}
        spellCheck={false}
        type={key === "password" ? "password" : "text"}
      />
    </div>
  );

  return (
    <div className="border border-rule rounded-sm bg-paper-alt">
      <div className="flex items-center justify-between px-3 py-1.5 border-b border-rule">
        <span className="text-[10px] text-muted tracking-widest uppercase">
          config · injected as python vars
        </span>
        <button
          onClick={onClose}
          className="text-[10px] text-muted hover:text-accent1 transition-colors"
        >
          ✕
        </button>
      </div>
      <div className="px-4 py-3 space-y-3">
        {field("ebuffUrl", "ebuffer url", "http://localhost:8000/api/v1")}
        {field("appmsUrl", "appms url", "http://localhost:8001/api/v1")}
        {field("username", "username", "maintainer")}
        {field("password", "password", "••••")}
        {field("hpcConfig", "hpc config path", "../../.vault/.secret_idris.ini")}
        <div className="pt-1 flex justify-end">
          <button
            onClick={() => {
              onChange(local);
              onClose();
            }}
            className="text-[11px] tracking-wider px-3 py-1 bg-accent1 text-paper rounded-sm hover:bg-accent2 transition-colors"
          >
            apply
          </button>
        </div>
        <p className="text-[10px] text-muted opacity-60 leading-relaxed">
          These values are prepended as Python variables before every kernel
          execution. The kernel session is shared with the user notebook unless
          you stop it.
        </p>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

export default function MaintainerPage() {
  const [config, setConfig] = useState(DEFAULT_CONFIG);
  const [showConfig, setShowConfig] = useState(false);
  const [cells, setCells] = useState(() => buildInitialCells());
  const [activeCell, setActiveCell] = useState(null);
  const [showExplorer, setShowExplorer] = useState(false);

  const { logout } = useAuth();
  const navigate = useNavigate();

  const {
    sessionId,
    sessionIdRef,
    sessionStatus,
    sessionError,
    startSession,
    stopSession,
  } = useNotebookSession("atow_maintainer_client_id");

  const handleLogout = async () => {
    await stopSession();
    await logout();
    navigate("/login", { replace: true });
  };

  // -- Cell mutations -------------------------------------------------------

  const updateCell = useCallback((id, patch) => {
    setCells((prev) => prev.map((c) => (c.id === id ? { ...c, ...patch } : c)));
  }, []);

  const deleteCell = useCallback((id) => {
    setCells((prev) => prev.filter((c) => c.id !== id));
  }, []);

  const handlePyChange = useCallback((id, value) => {
    setCells((prev) =>
      prev.map((c) => (c.id === id ? { ...c, content: value } : c)),
    );
  }, []);

  // -- Run python cell ------------------------------------------------------

  const runPyCell = useCallback(
    async (id) => {
      if (sessionStatus !== "ready") return;
      const cell = cells.find((c) => c.id === id);
      if (!cell || cell.kind !== "python") return;

      updateCell(id, { state: "running", outputs: [] });

      const code = buildPreamble(config) + "\n" + cell.content;

      try {
        const res = await authFetch(
          `${API_URL}/sessions/${sessionIdRef.current}/execute`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ code }),
          },
        );
        const data = await res.json();
        const outputs = res.ok
          ? data.outputs
          : [{ type: "error", text: data.detail }];
        updateCell(id, {
          state: outputs.some((o) => o.type === "error") ? "error" : "ok",
          outputs,
        });
      } catch (e) {
        updateCell(id, {
          state: "error",
          outputs: [{ type: "error", text: e.message }],
        });
      }
    },
    [cells, sessionStatus, config, updateCell, sessionIdRef],
  );

  // -- Run request cell -----------------------------------------------------

  const runReqCell = useCallback(
    async (id, { method, path, body, baseUrl }) => {
      updateCell(id, { state: "running", output: null });
      try {
        const opts = { method, headers: { "Content-Type": "application/json" } };
        if (body?.trim() && ["POST", "PUT", "PATCH"].includes(method)) {
          try {
            opts.body = JSON.stringify(JSON.parse(body));
          } catch {
            opts.body = body;
          }
        }
        const r = await fetch(`${baseUrl}${path}`, opts);
        const text = await r.text();
        let data;
        try {
          data = JSON.parse(text);
        } catch {
          data = { _raw: text };
        }
        updateCell(id, {
          state: r.ok ? "ok" : "error",
          output: `HTTP ${r.status}\n\n${JSON.stringify(data, null, 2)}`,
        });
      } catch (e) {
        updateCell(id, { state: "error", output: e.message });
      }
    },
    [updateCell],
  );

  // -- Run all --------------------------------------------------------------

  const runAll = useCallback(async () => {
    for (const cell of cells) {
      if (cell.kind === "python") await runPyCell(cell.id);
      else if (cell.kind === "request") {
        await runReqCell(cell.id, {
          method: cell.method,
          path: cell.path,
          body: cell.body,
          baseUrl: cell.baseUrl ?? config.ebuffUrl,
        });
      }
    }
  }, [cells, runPyCell, runReqCell, config]);

  const clearAll = useCallback(() => {
    setCells((prev) =>
      prev.map((c) => ({ ...c, state: "idle", outputs: [], output: null })),
    );
  }, []);

  // -- Add cells ------------------------------------------------------------

  const addPy = useCallback(() => setCells((p) => [...p, py("", "")]), []);
  const addReq = useCallback(() => setCells((p) => [...p, req()]), []);
  const addNote = useCallback(
    () => setCells((p) => [...p, note("### New note\n\n")]),
    [],
  );

  // -------------------------------------------------------------------------

  return (
    <div className="bg-paper text-ink text-sm antialiased min-h-screen font-mono">
      <Nav />
      <main className="max-w-content mx-auto px-8 py-16">
        {/* Header */}
        <div className="flex items-start justify-between mb-6 border-b border-rule pb-6">
          <div>
            <p className="text-[10px] tracking-widest uppercase text-muted mb-1">
              notebook · maintainer
            </p>
            <h1 className="text-xl font-semibold tracking-tight">
              maintainer.atow
            </h1>
            <p className="text-[11px] text-muted mt-1 opacity-60">
              ebclient · ebservice · runtime · microservice
            </p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={() => setShowConfig((v) => !v)}
              className={`text-[11px] tracking-wider px-3 py-1 border rounded-sm transition-colors ${
                showConfig
                  ? "border-accent2 text-accent2"
                  : "border-rule text-muted hover:border-accent2 hover:text-accent2"
              }`}
            >
              config
            </button>
            <button
              onClick={clearAll}
              className="text-[11px] tracking-wider px-3 py-1 border border-rule rounded-sm hover:bg-paper-alt transition-colors text-muted hover:text-ink"
            >
              clear
            </button>
            <button
              onClick={runAll}
              disabled={sessionStatus !== "ready"}
              className="text-[11px] tracking-wider px-3 py-1 bg-accent1 text-paper rounded-sm hover:bg-accent2 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              run all
            </button>
            <button
              onClick={() => setShowExplorer((v) => !v)}
              className={`text-[11px] tracking-wider px-3 py-1 border rounded-sm transition-colors ${
                showExplorer
                  ? "border-accent2 text-accent2"
                  : "border-rule text-muted hover:border-muted hover:text-ink"
              }`}
            >
              files
            </button>
            <button
              onClick={handleLogout}
              className="text-[11px] tracking-wider px-3 py-1 border border-rule rounded-sm hover:border-accent1 hover:text-accent1 transition-colors text-muted"
            >
              sign out
            </button>
          </div>
        </div>

        {/* Config panel */}
        {showConfig && (
          <div className="mb-6">
            <ConfigPanel
              config={config}
              onChange={setConfig}
              onClose={() => setShowConfig(false)}
            />
          </div>
        )}

        {/* Emergency: kill all containers */}
        <div className="mb-4">
          <KillAllSessions onKilled={stopSession} />
        </div>

        {/* Experimenter token mgmt */}
        <div className="mb-6">
          <ExperimenterTokens />
        </div>

        {/* Session bar */}
        <div className="mb-6">
          <SessionBar
            status={sessionStatus}
            error={sessionError}
            sessionId={sessionId}
            onStop={stopSession}
            onStart={startSession}
          />
        </div>

        {/* Preamble preview */}
        <details className="mb-6 border border-rule rounded-sm group">
          <summary className="flex items-center justify-between px-3 py-1.5 bg-paper-alt cursor-pointer text-[10px] text-muted tracking-widest uppercase select-none hover:text-ink transition-colors">
            <span>injected preamble</span>
            <span className="opacity-40 group-open:opacity-100">▾</span>
          </summary>
          <div className="px-4 py-3 border-t border-rule">
            <pre className="text-[12px] text-muted leading-relaxed whitespace-pre font-mono">
              {buildPreamble(config)}
            </pre>
          </div>
        </details>

        {/* Cells */}
        <div className="space-y-3">
          {cells.map((cell, i) => {
            if (cell.kind === "note")
              return (
                <NoteCell
                  key={cell.id}
                  cell={cell}
                  index={i + 1}
                  isActive={activeCell === cell.id}
                  onActivate={() => setActiveCell(cell.id)}
                  onDelete={deleteCell}
                />
              );
            if (cell.kind === "python")
              return (
                <PythonCell
                  key={cell.id}
                  cell={cell}
                  index={i + 1}
                  isActive={activeCell === cell.id}
                  onActivate={() => setActiveCell(cell.id)}
                  onChange={handlePyChange}
                  onRun={runPyCell}
                  onDelete={deleteCell}
                />
              );
            if (cell.kind === "request")
              return (
                <RequestCell
                  key={cell.id}
                  cell={cell}
                  index={i + 1}
                  isActive={activeCell === cell.id}
                  onActivate={() => setActiveCell(cell.id)}
                  onRun={runReqCell}
                  onDelete={deleteCell}
                  ebuffUrl={config.ebuffUrl}
                  appmsUrl={config.appmsUrl}
                />
              );
            return null;
          })}
        </div>

        {/* Add cell row */}
        <div className="mt-6 flex gap-2">
          <button
            onClick={addPy}
            className="flex-1 text-[11px] text-muted border border-dashed border-rule py-2 rounded-sm hover:border-accent1 hover:text-accent1 transition-colors tracking-wider"
          >
            + python
          </button>
          <button
            onClick={addReq}
            className="flex-1 text-[11px] text-muted border border-dashed border-rule py-2 rounded-sm hover:border-accent2 hover:text-accent2 transition-colors tracking-wider"
          >
            + request
          </button>
          <button
            onClick={addNote}
            className="flex-1 text-[11px] text-muted border border-dashed border-rule py-2 rounded-sm hover:border-muted hover:text-ink transition-colors tracking-wider"
          >
            + note
          </button>
        </div>

        {/* Stats footer */}
        <div className="mt-12 pt-6 border-t border-rule flex items-center gap-6 text-[10px] text-muted tracking-widest uppercase">
          <span>cells · {cells.length}</span>
          <span>python · {cells.filter((c) => c.kind === "python").length}</span>
          <span>requests · {cells.filter((c) => c.kind === "request").length}</span>
          <span>errors · {cells.filter((c) => c.state === "error").length}</span>
        </div>

        {/* File explorer — fixed left panel */}
        {showExplorer && (
          <div className="fixed left-0 top-12 bottom-0 w-56 z-40 flex flex-col border-r border-rule bg-paper-alt">
            <FileExplorer sessionId={sessionId} sessionStatus={sessionStatus} />
          </div>
        )}
      </main>
      <Footer />
    </div>
  );
}
