const META = [
  { label: "status", value: "active dev" },
  { label: "license", value: "AGPL-3.0" },
  { label: "target", value: "HPC / cluster" },
  { label: "lang", value: "Nix · Python" },
];

export default function Hero({ sectionNumber = 1 }) {
  return (
    <section className="pt-24 pb-20 border-b border-rule">
      <div className="flex items-baseline gap-4 mb-10">
        <span className="text-[11px] text-muted tracking-wider w-10">
          {String(sectionNumber).padStart(2, "0")}.
        </span>
        <span className="text-[11px] tracking-widest uppercase text-muted">
          Welcome
        </span>
      </div>
      <p className="text-[11px] tracking-widest uppercase text-muted mb-6">
        summer 26 demo
      </p>
      <h1 className="text-2xl sm:text-4xl font-semibold leading-tight tracking-tight mb-6 max-w-lg">
        exa-atow —<br />
        <em className="font-light not-italic italic">a system for</em>
        <br />
        adaptive task-oriented
        <br />
        workflows
      </h1>
      <p className="text-sm text-muted max-w-lg leading-relaxed mb-10">
        A compositional framework for expressing, scheduling, and reproducing
        structured task graphs across heterogeneous distributed environments.
        Designed for reproducibility-first research workflows.
      </p>
      <div className="flex flex-wrap items-center gap-3">
        <a
          href="#sandbox"
          className="inline-flex items-center gap-2 bg-accent1 text-paper text-[12px] font-medium tracking-wider px-5 py-2.5 rounded-sm hover:bg-accent1 hover:text-paper transition-colors"
        >
          try in sandbox <span>→</span>
        </a>
        <a
          href="#abstract"
          className="inline-flex items-center gap-2 text-[12px] text-ink tracking-wide px-5 py-2.5 border border-rule rounded-sm hover:bg-paper-alt transition-colors"
        >
          read paper
        </a>
      </div>
      <div className="mt-14 flex flex-wrap gap-10">
        {META.map(({ label, value }) => (
          <div key={label} className="flex flex-col gap-0.5">
            <span className="text-[10px] tracking-widest uppercase text-muted">
              {label}
            </span>
            <span className="text-[13px] font-medium">{value}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
