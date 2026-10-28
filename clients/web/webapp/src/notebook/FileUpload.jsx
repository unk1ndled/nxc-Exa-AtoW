import { useRef, useState } from "react";
import { API_URL, authFetch } from "./api";

// Uploads a file into the session's Jupyter working directory (/home/jovyan).
// Scripts can then reference the file by name (e.g. open('data.csv')).
export default function FileUpload({ sessionId, sessionStatus }) {
  const inputRef = useRef(null);
  const [uploading, setUploading] = useState(false);
  const [last, setLast] = useState(null); // { filename, size } | null
  const [error, setError] = useState(null);

  const handleChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setError(null);
    setLast(null);
    setUploading(true);

    const body = new FormData();
    body.append("file", file);

    try {
      const res = await authFetch(`${API_URL}/sessions/${sessionId}/upload`, {
        method: "POST",
        body,
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail ?? "Upload failed");
      }
      const data = await res.json();
      setLast(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setUploading(false);
      // Reset input so the same file can be re-uploaded if needed.
      e.target.value = "";
    }
  };

  const disabled = sessionStatus !== "ready" || uploading;

  return (
    <div className="flex items-center gap-2">
      <input
        ref={inputRef}
        type="file"
        className="hidden"
        onChange={handleChange}
      />
      <button
        onClick={() => inputRef.current?.click()}
        disabled={disabled}
        title="Upload a file into the kernel working directory"
        className="text-[11px] tracking-wider px-3 py-1 border border-rule rounded-sm hover:bg-paper-alt disabled:opacity-40 disabled:cursor-not-allowed transition-colors text-muted hover:text-ink"
      >
        {uploading ? (
          <span className="animate-pulse">uploading…</span>
        ) : (
          "upload file"
        )}
      </button>

      {last && !error && (
        <span className="text-[10px] text-accent2 tracking-wider truncate max-w-[180px]">
          ✓ {last.filename}
        </span>
      )}
      {error && (
        <span className="text-[10px] text-accent1 tracking-wider truncate max-w-[180px]">
          {error}
        </span>
      )}
    </div>
  );
}
