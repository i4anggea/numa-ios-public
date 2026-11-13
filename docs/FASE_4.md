# Fase 4 — Implementación

Fecha: 21 de octubre de 2026, America/Mexico_City.
Estado: IMPLEMENTADO, verificación inicial parcial; pendiente de revisión de fase 5.

## Reglas confirmadas al comenzar

- Sugerir próxima fecha de pago, editable; meses cortos usan último día disponible.
- Pagos parciales/totales contra deuda registrada; no marcar cuotas automáticamente como pagadas.
- Gastos y otros egresos consumen presupuesto global y de categoría.
- Advertir sobre saldos/presupuestos negativos y permitir confirmar el registro real.
- Deshacer cierre antes de modificar semanas repartidas, solo si las reservas pueden revertirse sin afectar operaciones relacionadas.
- Liberación parcial/total del ahorro a la cuenta original sin generar ingreso.
- Categorías iniciales, renombrado, creación y archivo conservando historial.

## Implementación y decisiones concretas

Proyecto Xcode incluido con aplicación iPhone y target de pruebas UI. Paquete Swift independiente para pruebas de dominio. Sin dependencias de terceros ni descargas necesarias para construirlo con el Xcode instalado.

La representación persistente v1 usa una fila SwiftData por entidad de dominio, con UUID único, tipo y datos Codable. El modelo conceptual sigue siendo cuentas, tarjetas, movimientos, categorías, metas, reservas, presupuestos y cierres. Esta adaptación mantiene el dominio independiente de SwiftData y permite guardar una operación completa en una transacción. No usa relaciones SwiftData; la integridad se controla en la aplicación y requiere profundización en fase 5. Los datos se cargan en memoria; aún no se ha medido su comportamiento con grandes volúmenes.

El margen trasladado se añade exclusivamente al límite global de la semana siguiente, nunca a saldos ni automáticamente a límites por categoría. Las semanas requieren un presupuesto propio; se muestra margen recibido pendiente si todavía no existe.

Se conservan metas con historial aun si la reserva llega a cero. Solo se eliminan metas sin historial, evitando perder trazabilidad. La gestión de cuentas/tarjetas permite añadir/editar, sin eliminación que deje movimientos huérfanos.

El calendario contable y las 09:00 de recordatorios están fijados a Ciudad de México. Los recordatorios próximos se limitan a 60 y se renuevan al abrir/activar la aplicación o modificar tarjetas. No se promete programación indefinida si la app no vuelve a abrirse.

## Verificaciones y evidencia

| Comprobación | Estado | Método y resultado |
|---|---|---|
| Entorno | PASS | Xcode 27.1 (27A9275), Swift 6.4, SDK iOS 27.1 y simulador iPhone 18 Pro iOS 27.0 detectados. |
| Proyecto reproducible | PASS | `python3 scripts/generate_project.py`, salida 0; proyecto con 12 fuentes Swift de la app y target UI. |
| Compilación iOS Simulator | PASS | `xcodebuild ... -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' ... CODE_SIGNING_ALLOWED=NO build`, salida 0, BUILD SUCCEEDED. |
| Reglas financieras | PASS | `swift test --scratch-path /private/tmp/finanzas-core-tests`, salida 0; 12 pruebas, 0 fallos. |
| Arranque en simulador | PASS | `simctl install` y `simctl launch` en iPhone 18 Pro iOS 27.0, salida 0; captura de Inicio inspeccionada. |
| Caso UI inicial | PASS | XCTest `testCreateExpensePersistsAndPrivacyHidesIt`: 1 caso sin fallos. El primer xcodebuild quedó detenido al finalizar el informe y se interrumpió; no se usa como evidencia de salida exitosa de la suite. |
| Última regresión UI | PASS | `xcodebuild ... -destination 'platform=iOS Simulator,id=00000000-0000-0000-0000-000000000000' -derivedDataPath /private/tmp/finanzas-ui-build -resultBundlePath /private/tmp/finanzas-ui-run-02.xcresult -parallel-testing-enabled NO test`, salida 0, TEST SUCCEEDED. Una prueba sin fallos: cuenta de $1,000, gasto de $125.50, saldo $874.50, persistencia, ocultación persistente y apertura de Reportes. |
| Inspección visual inicial | PASS | Capturas exportadas de la última prueba: Inicio con saldo/gasto y parte superior de Reportes inspeccionados. No cubre todas las pantallas ni temas. |
| Prueba explícita sin conectividad | NOT_RUN | No hay servicios de red en la implementación; falta recorrido completo con conectividad deshabilitada. |
| Notificaciones reales y permisos | NOT_RUN | Programador implementado; no se ha verificado entrega en dispositivo. |
| Protección de archivo y exclusión de copias | NOT_RUN | Configuradas; falta comprobar atributos/efectividad y escenarios de bloqueo. |
| Flujos UI de crédito, cierre semanal y ahorro | NOT_RUN | Lógica cubierta parcialmente por pruebas unitarias; falta recorrido completo de interfaz. |
| Accesibilidad, texto grande y ambos temas | NOT_RUN | Preparados; falta validación específica. |
| Rendimiento y auditoría de seguridad | NOT_RUN | Corresponden a fases 6 y 7. |
| iPhone físico y firma | NOT_RUN | Solo instalación en simulador; método de firma privada pendiente. |
| Publicación/CI/CD | NOT_RUN | No solicitados para ejecución en esta fase. |

Incidencias de entorno: el sandbox impidió inicialmente acceso a cachés y CoreSimulator; las operaciones se completaron mediante ejecución revisada fuera del sandbox. Swift Test desde Documentos falló por metadatos que impedían la firma; repetir con directorio de compilación temporal resolvió el fallo. El build inicial detectó errores de sintaxis de vista y de variable de error, corregidos antes de la compilación PASS.

XCTest observó una advertencia de dimensión de frame al mostrar el teclado y Xcode emitió avisos al interpretar la versión del sistema anfitrión. El caso UI pasó; investigar las advertencias en fase 5. No equivalen a una auditoría de interfaz completa.

Logs conservados en `evidence/phase4-build.log`, `evidence/phase4-core-tests.log` y `evidence/phase4-ui-tests.log`. Capturas: `evidence/inicio-con-gasto.png`, `evidence/reporte-con-gasto.png` y originales con manifiesto en `evidence/ui-run-02/`. Solo contienen datos ficticios. Bundle de pruebas en `/private/tmp/finanzas-ui-run-02.xcresult` (temporal). No se ha ejecutado el benchmark de la skill, que no corresponde a esta aplicación.

No hay repositorio Git inicializado en finanzas-ios; no se crearon commits, no se modificó primer-web y no hubo push ni publicación.
