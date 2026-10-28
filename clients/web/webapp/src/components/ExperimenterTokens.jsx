import { useEffect, useState, useCallback } from "react";
import { API_URL, authFetch } from "../notebook/api";

// Admin-only panel: mint / list / revoke experimenter invite tokens.
// Tokens are shown ONCE at mint time — they are not retrievable after.
export default function ExperimenterTokens() {
  const [tokens, setTokens] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const [label, setLabel] = useState("");
  const [minting, setMinting] = useState(false);
  const [justMinted, setJustMinted] = useState(null); // { label, token }
  const [copied, setCopied] = useState(false);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const r = await authFetch(`${API_URL}/admin/experimenter-tokens`);
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      setTokens(await r.json());
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const mint = async (e) => {
    e.preventDefault();
    if (!label.trim()) return;
    setMinting(true);
    setError(null);
    try {
      const r = await authFetch(`${API_URL}/admin/experimenter-tokens`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ label: label.trim() }),
      });
      if (!r.ok) {
        const err = await r.json().catch(() => ({}));
        throw new Error(err.detail ?? `HTTP ${r.status}`);
      }
      const data = await r.json();
      setJustMinted({ label: data.label, token: data.token });
      setLabel("");
      setCopied(false);
      refresh();
    } catch (e) {
      setError(e.message);
    } finally {
      setMinting(false);
    }
  };

  const revoke = async (id) => {
    if (!confirm("Revoke this token? Existing sessions stay live but new calls will 401.")) return;
    setError(null);
    try {
      const r = await authFetch(`${API_URL}/admin/experimenter-tokens/${id}`, {
        method: "DELETE",
      });
      if (!r.ok && r.status !== 204) {
        const err = await r.json().catch(() => ({}));
        throw new Error(err.detail ?? `HTTP ${r.status}`);
      }
      refresh();
    } catch (e) {
      setError(e.message);
    }
  };

  const copyToken = async () => {
    if (!justMinted) return;
    try {
      await navigator.clipboard.writeText(justMinted.token);
      setCopied(true);
    } catch {
      // Clipboard API blocked — user can select manually.
    }
  };

  return (
    <details className="border border-rule rounded-sm group">
      <summary className="flex items-center justify-between px-3 py-1.5 bg-paper-alt cursor-pointer text-[10px] text-muted tracking-widest uppercase select-none hover:text-ink transition-colors">
        <span>experimenter tokens · {tokens.length}</span>
        <span className="opacity-40 group-open:opacity-100">▾</span>
      </summary>

      <div className="px-4 py-3 border-t border-rule space-y-4">
        {/* Mint form */}
        <form onSubmit={mint} className="flex items-center gap-2">
          <input
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            placeholder="label (e.g. alice, demo-day-2026)"
            maxLength={64}
            className="flex-1 bg-paper border border-rule rounded-sm text-[12px] px-2 py-1 font-mono text-ink focus:outline-none focus:border-accent1 placeholder:text-muted"
          />
          <button
            type="submit"
            disabled={minting || !label.trim()}
            className="text-[11px] tracking-wider px-3 py-1 bg-accent1 text-paper rounded-sm hover:bg-accent2 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            {minting ? "minting…" : "mint token"}
          </button>
        </form>

        {/* Token-just-minted callout */}
        {justMinted && (
          <div className="border border-accent2 rounded-sm p-3 bg-paper-alt">
            <p className="text-[10px] tracking-widest uppercase text-accent2 mb-1">
              new token for {justMinted.label}
            </p>
            <p className="text-[10px] text-muted mb-2">
              Copy now — this is the only time it will be shown.
            </p>
            <div className="flex items-center gap-2">
              <code className="flex-1 text-[11px] text-ink break-all bg-paper px-2 py-1 border border-rule rounded-sm">
                {justMinted.token}
              </code>
              <button
                onClick={copyToken}
                className="text-[11px] tracking-wider px-2 py-1 border border-rule rounded-sm text-muted hover:text-ink"
              >
                {copied ? "copied" : "copy"}
              </button>
              <button
                onClick={() => { setJustMinted(null); setCopied(false); }}
                className="text-[11px] text-muted hover:text-accent1"
              >
                dismiss
              </button>
            </div>
          </div>
        )}

        {error && <p className="text-[10px] text-accent1">{error}</p>}

        {/* Existing tokens */}
        <div>
          <div className="flex items-center justify-between mb-1">
            <span className="text-[10px] tracking-widest uppercase text-muted">
              active
            </span>
            <button
              onClick={refresh}
              className="text-[10px] text-muted hover:text-ink"
              title="Refresh"
            >
              ↻
            </button>
          </div>
          {loading ? (
            <p className="text-[10px] text-muted animate-pulse">loading…</p>
          ) : tokens.length === 0 ? (
            <p className="text-[10px] text-muted opacity-50">no tokens minted</p>
          ) : (
            <ul className="divide-y divide-rule">
              {tokens.map((t) => (
                <li key={t.id} className="flex items-center justify-between py-1.5">
                  <div className="min-w-0">
                    <p className="text-[12px] text-ink truncate">{t.label}</p>
                    <p className="text-[10px] text-muted truncate">
                      {t.id} · {new Date(t.created_at * 1000).toLocaleString()}
                    </p>
                  </div>
                  <button
                    onClick={() => revoke(t.id)}
                    className="text-[10px] tracking-wider text-muted hover:text-accent1 transition-colors px-2 py-1"
                  >
                    revoke
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </details>
  );
}
