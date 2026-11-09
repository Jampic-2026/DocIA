# Conservación del diseño y del comportamiento

Se comparó la copia nueva con los archivos originales y también con los tres commits registrados en `SOURCE-SNAPSHOT.json`. La comparación con el commit es importante: las carpetas originales ya tenían cambios locales de centralización de URL antes de crear el monorepo.

| Aplicación          | Archivos de producción idénticos al commit | Archivos de interfaz/recursos idénticos | Diferencias de diseño detectadas           |
| ------------------- | ------------------------------------------ | --------------------------------------- | ------------------------------------------ |
| Flutter web y móvil | 357                                        | 168                                     | Ninguna en el código y recursos comparados |
| Landing             | 70                                         | 63                                      | Ninguna en el código y recursos comparados |
| API                 | 340                                        | No corresponde                          | No corresponde                             |

La comprobación incluye los archivos seleccionados de `lib`, assets, web y plataformas nativas de Flutter; componentes React, estilos, contenido, imágenes y configuración de compilación de la landing; y código, SQL y dependencias de la API. Para texto se admite la diferencia de fin de línea CRLF/LF. Los hashes de los recursos binarios se comparan directamente.

Los archivos de interfaz conservan pantallas, widgets, componentes, temas, textos, imágenes y navegación. Las versiones de dependencias se conservan en los lockfiles. No se hicieron cambios de diseño como parte de esta migración.

Las diferencias de producción frente a los commits se revisaron y están enumeradas en [PARITY-REPORT.json](PARITY-REPORT.json):

- API: carga de configuración pública por release, validación y derivación de URL, host/puerto aislado, parámetros de enlaces de registro y recuperación, y uso de la URL configurada al volver de Stripe. Se agregó al esquema el campo opcional de cuenta Firebase que el código ya usaba. Se agregaron pruebas para estos cambios, incluida la carga real de archivos públicos, privados y ajustes de PM2 en Nest. La lógica restante, repositorios y SQL seleccionados coinciden con el commit.
- Flutter: el repositorio de acceso a archivos normaliza el puerto junto con el dominio de las URL firmadas; este cambio ya estaba en la carpeta original antes de la copia. Durante la verificación se corrigió además el guardado inicial de tokens, evitando una carrera en la creación de la clave de cifrado web. Se mantienen las claves y el formato de almacenamiento existentes y se agregaron dos pruebas de regresión. No cambian widgets ni pantallas.
- Landing: los enlaces de acceso se obtienen de la configuración, y las etiquetas de redes sociales y canonical usan el dominio configurado. El APK histórico deja de guardarse en Git; la descarga estable se sirve desde la release web. No cambian los componentes visuales.
- Despliegue: se agregan scripts, workflow y documentación. Las copias de secretos y datos se preparan en el servidor; no se incluyen en Git.

Además se reforzó el instalador: antes de normalizar las URL de la copia privada, compara las rutas anteriores de correo, pagos y OAuth con las que se derivarían de la configuración nueva. Si hay una ruta personalizada o un dominio diferente, se detiene sin sustituir sus valores y sin mostrarlos. Esta comprobación tiene ocho pruebas.

El reintento con Chrome independiente permitió completar **56 comparaciones visuales con cero píxeles diferentes**, usando cuentas y datos simulados locales, y comprobar por separado el primer login corregido. El alcance, las capturas y el procedimiento están en [VISUAL.md](VISUAL.md). Esto no equivale a validar todas las operaciones contra servicios reales. No se probó una APK instalada ni se inspeccionó el VPS desde estas herramientas.

Antes del cambio público se requiere validar la instalación paralela con cuentas de prueba: acceso por cada rol, registro y recuperación, navegación, formularios, adjuntos y archivos firmados, agenda y telemedicina, pagos si están habilitados y descarga/actualización de Android. Las pruebas no deben crear pagos reales ni modificar datos clínicos de usuarios.

Las comparaciones realizadas usaron el mismo navegador, tamaño de pantalla, tema, idioma, fuentes y datos. Para Android instalado sigue siendo necesario comparar en el mismo dispositivo y escala de texto. Las diferencias de datos o plataforma fuera de los casos probados no quedan descartadas por esta revisión.

Las 66 variables del ejemplo API original se conservan sin cambiar sus valores de ejemplo. Se documentaron además HOST y FCM_SERVICE_ACCOUNT_PATH. Su destino y prioridad están en [API-ENV-MAP.md](API-ENV-MAP.md); la preparación conserva todos los valores privados mediante comprobaciones de igualdad y pruebas de contraseñas con # y claves multilínea.

Para repetir la comparación local, manteniendo las carpetas originales junto a esta copia:

```bash
npm run audit:parity
```

El informe usa los commits originales registrados; no presupone que sean exactamente la release que atiende el VPS. Confirmar también los marcadores de producción antes de la validación final. Los procedimientos de instalación y recuperación están en [MIGRATION.md](MIGRATION.md).
