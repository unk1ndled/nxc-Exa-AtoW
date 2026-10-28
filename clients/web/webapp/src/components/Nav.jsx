import { useState } from "react";
import { Link } from "react-router-dom";

export default function Nav() {
  const [open, setOpen] = useState(false);

  const links = [
    { href: "/#abstract", label: "abstract", external: false, anchor: true },
    { href: "/#architecture", label: "architecture", external: false, anchor: true },
    { href: "/notebook", label: "notebook", external: false, anchor: false },
    { href: "https://numpex.org/", label: "Numpex ⤤", external: true, anchor: false },
  ];

  return (
    <nav className="sticky top-0 z-50 bg-paper border-b border-rule">
      <div className="max-w-content mx-auto px-6 flex items-center justify-between h-12">
        {/* Left: logos + wordmark */}
        <div className="flex items-center gap-3 min-w-0">
          <img src="/france-2030.png" alt="France 2030 logo" className="h-8 shrink-0" />
          <Link
            to="/"
            className="flex items-center gap-2 text-xs font-semibold tracking-widest shrink-0"
          >
            <img src="/favicon.png" alt="Exa-AToW logo" className="w-8 h-8" />
            <span className="hidden sm:inline">Exa-AToW</span>
          </Link>
        </div>

        {/* Desktop nav */}
        <div className="hidden md:flex items-center gap-5">
          <span className="text-[10px] text-muted border border-rule px-2 py-0.5 rounded-sm tracking-wider whitespace-nowrap">
            summer 2026 demo
          </span>
          {links.map(({ href, label, external, anchor }) =>
            external || anchor ? (
              <a
                key={href}
                href={href}
                className="text-[12px] text-muted hover:text-ink tracking-wide transition-colors whitespace-nowrap"
              >
                {label}
              </a>
            ) : (
              <Link
                key={href}
                to={href}
                className="text-[12px] text-muted hover:text-ink tracking-wide transition-colors whitespace-nowrap"
              >
                {label}
              </Link>
            )
          )}
        </div>

        {/* Mobile hamburger */}
        <button
          onClick={() => setOpen((o) => !o)}
          className="md:hidden flex flex-col justify-center gap-1.5 w-8 h-8 shrink-0"
          aria-label="Toggle menu"
        >
          <span className={`block h-px bg-ink transition-transform origin-center ${open ? "rotate-45 translate-y-[7px]" : ""}`} />
          <span className={`block h-px bg-ink transition-opacity ${open ? "opacity-0" : ""}`} />
          <span className={`block h-px bg-ink transition-transform origin-center ${open ? "-rotate-45 -translate-y-[7px]" : ""}`} />
        </button>
      </div>

      {/* Mobile dropdown */}
      {open && (
        <div className="md:hidden border-t border-rule bg-paper px-6 py-4 flex flex-col gap-4">
          <span className="text-[10px] text-muted border border-rule px-2 py-0.5 rounded-sm tracking-wider self-start">
            summer 2026 demo
          </span>
          {links.map(({ href, label, external, anchor }) =>
            external || anchor ? (
              <a
                key={href}
                href={href}
                onClick={() => setOpen(false)}
                className="text-[13px] text-muted hover:text-ink tracking-wide transition-colors"
              >
                {label}
              </a>
            ) : (
              <Link
                key={href}
                to={href}
                onClick={() => setOpen(false)}
                className="text-[13px] text-muted hover:text-ink tracking-wide transition-colors"
              >
                {label}
              </Link>
            )
          )}
        </div>
      )}
    </nav>
  );
}
