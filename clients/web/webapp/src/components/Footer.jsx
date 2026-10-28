const LINKS = [
  { label: "github", href: "#" },
  { label: "paper (preprint)", href: "#" },
  { label: "contact", href: "#" },
];

export default function Footer() {
  return (
    <footer className="border-t border-rule px-8 py-5">
      <div className="max-w-content mx-auto flex flex-wrap items-center justify-between gap-4">
        <span className="text-[11px] text-muted tracking-wide">
          exa-atow · summer 26 demo · research prototype
        </span>
        <nav className="flex gap-6" aria-label="Footer navigation">
          {LINKS.map(({ label, href }) => (
            <a
              key={label}
              href={href}
              className="text-[11px] text-muted hover:text-ink tracking-wide transition-colors"
            >
              {label}
            </a>
          ))}
        </nav>
      </div>
    </footer>
  );
}
