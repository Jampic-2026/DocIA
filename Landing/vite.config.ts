import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import { readPublicEnvironment } from './src/config/environment';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', 'VITE_');
  const allowed = ['VITE_SITE_URL', 'VITE_WEB_APP_URL', 'VITE_ANDROID_APK_URL'];
  if (Object.keys(env).some(key => !allowed.includes(key))) throw Error('Solo se permiten las tres variables públicas documentadas VITE_SITE_URL, VITE_WEB_APP_URL y VITE_ANDROID_APK_URL.');
  const publicEnv = readPublicEnvironment(env, mode === 'production');
  return {
    plugins: [react(), {
      name: 'docia-public-site-metadata',
      transformIndexHtml: {
        order: 'pre',
        handler: (html) => html.replaceAll('%DOCIA_SITE_URL%', publicEnv.siteUrl),
      },
    }],
  };
});
