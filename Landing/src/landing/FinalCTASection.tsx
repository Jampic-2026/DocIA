import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { productLinks } from '../config/links';
import { containerShell, primaryButton, secondaryButton } from './ui';

export default function FinalCTASection({ language }: { language: Language }) {
  const content = landingContent[language].finalCta;

  return (
    <section id="contacto" className="relative overflow-hidden bg-slate-50 py-20 dark:bg-slate-950 sm:py-24">
      <div className={containerShell}>
        <AnimatedWrapper>
          <div className="grid gap-8 overflow-hidden rounded-3xl border border-white/15 bg-gradient-to-br from-slate-950 via-slate-900 to-teal-900 p-8 text-white shadow-2xl shadow-slate-900/20 lg:grid-cols-[1fr_240px] lg:items-center lg:p-12">
            <div className="[&_h2]:!text-white [&_p]:!text-slate-300">
              <SectionHeader title={content.title} subtitle={content.subtitle} />
              <div className="mt-8 flex flex-col gap-4 sm:flex-row">
                <a className={primaryButton} href={productLinks.webApp} target="_blank" rel="noreferrer">
                  {content.primaryCta}
                </a>
                <a
                  className={secondaryButton}
                  href={productLinks.androidApk}
                  download
                >
                  {content.secondaryCta}
                </a>
              </div>
            </div>
            <div className="grid min-h-56 place-items-center rounded-3xl border border-white/10 bg-white/10 p-6" aria-hidden="true">
              <div className="text-center">
                <span className="text-sm font-black text-teal-200">24/7</span>
                <strong className="mx-auto my-4 grid h-24 w-24 place-items-center rounded-full bg-red-500 text-xl font-black text-white shadow-[0_0_42px_rgba(239,68,68,0.55)]">
                  SOS
                </strong>
                <p className="text-sm font-bold text-slate-300">{content.care}</p>
              </div>
            </div>
          </div>
        </AnimatedWrapper>
      </div>
    </section>
  );
}
