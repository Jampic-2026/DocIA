import { Award, Building2, ExternalLink, Mic2, Newspaper, Sparkles } from 'lucide-react';
import AnimatedWrapper from '../components/AnimatedWrapper';
import SectionHeader from '../components/SectionHeader';
import { landingContent, type Language } from '../config/content';
import { awards, media, type CredibilityItem, type CredibilityItemType } from '../config/links';
import { containerShell, sectionShell } from './ui';

type CopyMap = Record<string, { title: string; description: string }>;

const typeIcon: Record<CredibilityItemType, typeof Award> = {
  award: Award,
  press: Newspaper,
  interview: Mic2,
  institutional: Building2,
};

const typeClasses: Record<CredibilityItemType, string> = {
  award: 'border-[#009FE3]/25 bg-[#009FE3]/10 text-[#007DB3] dark:text-sky-200',
  press: 'border-[#E30613]/25 bg-[#E30613]/10 text-[#B4040F] dark:text-red-200',
  interview: 'border-emerald-400/30 bg-emerald-400/10 text-emerald-700 dark:text-emerald-200',
  institutional: 'border-violet-400/30 bg-violet-400/10 text-violet-700 dark:text-violet-200',
};

function MetaBadge({ item, label }: { item: CredibilityItem; label: string }) {
  const Icon = typeIcon[item.type];

  return (
    <span className={`inline-flex w-fit items-center gap-2 rounded-full border px-3 py-1.5 text-xs font-extrabold ${typeClasses[item.type]}`}>
      <Icon className="h-3.5 w-3.5" aria-hidden="true" />
      {label}
    </span>
  );
}

function AwardCard({ item, copy }: { item: CredibilityItem; copy: CopyMap[string] }) {
  return (
    <article className="group relative grid min-h-[440px] overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-xl shadow-slate-900/5 transition-all duration-300 hover:-translate-y-1 hover:shadow-2xl dark:border-white/10 dark:bg-white/[0.06] dark:shadow-black/20">
      <div className="relative h-52 overflow-hidden bg-slate-100 dark:bg-slate-900/80">
        <img
          src={item.image}
          alt={copy.title}
          loading="lazy"
          className={`h-full w-full object-cover transition-transform duration-500 group-hover:scale-105 ${item.imageClassName ?? ''}`}
        />
        <div className="absolute inset-0 bg-gradient-to-t from-slate-950/55 via-transparent to-transparent" />
        {item.year ? (
          <span className="absolute bottom-4 right-4 rounded-full bg-white/90 px-3 py-1.5 text-xs font-black text-slate-950 shadow-lg dark:bg-slate-950/85 dark:text-white">
            {item.year}
          </span>
        ) : null}
      </div>

      <div className="grid content-between gap-6 p-6">
        <div className="grid gap-3">
          <p className="text-xs font-black uppercase tracking-[0.18em] text-[#009FE3] dark:text-sky-300">{item.organization}</p>
          <h3 className="text-2xl font-black leading-tight text-slate-950 dark:text-white">{copy.title}</h3>
          <p className="text-sm leading-6 text-slate-600 dark:text-slate-300">{copy.description}</p>
        </div>
        <div className="h-1.5 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
          <div className="h-full w-2/3 rounded-full bg-[#009FE3]" />
        </div>
      </div>
    </article>
  );
}

function MediaCard({ item, copy, label, cta }: { item: CredibilityItem; copy: CopyMap[string]; label: string; cta: string }) {
  return (
    <article className="group grid overflow-hidden rounded-2xl border border-slate-200 bg-white/90 shadow-lg shadow-slate-900/5 transition-all duration-300 hover:-translate-y-1 hover:shadow-xl dark:border-white/10 dark:bg-white/[0.06] dark:shadow-black/20 sm:grid-cols-[9rem_1fr]">
      <div className="relative min-h-36 overflow-hidden bg-slate-100 dark:bg-slate-900/80">
        <img
          src={item.image}
          alt={copy.title}
          loading="lazy"
          className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
        />
        <div className="absolute inset-0 bg-gradient-to-tr from-slate-950/45 to-transparent" />
      </div>

      <div className="grid gap-4 p-5">
        <div className="flex flex-wrap items-center gap-2">
          <MetaBadge item={item} label={label} />
          {item.year ? <span className="text-xs font-bold text-slate-500 dark:text-slate-400">{item.year}</span> : null}
        </div>
        <div className="grid gap-2">
          <p className="text-xs font-black uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400">{item.organization}</p>
          <h3 className="text-lg font-black leading-snug text-slate-950 dark:text-white">{copy.title}</h3>
          <p className="text-sm leading-6 text-slate-600 dark:text-slate-300">{copy.description}</p>
        </div>
        {item.url ? (
          <a
            href={item.url}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex w-fit items-center gap-2 rounded-full border border-slate-200 bg-slate-50 px-4 py-2 text-xs font-extrabold text-slate-950 transition-colors hover:border-[#009FE3]/40 hover:text-[#007DB3] dark:border-white/10 dark:bg-white/[0.06] dark:text-white dark:hover:text-sky-200"
          >
            {cta}
            <ExternalLink className="h-3.5 w-3.5" aria-hidden="true" />
          </a>
        ) : null}
      </div>
    </article>
  );
}

export default function CredibilitySection({ language }: { language: Language }) {
  const content = landingContent[language].credibility;
  const awardCopy = content.awards as CopyMap;
  const mediaCopy = content.media as CopyMap;

  return (
    <section id="reconocimientos" className={`${sectionShell} bg-[radial-gradient(circle_at_15%_10%,rgba(0,159,227,0.14),transparent_28%),radial-gradient(circle_at_85%_25%,rgba(227,6,19,0.10),transparent_30%),linear-gradient(180deg,#f8fafc,#eef6fb)] dark:bg-[radial-gradient(circle_at_15%_10%,rgba(0,159,227,0.22),transparent_30%),radial-gradient(circle_at_88%_12%,rgba(227,6,19,0.18),transparent_28%),linear-gradient(180deg,#020617,#071525)]`}>
      <div className="pointer-events-none absolute inset-x-0 top-20 mx-auto h-72 max-w-5xl rounded-full bg-[#009FE3]/10 blur-3xl dark:bg-[#009FE3]/15" />
      <div className={containerShell}>
        <AnimatedWrapper>
          <SectionHeader title={content.title} subtitle={content.subtitle} align="center" />
        </AnimatedWrapper>

        <AnimatedWrapper delay={0.08}>
          <div className="mt-12 flex items-center justify-between gap-4">
            <div>
              <p className="inline-flex items-center gap-2 text-sm font-black uppercase tracking-[0.2em] text-[#007DB3] dark:text-sky-300">
                <Sparkles className="h-4 w-4" aria-hidden="true" />
                {content.awardsTitle}
              </p>
            </div>
            <div className="hidden h-px flex-1 bg-gradient-to-r from-[#009FE3]/35 to-transparent md:block" />
          </div>
        </AnimatedWrapper>

        <div className="mt-6 grid gap-5 lg:grid-cols-3">
          {awards.map((item, index) => (
            <AnimatedWrapper key={item.id} delay={0.12 + index * 0.05}>
              <AwardCard item={item} copy={awardCopy[item.id]} />
            </AnimatedWrapper>
          ))}
        </div>

        <AnimatedWrapper delay={0.18}>
          <div className="mt-16 flex items-center justify-between gap-4">
            <div>
              <p className="inline-flex items-center gap-2 text-sm font-black uppercase tracking-[0.2em] text-[#B4040F] dark:text-red-200">
                <Newspaper className="h-4 w-4" aria-hidden="true" />
                {content.mediaTitle}
              </p>
            </div>
            <div className="hidden h-px flex-1 bg-gradient-to-r from-[#E30613]/35 to-transparent md:block" />
          </div>
        </AnimatedWrapper>

        <div className="mt-6 grid gap-5 xl:grid-cols-2">
          {media.map((item, index) => (
            <AnimatedWrapper key={item.id} delay={0.22 + index * 0.04}>
              <MediaCard
                item={item}
                copy={mediaCopy[item.id]}
                label={content.typeLabels[item.type]}
                cta={content.ctas[item.type]}
              />
            </AnimatedWrapper>
          ))}
        </div>
      </div>
    </section>
  );
}
