type ModuleCardProps = {
  title: string;
  description: string;
  index?: number;
};

export default function ModuleCard({ title, description, index = 0 }: ModuleCardProps) {
  const chips = ['Core', 'Seguro', 'Escalable'];

  return (
    <article className="relative overflow-hidden rounded-2xl border border-slate-200 bg-white/85 p-6 shadow-lg shadow-slate-900/5 backdrop-blur transition-all duration-300 hover:-translate-y-1 hover:shadow-xl dark:border-white/10 dark:bg-white/[0.06]">
      <span className="inline-flex h-10 w-10 items-center justify-center rounded-xl border border-[#009FE3]/20 bg-[#009FE3]/10 text-xs font-black text-[#007DB3] dark:text-sky-300">
        0{index + 1}
      </span>
      <div className="my-6 grid h-24 grid-cols-3 items-end gap-3 rounded-2xl bg-slate-100/80 p-4 dark:bg-white/[0.05]" aria-hidden="true">
        {[50, 78, 62].map((height) => (
          <span
            key={height}
            className="rounded-full bg-gradient-to-t from-teal-500 to-sky-400"
            style={{ height: `${height}%` }}
          />
        ))}
      </div>
      <h3 className="text-xl font-black leading-snug text-slate-950 dark:text-white">{title}</h3>
      <p className="mt-3 text-sm leading-6 text-slate-600 dark:text-slate-300">{description}</p>
      <div className="mt-5 flex flex-wrap gap-2">
        {chips.map((chip) => (
          <span key={chip} className="rounded-full bg-[#009FE3]/10 px-3 py-1 text-xs font-bold text-[#007DB3] dark:text-sky-300">
            {chip}
          </span>
        ))}
      </div>
    </article>
  );
}
