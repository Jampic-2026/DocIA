# Pruebas funcionales con Postman

Importar el ambiente local y las colecciones necesarias:

- `Jampic_API.postman_collection.json`: consulta general de la superficie REST de Doc IA.
- `Jampic_Benefits_Partners.postman_collection.json`: flujos encadenados de beneficios, empresas asociadas y diagnósticos.

## Preparación

1. Ejecutar la base y la API local.
2. Obtener sesiones para administrador, paciente, profesional y usuario de empresa.
3. Copiar sus tokens en las variables `adminAccessToken`, `patientAccessToken`, `professionalAccessToken` y `partnerAccessToken`.
4. Completar los identificadores requeridos por el flujo. Las solicitudes que crean entidades guardan automáticamente los identificadores principales cuando responden correctamente.

Los tokens son secretos locales: no deben guardarse con valores reales dentro de los archivos versionados.

## Orden sugerido

Para empresas asociadas, ejecutar desde registro de empresa hasta respuesta de solicitud. Para diagnósticos, el profesional debe tener acceso clínico vigente al paciente y la empresa debe tener asignado el usuario que carga el resultado.

Para beneficios, debe existir una orden de pago pendiente del paciente. Si el beneficio requiere validación empresarial, consultar `GET /benefits/validations`, copiar el identificador en `benefitValidationId` y ejecutar la validación con el token de la empresa.
