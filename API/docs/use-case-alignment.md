# Alineacion de casos de uso, modulos y modelo

Documento generado desde `db/traceability_matriz_use_cases.md` para mantener concordancia entre la matriz funcional, la base validada y la API.

## Resumen por modulo funcional

| Modulo funcional en trazabilidad | Casos de uso | Modulos API relacionados                                                      |
| -------------------------------- | -----------: | ----------------------------------------------------------------------------- |
| Administracion                   |           10 | administration, users, catalog, partners                                      |
| Auditoria                        |            8 | audit                                                                         |
| Autenticacion                    |            6 | auth, users                                                                   |
| Beneficios                       |            5 | benefits, payments, partners, coins                                           |
| Complementarias                  |           10 | auth, notifications, clinical-records, incidents, partners                    |
| Consultas                        |           16 | appointments, professionals, clinical-records, prescriptions, coins, payments |
| Directorio medico                |            2 | professionals, appointments                                                   |
| Emergencias                      |           14 | emergencies, home-services, notifications                                     |
| Entregas                         |            5 | deliveries, partners, audit                                                   |
| Familiares y tutores             |            8 | patients, users, notifications                                                |
| IA y orientacion                 |            6 | ai, emergencies, appointments, notifications                                  |
| Medicos y verificacion           |            8 | professionals, human-resources, audit                                         |
| Monedas y pagos                  |           13 | coins, payments, catalog, partners                                            |
| Perfil clinico                   |           12 | patients, people, clinical-records, benefits                                  |
| Recetas y negocios               |           12 | prescriptions, partners, deliveries, benefits                                 |
| Recursos Humanos                 |            6 | human-resources, professionals                                                |
| Servicios domiciliarios          |           14 | home-services, professionals, deliveries, coins, payments                     |
| Telemedicina                     |            5 | appointments, coins                                                           |
| Turnos                           |            5 | professionals, human-resources                                                |

## Cobertura tecnica actual

- `db/01_database.sql` contiene 105 tablas validadas.
- Los controladores consultan recursos persistidos mediante servicios y
  repositorios; no se publican respuestas simuladas.
- Autenticación, autorización y los dominios funcionales operan sobre
  PostgreSQL con el contexto de permisos y RLS de la sesión.
- `docs/api-endpoints.md` lista la superficie REST inicial.
- `docs/postman/Jampic_API.postman_collection.json` permite probar la superficie REST desde Postman.
- `docs/postman/Jampic_Benefits_Partners.postman_collection.json` cubre los
  flujos encadenados de beneficios, empresas asociadas y estudios diagnósticos.
- Las pruebas unitarias verifican contratos de aplicación y autorización para
  evitar regresiones en la proyección HTTP y la delegación hacia repositorios.

## Regla de cobro vigente

- Los usuarios compran paquetes de monedas; cada lote vence al anio de acreditarse.
- Los servicios no presenciales cobrables se consumen con monedas.
- Las consultas y servicios presenciales se pagan en fiat por QR o efectivo al responsable que asistio.
- Los usuarios finales no tienen suscripciones ni planes.
- Las empresas asociadas pueden operar mediante planes empresariales.

## Criterio de evolucion

Cada CU debe implementarse verticalmente, usando la matriz para identificar tablas principales, tablas relacionadas, auditoria y estados involucrados.

```text
interfaces/http -> application/use-case -> domain/ports -> infrastructure/persistence
```
