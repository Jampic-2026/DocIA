import { useState } from 'react';
import ThemeToggle from '../components/ThemeToggle';
import { landingContent, type Language, type Theme } from '../config/content';
import { brand } from '../config/brand';
import { productLinks } from '../config/links';
import { primaryButton } from './ui';

type NavbarProps = {
  language: Language;
  setLanguage: (lang: Language) => void;
  theme: Theme;
  setTheme: (theme: Theme) => void;
};

export default function Navbar({ language, setLanguage, theme, setTheme }: NavbarProps) {
  const content = landingContent[language].nav;
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <nav className="sticky top-0 z-50 border-b border-slate-200/70 bg-white/85 shadow-lg shadow-slate-900/5 backdrop-blur-2xl dark:border-white/10 dark:bg-slate-950/80 dark:shadow-black/20">
      <div className="mx-auto flex min-h-[74px] w-full max-w-7xl items-center justify-between gap-4 px-4 sm:px-6 lg:px-8">
        <div className="flex items-center">
          <img
            src={theme === 'dark' ? brand.logos.negative : brand.logos.positive}
            alt={brand.name}
            className="h-10 w-auto object-contain sm:h-11"
          />
        </div>

        <div
          className={`absolute left-4 right-4 top-[calc(100%+0.75rem)] grid overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-2xl shadow-slate-900/10 dark:border-white/10 dark:bg-slate-950 lg:static lg:flex lg:items-center lg:gap-6 lg:border-0 lg:bg-transparent lg:shadow-none lg:dark:bg-transparent ${menuOpen ? 'grid' : 'hidden lg:flex'
            }`}
          aria-expanded={menuOpen}
        >
          {content.links.map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="border-b border-slate-100 px-4 py-3 text-sm font-bold text-slate-600 transition-colors hover:text-[#009FE3] dark:border-white/10 dark:text-slate-300 dark:hover:text-sky-300 lg:border-0 lg:p-0"
              onClick={() => setMenuOpen(false)}
            >
              {link.label}
            </a>
          ))}
        </div>

        <div className="flex items-center gap-3">
          <div className="inline-flex rounded-full border border-slate-200 bg-slate-100 p-1 dark:border-white/10 dark:bg-white/10">
            {(['es', 'en'] as Language[]).map((lang) => (
              <button
                key={lang}
                type="button"
                className={`rounded-full px-3 py-1.5 text-xs font-black transition-colors ${language === lang
                    ? 'bg-white text-slate-950 shadow-sm dark:bg-white/15 dark:text-white'
                    : 'text-slate-500 hover:text-slate-950 dark:text-slate-400 dark:hover:text-white'
                  }`}
                onClick={() => setLanguage(lang)}
              >
                {lang.toUpperCase()}
              </button>
            ))}
          </div>
          <ThemeToggle theme={theme} setTheme={setTheme} />
          <a
            className={`${primaryButton} hidden xl:inline-flex`}
            href={productLinks.webApp}
            target="_blank"
            rel="noreferrer"
          >
            {content.cta}
          </a>
          <button
            type="button"
            className="grid h-11 w-11 place-items-center rounded-full border border-slate-200 bg-white text-slate-950 dark:border-white/10 dark:bg-white/10 dark:text-white lg:hidden"
            aria-label={menuOpen ? 'Cerrar menú' : 'Abrir menú'}
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen((open) => !open)}
          >
            <span className="grid gap-1">
              <span className="block h-0.5 w-5 rounded-full bg-current" />
              <span className="block h-0.5 w-5 rounded-full bg-current" />
            </span>
          </button>
        </div>
      </div>
    </nav>
  );
}
