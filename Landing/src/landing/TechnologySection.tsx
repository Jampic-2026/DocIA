import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { landingContent } from '../config/content';
import { partnerLogos } from '../config/links';
import type { Language } from '../config/content';
import { containerShell, sectionShell } from './ui';


export default function TechnologySection({ language }: { language: Language }) {
  const content = landingContent[language].technology;
  const marqueeItems = [...partnerLogos, ...partnerLogos];

  return (
    <section id="tecnologia" className={sectionShell}>
      <div className={containerShell}>
        <AnimatedWrapper>
          <SectionHeader title={content.title} subtitle={content.subtitle} align="center" />
        </AnimatedWrapper>
      </div>

      <AnimatedWrapper delay={0.08}>
        <div className="mt-12 overflow-hidden" aria-label={content.title}>
          <div className="flex w-max animate-marquee gap-4 px-4">
            {marqueeItems.map((partner, index) => (
              <article
                key={`${partner.name}-${index}`}
                className="grid h-28 w-64 shrink-0 place-items-center rounded-2xl border border-slate-200 bg-white/85 p-4 shadow-sm shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.06]"
              >
                <div
                  className={`grid h-20 w-52 place-items-center rounded-xl bg-white px-5 py-3 ${partner.surfaceClassName ?? ''}`}
                >
                  <img
                    src={partner.image}
                    alt={partner.name}
                    loading="lazy"
                    className={`h-14 w-40 object-contain ${partner.imageClassName ?? ''}`}
                  />
                </div>
              </article>
            ))}
          </div>
        </div>
      </AnimatedWrapper>
    </section>
  );
}
