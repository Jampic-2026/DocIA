import AnimatedWrapper from '../components/AnimatedWrapper';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { containerShell, sectionShell } from './ui';

export default function MissionVisionSection({ language }: { language: Language }) {
  const content = landingContent[language].missionVision;

  return (
    <section className={sectionShell}>
      <div className={`${containerShell} grid items-stretch gap-5 lg:grid-cols-2`}>
        <AnimatedWrapper className="h-full">
          <article className="flex h-full min-h-[240px] flex-col rounded-3xl border border-slate-200 bg-white p-6 shadow-xl shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.06]">
            <span className="text-xs font-black uppercase tracking-wider text-teal-600 dark:text-teal-300">
              {content.subtitleMission}
            </span>

            <h2 className="mt-8 text-2xl font-black text-slate-950 dark:text-white sm:text-3xl">
              {content.missionTitle}
            </h2>

            <p className="mt-3 text-sm leading-7 text-slate-600 dark:text-slate-300 sm:text-base">
              {content.mission}
            </p>
          </article>
        </AnimatedWrapper>

        <AnimatedWrapper delay={0.08} className="h-full">
          <article className="flex h-full min-h-[240px] flex-col rounded-3xl border border-teal-200 bg-gradient-to-br from-teal-50 via-white to-sky-50 p-6 shadow-xl shadow-teal-900/5 dark:border-white/10 dark:bg-gradient-to-br dark:from-slate-900 dark:to-cyan-950 dark:text-white dark:shadow-slate-900/10">
            <span className="text-xs font-black uppercase tracking-wider text-sky-600 dark:text-sky-300">
              {content.subtitleVision}
            </span>

            <h2 className="mt-8 text-2xl font-black text-slate-950 dark:text-white sm:text-3xl">
              {content.visionTitle}
            </h2>

            <p className="mt-3 text-sm leading-7 text-slate-600 dark:text-slate-300 sm:text-base">
              {content.vision}
            </p>
          </article>
        </AnimatedWrapper>

        <AnimatedWrapper delay={0.14} className="lg:col-span-2">
          <strong className="block rounded-3xl border border-teal-300/40 bg-teal-50 p-5 text-center text-lg font-black text-teal-800 shadow-sm dark:border-teal-400/20 dark:bg-teal-400/10 dark:text-teal-200 sm:text-xl">
            {content.tagline}
          </strong>
        </AnimatedWrapper>
      </div>
    </section>
  );
}