import { readPublicEnvironment } from './environment';

export const productLinks = readPublicEnvironment({
  VITE_SITE_URL: import.meta.env.VITE_SITE_URL,
  VITE_WEB_APP_URL: import.meta.env.VITE_WEB_APP_URL,
  VITE_ANDROID_APK_URL: import.meta.env.VITE_ANDROID_APK_URL,
}, import.meta.env.PROD);

export type CredibilityItemType = 'award' | 'press' | 'interview' | 'institutional';

export type CredibilityItem = {
  id: string;
  type: CredibilityItemType;
  organization: string;
  year?: number;
  url?: string;
  image: string;
  imageClassName?: string;
};

export const awards: CredibilityItem[] = [
  {
    id: 'incuba-union-emprende-futuro',
    type: 'award',
    organization: 'Incuba Union - Emprende Futuro',
    year: 2025,
    image: '/awards/11.jpeg',
  },
  {
    id: 'upsa-acceleration',
    type: 'award',
    organization: 'UPSA',
    year: 2025,
    image: '/awards/1.png',
  },
  {
    id: 'univalle-excellence-award',
    type: 'award',
    organization: 'Universidad Privada del Valle',
    year: 2025,
    image: '/awards/3.png',
    imageClassName: 'object-top',
  },
];

export const media: CredibilityItem[] = [
  {
    id: 'eldeber-univalle-research',
    type: 'press',
    organization: 'El Deber',
    year: 2025,
    url: 'https://eldeber.com.bo/te-puede-interesar/univalle-lidera-investigacion-en-bolivia_524150/',
    image: '/awards/el_deber.webp',
  },
  {
    id: 'bolivia-emprende-incubaunion',
    type: 'press',
    organization: 'Bolivia Emprende',
    year: 2025,
    url: 'https://boliviaemprende.com/eventos/innovacion-con-sello-boliviano-cinco-startups-gana-capital-semilla-en-el-1er-torneo-incubaunion-tecnologico',
    image: '/awards/bolivia_emprende.jpg',
  },
  {
    id: 'vision360-incubaunion',
    type: 'press',
    organization: 'Vision 360',
    year: 2025,
    url: 'https://www.vision360.bo/noticias/2025/07/09/28130-cinco-startups-ganan-capital-semilla-en-el-primer-torneo-nacional-de-incuba-union-tecnologico?fbclid=IwQ0xDSwLhG8dleHRuA2FlbQIxMQABHmJLONjbjP8-j_fSQE36H12dTrYiARZCywO0OSEIxtaVPHS53yn-SpmHEBkP_aem_wzbWktrVbtQJ91ZtvvxAtg',
    image: '/awards/vision_360.webp',
  },
  {
    id: 'portal-verde-incubaunion',
    type: 'press',
    organization: 'Portal Verde',
    year: 2025,
    url: 'https://portalverde.com.bo/docia-la-startup-universitaria-que-se-impuso-en-el-elevateu-2025/',
    image: '/awards/portal_verde.webp',
  },
  {
    id: 'univalle-tv',
    type: 'institutional',
    organization: 'Universidad Privada del Valle',
    year: 2025,
    url: 'https://www.facebook.com/univallesc/videos/583781101337424/',
    image: '/awards/3.png',
  },
  {
    id: 'in-noticias-interview',
    type: 'interview',
    organization: 'IN Noticias',
    year: 2025,
    url: 'https://www.facebook.com/innoticiasbolivia/videos/781976004475944',
    image: '/awards/11.jpeg',
  },
];

export type PartnerLogo = {
  name: string;
  image: string;
  imageClassName?: string;
  surfaceClassName?: string;
};

export const partnerLogos: PartnerLogo[] = [
  { name: 'Google Cloud', image: '/partners/Google-Cloud.png' },
  { name: 'OpenAI', image: '/partners/OpenAI.png' },
  { name: 'Firebase', image: '/partners/Firebase.png' },
  { name: 'PostgreSQL', image: '/partners/PostgreSQL.png' },
  { name: 'Banco Union', image: '/partners/bancoUnion.png' },
  { name: 'Incuba Union', image: '/partners/incubaUnion.png' },
  { name: 'Univalle', image: '/partners/univalle.png' },
  { name: 'Emprende Futuro', image: '/partners/EmprendeFuturo.png' },
  { name: 'LinkSpace', image: '/partners/LinkSpace.png' },
  {
    name: 'VCILAT',
    image: '/partners/vcilat.png',
    surfaceClassName: '!bg-slate-950 dark:!bg-slate-950',
  },
  { name: 'Stripe', image: '/partners/stripe.svg' },
];
