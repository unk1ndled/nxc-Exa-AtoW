import { useState, useEffect, useCallback } from "react";
import { API_URL, TOKEN_KEY } from "../notebook/api";

// Unified auth hook for admins AND experimenters.
// - Admins log in with username/password via /auth/login.
// - Experimenters log in by pasting an invite token (verified via /auth/verify).
// The role is sourced from /auth/verify, never stored client-side.

export function useAuth() {
  const [token, setToken] = useState(() => localStorage.getItem(TOKEN_KEY));
  const [role, setRole] = useState(null);
  const [verified, setVerified] = useState(false);
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    let cancelled = false;
    if (!token) {
      setVerified(false);
      setRole(null);
      setChecking(false);
      return;
    }
    setChecking(true);
    fetch(`${API_URL}/auth/verify`, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then(async (r) => {
        if (cancelled) return;
        if (r.ok) {
          const { role: roleFromServer } = await r.json();
          setRole(roleFromServer);
          setVerified(true);
        } else {
          localStorage.removeItem(TOKEN_KEY);
          setToken(null);
          setRole(null);
          setVerified(false);
        }
      })
      .catch(() => {
        if (cancelled) return;
        // Network unreachable — fail closed.
        setVerified(false);
        setRole(null);
      })
      .finally(() => !cancelled && setChecking(false));
    return () => {
      cancelled = true;
    };
  }, [token]);

  const loginAdmin = useCallback(async (username, password) => {
    const res = await fetch(`${API_URL}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username, password }),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail ?? "Login failed");
    }
    const { token: t, role: r } = await res.json();
    localStorage.setItem(TOKEN_KEY, t);
    setToken(t);
    setRole(r);
    setVerified(true);
  }, []);

  const loginExperimenter = useCallback(async (invite) => {
    const t = invite.trim();
    if (!t) throw new Error("Token required");
    const res = await fetch(`${API_URL}/auth/verify`, {
      headers: { Authorization: `Bearer ${t}` },
    });
    if (!res.ok) {
      throw new Error("Invalid or expired token");
    }
    const { role: r } = await res.json();
    localStorage.setItem(TOKEN_KEY, t);
    setToken(t);
    setRole(r);
    setVerified(true);
  }, []);

  const logout = useCallback(async () => {
    if (token) {
      await fetch(`${API_URL}/auth/logout`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      }).catch(() => {});
    }
    localStorage.removeItem(TOKEN_KEY);
    setToken(null);
    setRole(null);
    setVerified(false);
  }, [token]);

  return {
    token,
    role,
    verified,
    checking,
    isAdmin: verified && role === "admin",
    isExperimenter: verified && (role === "admin" || role === "experimenter"),
    loginAdmin,
    loginExperimenter,
    logout,
  };
}
