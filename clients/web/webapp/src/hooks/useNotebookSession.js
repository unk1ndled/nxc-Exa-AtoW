import { useState, useCallback, useEffect, useRef } from "react";
import { API_URL, authFetch } from "../notebook/api";

function getClientId(key) {
  let id = localStorage.getItem(key);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(key, id);
  }
  return id;
}

// Manages kernel session lifecycle: create, poll, stop.
// clientIdKey — localStorage key for the stable client identity.
// Returns session state + sessionIdRef for use in execute calls.
export function useNotebookSession(clientIdKey) {
  const [sessionId, setSessionId] = useState(null);
  const [sessionStatus, setSessionStatus] = useState("disconnected");
  const [sessionError, setSessionError] = useState(null);
  const pollRef = useRef(null);
  const sessionIdRef = useRef(null);

  const pollUntilReady = useCallback((id) => {
    clearInterval(pollRef.current);
    pollRef.current = setInterval(async () => {
      try {
        const r = await authFetch(`${API_URL}/sessions/${id}`);
        if (!r.ok) {
          clearInterval(pollRef.current);
          return;
        }
        const data = await r.json();
        if (data.status === "ready") {
          clearInterval(pollRef.current);
          setSessionStatus("ready");
        } else if (data.status === "error") {
          clearInterval(pollRef.current);
          setSessionStatus("error");
          setSessionError(data.error);
        }
      } catch (_) {}
    }, 2000);
  }, []);

  const startSession = useCallback(async () => {
    setSessionStatus("starting");
    setSessionError(null);
    try {
      const res = await authFetch(`${API_URL}/sessions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ client_id: getClientId(clientIdKey) }),
      });
      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.detail ?? "Failed to create session");
      }
      const { id, status, reused } = await res.json();
      setSessionId(id);
      sessionIdRef.current = id;
      if (reused && status === "ready") {
        setSessionStatus("ready");
        return;
      }
      pollUntilReady(id);
    } catch (e) {
      setSessionStatus("error");
      setSessionError(e.message);
    }
  }, [clientIdKey, pollUntilReady]);

  const stopSession = useCallback(async () => {
    if (!sessionIdRef.current) return;
    clearInterval(pollRef.current);
    await authFetch(`${API_URL}/sessions/${sessionIdRef.current}`, {
      method: "DELETE",
    }).catch(() => {});
    // Rotate client ID so the next visit starts a fresh session.
    localStorage.removeItem(clientIdKey);
    sessionIdRef.current = null;
    setSessionId(null);
    setSessionStatus("disconnected");
  }, [clientIdKey]);

  // Connect on mount. Do NOT delete on unmount — server keeps the session alive
  // and client_id will reconnect to it on the next visit.
  useEffect(() => {
    startSession();
    return () => clearInterval(pollRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return {
    sessionId,
    sessionIdRef,
    sessionStatus,
    sessionError,
    startSession,
    stopSession,
  };
}
