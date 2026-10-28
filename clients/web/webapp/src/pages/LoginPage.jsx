import { useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import Nav from "../components/Nav";
import Footer from "../components/Footer";
import { useAuth } from "../hooks/useAuth";

export default function LoginPage() {
  const [params] = useSearchParams();
  const initialMode = params.get("mode") === "experimenter" ? "experimenter" : "admin";

  const [mode, setMode] = useState(initialMode);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [invite, setInvite] = useState("");
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const { loginAdmin, loginExperimenter } = useAuth();
  const navigate = useNavigate();
  const next = params.get("next") ?? (mode === "experimenter" ? "/notebook" : "/maintainer");

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      if (mode === "admin") {
        await loginAdmin(username, password);
      } else {
        await loginExperimenter(invite);
      }
      navigate(next, { replace: true });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-paper text-ink text-sm antialiased min-h-screen font-mono">
      <Nav />
      <main className="max-w-content mx-auto px-8 py-16">
        <div className="max-w-sm">
          <p className="text-[10px] tracking-widest uppercase text-muted mb-1">
            access · {mode}
          </p>
          <h1 className="text-xl font-semibold tracking-tight mb-6">sign in</h1>

          <div className="flex gap-4 mb-6 text-[11px] tracking-wider">
            <button
              type="button"
              onClick={() => { setMode("admin"); setError(null); }}
              className={`pb-1 border-b ${
                mode === "admin"
                  ? "text-ink border-accent1"
                  : "text-muted border-transparent hover:text-ink"
              }`}
            >
              admin
            </button>
            <button
              type="button"
              onClick={() => { setMode("experimenter"); setError(null); }}
              className={`pb-1 border-b ${
                mode === "experimenter"
                  ? "text-ink border-accent1"
                  : "text-muted border-transparent hover:text-ink"
              }`}
            >
              experimenter
            </button>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            {mode === "admin" ? (
              <>
                <div>
                  <label className="block text-[10px] text-muted tracking-widest uppercase mb-1">
                    username
                  </label>
                  <input
                    type="text"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    autoFocus
                    required
                    spellCheck={false}
                    autoComplete="username"
                    className="w-full bg-paper-alt border border-rule rounded-sm text-[12px] px-3 py-1.5 font-mono text-ink focus:outline-none focus:border-accent1 placeholder:text-muted"
                  />
                </div>
                <div>
                  <label className="block text-[10px] text-muted tracking-widest uppercase mb-1">
                    password
                  </label>
                  <input
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    autoComplete="current-password"
                    className="w-full bg-paper-alt border border-rule rounded-sm text-[12px] px-3 py-1.5 font-mono text-ink focus:outline-none focus:border-accent1 placeholder:text-muted"
                  />
                </div>
              </>
            ) : (
              <div>
                <label className="block text-[10px] text-muted tracking-widest uppercase mb-1">
                  invite token
                </label>
                <input
                  type="password"
                  value={invite}
                  onChange={(e) => setInvite(e.target.value)}
                  autoFocus
                  required
                  spellCheck={false}
                  autoComplete="off"
                  placeholder="paste token from your admin"
                  className="w-full bg-paper-alt border border-rule rounded-sm text-[12px] px-3 py-1.5 font-mono text-ink focus:outline-none focus:border-accent1 placeholder:text-muted"
                />
                <p className="text-[10px] text-muted opacity-70 mt-1">
                  Don't have one? Ask an admin to mint one from /maintainer.
                </p>
              </div>
            )}

            {error && (
              <p className="text-[11px] text-accent1 tracking-wide">{error}</p>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full text-[11px] tracking-wider px-3 py-2 bg-accent1 text-paper rounded-sm hover:bg-accent2 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              {loading ? <span className="animate-pulse">signing in…</span> : "sign in"}
            </button>
          </form>
        </div>
      </main>
      <Footer />
    </div>
  );
}
