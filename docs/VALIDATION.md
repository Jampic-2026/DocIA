# Validación de la copia del monorepo

Verificaciones locales realizadas el 9 de noviembre de 2026, sobre esta carpeta nueva:

| Componente                  | Resultado                                                                                                                                                                        |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Repositorios originales     | 880 archivos conservan su hash y sus tres HEAD siguen iguales                                                                                                                    |
| API                         | Lint sin modificaciones, 58 pruebas en 19 suites y compilación NestJS correctos                                                                                                  |
| Flutter                     | Análisis sin incidencias, 56 pruebas y compilación web release correctos                                                                                                         |
| Landing                     | 5 pruebas de configuración y compilación TypeScript/Vite correctas                                                                                                               |
| Herramientas compartidas    | 67 pruebas: configuración pública, firma/certificado, versiones Android, paquetes, Nginx, rutas anteriores e inventario de variables                                             |
| Conservación de entorno API | 4 pruebas de todos los nombres del ejemplo, variables desconocidas, contraseñas con #, claves multilínea y rutas personalizadas                                                  |
| Comparación visual          | 56 escenarios con cero píxeles diferentes; primer login desde Chrome limpio correcto; API interceptada con datos simulados                                                       |
| Despliegue                  | 33 escenarios simulados correctos: publicación, rollback, migración/dependencias fallidas, salud incorrecta, contenido obsoleto, checksum, rutas inseguras y primera instalación |
| Workflow                    | actionlint 1.7.12 sin errores                                                                                                                                                    |
| Bash                        | ShellCheck 0.11.0 sin incidencias                                                                                                                                                |
| Nginx                       | Nginx 1.28.0 aceptó las tres plantillas públicas y las dos vistas privadas en una configuración de prueba con certificados sintéticos                                            |
| Paquetes reales             | API y landing empaquetadas desde sus builds; contienen su configuración pública por release                                                                                      |
| Revisión de subida          | Sin entornos privados, claves de firma ni APK históricos en el código fuente preparado                                                                                           |

Las pruebas de despliegue usan procesos npm/PM2 y respuestas HTTP simulados; no se conectan al VPS ni ejecutan SQL. En Linux CI se añade una comprobación con `flock` real. La prueba Nginx valida sintaxis y combina las plantillas; sustituye únicamente certificados y rutas de opciones Certbot por archivos de prueba, sin arrancar un servidor.

La API se prepara en 3100; los virtual hosts existentes se revisan y prueban en el VPS durante el cambio. La firma y el contenido de la APK nueva se verificarán con el keystore real y Android Build Tools en GitHub Actions. No se ejecutó una compilación Android firmada local ni se publicaron cambios en GitHub o el VPS desde esta preparación.

Todavía corresponden las comprobaciones del servidor y las pruebas funcionales con una cuenta de prueba descritas en [MIGRATION.md](MIGRATION.md). Tampoco se aplicaron migraciones de base de datos. Un resultado correcto de compilación o salud no demuestra por sí solo cada integración externa.

La revisión de conservación de interfaz está en [PARITY.md](PARITY.md), la comparación de capturas en [VISUAL.md](VISUAL.md) y el destino de cada variable en [API-ENV-MAP.md](API-ENV-MAP.md). La APK instalada y las integraciones reales siguen pendientes.

Para repetir las verificaciones principales, instalar dependencias en API, APP-MVP y Landing y ejecutar:

```bash
npm --prefix API run lint:check
npm --prefix API test -- --runInBand
npm --prefix API run build
npm run test:tools
npm run test:api-env
npm run audit:api-env
node --test deploy/tests/landing-env.test.cjs
node deploy/check-upload.cjs
bash deploy/tests/deploy.test.sh
```

Desde APP-MVP: `flutter analyze`, `flutter test` y el build con la configuración pública generada. El job `web` del workflow muestra los comandos exactos. Para comprobar de nuevo los repositorios hermanos locales: `npm run verify:sources` (requiere acceso de lectura a su Git).
