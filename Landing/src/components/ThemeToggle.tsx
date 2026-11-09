import type { Theme } from '../config/content';

type ThemeToggleProps = {
  theme: Theme;
  setTheme: (theme: Theme) => void;
};

export default function ThemeToggle({ theme, setTheme }: ThemeToggleProps) {
  const nextTheme = theme === 'light' ? 'dark' : 'light';

  return (
    <button
      type="button"
      className="relative h-8 w-14 rounded-full border border-slate-200 bg-slate-100 p-1 shadow-inner transition-colors dark:border-white/15 dark:bg-white/10"
      aria-label={theme === 'light' ? 'Activar modo oscuro' : 'Activar modo claro'}
      onClick={() => setTheme(nextTheme)}
    >
      <span className="block h-6 w-6 rounded-full bg-[#009FE3] shadow-lg shadow-[#009FE3]/20 transition-transform duration-300 dark:translate-x-6 dark:bg-[#E30613] dark:shadow-[#E30613]/20" />
    </button>
  );
}
