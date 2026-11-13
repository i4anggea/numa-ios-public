# Fase 6 — Optimización con 10,000 movimientos

Estado: optimizaciones implementadas; 28 pruebas de dominio y cinco recorridos UI aprobados. Verificación global parcial: rendimiento físico, memoria/batería y controles de fases posteriores pendientes.

## Alcance y protocolo

El usuario eligió 10,000 movimientos, equilibrio entre apertura/registro/reportes y carga progresiva al desplazarse. Protocolo definido antes de medir en FASE_6_PROTOCOLO.md. No se cambiaron los objetivos después de observar los resultados.

Datos seed-42-v1: 10 cuentas, 8 tarjetas, 20 categorías, 6 metas, 240 eventos de ahorro, 120 presupuestos y 60 cierres. Los 10,000 movimientos abarcan varios años y mezclan ingresos, gastos, otros egresos, débito, crédito, compras a meses, pagos y transferencias.

Motor medido en Release sobre macOS 27.0.1, 10 procesadores lógicos y 16 GiB de memoria física reportados por ProcessInfo. Se conservaron siete muestras por operación después de un calentamiento. Es contexto del anfitrión, no consumo de RAM de la app ni características de un iPhone físico.

Almacén medido en Debug en simulador iPhone 18 Pro, iOS 27.0, SDK 27.1/Xcode 27.1. Se excluye la primera apertura que crea los datos sintéticos; se comparan tres reaperturas y un registro por ejecución. Los tiempos del almacén no son tiempo total de arranque ni latencia táctil, y no se confunden con los tiempos del motor en Release.

## Cambios

1. **Reportes:** una pasada obtiene ingresos, gastos, categorías, métodos y cambios diarios de saldo. La vista reutiliza el resultado y prepara la consulta fuera del actor principal, descartando respuestas canceladas. Antes se recorría el historial por categoría, método, día y cuenta.
2. **Inicio e historial:** índice de lectura y resumen coherente tras abrir o confirmar una operación; ordenación una vez por versión de datos. Se usan mapas de nombres para búsqueda. Comparación de UUID por bytes/tuplas, sin crear cadenas en cada comparación, conservando el orden canónico.
3. **Carga progresiva:** se muestran inicialmente 50 movimientos y se añaden bloques de 50 al alcanzar el final. Los filtros consultan todo el índice antes de limitar las filas visibles. Se recuerda el resultado al volver de un detalle si no cambiaron filtros ni datos. Búsqueda con espera de 150 ms para no lanzar trabajo por cada pulsación; resultados obsoletos se descartan. Categorías ordenadas y acción Restablecer filtros.
4. **Persistencia:** filas y estado persistido conocidos por el repositorio; comparación por UUID/valor y serialización solo de entidades añadidas o modificadas, más eliminaciones explícitas. Una apertura sin cambios no vuelve a serializar todo el archivo. Se conserva validación en la frontera de persistencia y rollback ante error; se retira una validación duplicada del coordinador, no las reglas de las operaciones ni del repositorio.
5. **Validación:** calendario contable inmutable reutilizado, cambios de deuda agrupados en una pasada y egresos asignados a intervalos de semanas cerradas mediante búsqueda binaria. Se conservan fines de semana calculados con Calendar para no convertir semanas históricas con cambio de horario en intervalos de 168 horas.

No se alteró el esquema SwiftData ni se migraron/borraron datos. No hay nuevas dependencias externas, servidores ni telemetría remota. El formato monetario ya costaba aproximadamente 1 ms por 50 importes; no se modificó por no ser el cuello de botella principal.

## Resultados

<!-- PERFORMANCE_TABLE -->
| Operación | Antes (ms) | Después (ms) | Reducción observada |
|---|---:|---:|---:|
| Construcción del índice/resumen | 18.609 | 14.934 | 19.7% |
| Formato de 50 importes (sin cambios) | 1.092 | 1.080 | Sin optimización; variación de muestreo |
| Reporte mensual del motor | 60.977 | 0.246 | 99.6% |
| Registro: reglas del dominio | 19.651 | 10.927 | 44.4% |
| Búsqueda en todo el historial | 21.052 | 18.603 | 11.6% |
| Validación de 10,000 movimientos | 16.805 | 7.633 | 54.6% |
| Reapertura del almacén, simulador | 438.664 | 164.296 | 62.5% |
| Registro completo, simulador | 428.056 | 114.317 | 73.3% |

Motor: medianas de siete muestras. Almacén: mediana de tres reaperturas y una muestra de registro. Reducciones observadas en este ensayo, no garantías universales. Todos los objetivos iniciales se cumplen e invariantes monetarios iguales.
<!-- END_PERFORMANCE_TABLE -->

Un primer ajuste dejó el guardado en 253.72 ms frente al objetivo de 250 ms. Se conserva ese resultado en phase6-storage-after-iteration1.json y no se modificó el objetivo para hacerlo pasar. Después se optimizó la clasificación de egresos de cierres y se repitió la medición.

La comparación incluye todos los resultados monetarios de referencia. Además, las pruebas contrastan los reportes completos de día/semana/mes, resúmenes, filtros y orden con una implementación anterior congelada en Tests/CoreTests/ReferenceReadIndex.swift. Los hashes de Support/SyntheticLedger.swift y Benchmarks/main.swift se comprueban sin cambios entre las mediciones; los hashes acreditan que no se cambió el escenario, no sustituyen pruebas funcionales.

## Verificación

| Control | Estado | Evidencia |
|---|---|---|
| Reglas financieras y equivalencia | PASS | `swift test --scratch-path /private/tmp/finanzas-core-tests`: 28 pruebas, cero fallos. Incluye límites de semana, semanas sin cerrar entre otras cerradas y horario histórico. |
| Benchmark de motor antes/después | PASS | `swift run -c release --scratch-path /private/tmp/finanzas-bench-build FinanceBenchmarks RUTA_JSON`, salida 0 en ambos. Mismo fixture/harness e invariantes monetarios iguales. |
| Configuración | PASS | Generador de proyecto ejecutado; 16 fuentes de app. `plutil -lint` del proyecto y Info.plist correcto. |
| Regresión de interfaz | PASS | Cuatro recorridos financieros aprobaron en `phase6-ui-regression.log`; el caso amplio se repitió corregido y aprobó con salida 0/TEST SUCCEEDED en `phase6-ui-history.log`. No se presenta la ejecución anterior completa (salida 65) como aprobada. El código de producto es el mismo en ambos. |
| Compilación Release | PASS | `xcodebuild -configuration Release -sdk iphonesimulator -destination "generic/platform=iOS Simulator" -derivedDataPath /private/tmp/finanzas-release-build CODE_SIGNING_ALLOWED=NO build` con proyecto/esquema Finanzas: salida 0, BUILD SUCCEEDED; `evidence/phase6-release.log`. |
| Capturas finales | PASS | Exportadas en `evidence/phase6-ui-final`; inspeccionados el retorno a 10,001 registros, una fila posterior al primer bloque y el reporte semanal. |
| Memoria/batería y rendimiento en iPhone real | NOT_RUN | No hay dispositivo físico configurado; no se afirma una reducción de consumo ni un tiempo de respuesta garantizado en él. |
| Auditoría de seguridad | NOT_RUN | Fase 7, aún no iniciada. |

La medición UI base capturó correctamente apertura/registro y luego falló por intentar localizar un campo de búsqueda que estaba contraído. No se usa como prueba de interfaz completa aprobada. En iteraciones posteriores también se corrigió una consulta de prueba que intentaba seleccionar Todas cuando estaba fuera de la porción visible de un menú largo. Los datos medidos de apertura/registro se obtienen antes de esas acciones y se conservan; el recorrido final completo aprobó. Otro selector esperaba 10001 sin el separador de miles que iOS muestra como 10,001; la captura demostró el estado correcto y se corrigió la aserción para comparar dígitos, igual que al inicio del caso.

En una iteración los cinco casos individuales aprobaron, pero xcodebuild quedó detenido recopilando diagnósticos del sistema; se interrumpió ese proceso. Otra terminó los casos con un fallo del selector de prueba descrito. La repetición final usa `-collect-test-diagnostics never` para no quedar esperando esa recopilación; no desactiva pruebas ni comprobaciones de la app. Se conservan advertencias del SDK sobre versión del anfitrión y dimensiones de frame al abrir teclado.

## Límites y recuperación

La carga progresiva limita las filas de interfaz, **no es paginación de consultas a SwiftData**: se conserva el libro completo y un índice en memoria. Es una decisión proporcional al volumen medido; el intercambio es memoria adicional a cambio de evitar consultas, ordenaciones y serializaciones repetidas. No se ha medido el límite de 100,000 movimientos ni el uso real de RAM/batería. No declarar mejoras de memoria por mostrar menos filas.

Los reportes siguen usando todos los movimientos. Los cambios de datos invalidan el índice y los resultados; la interfaz no publica el nuevo estado hasta confirmar la escritura. Ante error se conserva el estado anterior. El repositorio no omite validación de datos nuevos; solo evita guardar de nuevo un estado exactamente igual al ya validado y persistido por esa instancia.

No se realizó despliegue ni instalación en un iPhone físico. No hay repositorio Git inicializado, por lo que no se creó commit. Las fases 7 a 10 siguen pendientes.

## Reproducción

```sh
swift test --scratch-path /private/tmp/finanzas-core-tests
swift run -c release --scratch-path /private/tmp/finanzas-bench-build FinanceBenchmarks /private/tmp/finanzas-core-current.json
```

El JSON de referencia previo se conserva en evidence; ejecutar el segundo comando sobre el código actual solo mide la versión actual. Para comparar los artefactos originales: `python3 scripts/compare_performance.py`. Este script compara mediciones existentes, no ejecuta pruebas de la app.

La prueba `testTenThousandHistoryPerformance` utiliza un directorio UUID aislado y escribe performance.json con tiempos/recuentos, sin importes ni notas, solo en Debug con bandera explícita. Los fixtures no se incluyen en Release ni en el almacén personal.

Comando del recorrido amplio aprobado (salida 0):

```sh
xcodebuild -project Finanzas.xcodeproj -scheme Finanzas -configuration Debug -destination "platform=iOS Simulator,id=00000000-0000-0000-0000-000000000000" -derivedDataPath /private/tmp/finanzas-ui-build -resultBundlePath /private/tmp/finanzas-phase6-history-passed.xcresult -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:FinanceUITests/FinanceUITests/testTenThousandHistoryPerformance test
```
