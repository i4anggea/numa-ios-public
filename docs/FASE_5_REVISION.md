# Fase 5 — Revisión y corrección

Fecha: 21 de octubre de 2026 (America/Mexico_City).
Estado: revisión y correcciones de fase 5 completadas. Verificación del alcance seleccionado: 22 pruebas financieras y 4 casos UI PASS. La aplicación conserva verificaciones globales pendientes para fases posteriores.

## Alcance solicitado

Priorizar exactitud financiera/integridad y uso cotidiano. Escenarios principales: una semana con ingreso, efectivo, débito, presupuesto, ahorro y cierre; una compra de crédito con intereses, mensualidades, pago parcial, corrección y eliminación relacionada. Se revisaron los fuentes del dominio, persistencia, recordatorios, pantallas/formularios, pruebas y configuración del proyecto.

No es la auditoría formal de seguridad ni la optimización de las fases 7 y 6. No se añadieron servicios ni dependencias, no se publicaron artefactos y no se accedió a datos financieros reales.

## Hallazgos y correcciones por prioridad

| ID | Prioridad | Ejemplo del problema | Corrección | Comprobación |
|---|---|---|---|---|
| F5-01 | P1 | El archivo podía contener un movimiento que apuntara a una cuenta inexistente, un importe negativo o identificadores repetidos y aun así superar la validación anterior. Esto podía alterar los agregados o reescribir entidades incorrectas. | Validar tamaños, UUID globales, referencias, importes, fechas, planes, presupuestos y enlaces de cierres antes de agregar o guardar. Comparar UUID de cada fila con el payload al decodificar. Fallar sin recrear/borrar el almacén. | Pruebas de referencias huérfanas, importes fuera de rango y UUID/semanas duplicados, reproducidas antes de corregir. El control fila/payload requiere prueba de integración específica adicional. |
| F5-02 | P1 | Registrar pago el 14 de septiembre contra una compra del día 15 producía deuda negativa el día 14, aunque el saldo final fuera positivo. | Verificar deuda cronológica por día. Revisar fecha, compra y apertura si un pago excede la deuda de ese día. Los movimientos del mismo día se concilian en conjunto porque la captura solo expone fecha. | `testPaymentCannotPrecedeRecordedDebt` y regresiones de pagos/correcciones. |
| F5-03 | P1 | Cerrar una semana trasladando margen a otra que ya estaba cerrada cambiaba retroactivamente su presupuesto. | Exigir deshacer primero el cierre de destino cuando se trasladará margen. Operación atómica, sin cambios parciales ante rechazo. | `testCannotCarryIntoAnAlreadyClosedWeek`. |
| F5-04 | P1 | Ahorro de cierre de $200, liberación posterior de $100 y nueva aportación de $100: el saldo final permitía deshacer el cierre, dejando una reserva histórica de -$100. | Comprobar historial de reservas por meta/cuenta antes de confirmar una reapertura; conservar todo el estado si se rechaza. | `testReopenDoesNotCreateNegativeHistoricalReserve` y pruebas previas de reapertura. |
| F5-05 | P2 | Categorías archivadas quedaban bloqueadas en el selector, pero el motor admitía nuevos movimientos que las utilizaran. | Aplicar la regla también en el dominio. Permitir corregir el historial que ya utilizaba esa categoría. | `testArchivedCategoryCannotBeUsedForNewEntryButHistoryCanBeEdited`. |
| F5-06 | P2 | Los errores al guardar podían aparecer al fondo de un formulario y los errores globales podían intentar presentarse detrás de una hoja ya abierta. | Alertas locales de formulario y presentación de errores del almacén en la superficie activa. El formulario conserva los valores al fallar. | Caso UI de validación y caso de eliminación protegida desde una hoja. |
| F5-07 | P2 | El cierre automático de una alerta compartía el borrado del movimiento pendiente con la acción de confirmar. | Separar estado de presentación y movimiento pendiente; cancelar y confirmar tienen acciones explícitas. | Caso UI: cancelar conserva formulario, confirmar deja un único gasto, saldo negativo y persistencia tras reapertura. Endurecimiento por revisión de código; no se reprodujo un fallo en la versión previa mediante UI. |
| F5-08 | P2 | El teclado podía cubrir selectores y varios formularios numéricos no ofrecían botón para cerrarlo. | Botón Listo y cierre por desplazamiento en formularios numéricos. | Se observó un selector de pago parcialmente cubierto en el diagnóstico UI; pruebas de captura y pago tras cerrar teclado. |
| F5-09 | P2 | Hojas de edición/ahorro estaban ligadas a secciones de listas sujetas a desplazamiento y reutilización. El recorrido de ahorro perdió el formulario al intentar usarlo. | Presentar hojas desde la vista principal de meta/cuenta/tarjeta, conservando identidad y entorno de fechas. | Caso UI de ahorro/cierre aprobado tras la corrección. |

Endurecimientos adicionales revisados: reconciliación de recordatorios en serie para evitar que llamadas solapadas dejen fechas antiguas; cubierta de privacidad también en hojas, no solo detrás de ellas. Ambos compilan, pero sus garantías de entrega/captura en dispositivo se comprobarán en fases 7 y 8. No se presentan como controles de seguridad completamente verificados.

## Escenarios y resultados esperados

**Semana de dominio:** $7,000 iniciales, ingreso de $1,000, gasto en efectivo de $200 y otro egreso con débito de $100 → dinero total $7,700. Presupuesto $1,000 → sobrante $700. Reservar $200 y trasladar $300 mantiene total $7,700, disponible $7,500 y margen siguiente $300.

**Semana de interfaz:** cuenta inicial en cero, ingreso $2,000, traslado interno $500 a efectivo, gasto $200 y otro egreso con débito $100 → total $1,700. Presupuesto $1,000 → sobrante $700. Cierre con ahorro $200 y margen $300 → disponible $1,500. Liberar $100 → disponible $1,600. Deshacer el cierre debe rechazarse mientras la liberación dependa de su reserva.

**Crédito:** precio $1,000, total $1,201 y tres mensualidades → $400.34 + $400.33 + $400.33. Pago $400.34 → deuda $800.66; corregir total a $1,301 → deuda $900.66. No duplicar gasto al pagar. Eliminar la única compra con un pago registrado debe rechazarse y conservar sus datos; al eliminar primero el pago, la compra puede eliminarse.

## Evidencia y comandos

| Verificación | Estado | Método / evidencia |
|---|---|---|
| Reproducción previa | PASS | `swift test --scratch-path /private/tmp/finanzas-core-tests`: salida 1 deliberada antes de las correcciones. Doce pruebas originales pasaron; ocho de las diez nuevas fallaron con 14 aserciones, demostrando los defectos de dominio. |
| Pruebas financieras tras corrección | PASS | Mismo comando, salida 0; 22 pruebas, cero fallos. Repetición final conservada en `evidence/phase5-core-after.log`. |
| Configuración de proyecto | PASS | Generador ejecutado, 14 fuentes de app. `plutil -lint Config/Info.plist Finanzas.xcodeproj/project.pbxproj`: salida 0. |
| Iteraciones UI previas | FAIL histórico, resuelto | Las ejecuciones 01/02/04 fallaron al ampliar cobertura: problemas de producto de teclado/hojas y problemas de pruebas con etiquetas combinadas, vistas subyacentes y botones fuera de pantalla. El intento 03 no ejecutó por usar una llamada inexistente de XCTest en las pruebas. Logs preservados; se corrigieron las causas, no se eliminaron las aserciones financieras ni los pasos funcionales. |
| Regresión UI completa final | PASS | Ejecución 05: `xcodebuild ... test`, salida 0, TEST SUCCEEDED. Cuatro casos completos, cero fallos, 166.527 s de ejecución de casos. Log `evidence/phase5-ui-final.log`. Incluye ambos escenarios solicitados, errores visibles en hojas y conservación de datos tras rechazo/reapertura. |
| Compilación actual | PASS | La ejecución 05 construyó app y target UI para iPhone 18 Pro, iOS 27.0; SDK iOS 27.1. Sin errores de compilación. |
| Inspección de nuevas capturas | PASS, parcial | Se exportaron seis PNG de la ejecución aprobada; inspeccionados visualmente detalle de mensualidades corregidas y saldo negativo. También se inspeccionó cierre semanal en la iteración 04. No equivale a revisar todos los tamaños, temas o estados. |
| Identidad fila/payload y corrupción real de SwiftData | NOT_RUN | La validación está implementada y compilada; falta prueba de integración inyectando corrupción en una base desechable. Las referencias y datos inválidos del dominio sí están cubiertos. |
| Recordatorios y cubierta de privacidad en selector | NOT_RUN | Cambios compilados y recorridos normales aprobados; entrega real, solapamiento y captura del selector requieren verificaciones específicas. |
| Dispositivo físico | NOT_RUN | Firma/instalación privada aún no configuradas. |
| Auditoría, rendimiento y batería completa | NOT_RUN | Fases posteriores; no se adelanta una aprobación global. |

El SDK/simulador emite advertencias de metadatos del anfitrión y de dimensión de frame al activar teclado. No se encontró un cálculo explícito de tamaño negativo en el código; se conserva como advertencia por investigar, sin afirmar que la causa sea definitivamente del sistema.

Comando de regresión UI final:

```sh
xcodebuild -project Finanzas.xcodeproj -scheme Finanzas -configuration Debug \
  -destination 'platform=iOS Simulator,id=00000000-0000-0000-0000-000000000000' \
  -derivedDataPath /private/tmp/finanzas-ui-build \
  -resultBundlePath /private/tmp/finanzas-phase5-ui-05.xcresult \
  -parallel-testing-enabled NO test
```

Los tests siguen incluyendo desplazamiento real de listas para alcanzar controles, y sus selectores excluyen vistas que quedan detrás de una hoja. Evidencias definitivas: `evidence/phase5-core-before.log`, `evidence/phase5-core-after.log`, `evidence/phase5-ui-final.log` y `evidence/phase5-ui-final/manifest.json`. El bundle XCResult completo está en la ruta temporal del comando anterior.

## Archivos afectados

- `Sources/Core/Ledger.swift` y nuevo `LedgerValidation.swift`: operaciones atómicas e invariantes estructurales/históricas.
- `Sources/App/Persistence.swift`: validación de identidad al cargar/guardar y serialización de reconciliaciones.
- `Sources/App/UITestFixtures.swift`: nuevos escenarios de prueba aislados en Debug.
- `Sources/UI/Shared.swift`, `RootView.swift`, `EntryEditor.swift`, `AccountsView.swift`, `BudgetsView.swift`, `GoalsView.swift` y `SettingsView.swift`: errores, confirmación, teclado, estabilidad de hojas y privacidad visual.
- `Tests/CoreTests/ReviewTests.swift` y `Tests/UITests/FinanceUITests.swift`: reproducción y regresiones.
- Proyecto Xcode/generador ejecutado para incluir fuentes nuevas; documentos de arquitectura, interfaz, requisitos y continuidad actualizados.

## Próximo paso

Fase 6: preguntar volumen esperado, prioridad de rendimiento y navegación del historial. Medir antes/después de cualquier optimización, conservando los resultados financieros y las pruebas de regresión. No se ha iniciado esa fase.

## Compatibilidad y límites

No cambia el esquema SwiftData v1 ni se migran/borran registros. Las nuevas validaciones rechazan estados incoherentes que antes podían aceptarse; ante uno de esos archivos la app muestra error y conserva el contenido, sin repararlo silenciosamente. La reparación de archivos realmente dañados no se implementa en esta fase.

Las fixtures de semana/crédito solo se habilitan en Debug, con `--ui-testing`, UUID válido para un directorio separado y un nombre de escenario permitido. No se cargan en el almacén personal ni se compilan sus datos de prueba en Release.

No existe Git inicializado en esta carpeta; no se creó commit. Se mantuvo el proyecto separado de primer-web.
