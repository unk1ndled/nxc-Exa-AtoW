export const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:9000";

export const TOKEN_KEY = "atow_token";

export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function authHeaders(extra = {}) {
  const token = getToken();
  return token ? { ...extra, Authorization: `Bearer ${token}` } : extra;
}

// Drop-in fetch that auto-attaches the bearer token. Use for any call that
// needs to be authenticated as the current principal.
export function authFetch(input, init = {}) {
  return fetch(input, {
    ...init,
    headers: authHeaders(init.headers ?? {}),
  });
}
