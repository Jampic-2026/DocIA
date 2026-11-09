import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { containerShell, sectionShell } from './ui';
import { Bell, Building2, CalendarDays, ClipboardList, FileText,
  MapPin, Mic, ShieldCheck, Smartphone, Stethoscope, Users, Video,
} from 'lucide-react';

export default function ModulesSection({ language }: { language: Language }) {
  const content = landingContent[language].modules;
  const labels = content.labels;

  const emergency = content.cards[0];
  const telemedicine = content.cards[1];
  const history = content.cards[2];
  const professional = content.cards[3];
  const operations = content.cards[4];
  const patientApp = content.cards[5];
  const family = content.cards[6];

  const emergencyFeatures = [
    {
      icon: MapPin,
      tone: 'red',
      title: labels.emergencyFeatures[0].title,
      description: labels.emergencyFeatures[0].description,
    },
    {
      icon: Bell,
      tone: 'amber',
      title: labels.emergencyFeatures[1].title,
      description: labels.emergencyFeatures[1].description,
    },
    {
      icon: ShieldCheck,
      tone: 'emerald',
      title: labels.emergencyFeatures[2].title,
      description: labels.emergencyFeatures[2].description,
    },
  ];

  const telemedicineFeatures = [
    {
      icon: Video,
      title: labels.telemedicineFeatures[0].title,
      description: labels.telemedicineFeatures[0].description,
    },
    {
      icon: FileText,
      title: labels.telemedicineFeatures[1].title,
      description: labels.telemedicineFeatures[1].description,
    },
    {
      icon: CalendarDays,
      title: labels.telemedicineFeatures[2].title,
      description: labels.telemedicineFeatures[2].description,
    },
  ];

  const iconTone = {
    red: 'bg-red-50 text-[#E30613] dark:bg-[#E30613]/10 dark:text-red-300',
    amber: 'bg-amber-50 text-amber-500 dark:bg-amber-500/10 dark:text-amber-300',
    emerald: 'bg-emerald-50 text-emerald-600 dark:bg-emerald-500/10 dark:text-emerald-300',
  };

  return (
    <section id="modulos" className={sectionShell}>
      <div className={containerShell}>
        <AnimatedWrapper>
          <SectionHeader title={content.title} align="center" />
        </AnimatedWrapper>

        <AnimatedWrapper delay={0.08}>
          <div className="mt-10 grid gap-5 lg:grid-cols-6" aria-label={content.title}>
            <article className="rounded-3xl border border-[#E30613]/20 bg-gradient-to-br from-[#E30613]/10 via-white to-sky-50 p-6 shadow-xl shadow-slate-900/5 dark:border-red-400/20 dark:from-[#E30613]/10 dark:via-white/[0.06] dark:to-sky-500/10 lg:col-span-3">
              <div>
                <span className="text-xs font-black uppercase tracking-wide text-[#E30613]">
                  {labels.prioritySystem}
                </span>

                <h3 className="mt-3 text-2xl font-black text-slate-950 dark:text-white">
                  {emergency.title}
                </h3>

                <p className="mt-3 text-sm leading-6 text-slate-600 dark:text-slate-300">
                  {emergency.description}
                </p>

                <div className="mt-6 grid gap-4">
                  {emergencyFeatures.map((feature) => {
                    const Icon = feature.icon;

                    return (
                      <div key={feature.title} className="flex gap-4">
                        <div
                          className={`grid h-11 w-11 shrink-0 place-items-center rounded-xl ${
                            iconTone[feature.tone as keyof typeof iconTone]
                          }`}
                        >
                          <Icon size={22} strokeWidth={2.4} />
                        </div>

                        <div>
                          <h4 className="text-sm font-black text-slate-950 dark:text-white">
                            {feature.title}
                          </h4>
                          <p className="mt-1 text-sm leading-6 text-slate-600 dark:text-slate-300">
                            {feature.description}
                          </p>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </article>

            <article className="grid gap-6 rounded-3xl border border-slate-200 bg-white/85 p-6 shadow-xl shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.06] lg:col-span-3 lg:grid-cols-[0.9fr_1.1fr]">
              <div>
                <span className="text-xs font-black uppercase tracking-wide text-sky-600 dark:text-sky-300">
                  {labels.digitalVisit}
                </span>

                <h3 className="mt-3 text-2xl font-black text-slate-950 dark:text-white">
                  {telemedicine.title}
                </h3>

                <p className="mt-3 text-sm leading-6 text-slate-600 dark:text-slate-300">
                  {telemedicine.description}
                </p>

                <div className="mt-6 grid gap-4">
                  {telemedicineFeatures.map((feature) => {
                    const Icon = feature.icon;

                    return (
                      <div key={feature.title} className="flex gap-4">
                        <div className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-sky-50 text-sky-600 dark:bg-sky-500/10 dark:text-sky-300">
                          <Icon size={22} strokeWidth={2.4} />
                        </div>

                        <div>
                          <h4 className="text-sm font-black text-slate-950 dark:text-white">
                            {feature.title}
                          </h4>
                          <p className="mt-1 text-sm leading-6 text-slate-600 dark:text-slate-300">
                            {feature.description}
                          </p>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              <div
                className="flex flex-col justify-center rounded-3xl border border-slate-200 bg-slate-50 p-5 dark:border-white/10 dark:bg-slate-950/70"
                aria-hidden="true"
              >
                <div className="grid h-36 place-items-center rounded-2xl bg-gradient-to-br from-sky-500/20 to-teal-500/20">
                  <span className="h-20 w-20 rounded-full bg-gradient-to-br from-slate-700 to-slate-950 ring-8 ring-white/70 dark:ring-white/10" />
                </div>

                <div className="mt-4 flex justify-center gap-3">
                  <span className="grid h-10 w-10 place-items-center rounded-full bg-white text-slate-700 shadow-sm dark:bg-white/10 dark:text-slate-200">
                    <Mic size={18} />
                  </span>
                  <span className="grid h-10 w-10 place-items-center rounded-full bg-white text-slate-700 shadow-sm dark:bg-white/10 dark:text-slate-200">
                    <Video size={18} />
                  </span>
                  <span className="grid h-10 w-10 place-items-center rounded-full bg-[#E30613] text-white shadow-lg shadow-[#E30613]/25">
                    <Stethoscope size={18} />
                  </span>
                </div>

                <div className="mt-5 rounded-2xl border border-slate-200 bg-white/70 p-4 shadow-sm dark:border-white/10 dark:bg-white/5">
                  <div className="flex items-center gap-3">
                    <span className="h-2.5 w-2.5 rounded-full bg-emerald-500" />
                    <strong className="text-sm font-black text-slate-950 dark:text-white">
                      {labels.doctorConnected}
                    </strong>
                  </div>

                  <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-slate-300">
                    {labels.doctorConnectedDescription}
                  </p>
                </div>
              </div>
            </article>

            <article className="rounded-3xl border border-slate-200 bg-white/85 p-6 shadow-xl shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.06] lg:col-span-2">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <span className="text-xs font-black uppercase tracking-wide text-[#007DB3] dark:text-sky-300">
                    {labels.clinicalProgress}
                  </span>

                  <h3 className="mt-3 text-xl font-black text-slate-950 dark:text-white">
                    {history.title}
                  </h3>

                  <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-slate-300">
                    {history.description}
                  </p>
                </div>

                <ClipboardList className="hidden text-emerald-300 sm:block" size={70} strokeWidth={1.8} />
              </div>

              <div className="mt-6 grid gap-3" aria-hidden="true">
                {labels.historyItems.map((item) => (
                  <div
                    key={item}
                    className="flex items-center gap-3 rounded-2xl bg-slate-50 px-4 py-3 text-sm font-bold text-slate-600 dark:bg-white/10 dark:text-slate-300"
                  >
                    <span className="h-2 w-2 rounded-full bg-[#009FE3]" />
                    {item}
                  </div>
                ))}

                <div className="mt-2 h-2 rounded-full bg-gradient-to-r from-[#E30613] via-amber-500 to-emerald-500" />
              </div>
            </article>

            <article className="rounded-3xl border border-slate-200 bg-white/85 p-6 shadow-xl shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.06] lg:col-span-2">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <span className="text-xs font-black uppercase tracking-wide text-emerald-700 dark:text-emerald-300">
                    {labels.support}
                  </span>

                  <h3 className="mt-3 text-xl font-black text-slate-950 dark:text-white">
                    {family.title}
                  </h3>

                  <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-slate-300">
                    {family.description}
                  </p>
                </div>

                <div className="hidden items-center gap-3 sm:flex">
                  <div className="grid h-14 w-14 place-items-center rounded-full bg-[#009FE3] font-black text-white shadow-lg shadow-[#009FE3]/20">
                    P
                  </div>
                  <div className="h-1 w-12 rounded-full bg-[#009FE3]/40" />
                  <div className="grid h-14 w-14 place-items-center rounded-full bg-sky-500 font-black text-white shadow-lg shadow-sky-500/20">
                    F
                  </div>
                </div>
              </div>

              <div className="mt-6 grid gap-3">
                {labels.familyItems.map((item) => (
                  <div key={item.title} className="flex gap-3">
                    <div className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-emerald-50 text-emerald-600 dark:bg-emerald-500/10 dark:text-emerald-300">
                      <Users size={18} />
                    </div>
                    <div>
                      <strong className="text-sm font-black text-slate-950 dark:text-white">
                        {item.title}
                      </strong>
                      <p className="text-sm leading-5 text-slate-600 dark:text-slate-300">
                        {item.description}
                      </p>
                    </div>
                  </div>
                ))}

                <strong className="mt-1 w-fit rounded-full bg-emerald-500/10 px-3 py-2 text-xs font-black text-emerald-700 dark:text-emerald-300">
                  {labels.notificationSent}
                </strong>
              </div>
            </article>

            <article className="rounded-3xl border border-slate-200 bg-white/85 p-6 shadow-xl shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.06] lg:col-span-2">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <span className="text-xs font-black uppercase tracking-wide text-violet-700 dark:text-violet-300">
                    {labels.careTeam}
                  </span>

                  <h3 className="mt-3 text-xl font-black text-slate-950 dark:text-white">
                    {professional.title}
                  </h3>

                  <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-slate-300">
                    {professional.description}
                  </p>
                </div>

                <div className="hidden rounded-full bg-violet-100 p-5 text-violet-600 dark:bg-violet-500/10 dark:text-violet-300 sm:block">
                  <Users size={46} />
                </div>
              </div>

              <div className="mt-6 grid gap-3" aria-hidden="true">
                {labels.professionalItems.map((item) => (
                  <div
                    key={item}
                    className="flex items-center justify-between rounded-2xl bg-violet-50 px-4 py-3 text-sm font-bold text-slate-600 dark:bg-violet-500/10 dark:text-slate-300"
                  >
                    <span>{item}</span>
                    <span className="h-2 w-2 rounded-full bg-violet-500" />
                  </div>
                ))}
              </div>
            </article>

            <article className="grid gap-6 rounded-3xl border border-cyan-200 bg-gradient-to-br from-cyan-50 via-white to-teal-50 p-6 text-slate-950 shadow-xl shadow-slate-900/5 dark:border-white/10 dark:from-slate-900 dark:to-cyan-950 dark:text-white dark:shadow-slate-900/10 lg:col-span-6 lg:grid-cols-[0.85fr_1.15fr]">
              <div>
                <span className="text-xs font-black uppercase tracking-wide text-[#007DB3] dark:text-teal-200">
                  {labels.institutionalOps}
                </span>

                <h3 className="mt-3 text-2xl font-black">
                  {operations.title}
                </h3>

                <p className="mt-3 text-sm leading-6 text-slate-600 dark:text-slate-300">
                  {operations.description}
                </p>
              </div>

              <div className="grid gap-4 md:grid-cols-3" aria-hidden="true">
                <div className="flex gap-4 rounded-2xl border border-cyan-200 bg-white/70 p-5 shadow-sm dark:border-white/10 dark:bg-white/10">
                  <div className="grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-teal-50 text-[#009FE3] dark:bg-[#009FE3]/10 dark:text-sky-300">
                    <Users size={30} />
                  </div>

                  <div>
                    <strong className="text-3xl font-black">128</strong>
                    <span className="block text-sm font-bold text-slate-700 dark:text-slate-300">
                      {labels.users}
                    </span>
                    <span className="mt-1 block text-sm leading-5 text-slate-600 dark:text-slate-300">
                      {labels.userMetricDescription}
                    </span>
                  </div>
                </div>

                <div className="flex gap-4 rounded-2xl border border-cyan-200 bg-white/70 p-5 shadow-sm dark:border-white/10 dark:bg-white/10">
                  <div className="grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-teal-50 text-[#009FE3] dark:bg-[#009FE3]/10 dark:text-sky-300">
                    <Building2 size={30} />
                  </div>

                  <div>
                    <strong className="text-3xl font-black">3</strong>
                    <span className="block text-sm font-bold text-slate-700 dark:text-slate-300">
                      {labels.sites}
                    </span>
                    <span className="mt-1 block text-sm leading-5 text-slate-600 dark:text-slate-300">
                      {labels.siteMetricDescription}
                    </span>
                  </div>
                </div>

                <div className="flex gap-4 rounded-2xl border border-cyan-200 bg-white/70 p-5 shadow-sm dark:border-white/10 dark:bg-white/10">
                  <div className="grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-teal-50 text-[#009FE3] dark:bg-[#009FE3]/10 dark:text-sky-300">
                    <Smartphone size={30} />
                  </div>

                  <div>
                    <strong className="text-xl font-black">
                      {patientApp.title}
                    </strong>
                    <span className="mt-1 block text-sm leading-5 text-slate-600 dark:text-slate-300">
                      {labels.patientAppMetric}
                    </span>
                  </div>
                </div>
              </div>
            </article>
          </div>
        </AnimatedWrapper>
      </div>
    </section>
  );
}
