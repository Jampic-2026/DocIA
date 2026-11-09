import { FaFacebookF, FaInstagram, FaTiktok } from "react-icons/fa";
import type { Language } from "../config/content";
import { brand } from "../config/brand";
import { landingContent } from "../config/content";
import { containerShell } from "./ui";

type FooterProps = {
  language: Language;
};

export default function Footer({ language }: FooterProps) {
  const { footer } = landingContent[language];

  return (
    <footer className="border-t border-slate-200 bg-white py-8 text-slate-900 dark:border-white/10 dark:bg-slate-950 dark:text-white">
      <div
        className={`${containerShell} flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between`}
      >
        <div className="grid gap-1">
          <img
            src={brand.logos.positive}
            alt={brand.name}
            className="h-10 w-auto object-contain dark:hidden"
          />
          <img
            src={brand.logos.negative}
            alt={brand.name}
            className="hidden h-10 w-auto object-contain dark:block"
          />

          <small className="text-sm text-slate-500 dark:text-slate-400">
            {footer.copyright}
          </small>
        </div>

        <div
          className="flex items-center gap-3"
          aria-label="Social media"
        >
          <a
            className="grid h-10 w-10 place-items-center rounded-full border border-slate-200 bg-slate-100 text-slate-700 transition-colors hover:bg-slate-200 dark:border-white/10 dark:bg-white/10 dark:text-white dark:hover:bg-white/15"
            href="https://www.facebook.com/profile.php?id=61574449793627"
            target="_blank"
            rel="noreferrer"
            aria-label="Facebook"
          >
            <FaFacebookF size={18} />
          </a>

          <a
            className="grid h-10 w-10 place-items-center rounded-full border border-slate-200 bg-slate-100 text-slate-700 transition-colors hover:bg-slate-200 dark:border-white/10 dark:bg-white/10 dark:text-white dark:hover:bg-white/15"
            href="https://www.instagram.com/docia_bo"
            target="_blank"
            rel="noreferrer"
            aria-label="Instagram"
          >
            <FaInstagram size={18} />
          </a>
        </div>
      </div>
    </footer>
  );
}