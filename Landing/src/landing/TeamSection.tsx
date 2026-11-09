import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { landingContent } from '../config/content';
import type { Language } from '../config/content';
import { containerShell, sectionShell } from './ui';

export default function TeamSection({ language }: { language: Language }) {
  const content = landingContent[language].team;

  return (
    <section id="equipo" className={sectionShell}>
      
      <div className={containerShell}>
        <AnimatedWrapper>
          <SectionHeader
            title={content.title}
            subtitle={content.subtitle}
          />
        </AnimatedWrapper>

        <AnimatedWrapper delay={0.08}>
          <div className="mt-10 grid gap-6 md:grid-cols-2 xl:grid-cols-3">
            {content.members.map((member) => (
              <article
                key={member.role}
                className="overflow-hidden rounded-3xl border border-slate-200 bg-white p-6 shadow-lg shadow-slate-900/5 transition-all hover:-translate-y-1 hover:shadow-xl dark:border-white/10 dark:bg-white/[0.06]"
              >
                <div className="mx-auto mb-5 aspect-[4/5] w-full max-w-[220px] overflow-hidden rounded-2xl bg-slate-100 dark:bg-slate-800">
                  <img
                    src={member.image} 
                    alt={member.name}
                    className="h-full w-full object-cover"
                    loading="lazy"
                  />
                </div>

                <div className="text-center">
                  <h3 className="text-2xl font-black text-slate-950 dark:text-white">
                    {member.name}
                  </h3>

                  <p className="mt-2 text-sm font-bold text-teal-700 dark:text-teal-300">
                    {member.role}
                  </p>

                  <p className="mt-4 text-sm leading-6 text-slate-600 dark:text-slate-300">
                    {member.description}
                  </p>
                </div>
              </article>
            ))}
          </div>
        </AnimatedWrapper>
      </div>
    </section>
  );
}
