import { useState } from "react";
import { API_URL, authFetch } from "../notebook/api";

export default function KillAllSessions({ onKilled }) {
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);

  const kill = async () => {
    setBusy(true);
    setError(null);
    setResult(null);
    try {
      const r = await authFetch(`${API_URL}/admin/sessions`, { method: "DELETE" });
      if (!r.ok) {
        const err = await r.json().catch(() => ({}));
        throw new Error(err.detail ?? `HTTP ${r.status}`);
      }
      const data = await r.json();
      setResult(data.stopped);
      onKilled?.();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
      setConfirming(false);
    }
  };

  return (
    <div className="border border-rule rounded-sm">
      <div className="flex items-center justify-between px-3 py-1.5 bg-paper-alt">
        <span className="text-[10px] text-muted tracking-widest uppercase">
          emergency · kill all sessions
        </span>
        {!confirming && (
          <button
            onClick={() => { setConfirming(true); setResult(null); setError(null); }}
            className="text-[11px] tracking-wider px-3 py-1 border border-accent1 text-accent1 rounded-sm hover:bg-accent1 hover:text-paper transition-colors"
          >
            kill all
          </button>
        )}
      </div>

      {confirming && (
        <div className="px-4 py-3 border-t border-rule space-y-3">
          <p className="text-[12px] text-ink">
            Hard-stop <strong>all</strong> running containers immediately. This cannot be undone.
          </p>
          <div className="flex items-center gap-2">
            <button
              onClick={kill}
              disabled={busy}
              className="text-[11px] tracking-wider px-3 py-1 bg-accent1 text-paper rounded-sm hover:bg-accent2 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              {busy ? "stopping…" : "confirm kill all"}
            </button>
            <button
              onClick={() => setConfirming(false)}
              disabled={busy}
              className="text-[11px] text-muted hover:text-ink"
            >
              cancel
            </button>
          </div>
        </div>
      )}

      {result !== null && (
        <div className="px-4 py-2 border-t border-rule">
          <p className="text-[11px] text-ink">
            Stopped <strong>{result}</strong> container{result !== 1 ? "s" : ""}.
          </p>
        </div>
      )}
      {error && (
        <div className="px-4 py-2 border-t border-rule">
          <p className="text-[10px] text-accent1">{error}</p>
        </div>
      )}
    </div>
  );
}
