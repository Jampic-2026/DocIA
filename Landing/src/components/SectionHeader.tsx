type SectionHeaderProps = {
  badge?: string;
  title: string;
  subtitle?: string;
  align?: 'left' | 'center';
};

export default function SectionHeader({ badge, title, subtitle, align = 'left' }: SectionHeaderProps) {
  return (
    <div
      className={`grid max-w-3xl gap-4 ${align === 'center' ? 'mx-auto text-center' : 'text-left'}`}
    >
      {badge ? (
        <span className="inline-flex w-fit items-center gap-2 rounded-full border border-[#009FE3]/20 bg-[#009FE3]/10 px-3 py-2 text-xs font-extrabold text-[#007DB3] dark:text-sky-300">
          <span className="h-2 w-2 rounded-full bg-[#009FE3] shadow-[0_0_0_5px_rgba(0,159,227,0.14)]" />
          {badge}
        </span>
      ) : null}
      <h2 className="text-3xl font-black leading-tight text-slate-950 dark:text-white sm:text-4xl lg:text-5xl">
        {title}
      </h2>
      {subtitle ? <p className="text-base leading-7 text-slate-600 dark:text-slate-300 sm:text-lg">{subtitle}</p> : null}
    </div>
  );
}
