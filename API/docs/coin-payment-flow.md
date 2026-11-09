# Flujo de monedas y pagos

Este documento describe el flujo vigente de cobros de Doc IA y la relación entre catálogo, monedas, pagos fiat y planes de empresas asociadas.

## Principios

- El usuario final no tiene suscripciones ni planes.
- El usuario final compra paquetes de monedas Doc IA.
- Cada compra acredita uno o más lotes de monedas con vencimiento de un año.
- Todo servicio no presencial cobrable se paga con monedas.
- Toda atención presencial se paga en fiat mediante QR o efectivo.
- El cobro presencial lo registra el profesional responsable que asistió la atención.
- Las empresas asociadas sí pueden contratar planes empresariales.

## Compra de monedas

1. Administración configura paquetes en `coin_packages`.
2. El usuario elige un paquete.
3. La API crea una `payment_order` con `related_entity_type = 'coin_package'` y `charge_mode = 'fiat'`.
4. El usuario registra un pago QR con comprobante o selecciona efectivo.
5. La compra queda representada en `coin_purchases`.
6. Un rol con `payments.manage` revisa el pago. Solamente al aprobarlo, la API acredita la billetera, crea el lote y registra el movimiento positivo dentro de una única transacción.
7. Cada lote se crea con `expires_at = credited_at + 1 year`, salvo que el paquete defina otra vigencia.

## Consumo de monedas

1. El servicio cobrable se define en `service_catalog` y su precio vigente en `price_list`.
2. Si el servicio no es presencial, el precio debe usar `charge_mode = 'coins'` y `coin_price`.
3. La API crea una `payment_order` con `charge_mode = 'coins'`.
4. Una RPC debe consumir monedas desde la billetera del usuario en `coin_wallets`.
5. El descuento debe aplicar FIFO por vencimiento usando `coin_lots`, consumiendo primero los lotes que vencen antes.
6. El movimiento negativo se registra en `coin_transactions`.
7. El detalle de qué lotes financiaron el consumo se guarda en `coin_transaction_allocations`.

## Atención presencial

1. Las consultas o servicios presenciales se modelan con `charge_mode = 'fiat'`.
2. La orden se guarda en `payment_orders` con monto fiat en `amount`.
3. El pago se registra en `payments` con `method = 'qr'` o `method = 'cash'`.
4. `collected_by_professional_id` identifica al responsable que cobró durante la atención.
5. Los triggers de `03_triggers.sql` validan que el contexto presencial no se cobre con monedas.

## Reversas, expiración y ajustes

- Una incidencia puede rechazarse, resolverse como ajuste, generar un reembolso fiat o una devolución compensatoria de monedas.
- El reembolso fiat se registra en `refunds` y actualiza el pago y su orden como `partially_refunded` o `refunded`.
- Si el pago corresponde a una compra de monedas, el reembolso debe ser total y solo procede cuando las monedas del paquete siguen sin consumirse. En ese caso se revierten lote, billetera y compra.
- Una devolución de monedas crea un lote compensatorio con vigencia de un año, un movimiento `refund` y su asignación, todos vinculados a la incidencia y orden originales.
- La resolución, el movimiento financiero y la auditoría se ejecutan en una única transacción.
- Al consultar la billetera se sincronizan los lotes propios vencidos y se crean avisos previos sin duplicarlos.
- `POST /coins/maintenance/process-expirations` realiza el procesamiento global y debe ser invocado diariamente por el programador del despliegue con `coins.manage`.
- La anticipación del aviso se administra mediante `coins.expiration_notice_days` y usa 30 días por defecto.
- La expiración descuenta el saldo, agota el lote, crea una transacción `expiration`, registra su asignación y genera auditoría y notificación.
- La expiración de lotes se debe ejecutar desde jobs futuros en `06_jobs.sql`, cerrando saldos vencidos y registrando `coin_transactions` de tipo `expiration`.
- Los ajustes manuales deben quedar trazados con `performed_by_user_id` y auditoría en `audit_events`.

## Empresas asociadas

1. Los planes empresariales viven en `partner_subscription_plans`.
2. Sus beneficios se detallan en `partner_plan_benefits`.
3. La contratación se registra en `partner_subscriptions`.
4. El consumo se registra en `partner_subscription_usage`.
5. Estos planes aplican a empresas asociadas, no a usuarios finales.
6. Cada renovación genera una nueva suscripción y orden para conservar el historial.
7. `auto_renew` genera la renovación durante los siete días anteriores al vencimiento.
8. Si no existe pago vigente, la suscripción entra en gracia y luego vence según `partners.grace_period_days`.
9. Los consumos se acumulan por característica y periodo y no pueden superar los límites JSON del plan.

## Configuración desde panel

- El tarifario se administra creando nuevas vigencias en `price_list`; no se modifica el precio histórico de una orden ya emitida.
- Los paquetes y sus precios se administran en `coin_packages`.
- Los planes y precios para empresas se administran en `partner_subscription_plans`.
- El QR y los datos visibles de cobro se guardan en `system_settings` con las claves `payments.qr_image_url`, `payments.qr_account_name`, `payments.qr_bank_name` y `payments.cash_enabled`.
- El QR no es una credencial y no pertenece al `.env`. Las llaves privadas de proveedores sí permanecen exclusivamente en el entorno de la API.

## SQL involucrados

- `01_database.sql`: enums, extensiones, tablas e índices.
- `02_functions.sql`: funciones internas y RPC de movimientos de monedas.
- `03_triggers.sql`: triggers de validación, expiración y `updated_at`.
- `04_policies.sql`: policies/RLS basadas en claims JWT seteados por la API.
- `05_init.sql`: datos iniciales reproducibles.
- `06_jobs.sql`: jobs SQL futuros, como expiración de lotes.
