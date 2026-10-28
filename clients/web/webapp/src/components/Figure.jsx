export default function Figure({ src, alt, label }) {
  return (
    <figure className="flex flex-col gap-3">
      <div className="border border-dashed border-rule bg-paper-alt rounded-sm p-4 flex items-center justify-center">
        <img src={src} alt={alt} className="max-w-full h-auto" />
      </div>
      {label && (
        <figcaption className="text-[11px] text-muted italic leading-relaxed">
          {label}
        </figcaption>
      )}
    </figure>
  );
}
