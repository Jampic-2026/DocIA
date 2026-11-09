import { useEffect, useState } from 'react';
import Navbar from './Navbar';
import HeroSection from './HeroSection';
import MissionVisionSection from './MissionVisionSection';
import EmergencySystemSection from './EmergencySystemSection';
import FamilyCareSection from './FamilyCareSection';
import ProblemSection from './ProblemSection';
import SolutionSection from './SolutionSection';
import HowItWorksSection from './HowItWorksSection';
import ModulesSection from './ModulesSection';
import BenefitsSection from './BenefitsSection';
import TrustSection from './TrustSection';
import TechnologySection from './TechnologySection';
import CredibilitySection from './CredibilitySection';
import TeamSection from './TeamSection';
import ImpactSection from './ImpactSection';
import FinalCTASection from './FinalCTASection';
import Footer from './Footer';
import { brand } from '../config/brand';
import type { Language, Theme } from '../config/content';

export default function LandingPage() {
  const [language, setLanguage] = useState<Language>('es');
  const [theme, setThemeState] = useState<Theme>(() => {
    const savedTheme = window.localStorage.getItem(brand.themeStorageKey);
    return savedTheme === 'light' || savedTheme === 'dark' ? savedTheme : 'light';
  });

  useEffect(() => {
    document.documentElement.classList.toggle('dark', theme === 'dark');
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  const setTheme = (nextTheme: Theme) => {
    setThemeState(nextTheme);
    window.localStorage.setItem(brand.themeStorageKey, nextTheme);
  };

  return (
    <div data-theme={theme} className={theme === 'dark' ? 'dark' : undefined}>
      <Navbar language={language} setLanguage={setLanguage} theme={theme} setTheme={setTheme} />
      <main>
        <HeroSection language={language} />
        <MissionVisionSection language={language} />
        <EmergencySystemSection language={language} />
        <FamilyCareSection language={language} />
        <ProblemSection language={language} />
        {/* <SolutionSection language={language} /> */}
        {/* <HowItWorksSection language={language} /> */}
        <ModulesSection language={language} />
        {/* <BenefitsSection language={language} /> */}
        {/* <TrustSection language={language} /> */}
        <TechnologySection language={language} />
        <CredibilitySection language={language} />
        {/* <ImpactSection language={language} /> */}
        <TeamSection language={language} />
        <FinalCTASection language={language} />
      </main>
      <Footer language={language} />
    </div>
  );
}
