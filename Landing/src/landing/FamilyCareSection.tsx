import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { containerShell, primaryButton, sectionShell } from './ui';

export default function FamilyCareSection({ language }: { language: Language }) {
  const content = landingContent[language].familyCare;

  return (
    <section className={sectionShell}>
      <div className={`${containerShell} grid gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:items-center`}>
        <AnimatedWrapper>
          <div>
            <SectionHeader title={content.title} subtitle={content.subtitle} />
            <ul className="mt-8 grid gap-3">
              {content.items.map((item) => (
                <li key={item} className="flex gap-3 rounded-2xl border border-slate-200 bg-white/75 p-4 text-sm font-bold text-slate-700 shadow-sm dark:border-white/10 dark:bg-white/[0.06] dark:text-slate-200">
                  <span className="mt-1 h-2.5 w-2.5 shrink-0 rounded-full bg-[#009FE3] shadow-[0_0_18px_rgba(20,184,166,0.45)]" />
                  {item}
                </li>
              ))}
            </ul>
          </div>
        </AnimatedWrapper>
        <AnimatedWrapper delay={0.08}>
          <div className="relative mx-auto grid min-h-[520px] max-w-lg place-items-center">
            <div className="absolute inset-8 rounded-full bg-[#009FE3]/10 blur-3xl" />
            <div className="relative grid w-[min(360px,100%)] gap-4 rounded-[2rem] border border-slate-200 bg-white p-5 shadow-2xl shadow-slate-900/10 dark:border-white/10 dark:bg-slate-950">
              <div className="w-fit rounded-full bg-emerald-500/10 px-3 py-1 text-xs font-black text-emerald-600 dark:text-emerald-300">{content.mockup.status}</div>
              <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4 dark:border-white/10 dark:bg-white/[0.06]">
                <span className="text-xs font-bold text-slate-500 dark:text-slate-400">{content.mockup.patient}</span>
                <strong className="mt-1 block text-lg font-black text-slate-950 dark:text-white">Valeria M.</strong>
              </div>
              <div className="relative rounded-2xl border border-slate-200 bg-slate-50 p-4 dark:border-white/10 dark:bg-white/[0.06]">
                <span className="text-xs font-bold text-slate-500 dark:text-slate-400">{content.mockup.relative}</span>
                <strong className="mt-1 block text-lg font-black text-slate-950 dark:text-white">Carlos M.</strong>
              </div>
              <div className="rounded-2xl border border-[#009FE3]/20 bg-[#009FE3]/10 p-4">
                <span className="text-xs font-bold text-[#007DB3] dark:text-sky-300">{content.mockup.lastCare}</span>
                <strong className="mt-1 block text-base font-black text-slate-950 dark:text-white">{content.mockup.telemedicine}</strong>
              </div>
              <button type="button" className={primaryButton}>{content.mockup.notify}</button>
            </div>
            <div className="absolute bottom-10 right-0 rounded-2xl border border-red-400/25 bg-[#E30613] p-4 text-white shadow-2xl shadow-red-500/30">
              <span className="text-xs font-black">SOS</span>
              <strong className="block text-sm font-black">{content.mockup.notifyed}</strong>
            </div>
          </div>
        </AnimatedWrapper>
      </div>
    </section>
  );
}
