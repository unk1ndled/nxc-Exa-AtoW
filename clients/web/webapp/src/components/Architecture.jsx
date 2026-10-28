import Figure from "./Figure";

export default function Architecture({ sectionNumber = 1 }) {
  return (
    <section id="architecture" className="py-20 border-b border-rule">
      <div className="flex items-baseline gap-4 mb-10">
        <span className="text-[11px] text-muted tracking-wider w-10">
          {String(sectionNumber).padStart(2, "0")}.
        </span>
        <span className="text-[11px] tracking-widest uppercase text-muted">
          Architecture
        </span>
      </div>

      <div className="pl-0 sm:pl-14 flex flex-col gap-10">
        <Figure
          src="/Composition.png"
          alt="System overview diagram"
          label={`fig. ${sectionNumber} — system overview`}
        />

        <p className="text-[13px] text-muted leading-relaxed text-justify">
          The demo app is designed for maximum deployment modularity. Neither
          the EB layer nor the webapp need to be co-located with the compute
          cluster, each tier can be deployed independently and hot-swapped
          without affecting the others. This reflects the aforementioned digital
          continuum integration approach, where heterogeneous compute sites are
          abstracted and unified behind the EB layer, which acts as the single
          point of routing and mediation between the frontend and the underlying
          kernels.
        </p>

        <Figure
          src="/EB-DDF.png"
          alt="EBbuffer architecture diagram"
          label={`fig. ${sectionNumber}.1 — ebbuffer architecture diagram`}
        />
      </div>
    </section>
  );
}
