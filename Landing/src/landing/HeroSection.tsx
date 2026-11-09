import AnimatedWrapper from '../components/AnimatedWrapper';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { productLinks } from '../config/links';
import { BarChart3, LockKeyhole, ShieldCheck, UsersRound } from 'lucide-react';

type HeroSectionProps = {
  language: Language;
};

const featureIcons = [ShieldCheck, LockKeyhole, UsersRound, BarChart3];

export default function HeroSection({ language }: HeroSectionProps) {
  const content = landingContent[language].hero;

  return (
    <section
      id="inicio"
      className="relative overflow-hidden bg-gradient-to-br from-white via-slate-50 to-cyan-50 px-4 py-20 dark:from-slate-950 dark:via-slate-950 dark:to-slate-900 sm:px-6 lg:px-8 lg:py-28"
    >
      <div className="pointer-events-none absolute left-[-10rem] top-[-8rem] h-96 w-96 rounded-full bg-blue-500/10 blur-3xl" />
      <div className="pointer-events-none absolute bottom-[-8rem] right-[-10rem] h-[28rem] w-[28rem] rounded-full bg-teal-400/20 blur-3xl" />

      <div className="container relative z-10 mx-auto grid max-w-7xl items-start gap-16 xl:grid-cols-[1.08fr_0.92fr]">
        <AnimatedWrapper>
          <div className="max-w-3xl">
            <h1 className="text-5xl font-black leading-[0.96] tracking-[-0.055em] text-slate-950 dark:text-white sm:text-6xl lg:text-7xl">
              {content.title}
            </h1>

            <p className="mt-7 max-w-2xl text-lg leading-8 text-slate-600 dark:text-slate-300">
              {content.subtitle}
            </p>

            <div className="mt-10 flex flex-col gap-4 sm:flex-row">
              <a
                href={productLinks.webApp}
                target="_blank"
                rel="noreferrer"
                className="inline-flex min-h-14 items-center justify-center rounded-2xl bg-[#009FE3] px-7 text-base font-extrabold text-white shadow-xl shadow-[#009FE3]/25 transition-all duration-300 hover:-translate-y-1 hover:bg-[#0088C7] hover:shadow-2xl"
              >
                {content.primaryCta}
                <span className="ml-3">→</span>
              </a>

              <a
                href={productLinks.androidApk}
                download
                className="inline-flex min-h-14 items-center justify-center rounded-2xl bg-[#E30613] px-7 text-base font-extrabold text-white shadow-xl shadow-[#E30613]/20 transition-all duration-300 hover:-translate-y-1 hover:bg-[#C90511] hover:shadow-2xl"
              >
                {content.secondaryCta}
                <span className="ml-3">→</span>
              </a>
            </div>

          </div>
        </AnimatedWrapper>

        <AnimatedWrapper delay={0.1}>
          <div className="relative mx-auto mt-0 w-full max-w-4xl xl:-mt-8 2xl:-mt-14">
            <div className="absolute inset-0 rounded-[3rem] bg-gradient-to-br from-blue-500/10 to-teal-400/20 blur-3xl" />

            <img
              src="/images/dashboard_light.png"
              alt={content.dashboardAlt}
              className="relative z-10 w-full rounded-[1.5rem] shadow-2xl shadow-slate-900/10 dark:hidden"
            />

            <img
              src="/images/dashboard_dark.png"
              alt={content.dashboardAlt}
              className="relative z-10 hidden w-full rounded-[1.5rem] shadow-2xl shadow-black/40 dark:block"
            />

            <img
              src="/images/mobile_light.png"
              alt={content.mobileAlt}
              className="absolute -bottom-6 right-0 z-20 w-[26%] min-w-[100px] max-w-[200px] drop-shadow-2xl dark:hidden sm:-bottom-8 sm:right-4 xl:right-[-1.5rem]"
            />

            <img
              src="/images/mobile_dark.png"
              alt={content.mobileAlt}
              className="absolute -bottom-6 right-0 z-20 hidden w-[26%] min-w-[100px] max-w-[200px] drop-shadow-2xl dark:block sm:-bottom-8 sm:right-4 xl:right-[-1.5rem]"
            />
          </div>
        </AnimatedWrapper>

        <div className="col-span-full mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {content.features.map((feature, index) => {
            const Icon = featureIcons[index] ?? ShieldCheck;

            return (
              <div
                key={feature.title}
                className="flex min-h-[120px] items-start gap-4 rounded-2xl border border-slate-200 bg-white/85 p-5 shadow-sm backdrop-blur transition-all duration-300 hover:-translate-y-1 hover:shadow-md dark:border-slate-700 dark:bg-slate-900/70"
              >
                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-600 dark:bg-blue-950/50 dark:text-blue-300">
                  <Icon size={23} strokeWidth={2.4} />
                </div>

                <div>
                  <p className="text-base font-extrabold leading-6 text-slate-950 dark:text-white">
                    {feature.title}
                  </p>

                  <p className="mt-1 text-sm leading-6 text-slate-500 dark:text-slate-400">
                    {feature.description}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
