const SPECS = [
  {
    label: 'execution model',
    value: 'lazy graph evaluation, demand-driven scheduling',
  },
  {
    label: 'task definition',
    value: 'pure DSL, no side effects at declaration time',
  },
  {
    label: 'ir format',
    value: (
      <>
        <code className="bg-paper-alt border border-rule px-1.5 py-0.5 rounded-sm text-[12px]">
          .atow
        </code>
        {' '}— typed, hash-addressed, content-addressed store
      </>
    ),
  },
  {
    label: 'scheduler backends',
    value: 'OAR, SLURM, local process pool, Docker compose',
  },
  {
    label: 'reproducibility',
    value: 'bit-exact replay via Nix derivation pinning',
  },
  {
    label: 'provenance',
    value: 'full input/output merkle log per task node',
  },
  {
    label: 'dependencies',
    value: 'Python \u2265\u00a03.11, Nix \u2265\u00a02.18, Linux x86_64',
  },
  {
    label: 'distribution',
    value: 'Nix flake, pip-installable core lib',
  },
];

export default function Specs() {
  return (
    <section id="specs" className="py-20 border-b border-rule">
      <div className="flex items-baseline gap-4 mb-10">
        <span className="text-[11px] text-muted tracking-wider w-10">03.</span>
        <span className="text-[11px] tracking-widest uppercase text-muted">Technical Specifications</span>
      </div>

      <div className="pl-0 sm:pl-14">
        <dl className="divide-y divide-rule text-[13px]">
          {SPECS.map(({ label, value }) => (
            <div key={label} className="py-3 flex flex-col sm:flex-row sm:gap-6">
              <dt className="text-muted shrink-0 sm:w-2/5 mb-0.5 sm:mb-0">{label}</dt>
              <dd>{value}</dd>
            </div>
          ))}
        </dl>
      </div>
    </section>
  );
}
