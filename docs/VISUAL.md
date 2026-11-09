# Verificación visual local

Resultado: **56 escenarios comparados con 0 píxeles diferentes**, incluyendo antialiasing, y primer inicio de sesión correcto desde un navegador limpio. El resultado detallado está en [VISUAL-REPORT.json](VISUAL-REPORT.json).

Se utilizó Chrome con contextos aislados, sin el perfil personal del usuario. La versión original se compiló desde los commits registrados en `SOURCE-SNAPSHOT.json`; la nueva se compiló desde el monorepo. Ambas usaron las mismas URL `.cloud`, dependencias, dimensiones, tema y datos simulados.

| Escenarios                                                                                                 | Cantidad |
| ---------------------------------------------------------------------------------------------------------- | -------- |
| Landing completa: español/inglés, claro/oscuro, 1440 y 390 píxeles de ancho                                | 8        |
| Menú móvil de la landing, ambos idiomas y temas                                                            | 4        |
| Login, registro, recuperación, completar registro con token y recuperación con token, ambos anchos y temas | 20       |
| Validación local del formulario de login vacío, ambos anchos y temas                                       | 4        |
| Paneles de paciente, médico general, enfermería, administración y operaciones, ambos anchos y temas        | 20       |

Las llamadas a `api.doc-ia.cloud` se interceptaron en el navegador y recibieron respuestas locales de prueba. Se comprobó que los paneles autenticados efectivamente solicitaran y cargaran esos datos, sin errores de descifrado o mensajes de fallo de carga. Los enlaces a la web y al APK de la landing también se comprobaron. No se ejecutaron operaciones contra la API real, PostgreSQL ni proveedores de mensajes/pagos.

Las capturas se compararon con umbral cero y antialiasing incluido. Las animaciones se estabilizaron para comparar el mismo estado. Las páginas largas de la landing se capturaron por posiciones de desplazamiento para evitar problemas de renderizado de imágenes muy altas: cada tramo conserva su cabecera sticky. La imagen compuesta documenta esas vistas sucesivas.

Las imágenes y una galería interactiva están en **`.validation/results/index.html`** dentro de esta carpeta de trabajo. Se conservan localmente y están excluidas de Git, junto con las dependencias y las compilaciones temporales. Hay una captura original y otra nueva por escenario, más una del primer login nuevo. Abrir la galería en el navegador permite elegir el escenario y ver ambas versiones.

## Corrección encontrada durante la prueba

En una sesión nueva, el proveedor web de almacenamiento seguro podía generar dos claves de cifrado distintas al guardar access token y refresh token en paralelo. El login llegaba al panel, pero las lecturas posteriores de la sesión fallaban y no cargaban sus datos. El problema se reprodujo con el código original y con la copia anterior a la corrección.

En la copia nueva, `SecureSessionStorage.write` guarda los dos tokens de forma secuencial. Se conservan sus nombres, cifrado, formato y almacenamiento. No se modifican vistas. La prueba de regresión del primer guardado falla con la implementación original y pasa con la nueva; las dos pruebas de almacenamiento nuevas pasan. También se verificó el primer login en Chrome limpio con respuestas simuladas, sin preparar antes una clave de cifrado.

Para comparar el diseño de los paneles, el contexto original y el nuevo disponen de una clave de almacenamiento ya inicializada, equivalente al estado de un navegador previamente usado. Así se compara la interfaz con datos cargados. El caso separado `freshLogin` comprueba que el monorepo también funcione en el primer uso.

## Alcance

Estos resultados confirman igualdad visual en los escenarios enumerados. No comprueban todas las operaciones posibles, todos los registros clínicos, pagos reales ni las integraciones externas. Tampoco son una prueba de la APK instalada: no había un dispositivo Android conectado. El ancho 390 corresponde a la web; se conserva su comportamiento existente de sidebar. El código y los recursos visuales compartidos con Android también se compararon por hash y las 56 pruebas Flutter pasaron.

La instalación paralela y las comprobaciones reales del servidor siguen descritas en [MIGRATION.md](MIGRATION.md). Los tres repositorios originales y el VPS no fueron modificados.

## Repetir en Windows

Desde la raíz nueva, conservando los repositorios originales como hermanos, instalar las herramientas de prueba aisladas:

```powershell
npm install --prefix .validation --no-audit --no-fund --package-lock=false playwright-core@1.65.0 pngjs@7.0.0 pixelmatch@8.0.0
npm run visual:prepare
```

`visual:prepare` crea `.validation/baseline-flutter` y `.validation/baseline-landing` desde los commits originales. Si ya existen, las conserva y se detiene; no modifica los originales. No es necesario repetir esa preparación en esta carpeta, donde ya se realizó.

Compilar la landing de referencia:

```powershell
$env:VITE_SITE_URL='https://doc-ia.cloud'
$env:VITE_WEB_APP_URL='https://app.doc-ia.cloud'
$env:VITE_ANDROID_APK_URL='/downloads/DocIA.apk'
npm --prefix .validation/baseline-landing ci --no-audit --no-fund
npm --prefix .validation/baseline-landing run build
```

Compilar Flutter de referencia:

```powershell
Push-Location .validation/baseline-flutter
flutter pub get --enforce-lockfile
flutter build web --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.doc-ia.cloud/api/v1/
Pop-Location
```

Los builds nuevos deben estar en `Landing/dist` y `APP-MVP/build/web`, preparados con el mismo archivo público. El workflow muestra sus comandos; para uso local se pueden usar los archivos generados por `npm run config:render`. Después:

```powershell
Remove-Item Env:DOCIA_VISUAL_RETRY -ErrorAction SilentlyContinue
Remove-Item Env:DOCIA_VISUAL_CASE_ID -ErrorAction SilentlyContinue
$env:DOCIA_CHROME_PATH='C:/Program Files/Google/Chrome/Application/chrome.exe'
npm run verify:visual
```

La herramienta crea servidores exclusivamente en loopback y puertos disponibles, intercepta las solicitudes de API y cierra Chrome y los servidores al finalizar. El informe y la galería se regeneran con los resultados. Un resultado correcto corresponde a esos builds y a los casos probados, no a una inspección del VPS vivo.
