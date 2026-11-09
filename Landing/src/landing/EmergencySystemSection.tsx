import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { containerShell, sectionShell } from './ui';

const levelStyles: Record<string, string> = {
  red: 'border-l-red-500 bg-[#E30613]/10',
  yellow: 'border-l-amber-500 bg-amber-500/10',
  green: 'border-l-emerald-500 bg-emerald-500/10',
};

export default function EmergencySystemSection({ language }: { language: Language }) {
  const content = landingContent[language].emergencySystem;

  return (
    <section className={sectionShell}>
      <div className={`${containerShell} grid gap-10 lg:grid-cols-[0.85fr_1.15fr] lg:items-center`}>
        <AnimatedWrapper>
          <SectionHeader title={content.title} subtitle={content.subtitle} />
        </AnimatedWrapper>
        <AnimatedWrapper delay={0.08}>
          <div className="grid gap-6 rounded-3xl border border-slate-200 bg-white/85 p-5 shadow-xl shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.05] lg:grid-cols-[220px_1fr]">
            <div className="relative grid place-items-center rounded-3xl bg-slate-100/80 p-8 dark:bg-slate-950/70" aria-hidden="true">
              <div className="absolute inset-8 rounded-full bg-[#E30613]/10 blur-2xl" />
              <div className="relative grid justify-items-center gap-4">
                <span className="h-[90px] w-[90px] animate-pulse rounded-full bg-[#E30613] shadow-[0_0_44px_rgba(239,68,68,0.68)]" />
                <span className="h-10 w-1 rounded-full bg-slate-300 dark:bg-white/15" />
                <span className="h-[90px] w-[90px] rounded-full bg-amber-500 shadow-[0_0_42px_rgba(245,158,11,0.58)]" />
                <span className="h-10 w-1 rounded-full bg-slate-300 dark:bg-white/15" />
                <span className="h-[90px] w-[90px] rounded-full bg-emerald-500 shadow-[0_0_38px_rgba(34,197,94,0.5)]" />
              </div>
            </div>
            <div className="grid gap-4">
              {content.levels.map((level, index) => (
                <article
                  key={level.title}
                  className={`grid gap-4 rounded-2xl border border-slate-200 border-l-4 p-5 dark:border-white/10 ${levelStyles[level.color] ?? levelStyles.green}`}
                >
                  <div>
                    <span className="text-xs font-black text-slate-500 dark:text-slate-400">0{index + 1}</span>
                    <h3 className="mt-1 text-lg font-black text-slate-950 dark:text-white">{level.title}</h3>
                  </div>
                  <ul className="grid gap-2 text-sm leading-6 text-slate-600 dark:text-slate-300">
                    {level.examples.map((example) => (
                      <li key={example} className="flex gap-2">
                        <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-current opacity-70" />
                        {example}
                      </li>
                    ))}
                  </ul>
                </article>
              ))}
              <aside className="rounded-2xl border border-[#009FE3]/20 bg-[#009FE3]/10 p-5">
                <span className="text-xs font-black uppercase text-[#007DB3] dark:text-sky-300">
                  {content.sideTitle}
                </span>
                <strong className="mt-2 block text-lg font-black leading-snug text-slate-950 dark:text-white">
                  {content.sideNote}
                </strong>
              </aside>
            </div>
          </div>
        </AnimatedWrapper>
      </div>
    </section>
  );
}
