import { useState, useCallback, useEffect, useRef } from "react";
import { API_URL, authFetch } from "./api";

export default function FileExplorer({ sessionId, sessionStatus }) {
  const [currentPath, setCurrentPath] = useState("");
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const [showNewFolder, setShowNewFolder] = useState(false);
  const [newFolderName, setNewFolderName] = useState("");
  const [creatingFolder, setCreatingFolder] = useState(false);

  const [uploading, setUploading] = useState(false);
  const [lastUpload, setLastUpload] = useState(null);
  const fileInputRef = useRef(null);
  const newFolderInputRef = useRef(null);

  // ---------------------------------------------------------------------------

  const fetchPath = useCallback(
    async (path) => {
      if (!sessionId || sessionStatus !== "ready") return;
      setLoading(true);
      setError(null);
      try {
        const res = await authFetch(
          `${API_URL}/sessions/${sessionId}/files?path=${encodeURIComponent(path)}`,
        );
        if (!res.ok) {
          const err = await res.json().catch(() => ({}));
          throw new Error(err.detail ?? "Failed to list files");
        }
        const data = await res.json();
        setItems(data.items);
        setCurrentPath(data.path);
      } catch (e) {
        setError(e.message);
      } finally {
        setLoading(false);
      }
    },
    [sessionId, sessionStatus],
  );

  useEffect(() => {
    if (sessionStatus === "ready") fetchPath("");
  }, [sessionStatus, fetchPath]);

  // ---------------------------------------------------------------------------

  const goUp = () => {
    const parts = currentPath.split("/").filter(Boolean);
    parts.pop();
    fetchPath(parts.join("/"));
  };

  const enterDir = (path) => {
    setLastUpload(null);
    setError(null);
    fetchPath(path);
  };

  const deleteItem = async (itemPath) => {
    try {
      const res = await authFetch(
        `${API_URL}/sessions/${sessionId}/files?path=${encodeURIComponent(itemPath)}`,
        { method: "DELETE" },
      );
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail ?? "Delete failed");
      }
      fetchPath(currentPath);
    } catch (e) {
      setError(e.message);
    }
  };

  const createFolder = async () => {
    const name = newFolderName.trim();
    if (!name) return;
    const path = currentPath ? `${currentPath}/${name}` : name;
    setCreatingFolder(true);
    try {
      const res = await authFetch(`${API_URL}/sessions/${sessionId}/mkdir`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ path }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail ?? "Failed to create folder");
      }
      setNewFolderName("");
      setShowNewFolder(false);
      fetchPath(currentPath);
    } catch (e) {
      setError(e.message);
    } finally {
      setCreatingFolder(false);
    }
  };

  const handleUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setLastUpload(null);
    setError(null);
    const body = new FormData();
    body.append("file", file);
    const qs = currentPath
      ? `?path=${encodeURIComponent(currentPath)}`
      : "";
    try {
      const res = await authFetch(
        `${API_URL}/sessions/${sessionId}/upload${qs}`,
        { method: "POST", body },
      );
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail ?? "Upload failed");
      }
      const data = await res.json();
      setLastUpload(data.filename);
      fetchPath(currentPath);
    } catch (e) {
      setError(e.message);
    } finally {
      setUploading(false);
      e.target.value = "";
    }
  };

  // ---------------------------------------------------------------------------

  const isRoot = currentPath === "";
  const dirLabel = isRoot
    ? "working dir"
    : currentPath.split("/").filter(Boolean).pop();

  return (
    <div className="h-full flex flex-col text-[11px] font-mono">
      {/* Header */}
      <div className="flex items-center justify-between px-3 py-1.5 border-b border-rule">
        <div className="flex items-center gap-1.5 min-w-0">
          {!isRoot && (
            <button
              onClick={goUp}
              className="text-muted hover:text-ink transition-colors flex-shrink-0"
              title="Go up"
            >
              ←
            </button>
          )}
          <span className="text-[10px] text-muted tracking-widest uppercase truncate">
            {dirLabel}
          </span>
        </div>
        <button
          onClick={() => fetchPath(currentPath)}
          className="text-muted hover:text-ink transition-colors flex-shrink-0 ml-2"
          title="Refresh"
        >
          ↻
        </button>
      </div>

      {/* Breadcrumb */}
      {!isRoot && (
        <div className="px-3 py-1 border-b border-rule text-[10px] text-muted truncate">
          /{currentPath}
        </div>
      )}

      {/* File list */}
      <div className="flex-1 min-h-0 overflow-y-auto">
        {loading && (
          <div className="px-3 py-3 text-[10px] text-muted animate-pulse">
            loading…
          </div>
        )}
        {!loading && !error && items.length === 0 && (
          <div className="px-3 py-4 text-[10px] text-muted opacity-50 text-center">
            empty
          </div>
        )}
        {!loading &&
          items.map((item) => (
            <div
              key={item.path}
              className="group flex items-center justify-between px-3 py-1.5 hover:bg-paper transition-colors border-b border-rule last:border-0"
            >
              <button
                className="flex items-center gap-2 min-w-0 flex-1 text-left"
                onClick={() =>
                  item.type === "directory" ? enterDir(item.path) : undefined
                }
              >
                <span className="text-[10px] text-muted flex-shrink-0">
                  {item.type === "directory" ? "▸" : "·"}
                </span>
                <span
                  className={`truncate ${
                    item.type === "directory" ? "text-accent2" : "text-ink"
                  }`}
                >
                  {item.name}
                  {item.type === "directory" ? "/" : ""}
                </span>
              </button>
              <button
                onClick={() => deleteItem(item.path)}
                className="opacity-0 group-hover:opacity-100 transition-opacity text-[10px] text-muted hover:text-accent1 px-1 flex-shrink-0"
                title={`Delete ${item.name}`}
              >
                ✕
              </button>
            </div>
          ))}
      </div>

      {/* Footer actions */}
      <div className="border-t border-rule px-3 py-2 space-y-1.5">
        {error && (
          <p className="text-[10px] text-accent1 truncate">{error}</p>
        )}
        {lastUpload && !error && (
          <p className="text-[10px] text-accent2 truncate">✓ {lastUpload}</p>
        )}

        {showNewFolder ? (
          <div className="flex items-center gap-1.5">
            <input
              ref={newFolderInputRef}
              autoFocus
              value={newFolderName}
              onChange={(e) => setNewFolderName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") createFolder();
                if (e.key === "Escape") {
                  setShowNewFolder(false);
                  setNewFolderName("");
                }
              }}
              placeholder="folder name"
              className="flex-1 bg-paper border border-rule rounded-sm text-[11px] px-2 py-0.5 font-mono text-ink focus:outline-none focus:border-accent1 placeholder:text-muted"
            />
            <button
              onClick={createFolder}
              disabled={creatingFolder || !newFolderName.trim()}
              className="text-accent2 hover:text-ink disabled:opacity-40 transition-colors"
            >
              {creatingFolder ? "…" : "✓"}
            </button>
            <button
              onClick={() => {
                setShowNewFolder(false);
                setNewFolderName("");
              }}
              className="text-muted hover:text-accent1 transition-colors"
            >
              ✕
            </button>
          </div>
        ) : (
          <div className="flex items-center gap-3">
            <input
              ref={fileInputRef}
              type="file"
              className="hidden"
              onChange={handleUpload}
            />
            <button
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading || sessionStatus !== "ready"}
              className="text-muted hover:text-ink disabled:opacity-40 transition-colors tracking-wider"
            >
              {uploading ? (
                <span className="animate-pulse">uploading…</span>
              ) : (
                "+ upload"
              )}
            </button>
            <span className="text-muted opacity-30">·</span>
            <button
              onClick={() => setShowNewFolder(true)}
              disabled={sessionStatus !== "ready"}
              className="text-muted hover:text-ink disabled:opacity-40 transition-colors tracking-wider"
            >
              + folder
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
