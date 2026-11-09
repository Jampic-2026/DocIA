import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { brand } from '../config/brand';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { containerShell, darkSectionShell } from './ui';

export default function TrustSection({ language }: { language: Language }) {
  const content = landingContent[language].trust;

  return (
    <section className={darkSectionShell}>
      <div className={containerShell}>
        <AnimatedWrapper className="[&_h2]:!text-white [&_p]:!text-slate-300">
          <SectionHeader title={content.title} />
        </AnimatedWrapper>
        <AnimatedWrapper delay={0.08}>
          <div className="mt-10 grid gap-8 lg:grid-cols-[0.8fr_1.2fr] lg:items-center">
            <div className="relative grid min-h-[360px] place-items-center rounded-3xl border border-white/10 bg-white/[0.06] p-8" aria-hidden="true">
              <div className="absolute inset-8 rounded-full border border-dashed border-teal-300/25" />
              <div className="grid gap-3">
                {content.pillars.map((item) => (
                  <span key={item} className="rounded-2xl border border-white/10 bg-white/10 px-5 py-3 text-sm font-black text-slate-200">
                    {item}
                  </span>
                ))}
              </div>
              <div className="absolute bottom-8 rounded-full bg-white/10 px-5 py-2"><img src={brand.logos.negative} alt={brand.name} className="h-7 w-auto object-contain" /></div>
            </div>
            <div className="grid gap-4 md:grid-cols-3">
              {content.cards.map((item, index) => (
                <article key={item} className="rounded-2xl border border-white/10 bg-white/[0.08] p-5 shadow-xl shadow-black/20">
                  <span className="grid h-10 w-10 place-items-center rounded-xl bg-white/10 text-xs font-black text-sky-200">0{index + 1}</span>
                  <h3 className="mt-6 text-lg font-black leading-snug text-white">{item}</h3>
                </article>
              ))}
            </div>
          </div>
        </AnimatedWrapper>
      </div>
    </section>
  );
}
