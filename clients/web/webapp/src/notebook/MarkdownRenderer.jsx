export default function MarkdownRenderer({ content }) {
  return (
    <div className="text-sm leading-loose space-y-1">
      {content.split("\n").map((line, i) => {
        if (line.startsWith("### "))
          return (
            <h3 key={i} className="text-sm font-semibold text-accent2 mt-1">
              {line.slice(4)}
            </h3>
          );
        if (line.startsWith("## "))
          return (
            <h2 key={i} className="text-base font-semibold mt-2">
              {line.slice(3)}
            </h2>
          );
        if (line === "") return <div key={i} className="h-1" />;
        return (
          <p key={i} className="text-muted">
            {line}
          </p>
        );
      })}
    </div>
  );
}
