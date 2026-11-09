# Doc IA Landing Page

> Producción, dominios y descarga Android: [guía del monorepo](../docs/MIGRATION.md).

Landing page modular para Doc IA, construida con React, Vite y TypeScript.

## Estructura

- `src/`
  - `landing/` - componentes de la landing.
  - `components/` - componentes reutilizables.
  - `config/` - contenido bilingüe y tipos.
  - `App.tsx` - entrada de la aplicación.
  - `main.tsx` - bootstrap de React.
- `globals.css` - base global de Tailwind y estilos mínimos no específicos de secciones.
- `index.html` - punto de entrada para Vite.
- `package.json` - dependencias y scripts.
- `tsconfig.json` - configuración de TypeScript.
- `vite.config.ts` - configuración de Vite.

## Scripts

El despliegue automático por push a `main`, preparación del VPS y distribución
del APK desde el dominio de la landing están en
[`../docs/MIGRATION.md`](../docs/MIGRATION.md).

- `npm install` - instala dependencias.
- `npm run dev` - inicia el servidor de desarrollo.
- `npm run build` - genera la versión de producción.
- `npm run preview` - sirve la compilación de producción localmente.

## Cómo usar

1. Abre la terminal en `landing/`.
2. Ejecuta `npm install`.
3. Ejecuta `npm run dev`.
4. Accede a `http://localhost:5173`.

## Contenido bilingüe

El contenido de la landing está centralizado en `src/config/content.ts` y soporta los idiomas:

- `es` (español)
- `en` (inglés)

## Enlaces del producto

Los enlaces de acceso están centralizados en `src/config/links.ts`. Se pueden
sobrescribir durante el despliegue con estas variables:

```env
VITE_SITE_URL=https://landing.example.com
VITE_WEB_APP_URL=https://app.example.com
VITE_ANDROID_APK_URL=/downloads/DocIA.apk
```

La URL estable es `https://landing.example.com/downloads/DocIA.apk`. Nginx la sirve
mediante un alias al APK firmado que publica Flutter junto con la web. No se
copia cada APK al repositorio Landing ni se cambia el enlace con cada versión.
El APK histórico no se copia a este repositorio. Su URL antigua se conserva
mediante la redirección de Nginx a la descarga estable.

El workflow deriva estas variables de `config/environments/production.env` de la raíz al compilar. Para
builds manuales, actualizar cualquier override `VITE_ANDROID_APK_URL` que aún
apunte al APK histórico. Completar la preparación única de
[`../docs/MIGRATION.md`](../docs/MIGRATION.md); después cada push a `main` verifica,
compila y publica la landing sin comandos manuales de build ni recargas Nginx.

## Secciones principales

- `Navbar`
- `HeroSection`
- `ProblemSection`
- `SolutionSection`
- `HowItWorksSection`
- `ModulesSection`
- `BenefitsSection`
- `DifferentiatorsSection`
- `TrustSection`
- `FinalCTASection`
- `Footer`

## Notas

- El diseño usa paleta de colores inspirada en salud digital y tonos suaves.
- Se emplean animaciones ligeras con `framer-motion`.
- La landing es responsive y modular para facilitar mantenimiento.
