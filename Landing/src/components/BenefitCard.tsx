type BenefitCardProps = {
  title: string;
  items: string[];
};

export default function BenefitCard({ title, items }: BenefitCardProps) {
  return (
    <article className="relative overflow-hidden rounded-2xl border border-slate-200 bg-white/85 p-6 shadow-lg shadow-slate-900/5 backdrop-blur dark:border-white/10 dark:bg-white/[0.06]">
      <div className="mb-5 h-12 w-12 rounded-2xl bg-[#009FE3] shadow-lg shadow-[#009FE3]/20" />
      <h3 className="text-xl font-black text-slate-950 dark:text-white">{title}</h3>
      <ul className="mt-5 grid gap-3">
        {items.map((item) => (
          <li key={item} className="flex gap-3 text-sm leading-6 text-slate-600 dark:text-slate-300">
            <span className="mt-2 h-2 w-2 shrink-0 rounded-full bg-[#009FE3]" />
            {item}
          </li>
        ))}
      </ul>
    </article>
  );
}
