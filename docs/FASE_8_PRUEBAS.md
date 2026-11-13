# Fase 8 — Conservación de datos y exactitud financiera

Estado: correcciones implementadas y regresión de simulador aprobada. 28 pruebas de dominio, 13 de integración y cinco recorridos UI, cero fallos en las ejecuciones finales. Verificación física pendiente según el entorno elegido por el usuario.

## Alcance aprobado

Empezar con simulador y preparar una guía para iPhone. Priorizar conjuntamente protección/conservación del almacenamiento y exactitud financiera: semanas, cierres, ahorro, meses y pagos. No se introducen cuentas, biometría, nube, recuperación ni exportación. Ningún ensayo utiliza datos financieros reales.

## Correcciones de auditoría

- **H2:** FinanceStore comprueba disponibilidad de datos protegidos antes de abrir o escribir. Al recibir el evento de indisponibilidad, deja de estar listo, libera sus referencias al repositorio y sustituye libro/índice por valores iniciales sin datos personales. RootView cierra sus hojas y retira las pantallas financieras; conserva la cubierta de privacidad al quedar inactiva. Al recibir disponibilidad o volver a primer plano, reabre si estaba suspendido. Los recordatorios ya programados permanecen genéricos; las reconciliaciones nuevas requieren almacén disponible. Liberar referencias propias no demuestra que el framework cierre cada descriptor ni garantiza borrado de RAM: la prueba física continúa pendiente.
- **Protección tras escritura:** se vuelve a aplicar la política a directorio y auxiliares antes/después de guardar y en guardados sin cambios. Un fallo previo puede rechazarse antes de confirmar; un fallo posterior se distingue expresamente de un rollback. En ese caso se retira la vista financiera y se exige reabrir/comprobar el registro antes de repetir, porque la escritura ya pudo terminar. Se mantiene validación, transacción y guardado diferencial.
- **H3:** Config/PrivacyInfo.xcprivacy declara ausencia de seguimiento/recogida remota y uso de UserDefaults para preferencias propias, motivo CA92.1. El generador incorpora el archivo a Resources. La comprobación del bundle y del archive se registra abajo; no se ha enviado a App Store Connect.
- **H4:** los fallos inesperados de apertura/guardado muestran mensajes estables sin el dominio interno de SwiftData/NSError. Se mantienen explicaciones de reglas financieras y conservación de registros.

No se cambia el esquema ni se borran/migran datos. Se conserva el funcionamiento local. Un protocolo interno de repositorio permite inyectar fallos antes/después de confirmar sin manipular un almacén personal; no añade dependencias externas.

Referencias oficiales consultadas: [protección y eventos de disponibilidad](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files), [motivos de APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). La configuración de software no sustituye las comprobaciones en dispositivo.

## Pruebas nuevas de integración

El target FinanceIntegrationTests utiliza XCTest dentro de la app del simulador y directorios temporales UUID independientes. El arranque del host de pruebas usa también un directorio UITest explícito, sin abrir PrivateFinance. Las pruebas de UI siguen creando sus propios UUID.

1. Inicio con datos protegidos indisponibles: no crea ni abre repositorio hasta recuperar disponibilidad.
2. Tres ciclos simulados de indisponibilidad/disponibilidad: libro retirado, operación de escritura no invocada mientras está suspendido y saldo/registro recuperados sin duplicados.
3. Guardado, reapertura, edición y eliminación; marca de exclusión de copias tras escritura.
4. Candidato financiero inválido: conserva el estado persistido anterior.
5. Fallo de transacción después de modificar parcialmente el contexto por conflicto de tipo de fila: rollback de inserciones, estado anterior conservado y siguiente escritura válida posible.
6. Payload malformado, identidad diferente y tipo desconocido: apertura rechazada sin sustituir el contenido.
7. Fallo de apertura: no revela el dominio de error interno.
8. Fallo simulado antes de confirmar: saldos publicados/persistidos conservados y reintento posterior registra una sola vez.
9. Fallo simulado de protección después de confirmar: vista indisponible, aviso específico y reapertura con exactamente un movimiento. Esta inyección prueba al coordinador; no reproduce un fallo real del sistema de archivos en ese punto.
10. Semana/ahorro/margen trasladado sobreviven a una reapertura real de SwiftData.
11. Compra a meses y pago parcial sobreviven a reapertura sin duplicar gasto.

El recuento final de funciones es 13: el punto 6 incluye tres casos separados. La simulación de disponibilidad no cambia las claves criptográficas del simulador y no se registra como prueba de cifrado físico.

## Matriz de verificación

Evidencia definitiva de esta tanda; PASS solo para el alcance observado.

| Control | Estado | Evidencia |
|---|---|---|
| Dominio financiero | PASS | 28 pruebas, salida 0, evidence/phase8/core-tests.log. |
| Primera tanda de integración | PASS | 10 pruebas, salida 0, evidence/phase8/integration.log. |
| Integración ampliada y UI completas | PASS | 13 casos de integración y cinco UI; comando completo salida 0/TEST SUCCEEDED. `full-regression.log`, bundle temporal `/private/tmp/finanzas-phase8-full-02.xcresult`. |
| Errores/corrupción de copias SQLite | PASS | Seis copias nuevas del historial sintético: control válido abre y cinco alteraciones se rechazan. Contenido conservado y sin diagnósticos activados. `storage/storage-results.json`, capturas y run.log. Las seis capturas se inspeccionaron. |
| Release/archive y manifiesto embebido | PASS | `xcodebuild -configuration Release -sdk iphoneos -destination "generic/platform=iOS" -archivePath /private/tmp/finanzas-phase8-unsigned.xcarchive CODE_SIGNING_ALLOWED=NO archive` con proyecto/esquema Finanzas: salida 0/ARCHIVE SUCCEEDED. Manifiesto embebido idéntico al fuente y marcadores de fixtures/fallos/diagnóstico ausentes del binario. `device-archive.log`, `archive-checks.json`. Archive SIN firma: no acredita instalación ni aceptación de Apple. |
| Configuración reproducible | PASS | Generador produce el mismo hash al repetirse; plutil de proyecto, Info.plist y manifiesto correcto; py_compile de scripts correcto. |
| Marca de exclusión tras correcciones | PASS (simulador) | Directorio/base/WAL/SHM devuelven true en Foundation. `file-attributes.json`; atributo de clase de protección sigue no disponible en simulador. |
| Inspección visual | PASS (acotada) | Capturas de cierre semanal, compra corregida y mensaje genérico inspeccionadas. Nueve capturas UI exportadas en ui-captures. No implica revisión exhaustiva de temas/accesibilidad. |
| Protección criptográfica con iPhone bloqueado | BLOCKED | Sin iPhone firmado/configurado; usuario eligió simulador y guía posterior. |
| Marca de protección completa en físico | BLOCKED | Simulador no devuelve el atributo real; no dar por resuelto H1 de fase 7. |
| Copia/restauración del sistema | BLOCKED | Requiere entorno separado; no borrar/restaurar un iPhone personal como prueba. |
| Entrega de avisos y modo avión real | NOT_RUN | Guía preparada, pendientes de ejecución física. |
| VoiceOver, texto grande y tema oscuro exhaustivos | NOT_RUN | Fuera de los dos grupos priorizados en esta tanda; quedan pendientes antes de distribución pública. |
| App Store Connect / firma de dispositivo | NOT_RUN | No se configuró distribución ni se publicó. |

## Guía y limitaciones

PRUEBAS_IPHONE.md contiene preparación, cifras esperadas, bloqueo desde Inicio/formularios/hojas, selector, modo avión, recordatorios, protección de archivos y registro de resultados. Todas sus casillas parten pendientes; no convertir el documento en evidencia ejecutada. Si existe una instalación con datos personales, usar otro bundle de validación y conservarla.

No se ensayó un corte físico de energía durante una escritura ni migraciones de una versión futura. Los ensayos de errores no equivalen a extracción forense o verificación del sandbox de iOS. El análisis de archivos auxiliares se limita a los generados por el esquema actual; no hay almacenamiento externo de blobs.

## Reproducción local

```sh
swift test --scratch-path /private/tmp/finanzas-core-tests
python3 scripts/generate_project.py
xcodebuild -project Finanzas.xcodeproj -scheme Finanzas -configuration Debug -destination 'platform=iOS Simulator,id=00000000-0000-0000-0000-000000000000' -derivedDataPath /private/tmp/finanzas-phase8-build -parallel-testing-enabled NO -collect-test-diagnostics never test
```

El generador conserva el target de integración y el manifiesto. Ejecutar Test usa un directorio ficticio para el host; Run normal mantiene la base personal, sin flags de pruebas. Si se cambian ajustes en Xcode, reflejarlos en el generador antes de regenerar. No hay Git inicializado, commit, publicación ni consumo de servicios externos.

## Incidencias de ejecución y cobertura pendiente

Una compilación intermedia de las pruebas nuevas falló por usar una etiqueta de constructor incorrecta en Category. Se corrigió el test; no fue un fallo de la app. Se conserva `test-compile-iteration1.log`; la ejecución completa posterior aprobó los 18 casos de Xcode. Las advertencias de frame al abrir teclado y metadatos del anfitrión observadas en fases anteriores siguen apareciendo en el simulador; no hubo fallo de los recorridos finales. El archive solo informa extracción de AppIntents omitida por no usar ese framework.

H2 queda implementado y cubierto en simulación, con prueba física pendiente. H3 queda corregido y embebido, con validación de distribución pendiente. H4 queda corregido y verificado. H1 continúa BLOCKED para el escenario criptográfico real. No se afirma verificación completa ni se instalaron/publicaron builds en iPhone/App Store. Fases 9 y 10 pendientes de sus preguntas.
