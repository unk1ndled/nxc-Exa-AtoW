// Renders outputs for both python cells (outputs[]) and request cells (output string).
// state: "idle" | "running" | "ok" | "error"
export default function CellOutput({ outputs, output, state }) {
  const items = outputs?.length
    ? outputs
    : output != null
      ? [{ type: state === "error" ? "error" : "stream", text: output }]
      : [];

  if (!items.length && state === "idle") return null;
  if (state === "running")
    return (
      <div className="border-t border-rule px-4 py-3 bg-paper-alt">
        <span className="text-[10px] text-muted animate-pulse tracking-widest uppercase">
          ◌ running…
        </span>
      </div>
    );
  if (!items.length) return null;

  return (
    <div className="border-t border-rule px-4 py-3 bg-paper-alt">
      <span
        className={`block text-[10px] tracking-widest uppercase mb-2 ${
          state === "error" ? "text-accent1" : "text-accent2"
        }`}
      >
        {state === "error" ? "error" : "output"}
      </span>
      {items.map((o, i) => (
        <pre
          key={i}
          className={`text-[12px] leading-relaxed whitespace-pre-wrap font-mono ${
            o.type === "error"
              ? "text-accent1"
              : o.name === "stderr"
                ? "text-accent1 opacity-80"
                : "text-ink"
          }`}
        >
          {o.text}
        </pre>
      ))}
    </div>
  );
}
