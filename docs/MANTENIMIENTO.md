# Numa — Guía técnica de mantenimiento

Estado documentado: versión 0.3.0. Hay validaciones locales y respaldo privado en GitHub. El usuario ya probó la versión inicial en su iPhone; faltan la actualización física y las comprobaciones de seguridad/accesibilidad de esta mejora. La disponibilidad comercial del nombre Numa no se ha comprobado.

## Identidad y entorno

El nombre visible es Numa. Por continuidad se conservan proyecto/esquema/módulo `Finanzas`, bundle ID definido en Config/AppIdentity.json (actualmente `com.example.numa`), directorio `PrivateFinance` y esquema de datos v1. El identificador original local.personal.finanzas no estaba disponible en Apple al configurar la primera instalación; se sustituyó antes de instalar en el iPhone. Cambiar marca por sí solo no requiere renombrar identificadores. Un cambio futuro del bundle ID crea otro contenedor y debe planificarse como tal.

Entorno de la última regresión funcional: Xcode 27.1 (27A9275), Swift 6.4, SDK iOS 27.1; simulador iPhone 18 Pro con iOS 27.0. Deployment target iOS 27. El paquete Swift del motor también permite ejecutar pruebas nativas en macOS. No hay dependencias externas declaradas, servidor ni credenciales requeridas para simulador.

Abrir [Finanzas.xcodeproj](../Finanzas.xcodeproj) y seleccionar esquema Finanzas. [README](../README.md) contiene los comandos de arranque. El proyecto no tiene Git inicializado; no interpretar los hashes de evidencia como commits.

## Mapa del código

| Ubicación | Responsabilidad |
|---|---|
| [Ledger.swift](../Sources/Core/Ledger.swift) | Valores Codable, centavos, calendario, operaciones y reglas financieras. |
| [LedgerValidation.swift](../Sources/Core/LedgerValidation.swift) | Validación estructural e histórica antes de aceptar el libro. |
| [LedgerReadModel.swift](../Sources/Core/LedgerReadModel.swift) | Índice ordenado, resumen, filtros y reportes derivados. |
| [Persistence.swift](../Sources/App/Persistence.swift) | Esquema SwiftData, protocolo/repositorio, guardado diferencial y FinanceStore. |
| [Reminders.swift](../Sources/App/Reminders.swift) | Reconciliación serializada de recordatorios locales. |
| [Sources/UI](../Sources/UI) | Vistas SwiftUI, formularios, presentación de errores y cubierta de privacidad. |
| [Tests/CoreTests](../Tests/CoreTests) | Reglas financieras y equivalencia frente a referencia de consultas. |
| [Tests/IntegrationTests](../Tests/IntegrationTests) | SwiftData y coordinador, disponibilidad simulada y fallos controlados. |
| [Tests/UITests](../Tests/UITests) | Flujos de semana, ahorro, crédito, registro, privacidad e historial amplio. |
| [Support](../Support) y [Benchmarks](../Benchmarks) | Fixture determinista y medición local; fixtures de app excluidas de Release. |

Consulta [arquitectura](ARQUITECTURA.md) y [requisitos](REQUISITOS.md) para decisiones y reglas completas. No hay endpoints HTTP ni autenticación que documentar en esta versión.

## Recorrido de una escritura

1. El formulario construye el valor y valida campos; las advertencias de saldo/presupuesto permiten confirmación explícita.
2. `FinanceStore.change` verifica disponibilidad y prepara una copia del libro. La operación de dominio modifica esa copia.
3. `LocalRepository.save` valida el libro, compara entidades con el estado persistido y modifica únicamente filas necesarias en un contexto sin autosave.
4. Tras confirmar la transacción, actualiza sus referencias y reaplica atributos de protección. Solo al concluir publica FinanceStore el libro y reconstruye su índice/revisión.
5. Si falla antes de confirmar, el contexto modificado hace rollback. Si falla la protección después de confirmar, `RepositoryFailure.protectionAfterCommit` obliga a retirar las vistas y reabrir/comprobar; no anunciar que el movimiento no se guardó.

No mover cálculos de deuda/presupuesto a las vistas ni actualizar importes en ellas por anticipado. No repetir automáticamente una operación cuyo resultado de escritura sea incierto.

## Persistencia y cambios de esquema

Cada `FinanceSchemaV1.StoredEntity` tiene UUID, tipo y payload Codable. Las entidades del dominio son Account, Card, Category, Entry, Goal, SavingsEvent, WeeklyBudget y WeekClosure. El calendario de cuotas es derivado de Entry; no representa cuotas conciliadas con el banco.

La base vive en Application Support/PrivateFinance/Finance.store, con auxiliares de SQLite gestionados por SwiftData. CloudKit está desactivado. La carga rechaza tipo desconocido, JSON inválido, identidad fila/payload distinta y referencias/reglas inválidas. No sustituir errores de apertura por una base vacía ni eliminar el archivo para recuperar disponibilidad.

El esquema está versionado; el plan solo contiene v1 y aún no tiene etapas de migración. Para cambiar modelos o payloads:

1. Definir compatibilidad de lectura, valores ausentes y transformación de datos con fixtures de la versión anterior.
2. Ensayar apertura, migración, escritura y reapertura sobre copias sintéticas; comprobar invariantes e identificadores.
3. Diseñar recuperación del cambio sin pérdida antes de aplicarlo a datos reales. No asumir que bajar el binario revierte una migración.
4. Actualizar documentación/evidencia y obtener autorización contextual si implica incompatibilidad o transformación destructiva.

No se incluye backup del usuario, exportación ni restauración en v1. No crear copias ocultas de datos personales para simplificar una migración: contradice el alcance aprobado.

## Invariantes a conservar

- Dinero en Int64 de centavos; no usar Double para aritmética monetaria. Las gráficas pueden convertir resultados ya calculados para dibujar.
- `Money.maximum` limita un importe a 100,000,000,000 centavos; se comprueban además volúmenes y rangos antes de agregaciones.
- Compra a crédito: deuda y presupuesto por el total en la fecha de compra. Pago: baja cuenta/deuda sin gasto duplicado.
- Débito: mismo saldo de la cuenta vinculada. Transferencia: conserva dinero total.
- Reserva: baja disponible y mantiene total. Liberación: no es ingreso.
- Semanas lunes-domingo en America/Mexico_City, intervalo con final excluido. Meses cortos y semanas históricas se calculan con Calendar.
- Repartos no duplicables y reversión condicionada por dependencias. No admitir deuda histórica negativa al cierre de una fecha ni reservas históricas negativas por meta/cuenta.

## Datos protegidos, errores y notificaciones

RootView escucha eventos UIKit de disponibilidad de datos protegidos y los transmite a FinanceStore. Al suspender, este retira sus referencias al repositorio y al libro/índice cargado; las hojas se cierran. Al recuperar disponibilidad o volver a primer plano, reabre si estaba suspendido. Se comprueba disponibilidad también antes de escribir. Esto no garantiza borrado de RAM ni que todos los descriptores internos del framework se cierren inmediatamente.

Directorio y archivos reciben protección completa y exclusión de copias al abrir y antes/después de guardar. La clase criptográfica no se pudo comprobar en simulador; la prueba física permanece pendiente. Tampoco se completó una copia/restauración real del sistema.

Los errores inesperados de almacenamiento usan mensajes estables; las reglas financieras conservan explicación útil. No añadir payloads, importes, alias o credenciales a logs. Los diagnósticos de tiempos se limitan a Debug, prueba explícita y directorio UUID.

Los recordatorios usan contenido genérico, hasta 60 solicitudes próximas y reconciliaciones serializadas. Se renuevan al abrir/configurar; no hay servicio de servidor que mantenga el horizonte cuando la app no se usa. No confundir la solicitud pendiente con entrega comprobada. Las cuotas de crédito no se concilian por notificaciones.

## Índice, filtros y rendimiento

FinanceStore reconstruye LedgerReadIndex al abrir o confirmar cambios. El historial filtra todo el índice, muestra bloques de 50 y descarta resultados cancelados; la búsqueda espera 150 ms. Los reportes agregan datos en una pasada y se preparan fuera del actor principal.

El libro y el índice permanecen completos en memoria: la carga progresiva es de filas de UI, no paginación de SwiftData. No se ha demostrado una reducción de RAM/batería ni el comportamiento de 100,000 movimientos. Las [mediciones de fase 6](FASE_6_OPTIMIZACION.md) conservan baseline, protocolo y límites; cambios posteriores de protección no deben presentarse como una repetición idéntica de ese benchmark.

## Configuración y generación reproducible

[generate_project.py](../scripts/generate_project.py) genera project.pbxproj, esquema compartido e Info.plist. Conserva target de integración y el manifiesto [PrivacyInfo.xcprivacy](../Config/PrivacyInfo.xcprivacy) como recurso. No edita el contenido de ese manifiesto. Reflejar en el generador cualquier cambio de proyecto que deba persistir.

```sh
python3 scripts/generate_project.py
plutil -lint Finanzas.xcodeproj/project.pbxproj Config/Info.plist Config/PrivacyInfo.xcprivacy
```

| Entrada de pruebas | Condición y uso |
|---|---|
| `--ui-testing` y `FINANCE_TEST_STORE` | Solo Debug, UUID válido; seleccionan directorio UITest-UUID. Sin estas condiciones se usa PrivateFinance. |
| `FINANCE_TEST_SCENARIO` | Solo en prueba aislada vacía; week, credit o large crean cifras ficticias. |
| `FINANCE_PERFORMANCE=1` | Solo con Debug y prueba UUID explícita; escribe tiempos y recuentos, sin contenido financiero. |

TestAction del esquema configura un directorio UITest para el host XCTest. Las pruebas UI crean sus propios UUID; las de integración usan directorios temporales únicos. Run normal no hereda los flags del TestAction. No ejecutar herramientas de corrupción contra PrivateFinance.

## Verificación por tipo de cambio

Para reglas financieras, ejecutar pruebas del motor:

```sh
swift test --scratch-path /private/tmp/finanzas-core-tests
```

Para persistencia/coordinación o UI, usar un simulador disponible. Sustituir UUID_DEL_SIMULADOR por uno obtenido con `xcrun simctl list devices available`:

```sh
xcodebuild -project Finanzas.xcodeproj -scheme Finanzas -configuration Debug \
  -destination 'platform=iOS Simulator,id=UUID_DEL_SIMULADOR' \
  -derivedDataPath /private/tmp/finanzas-validation \
  -parallel-testing-enabled NO -collect-test-diagnostics never test
```

Añadir `-only-testing:FinanceIntegrationTests` para integración focalizada, o `-only-testing:FinanceUITests` para interfaz. `-collect-test-diagnostics never` evita una recopilación que se bloqueó en este anfitrión; no desactiva las pruebas. Dar un resultBundlePath nuevo si se desea conservar xcresult; no reutilizar uno existente.

Para compilar un archive de dispositivo sin firma:

```sh
xcodebuild -project Finanzas.xcodeproj -scheme Finanzas -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/finanzas-device \
  -archivePath /private/tmp/Numa-validacion.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

Esto no instala, firma, publica ni valida aceptación en App Store Connect. Inspeccionar Products/Applications/Finanzas.app/PrivacyInfo.xcprivacy dentro del archive; el nombre interno del producto se conserva aunque el nombre visible sea Numa.

Para documentación o texto de marca, comprobar enlaces, coherencia y configuración; no repetir toda la regresión financiera si no cambian comportamiento ni estructura. La última regresión funcional es la de [fase 8](FASE_8_PRUEBAS.md): 28 + 13 + 5 pruebas aprobadas, seis copias de almacenamiento y archive sin firma. La fase 9 debe registrar por separado su verificación documental y de marca.

## Evidencia y tareas pendientes

El informe FASE_8_PRUEBAS.md resume los resultados de fase 8; `evidence/phase8/summary.json` solo está disponible en la máquina original. Los logs y capturas están en evidence; los xcresult y archives bajo /private/tmp son temporales y pueden desaparecer. Un hash acredita integridad del artefacto, no ejecución de pruebas ni aprobación humana.

La [guía de iPhone](PRUEBAS_IPHONE.md) mantiene pendientes pruebas de protección física, selector/hojas, modo avión, entrega y copias del sistema. Texto grande, VoiceOver y tema oscuro exhaustivos también siguen pendientes. No declarar verificación completa ni preparar distribución pública como aprobada antes de resolver los controles pertinentes.

Existe el repositorio privado `i4anggea/numa-ios`, con respaldo inicial `e679b06`. No hay proveedor CI remoto configurado. La fase 10 añade scripts locales quick/full de activación manual, sin firma/publicación automática; ver [CI_LOCAL](CI_LOCAL.md) e [INSTALACION_PRIVADA](INSTALACION_PRIVADA.md). Mantener [PROJECT_HANDOFF](PROJECT_HANDOFF.md) y el [índice](INDICE.md) alineados con la evidencia actual; los informes de fases anteriores son históricos y no deben reescribirse como si hubieran probado cambios futuros.


## Identidad, icono y firma local

`Brand/numa-mark.svg` es el logo vectorial temporal. `Sources/UI/Brand.swift` contiene su equivalente SwiftUI y los componentes de progreso. `swift scripts/render_brand.swift` regenera el PNG opaco de 1024 × 1024 en `Assets/Numa.xcassets/AppIcon.appiconset`; el sistema aplica la máscara del icono. Después de modificar recursos/referencias, regenerar el proyecto y ejecutar la validación.

La configuración versionada `Config/Signing.xcconfig` incluye opcionalmente `Signing.local.xcconfig`, ignorado. El generador valida `Signing.local.json` y deriva ese archivo local, de modo que el Team no cambia el proyecto versionado. Sin configuración local, se puede compilar sin firma y ejecutar el simulador; para instalar en iPhone se necesita configurar el Team. No sustituir el bundle de una instalación existente.

El efectivo conserva `Account.cash` y sus UUID: cambian las etiquetas y la captura, sin migración ni nuevo almacén. `Account.paymentLabel` y `Ledger.displayMethod` son presentación, no reglas financieras. Los hitos reflejan la reserva actual; no se persisten insignias ni se añaden transacciones. La preferencia de privacidad oculta también todo el progreso.


## Captura rápida y App Intents

`Sources/Core/QuickCapture.swift` define los datos, parser acotado, reglas exactas, comprobación de posibles duplicados e idempotencia por origen/ID. `Ledger.capture` es opcional, por lo que los libros anteriores siguen cargando sin esa propiedad. En SwiftData se añade una fila `capture` a la tabla StoredEntity existente; no se elimina ni reemplaza el almacén. Una versión anterior a 0.3.0 rechaza ese nuevo tipo de fila conservando los datos: no hacer downgrade con capturas configuradas.

`FinanceStore.shared` es el único escritor utilizado por la app y los intents. Ambos intents restringen ejecución al proceso principal y actor principal, requieren autenticación local y comprueban protección/ready antes de operar. El importador funciona en modo background cuando iOS lo permita; no promete ejecución estando bloqueado. No hay extensión ni contenedor compartido externo. Las consultas de tarjetas comprueban acceso antes de devolver alias, sin balances.

`prepareCapture` valida entrada y guarda únicamente metadatos de borrador con FinanceStore.change. `Ledger.saveCapturedExpense` se invoca desde EntryEditor con el ID del borrador, valida estado pendiente y ausencia de movimiento previo, guarda el gasto y marca la captura en la misma transacción del repositorio. Repositorio y sus dobles de pruebas siguen recibiendo un Ledger. Los avisos financieros y de posible duplicado requieren confirmación.

La configuración fusiona preferencias/reglas con la versión actual del libro y no sustituye los borradores recibidos mientras la pantalla está abierta. RootView coalesce solicitudes de navegación y espera a que una hoja activa se cierre; los intents nunca descartan un formulario abierto. El archivo y su identidad se conservan, y el índice financiero sigue ignorando los pendientes para agregados.

La guía ATAJOS.md detalla parámetros, limitaciones, privacidad de Atajos e integración manual. Verificar Metadata.appintents/extract.actionsdata dentro de la build y archive: deben contener las dos acciones, el proveedor y restricciones de autenticación. Compilación/metadatos no prueban el gesto físico ni la entrega de variables de Wallet/Santander.
