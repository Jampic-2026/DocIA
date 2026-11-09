# Doc IA

Aplicación multiplataforma de la clínica digital Doc IA.

## Producción en el monorepo

La verificación y publicación conjunta de API, web, APK firmado y landing está descrita en [la guía de migración](../docs/MIGRATION.md). Los dominios se configuran en el archivo central de la raíz.

## Usuarios, roles y experiencias

La fuente backend de roles y permisos base está en `API/db/05_init.sql` y
`API/db/07_permission_catalog.sql`. El frontend no crea permisos de seguridad:
solo usa el rol principal y los permisos recibidos en sesión para decidir qué
experiencia y acciones mostrar. La API y las policies RLS siguen siendo la
barrera real de autorización.

| Rol backend | Usuario contemplado | Experiencia frontend | Alcance funcional esperado |
| --- | --- | --- | --- |
| `admin` | Administrador de plataforma | Administración | Gestiona usuarios, configuración, catálogos, permisos, integraciones, auditoría, profesionales, empresas asociadas, emergencias y correcciones clínicas según permisos. |
| `patient` | Paciente | Paciente | Gestiona perfil personal y clínico, citas, asistente IA, familiares/dependientes, emergencias, directorio médico, telemedicina, recetas, catálogo, monedas, pagos y consentimientos. |
| `guardian` | Tutor, apoderado o cuidador | Paciente | Administra perfiles vinculados y dependientes autorizados, agenda y consulta información permitida por consentimiento o vínculo familiar. |
| `doctor_general` | Médico general | Profesional | Atiende pacientes, revisa ficha clínica autorizada, gestiona agenda, teleconsulta, notas clínicas, recetas, seguimiento, derivaciones y disponibilidad. |
| `doctor_specialist` | Médico especialista | Profesional | Atiende consultas especializadas, revisa ficha clínica autorizada, gestiona agenda, teleconsulta, notas clínicas, recetas y disponibilidad. |
| `nurse` | Profesional de enfermería | Profesional | Registra signos vitales, valoraciones y procedimientos permitidos, consulta pacientes autorizados y apoya emergencias/servicios. No debe exponer acciones médicas que el backend no permita, como emisión de recetas. |
| `operator` | Operador clínico / coordinador | Operaciones | Coordina emergencias, soporte humano, servicios domiciliarios, incidencias y seguimiento operativo autorizado. |
| `clinical_supervisor` | Supervisor clínico | Operaciones | Supervisa emergencias, correcciones clínicas, calidad clínica, incidentes y auditoría clínica autorizada. |
| `health_partner` | Proveedor de salud aliado | Administración | Gestiona o consulta datos de empresa aliada, sedes, documentos, solicitudes, beneficios, pagos, entregas o diagnósticos según permisos. Debe filtrar vistas administrativas a su alcance. |
| `delivery_assistant` | Auxiliar de entrega | Operaciones | Gestiona entregas, evidencias, estados e incidencias relacionadas con traslado de productos o insumos. |
| `human_resources` | Recursos Humanos | Administración | Revisa postulaciones, documentos, altas de personal, validación profesional, expedientes laborales y observaciones de personal. Debe filtrar vistas administrativas a su alcance. |

### Mapeo actual de experiencias

```text
Paciente:
  patient, guardian

Profesional:
  doctor_general, doctor_specialist, nurse

Administración:
  admin, human_resources, health_partner

Operaciones:
  operator, clinical_supervisor, delivery_assistant
```

### Brechas conocidas

- `human_resources` y `health_partner` comparten la experiencia de
  administración, pero las pestañas deben filtrarse por permisos para evitar
  mostrar módulos que no correspondan a su rol.
- `nurse` comparte experiencia profesional con médicos. Las acciones clínicas
  deben condicionarse por permisos para no mostrar emisión de recetas u otras
  tareas médicas no autorizadas.
- `operator` ya cuenta con panel operativo por pestañas para emergencias,
  incidentes/reclamos y alertas según permisos. Queda pendiente una vista
  específica de servicios domiciliarios aunque el backend ya contempla sus
  permisos.
- `health_partner` no tiene todavía una experiencia dedicada para empresas,
  sedes, documentos, planes, solicitudes y órdenes diagnósticas.
- En postulaciones profesionales, la revisión debe permitir abrir/ver los
  documentos adjuntos antes de aprobarlos o rechazarlos.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# Generar APK de distribución

La versión se define en `pubspec.yaml`. Para generar el APK con el nombre
estándar técnico vigente del proyecto:

```powershell
Copy-Item config\production.example.json config\production.json
.\tool\build_apk.ps1 -ConfigFile config\production.json
```

Con `version: 1.0.0+1`, el artefacto resultante es:

```text
build/app/outputs/flutter-apk/DocIA_V1.0.0.apk
```

Para la siguiente entrega se actualiza la versión en `pubspec.yaml`; por
ejemplo, `version: 1.0.1+2` genera `DocIA_V1.0.1.apk`.
