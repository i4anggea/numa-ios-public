# Fase 7 — Auditoría de seguridad

Estado: auditoría local ejecutada; verificación parcial. No equivale a certificar la seguridad del iPhone bloqueado ni a autorizar distribución. Se conservaron los fuentes de producto sin modificaciones; se añadieron herramientas de auditoría y evidencia.

## Decisiones y alcance

Prioridad confirmada: pérdida del iPhone bloqueado. El dispositivo tendrá código del sistema. Diagnósticos únicamente en pruebas con datos ficticios. Face ID/código propio de la app, cuentas, sincronización y recuperación siguen fuera de esta versión.

Activos: movimientos, saldos, reservas, alias de cuentas/tarjetas, fechas, categorías y planes. Fronteras: sandbox del proceso, almacén SwiftData, preferencias no financieras, pantalla/selector y notificaciones del sistema. Se revisaron Sources/Core, Sources/App, Sources/UI, configuración Xcode/Info.plist, dependencias declaradas y binario Release.

Amenazas consideradas: acceso al archivo con dispositivo perdido/bloqueado, exposición en avisos/pantallas/copias, diagnósticos indebidos y apertura de datos inconsistentes. Un dispositivo comprometido, extracción forense, acceso privilegiado al proceso, autenticidad criptográfica de cada registro y capturas manuales no quedan garantizados por esta auditoría. No se atacaron servicios externos ni se usaron datos reales.

## Hallazgos por prioridad

### H1 — Alta: falta evidencia física para el escenario principal (BLOCKED)

El código solicita `FileProtectionType.complete` para directorio, base y auxiliares, pero Foundation del simulador devuelve atributo de protección no disponible. La marca de exclusión de copias sí devuelve true. Esto demuestra la configuración y la marca de copias; no demuestra el aislamiento criptográfico al bloquear.

Acción necesaria antes de validar el uso con datos reales: instalar una compilación firmada en el iPhone con código, verificar clase de protección de base/WAL/SHM y archivos nuevos, bloquear tras una apertura, esperar la transición de datos protegidos y comprobar indisponibilidad; desbloquear y comprobar apertura/registro sin pérdidas. Repetir tras escritura y reapertura. Comprobar también la exclusión efectiva en una copia del sistema con datos ficticios. No hay iPhone físico firmado/configurado en esta sesión.

Apple describe cómo la clase completa depende del código y del identificador del dispositivo y cambia su disponibilidad tras el bloqueo. Fuente: [Data Protection classes](https://support.apple.com/en-ca/guide/security/secb010e978a/web). No se afirma un cifrado adicional propio.

### H2 — Media: gestión explícita de disponibilidad de datos protegidos pendiente

`FinanceStore` mantiene repositorio/índice en memoria y RootView atiende scenePhase, pero no se observan eventos de disponibilidad de datos protegidos para suspender/reabrir acceso al almacén. Los errores se capturan; no se reprodujo corrupción ni acceso indebido por este motivo. La cubierta visual no sustituye la disponibilidad del archivo.

Recomendación para corrección y regresión: coordinar acceso con los eventos de datos protegidos, impedir escrituras durante indisponibilidad y reabrir de forma segura al desbloquear. Validar en iPhone real la política de base y auxiliares después de recreación/guardado; actualmente `protectFiles()` se aplica al abrir, no tras cada guardado. No se observó pérdida de exclusión de copias en los archivos ensayados, por lo que no se presenta esa posibilidad como fuga confirmada.

Apple recomienda cerrar y reabrir el acceso a archivos con protección completa al cambiar la disponibilidad: [Encrypting Your App’s Files](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files). Algunos cambios de archivo pueden restablecer la marca de exclusión: [isExcludedFromBackupKey](https://developer.apple.com/documentation/foundation/urlresourcekey/isexcludedfrombackupkey).

### H3 — Media para distribución pública: falta manifiesto de privacidad

Las preferencias `@AppStorage` utilizan UserDefaults. No hay PrivacyInfo.xcprivacy en Config/Sources ni en el bundle Release inspeccionado, y la fase Resources generada está vacía. No supone una extracción de datos observada, pero debe resolverse antes de App Store Connect.

Corrección propuesta: inventariar las APIs con motivo obligatorio, declarar los motivos que correspondan al uso real e incorporar el manifiesto al generador y al bundle; verificar el archivo dentro de un archive de dispositivo. No se realizó envío ni validación con App Store Connect. Referencias oficiales: [Required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [TN3183](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).

### H4 — Baja: mensaje de error interno visible

La cabecera SQLite dañada produce un aviso con `SwiftData.SwiftDataError 1`. No mostró importes, payload ni credenciales en el caso ensayado, pero el código técnico aporta poco al usuario. Recomendación: mensajes estables para errores de almacenamiento, conservando causas técnicas solo en pruebas ficticias. Los errores financieros concretos deben conservar su explicación útil.

No se confirmó una vulnerabilidad crítica en los controles ejecutados. La ausencia de un hallazgo crítico no resuelve H1 ni constituye una garantía general.

## Controles ejecutados

| Control | Estado | Método y evidencia |
|---|---|---|
| Revisión de protección/configuración local | PASS (código) | Persistence.swift solicita complete, exclusión de copias y CloudKit.none. No borra ni recrea el archivo en el catch. |
| Marca de exclusión en archivos existentes | PASS (simulador) | Helper Foundation compilado para iOS Simulator; directorio y Finance.store/-wal/-shm devuelven true. `evidence/phase7/file-attributes.json`. No es una copia/restauración real. |
| Protección efectiva con iPhone bloqueado | BLOCKED | Sin dispositivo físico configurado. El helper devuelve fileProtection unavailable en simulador; no interpretar esto como falta de protección en iPhone. |
| Control positivo de apertura | PASS | Copia del historial ficticio de 10,001 movimientos abre Inicio. `valid.png`; filas/payload conservados. |
| JSON inválido | PASS | Apertura rechazada, aviso observado, filas/payload sin cambios. `invalid-json.png`. |
| UUID de fila diferente del payload | PASS | Apertura rechazada y contenido conservado. `identity-mismatch.png`. |
| Tipo de entidad desconocido | PASS | Apertura rechazada y contenido conservado. `unknown-kind.png`. |
| Referencia a cuenta inexistente | PASS | Apertura rechazada y contenido conservado. `missing-reference.png`. |
| Cabecera SQLite inválida | PASS | Apertura rechazada; bytes del archivo inválido conservados, sin reemplazarlo por otro. `invalid-header.png`. |
| Diagnósticos desactivados | PASS (casos ensayados) | Ninguna de las seis copias produjo performance.json sin FINANCE_PERFORMANCE=1. Source gate exige además Debug, --ui-testing y UUID válido. |
| Exclusión de mecanismos de prueba en Release | PASS | Seis marcadores de fixtures/flags/diagnóstico ausentes en strings del binario Release. `static-checks.json`; no es análisis completo de código máquina. |
| Notificaciones genéricas | PASS (código) | Reminders.swift usa título/cuerpo fijos, sin alias/importes/userInfo financiero. Identificadores internos contienen UUID/fecha. Entrega real no ensayada. |
| Superficie remota/dependencias | PASS (inspección acotada) | Sin paquetes externos declarados, CloudKit desactivado, sin URLSession/NWConnection/WKWebView/logging en búsqueda de Sources. No es un análisis de tráfico ni de todo el código de frameworks Apple. |
| Análisis Xcode Release | PASS | `xcodebuild … analyze`, salida 0/ANALYZE SUCCEEDED; static-analyzer.log. Advertencia de extracción AppIntents omitida por no usar ese framework. Sin diagnósticos de análisis reportados; no prueba ausencia de vulnerabilidades. |
| Reglas de integridad | PASS | `swift test --scratch-path /private/tmp/finanzas-core-tests`: 28 pruebas, cero fallos, salida 0. `core-tests.log`. |
| Manifiesto de privacidad en bundle | FAIL | Ausente en código/configuración y bundle Release inspeccionado; H3. |
| Selector de apps/hojas y datos protegidos en físico | BLOCKED | Sin iPhone configurado; cubierta y etiquetas de importes revisadas en código, sin dar el comportamiento real por aprobado. |
| Copia/restauración del sistema, entrega de avisos y tráfico offline real | NOT_RUN | Se reservan para fase 8 con datos ficticios y entorno acordado. |
| Firma/archive de dispositivo/App Store | NOT_RUN | Sin destino/cuenta configurados; distribución aún no definida. |

## Evidencia de integridad y límites de los ensayos

Se utilizó únicamente la fixture sintética de fase 6. `audit_storage.py prepare` abre su base en modo read-only y crea seis bases nuevas bajo directorios UITest-UUID. No abre PrivateFinance. Inyecta un defecto diferente en cada copia y conserva un control válido. `run` abre esas copias con la app Debug instalada, captura pantalla y termina la app antes de comprobar el resultado.

En las cinco bases SQLite válidas se compara el hash de **todas las filas financieras y payloads**, no todos los bytes del fichero: SQLite puede cambiar metadatos. En la cabecera inválida se compara el hash de sus bytes. Resultado: seis contenidos conservados; seis lanzamientos con salida 0; cinco rechazos y un Inicio válido observados al inspeccionar las seis capturas. El retorno 0 de simctl por sí solo no demuestra la pantalla; se combinó con inspección visual. No se probado corte de energía durante una escritura ni una migración futura.

Los JSON contienen solo identificadores sintéticos, hashes y estados, sin payloads financieros. Las capturas usan exclusivamente cifras ficticias. No se modificaron datos personales ni se instalaron dependencias. Los límites estructurales del motor se aplican después de decodificar/fetch; no se promete resistencia a un archivo arbitrariamente enorme colocado por un atacante con acceso privilegiado al contenedor.

Ocultar importes sustituye cifras y etiquetas de accesibilidad y retira gráficas; conceptos/alias introducidos por el usuario pueden contener números y los formularios muestran importes al editar, conforme al diseño aprobado. No es autenticación. Tras desbloquear el iPhone la app sigue sin bloqueo propio, por decisión del usuario. El libro ya cargado permanece en memoria; no se promete borrado seguro de RAM ni de restos de SQLite al eliminar un movimiento.

## Reproducción

Desde finanzas-ios, con el simulador de la fase 6 y su fixture sintética aún disponibles:

```sh
python3 scripts/audit_storage.py prepare
python3 scripts/audit_storage.py run
swift test --scratch-path /private/tmp/finanzas-core-tests
xcodebuild -project Finanzas.xcodeproj -scheme Finanzas -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/finanzas-phase7-analysis CODE_SIGNING_ALLOWED=NO analyze
```

El script fija UUID del simulador y directorio de la fixture original; si no existen, debe fallar y prepararse una nueva fixture con la prueba testTenThousandHistoryPerformance. No sustituirlo por una base personal. El helper `scripts/audit_file_attributes.swift` se compiló con swiftc, target arm64-apple-ios27.0-simulator, SDK iphonesimulator, y se ejecutó con simctl spawn sobre el directorio UITest del control válido. Se conserva `storage-cases.json` para enlazar las copias con sus capturas/resultados.

No se hicieron correcciones al código de producto durante la auditoría. H2/H3/H4 quedan concretados para corrección y pruebas en la siguiente fase; H1 exige acceso físico. No hubo publicación, nueva infraestructura, transacciones reales ni commit (proyecto sin Git).

## Seguimiento posterior — fase 8

H2/H3/H4 se corrigieron después de esta auditoría; ver FASE_8_PRUEBAS.md para cambios y evidencias. H2 tiene regresión de disponibilidad simulada y reapertura; H3 incluye manifiesto en archive sin firma; H4 tiene prueba de mensaje y captura actualizada. El FAIL del manifiesto en esta auditoría describe el estado previo, no el actual. H1 permanece BLOCKED hasta probar en iPhone real.
