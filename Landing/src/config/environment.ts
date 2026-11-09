/** All deployment-dependent links enter through this public environment. */
export function readPublicEnvironment(
  env: Record<string, string | undefined>,
  production: boolean,
) {
  const origin = (key: string, fallback: string) => {
    const value = env[key]?.trim() || (production ? '' : fallback);
    let url: URL;
    try { url = new URL(value); } catch { throw Error(`Falta configurar ${key}.`); }
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.pathname !== '/' || url.search || url.hash ||
      !/^[a-zA-Z0-9.-]+$/.test(url.hostname) ||
      (production && (url.protocol !== 'https:' || ['localhost', '127.0.0.1'].includes(url.hostname)))) {
      throw Error(`${key} debe ser un origen HTTPS sin rutas ni credenciales en producción.`);
    }
    return url.origin;
  };
  const siteUrl = origin('VITE_SITE_URL', 'http://localhost:5173');
  const webApp = origin('VITE_WEB_APP_URL', 'http://localhost:3001');
  const androidApk = env.VITE_ANDROID_APK_URL?.trim() || '/downloads/DocIA.apk';
  if (!androidApk.startsWith('/') || androidApk.startsWith('//') || /[\\\s?#]/.test(androidApk)) {
    throw Error('VITE_ANDROID_APK_URL debe ser una ruta del mismo sitio, sin dominio, query ni fragmento.');
  }
  return { siteUrl, webApp, androidApk };
}
