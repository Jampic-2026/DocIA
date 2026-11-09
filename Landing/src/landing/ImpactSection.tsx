import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { brand } from '../config/brand';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { containerShell, darkSectionShell } from './ui';

export default function ImpactSection({ language }: { language: Language }) {
  const content = landingContent[language].impact;

  return (
    <section className={darkSectionShell}>
      <div className={containerShell}>
        <AnimatedWrapper className="[&_h2]:!text-white [&_p]:!text-slate-300">
          <SectionHeader title={content.title} align="center" />
        </AnimatedWrapper>
        <AnimatedWrapper delay={0.08}>
          <div className="mt-12 grid gap-8 lg:grid-cols-[0.9fr_1.1fr] lg:items-center">
            <div className="relative grid min-h-[360px] place-items-center rounded-3xl border border-white/10 bg-white/[0.06]" aria-hidden="true">
              <span className="absolute h-52 w-52 animate-pulse rounded-full border border-[#009FE3]/25" />
              <span className="absolute h-72 w-72 rounded-full border border-sky-300/15" />
              <span className="absolute h-[21rem] w-[21rem] rounded-full border border-emerald-300/10" />
              <div className="grid h-32 w-32 place-items-center rounded-full bg-white/10 p-5 ring-1 ring-white/15"><img src={brand.logos.negative} alt={brand.name} className="w-full object-contain" /></div>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              {content.metrics.map((metric, index) => (
                <article key={metric.value} className="rounded-3xl border border-white/10 bg-white/[0.08] p-6 shadow-2xl shadow-black/20">
                  <span className="text-xs font-black text-sky-200">0{index + 1}</span>
                  <strong className="mt-8 block text-4xl font-black text-white">{metric.value}</strong>
                  <p className="mt-3 text-sm leading-6 text-slate-300">{metric.label}</p>
                  <div className="mt-6 h-2 overflow-hidden rounded-full bg-white/10" aria-hidden="true">
                    <i className="block h-full rounded-full bg-gradient-to-r from-teal-400 to-sky-400" style={{ width: `${70 + index * 6}%` }} />
                  </div>
                </article>
              ))}
            </div>
          </div>
          <p className="mt-8 rounded-2xl border border-[#009FE3]/20 bg-[#009FE3]/10 p-5 text-sm leading-7 text-slate-200">
            <span className="mr-3 font-black text-sky-200">{content.projection}</span>
            {content.note}
          </p>
        </AnimatedWrapper>
      </div>
    </section>
  );
}
