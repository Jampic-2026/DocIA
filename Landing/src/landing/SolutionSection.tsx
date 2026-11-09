import AnimatedWrapper from '../components/AnimatedWrapper';
import FeatureCard from '../components/FeatureCard';
import SectionHeader from '../components/SectionHeader';
import { brand } from '../config/brand';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { containerShell, sectionShell } from './ui';

export default function SolutionSection({ language }: { language: Language }) {
  const content = landingContent[language].solution;

  return (
    <section className={sectionShell}>
      <div className={containerShell}>
        <AnimatedWrapper>
          <SectionHeader title={content.title} />
        </AnimatedWrapper>
        <AnimatedWrapper delay={0.08}>
          <div className="mt-10 grid gap-8 lg:grid-cols-[0.9fr_1.1fr] lg:items-center">
            <div className="relative min-h-[440px] overflow-hidden rounded-3xl border border-slate-200 bg-white/80 shadow-xl shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.05]" aria-hidden="true">
              <div className="absolute left-1/2 top-1/2 h-64 w-64 -translate-x-1/2 -translate-y-1/2 animate-pulse rounded-full border border-dashed border-[#009FE3]/30" />
              <div className="absolute left-1/2 top-1/2 h-[22rem] w-[22rem] -translate-x-1/2 -translate-y-1/2 rounded-full border border-dashed border-sky-400/20" />
              <div className="absolute left-1/2 top-1/2 grid h-40 w-40 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full bg-gradient-to-br from-slate-900 to-[#007DB3] p-5 text-center text-white shadow-2xl shadow-[#009FE3]/20">
                <img src={brand.logos.negative} alt={brand.name} className="h-8 w-auto object-contain" />
                <strong className="text-lg font-black leading-tight">{content.ecosystem}</strong>
              </div>
              {content.cards.slice(0, 6).map((item, index) => (
                <span
                  key={item.title}
                  className={`absolute max-w-32 rounded-full border border-[#009FE3]/25 bg-white px-3 py-2 text-center text-xs font-black text-slate-950 shadow-lg shadow-slate-900/5 dark:bg-slate-950 dark:text-white ${
                    index === 0
                      ? 'left-1/2 top-5 -translate-x-1/2'
                      : index === 1
                        ? 'right-5 top-28'
                        : index === 2
                          ? 'bottom-28 right-8'
                          : index === 3
                            ? 'bottom-5 left-1/2 -translate-x-1/2'
                            : index === 4
                              ? 'bottom-28 left-8'
                              : 'left-5 top-28'
                  }`}
                >
                  {item.title}
                </span>
              ))}
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              {content.cards.map((item, index) => (
                <FeatureCard key={item.title} title={item.title} description={item.description} index={index} />
              ))}
            </div>
          </div>
        </AnimatedWrapper>
      </div>
    </section>
  );
}
