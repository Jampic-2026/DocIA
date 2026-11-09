import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { containerShell, sectionShell } from './ui';

export default function ProblemSection({ language }: { language: Language }) {
  const content = landingContent[language].problem;

  return (
    <section id="soluciones" className={sectionShell}>
      <div className={`${containerShell} grid gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:items-center`}>
        <AnimatedWrapper>
          <SectionHeader title={content.title} subtitle={content.subtitle} />
        </AnimatedWrapper>
        <AnimatedWrapper delay={0.08}>
          <div className="relative grid min-h-[520px] gap-4 rounded-3xl border border-slate-200 bg-white/80 p-4 shadow-xl shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.05] sm:block">
            <div className="pointer-events-none absolute inset-8 hidden rounded-full border border-dashed border-red-400/30 sm:block" />
            <div className="pointer-events-none absolute left-1/2 top-1/2 hidden h-px w-[78%] -translate-x-1/2 bg-gradient-to-r from-transparent via-red-400/40 to-transparent sm:block" />
            <div className="pointer-events-none absolute left-1/2 top-1/2 hidden h-[78%] w-px -translate-y-1/2 bg-gradient-to-b from-transparent via-red-400/40 to-transparent sm:block" />
            <div className="z-10 grid place-items-center rounded-2xl border border-red-400/20 bg-red-500/10 p-5 text-center sm:absolute sm:left-1/2 sm:top-1/2 sm:h-44 sm:w-44 sm:-translate-x-1/2 sm:-translate-y-1/2 sm:rounded-full">
              <span className="text-xs font-black uppercase text-red-500">{content.patient}</span>
              <strong className="mt-2 text-lg font-black leading-tight text-slate-950 dark:text-white">
                {content.needCare}
              </strong>
            </div>
            {content.items.map((item, index) => (
              <article
                key={item}
                className={`z-10 rounded-2xl border border-slate-200 bg-white p-4 shadow-lg shadow-slate-900/5 dark:border-white/10 dark:bg-slate-950/85 sm:absolute sm:w-[220px] ${
                  index === 0
                    ? 'sm:left-5 sm:top-5'
                    : index === 1
                      ? 'sm:right-5 sm:top-5'
                      : index === 2
                        ? 'sm:bottom-5 sm:left-5'
                        : 'sm:bottom-5 sm:right-5'
                }`}
              >
                <span className="text-xs font-black text-red-500">0{index + 1}</span>
                <h3 className="mt-2 text-base font-black leading-snug text-slate-950 dark:text-white">{item}</h3>
              </article>
            ))}
          </div>
        </AnimatedWrapper>
      </div>
    </section>
  );
}
