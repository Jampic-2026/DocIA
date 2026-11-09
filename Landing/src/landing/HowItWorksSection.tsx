import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { containerShell, sectionShell } from './ui';

export default function HowItWorksSection({ language }: { language: Language }) {
  const content = landingContent[language].howItWorks;

  return (
    <section id="como-funciona" className={sectionShell}>
      <div className={containerShell}>
        <AnimatedWrapper>
          <SectionHeader title={content.title} />
        </AnimatedWrapper>
        <AnimatedWrapper delay={0.08}>
          <div className="relative mt-10 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <div className="absolute left-8 right-8 top-16 hidden h-px bg-gradient-to-r from-teal-500/0 via-teal-500/40 to-teal-500/0 xl:block" />
            {content.steps.map((step, index) => (
              <article key={step.title} className="relative rounded-2xl border border-slate-200 bg-white/85 p-6 shadow-lg shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.06]">
                <span className="text-xs font-black text-[#007DB3] dark:text-sky-300">0{index + 1}</span>
                <div className="my-8 h-12 w-12 rounded-2xl bg-[#E30613] shadow-lg shadow-[#E30613]/20" aria-hidden="true" />
                <h4 className="text-lg font-black text-slate-950 dark:text-white">{step.title}</h4>
                <p className="mt-3 text-sm leading-6 text-slate-600 dark:text-slate-300">{step.description}</p>
              </article>
            ))}
          </div>
        </AnimatedWrapper>
      </div>
    </section>
  );
}
