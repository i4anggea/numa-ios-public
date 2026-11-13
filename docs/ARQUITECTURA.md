# Arquitectura de la primera versión

Estado actual: arquitectura de Numa implementada y revisada hasta fase 8. Ver FASE_8_PRUEBAS.md para la última regresión y los límites físicos pendientes. Los informes de fases anteriores conservan su contexto histórico.

## Decisiones aprobadas

- App nativa para iPhone con Swift y SwiftUI, objetivo iOS 27.
- Persistencia local con SwiftData, sin servidor, CloudKit, cuentas ni sincronización.
- Base financiera excluida de copias del sistema. No habrá exportación/restauración.
- Compras con intereses: entrada manual de precio, total final y número de meses.
- Notificaciones locales con contenido genérico sin nombres ni importes.

Se elige nativo frente a una solución multiplataforma porque el alcance actual solo incluye iPhone. SwiftData se elige frente a acceso directo a SQLite por integración y menor mantenimiento inicial. Revisar estas decisiones si cambia el alcance, sin prometer reutilización automática en Android.

## Estructura técnica

Un único proyecto y aplicación, organizado por funcionalidades: Inicio, Movimientos, Cuentas/Tarjetas, Presupuestos, Ahorro, Reportes y Ajustes. Cinco pestañas aprobadas: Inicio, Movimientos, Presupuestos, Ahorro y Reportes. Cuentas/tarjetas desde Inicio y Ajustes desde la barra superior.

Separación interna:

- Presentación: vistas SwiftUI y estado de pantalla; no calcula saldos ni modifica relaciones por su cuenta.
- Dominio/aplicación: reglas de movimientos, deuda, presupuestos, reservas y mensualidades, independientes de SwiftData para poder probarlas.
- Infraestructura: modelos y repositorios SwiftData, migraciones versionadas, preferencias y programación de notificaciones.

El protocolo FinanceRepository ofrece carga, guardado del libro y medición opcional de pruebas; las operaciones financieras específicas pertenecen a Ledger. No se necesita un framework de inyección ni un repositorio genérico. Escrituras relacionadas deben guardarse como una unidad; los errores no deben comunicarse como éxito. La base persistida es la fuente de verdad, y los agregados se derivan para evitar divergencias.

## Modelo de datos implementado

Implementación v1: cada entidad conceptual ocupa una fila SwiftData con UUID, tipo y payload Codable. El motor trabaja con valores independientes del framework y guarda conjuntamente las filas afectadas. La integridad se controla en la aplicación, sin relaciones SwiftData. Fase 5 añade validación estructural y de historia antes de abrir/guardar: referencias, UUID, fechas, rangos monetarios, límites de volumen, deuda por día y reservas por meta/cuenta. La identidad fila/payload también se comprueba al decodificar. Carga de 10,000 movimientos medida en fase 6; ver FASE_6_OPTIMIZACION.md.

- Cuenta: efectivo o banco, identificador estable, nombre y saldo inicial.
- Tarjeta de débito: método vinculado a una cuenta bancaria; no tiene un segundo saldo que duplique el de la cuenta.
- Tarjeta de crédito: identificador, nombre, deuda inicial y configuración de corte/pago. No se almacenan PAN completo, CVV ni credenciales bancarias.
- Categoría: identificador, nombre y estado archivado.
- Movimiento: tipo, fecha, importe, categoría cuando corresponda, nota opcional y origen/destino. Una compra usa un método.
- Plan de mensualidades: compra asociada, precio, total, número de meses, condición con/sin intereses y calendario.
- Pago de tarjeta: cuenta de origen y tarjeta destino, sin otro gasto de consumo.
- Presupuesto semanal: inicio de semana, límite global y límites por categoría.
- Meta y aportación: objetivo, fecha opcional, importe aportado y cuenta que respalda la reserva.
- Cierre semanal: margen sobrante y asignaciones a ahorro/próxima semana, con referencia al cierre para evitar duplicados.

No se incluye reconstrucción de planes de deuda previos. La deuda inicial se puede registrar como valor de apertura.

## Invariantes de dinero

- Representar importes MXN como centavos enteros de 64 bits, con validación de límites y operaciones aritméticas. No usar Double para cálculos monetarios.
- Distribuir el residuo de divisiones de mensualidades de forma determinista; la suma debe coincidir exactamente con el total, mostrando cualquier ajuste de centavos.
- Dinero total: efectivo más saldos bancarios. Disponible para gastar: dinero total menos reservas. Deuda de crédito se muestra aparte, sin tratar crédito disponible como dinero propio.
- Una compra de débito/efectivo reduce su cuenta; una compra de crédito aumenta la deuda. Ambas consumen presupuesto por el total en la fecha de compra.
- Pagar crédito reduce cuenta y deuda sin consumir presupuesto de nuevo.
- Aportar a ahorro reserva dinero de una cuenta sin crear un gasto ni cambiar el dinero total.
- El sobrante presupuestario es margen de planificación, no dinero nuevo. Reservar para ahorro requiere saldo real disponible; trasladar margen a otra semana no mueve dinero.
- Una asignación de sobrante no puede repetirse ni superar el sobrante permitido. Recalcular o resolver explícitamente su efecto si se modifica el historial.
- No trasladar margen a una semana ya cerrada sin reabrirla primero. No reabrir un cierre si al retirar su aportación alguna liberación posterior deja ahorro histórico negativo.
- Pagos y correcciones no pueden dejar deuda de crédito negativa al terminar ninguna fecha registrada. Para captura por fecha, las operaciones del mismo día se concilian juntas.

## Fechas y recordatorios

Presupuestos de lunes a domingo usando intervalos con final excluido. Las fechas contables, semanas y visualización usan America/Mexico_City de forma explícita.

Programar recordatorios a siete y tres días antes de corte/pago, 09:00, con identificadores estables para sustituir o cancelar solicitudes sin duplicarlas. Reconciliar solicitudes al abrir la app y cambiar fechas/tarjetas. Pedir permiso en contexto y mostrar su estado; la entrega queda sujeta a iOS y ajustes del dispositivo.

Las reconciliaciones se serializan y solo la solicitud más reciente actualiza el estado visible; cada una usa las tarjetas actuales después de completar la anterior. Falta comprobar permisos/entrega y escenarios concurrentes en dispositivo.

Reglas implementadas: sugerir la próxima fecha de pago y permitir modificarla; usar último día en meses cortos; pagos parciales/totales sobre deuda registrada. No se calcula el importe exigible del estado de cuenta ni se asignan pagos a cuotas. Mostrar cuotas previstas no equivale a confirmar un estado de cuenta bancario.

## Privacidad y evolución

Configurar protección de archivos del sistema y exclusión de copias para el almacén y sus archivos auxiliares; verificar ambos controles en pruebas. No afirmar cifrado adicional propio ni protección biométrica implementada.

Sin SDKs de analítica ni registro de datos financieros en logs. Preferencias no financieras separadas del almacén. Ocultación persistente de cifras y gráficas en consultas, con importes visibles en formularios de edición; cubrir contenido sensible al pasar al selector de aplicaciones. Ver UI_UX.md.

Usar esquema versionado y migraciones no destructivas. Un error de apertura nunca debe provocar borrado o recreación silenciosa del almacén. Sin recuperación de usuario en v1, las migraciones requieren especial verificación con datos sintéticos.

## Verificación prevista

- Pruebas de dominio: precisión, pagos sin duplicación, límites semanales, reservas, cierres y distribución de centavos.
- Integración: persistencia tras reapertura, coherencia de escrituras, migraciones y eliminación/edición de relaciones.
- Interfaz: flujos críticos, accesibilidad, ocultación y estados vacíos/errores.
- Dispositivo: permisos y recordatorios, protección de archivos y funcionamiento sin red.

Última regresión funcional, fase 8: 28 pruebas de dominio, 13 de integración y cinco casos UI PASS. Archive Release para iOS sin firma comprobado. Controles físicos y accesibilidad exhaustiva pendientes según FASE_8_PRUEBAS.md; firma e instalación en iPhone físico sin comprobar.

## Optimización de lectura y persistencia — fase 6

FinanceStore reconstruye un LedgerReadIndex inmutable al abrir y tras cada escritura confirmada. Incluye resumen, movimientos ordenados y mapas de nombres. Los reportes se agregan en una pasada fuera del actor principal y descartan resultados cancelados. El repositorio conserva filas y valores persistidos para serializar únicamente entidades nuevas/modificadas y eliminar explícitamente las retiradas, conservando validación y rollback. No hay cambio de esquema.

El historial limita filas a bloques de 50; filtra el índice completo, no solo el bloque visible. Se mantiene el libro completo en memoria: no es paginación de SwiftData ni una mejora de RAM demostrada. Mediciones y equivalencia financiera en FASE_6_OPTIMIZACION.md.

## Datos protegidos y pruebas de integración — fase 8

FinanceStore verifica disponibilidad antes de abrir/escribir. RootView transmite notificaciones de disponibilidad de UIKit; al suspender se retiran las vistas financieras, se cierran hojas y se liberan referencias propias al libro/índice/repositorio. Al recuperar disponibilidad se reabre el almacén. No se garantiza borrado criptográfico de RAM ni cierre interno de todos los descriptores de SwiftData.

El repositorio reaplica atributos antes/después del guardado. Distingue fallo previo de fallo de protección después de commit; este último requiere reabrir y comprobar el resultado antes de repetir. Se añade protocolo interno para inyección controlada de errores y target de integración con directorios temporales. Esquema y reglas financieras conservados. Manifiesto de privacidad incorporado por el generador. Ver FASE_8_PRUEBAS.md para 28 pruebas core, 13 de integración, cinco UI y los límites físicos pendientes.
