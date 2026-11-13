# Verificación de Atajos — 22/10/2026

Versión 0.3.0/build 3. Rama `feat/atajos-gasto-rapido`, basada en el commit 929bee6 de identidad/efectivo (PR #1).

## Implementación

Dos App Intents y App Shortcuts: Abrir gasto rápido (foreground) y Preparar compra detectada (background cuando iOS permita ejecución). Ambos restringidos al proceso principal y autenticación local. App y acciones comparten el mismo FinanceStore en MainActor. La importación solo añade un borrador protegido; no crea un gasto. Las preferencias se fusionan sin sobrescribir capturas recibidas.

Los borradores se guardan como una nueva fila de metadatos dentro del esquema SwiftData existente. Ledger.capture es opcional y los datos anteriores siguen cargando. Al guardar desde EntryEditor se usa Ledger.saveCapturedExpense: valida estado pendiente/ID, guarda el movimiento y marca la captura en una única transacción. Los reintentos no sobrescriben gastos. Un formato inválido o moneda extranjera se rechaza explícitamente. El texto original de los avisos no se guarda.

Se conserva bundle, Team, proyecto, módulo y ruta del almacén. Solo CFBundleName visible se ajusta a Numa para evitar que ShortcutsLink anuncie el nombre interno Finanzas. No instalar versiones anteriores a 0.3.0 después de configurar capturas: rechazan la fila nueva conservando los datos.

## Comprobaciones

| Comprobación | Estado | Evidencia / alcance |
|---|---|---|
| Parser, dinero, reglas, replay, capacidad y compatibilidad de libros | PASS | 35 pruebas core, incluidas 7 nuevas, sin fallos. |
| Persistencia, rollback, protección y guardado conjunto | PASS | 15 pruebas de integración, incluidas 2 nuevas, sin fallos. |
| Interfaz: configuración, cancelación, duplicados, importe requerido y persistencia | PASS | 9 pruebas UI, incluidas 2 nuevas, sin fallos. |
| Regresión completa | PASS | `python3 scripts/validate.py full --output /private/tmp/numa-shortcuts-full-01`; 59 pruebas distintas y archive sin firma. |
| Flujos nuevos aislados | PASS | Ejecución enfocada previa de UI y almacenamiento; repetición visual de configuración posterior. No se suman ejecuciones repetidas al total de 59. |
| Metadatos de App Intents en archive | PASS | extract.actionsdata contiene OpenQuickExpenseIntent y CapturePurchaseIntent, autenticación local y destino main. |
| Inspección visual | PASS | Formulario de compra detectada y pantalla de configuración con datos ficticios. |
| Gesto físico, app Atajos, Wallet y Santander reales | NOT_RUN | Requiere configuración y prueba en el iPhone; no confundir metadatos compilados con ejecución bancaria verificada. |
| Bloqueo físico y autenticación del sistema | NOT_RUN | El guardado bloqueado se prueba por inyección en almacenamiento; el comportamiento real del sistema sigue pendiente. |

Después de la regresión solo se corrigió el nombre visible para el enlace de Atajos y se añadió una captura a la prueba existente. Se recompila, se repite el flujo de configuración y se genera un archive final sin firma. No cambian reglas financieras por ese ajuste de presentación.

Las evidencias completas permanecen locales, excluidas de Git. La guía [ATAJOS.md](ATAJOS.md) detalla la configuración, formatos aceptados, parámetros, límites, iCloud de Atajos y las pruebas físicas pendientes. El importador no consulta cuentas bancarias ni promete que iOS entregue todos los datos de cada evento.
