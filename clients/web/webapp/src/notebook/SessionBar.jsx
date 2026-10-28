// status: "starting" | "ready" | "error" | "disconnected"
// onStart is optional — if omitted the "connect" button is not shown
export default function SessionBar({ status, error, sessionId, onStop, onStart }) {
  const dot =
    {
      starting: "bg-amber-400 animate-pulse",
      ready: "bg-green-500",
      error: "bg-accent1",
      disconnected: "bg-muted",
    }[status] ?? "bg-muted";

  const label =
    {
      starting: "starting kernel…",
      ready: `kernel ready · session ${sessionId?.slice(0, 8)}…`,
      error: error ?? "error",
      disconnected: "not connected",
    }[status] ?? status;

  return (
    <div className="flex items-center justify-between text-[11px] text-muted border border-rule rounded-sm px-3 py-1.5 bg-paper-alt">
      <div className="flex items-center gap-2">
        <span className={`w-1.5 h-1.5 rounded-full ${dot}`} />
        <span>{label}</span>
      </div>
      <div className="flex items-center gap-3">
        {status === "disconnected" && onStart && (
          <button
            onClick={onStart}
            className="hover:text-accent2 transition-colors tracking-wider"
          >
            connect →
          </button>
        )}
        {sessionId && status === "ready" && (
          <button
            onClick={onStop}
            className="hover:text-accent1 transition-colors tracking-wider"
          >
            stop session
          </button>
        )}
      </div>
    </div>
  );
}
