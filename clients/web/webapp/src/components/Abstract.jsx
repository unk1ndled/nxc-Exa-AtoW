export default function Abstract({ sectionNumber = 2 }) {
  return (
    <section id="abstract" className="py-20 border-b border-rule">
      <div className="flex items-baseline gap-4 mb-10">
        <span className="text-[11px] text-muted tracking-wider w-10">
          {String(sectionNumber).padStart(2, "0")}.
        </span>
        <span className="text-[11px] tracking-widest uppercase text-muted">
          Abstract
        </span>
      </div>
      <div className="pl-0 sm:pl-14 space-y-5 max-w-xl">
        <p className="text-sm leading-loose">
          <strong>Exa-AToW</strong> develops architectures and tools for
          managing large-scale scientific workflows across the entire data
          continuum—from edge devices to supercomputers.
        </p>
        <p className="text-sm leading-loose">
          Our goal: enable efficient, secure, and sustainable workflows that
          combine HPDA, AI, and HPC tasks, distributed over Exascale, HPC, and
          data infrastructures.
        </p>
        <p className="text-sm leading-loose">
          <strong>Main challenges we address:</strong>
        </p>
        <ul className="list-disc pl-6 mt-2 text-sm leading-loose">
          <li>
            Integrating Exascale systems into the broader scientific data sphere
          </li>
          <li>
            Ensuring robust cybersecurity across diverse, large-scale
            technologies
          </li>
          <li>
            Dynamically allocating resources to optimize for energy costs and
            sustainability
          </li>
        </ul>
        <p className="text-sm leading-loose">
          <strong>Our approach:</strong> We build a collaborative,
          service-oriented, and data-driven architecture that unifies
          technology, governance, and cybersecurity—while optimizing for
          performance, energy, and sustainability.
        </p>
        <p className="text-sm leading-loose">
          <strong>Key outcomes:</strong>
        </p>
        <ul className="list-disc pl-6 mt-2 text-sm leading-loose">
          <li>Machine-actionable data and project planning tools</li>
          <li>A software stack supporting advanced workflows and APIs</li>
          <li>Principles for governance and cybersecurity</li>
          <li>
            Examobile: an integrated hardware/software solution for data
            logistics
          </li>
        </ul>
        <p className="text-sm leading-loose">
          <span className="text-muted">Project partners:</span>{" "}
          <a
            href="https://www.irisa.fr/"
            target="_blank"
            rel="noopener noreferrer"
            className="text-blue-600 hover:underline"
          >
            IRISA
          </a>
          ,{" "}
          <a
            href="https://www.idris.fr/"
            target="_blank"
            rel="noopener noreferrer"
            className="text-blue-600 hover:underline"
          >
            Idris
          </a>
          ,{" "}
          <a
            href="https://team.inria.fr/datamove/"
            target="_blank"
            rel="noopener noreferrer"
            className="text-blue-600 hover:underline"
          >
            Datamove/Inria
          </a>
          ,{" "}
          <a
            href="https://www.cea.fr/"
            target="_blank"
            rel="noopener noreferrer"
            className="text-blue-600 hover:underline"
          >
            CEA
          </a>
          .
        </p>
      </div>
    </section>
  );
}
