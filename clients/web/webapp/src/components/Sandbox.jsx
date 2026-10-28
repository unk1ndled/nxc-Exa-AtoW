export default function Sandbox({ sectionNumber = 4 }) {
  return (
    <section id="sandbox" className="py-20">
      <div className="flex items-baseline gap-4 mb-10">
        <span className="text-[11px] text-muted tracking-wider w-10">
          {String(sectionNumber).padStart(2, "0")}.
        </span>
        <span className="text-[11px] tracking-widest uppercase text-muted">
          Try It
        </span>
      </div>
      <div className="pl-0 sm:pl-14 space-y-6">
        <h2 className="text-xl font-medium leading-snug max-w-sm">
          Run a minimal workflow
          <br />
          <em className="font-light italic">in the hosted sandbox.</em>
        </h2>
        <p className="text-[13px] text-muted max-w-md leading-relaxed">
          No installation required. The sandbox provides a preloaded Nix
          environment with a small synthetic task graph. Persistent sessions are
          not supported — results are ephemeral and discarded on exit.
        </p>
        <div className="flex flex-wrap items-center gap-3">
          <div className="group flex items-center gap-3">
            <a
              href="/notebook"
              className="inline-flex items-center gap-2 bg-accent1 text-paper text-[13px] font-medium tracking-wider px-6 py-3 rounded-sm hover:opacity-80 transition-opacity"
            >
              open notebook sandbox →
            </a>
            <a
              href="/maintainer"
              className="opacity-0 group-hover:opacity-100 transition-opacity text-[11px] text-muted hover:text-ink tracking-wider"
            >
              maintainer ⤤
            </a>
          </div>
          <a
            href="#"
            className="inline-flex items-center gap-2 text-[13px] text-ink tracking-wide px-6 py-3 border border-rule rounded-sm hover:bg-paper-alt transition-colors"
          >
            read docs
          </a>
        </div>
        <p className="text-[11px] text-muted">
          sandbox instances are isolated · max session 30 min · compute quota
          applies
        </p>
      </div>
    </section>
  );
}
