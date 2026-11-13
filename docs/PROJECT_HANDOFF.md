# Continuidad del proyecto

## Objetivo y forma de trabajo

App de finanzas personal para iPhone, futura apertura al público. El usuario exige diez fases y preguntas interactivas con opciones múltiples en cada fase. No saltar a fases posteriores sin formular sus preguntas; usar respuestas ya confirmadas sin repetirlas.

## Estado verificable

- Fases 1 a 3 documentadas en REQUISITOS.md, ARQUITECTURA.md y UI_UX.md.
- Reglas de fase 4 respondidas; aplicación implementada en Sources y proyecto Xcode generado.
- Fase 5 completada con prioridad financiera y de uso cotidiano. Corregidas validaciones/referencias, deuda histórica, cierres dependientes, reservas históricas, categorías archivadas, errores en hojas, confirmación de negativos, teclado y estabilidad de hojas. Detalles en FASE_5_REVISION.md.
- Regresión de fase 5: 22 pruebas unitarias, cuatro casos UI y compilación para simulador PASS. Xcode test 05: salida 0, TEST SUCCEEDED; bundle temporal `/private/tmp/finanzas-phase5-ui-05.xcresult`, logs/capturas definitivos en evidence.
- Xcode 27.1, Swift 6.4; simulador iPhone 18 Pro iOS 27.0, UUID 00000000-0000-0000-0000-000000000000.
- Sin firma/instalación en iPhone físico, publicación ni cuenta de usuario. Fase 10 prepara validación local manual quick/full; no hay proveedor CI remoto ni servicios externos activados.
- Sin repositorio Git local inicializado; respetar el proyecto independiente primer-web.

## Decisiones que se deben conservar

SwiftUI + SwiftData locales; MXN/español; datos sin respaldo/restauración ni sincronización. Presupuestos lunes-domingo, globales y por categoría. Compras a crédito consumen el total de presupuesto al comprar; pagos reducen cuenta/deuda sin duplicar gasto. Ahorro reservado reduce disponible, no dinero total. Negativos permitidos con confirmación. Notificaciones genéricas 7/3 días antes, 09:00. Consultar detalles en documentos de requisitos/diseño.

## Pendientes

Fase 6 implementada con 10,000 movimientos sintéticos, equilibrio apertura/registro/reportes y carga progresiva de 50 filas. Índice cacheado, reportes en una pasada, persistencia diferencial y validación de cierres optimizada. Benchmark Release y almacén Debug cumplen objetivos originales, sin cambiar invariantes financieros. 28 pruebas core PASS. Cuatro casos UI financieros PASS en phase6-ui-regression.log; caso de historial completo PASS con salida 0 en phase6-ui-history.log (corrige separador de miles en selector de prueba). Capturas inspeccionadas en evidence/phase6-ui-final. Compilación Release de simulador PASS, salida 0/BUILD SUCCEEDED, evidence/phase6-release.log. Detalles y límites en FASE_6_OPTIMIZACION.md.

Fase 7: auditoría local ejecutada, verificación parcial; informe FASE_7_SEGURIDAD.md. Usuario prioriza pérdida del iPhone bloqueado, tendrá código del sistema y mantiene diagnósticos únicamente en pruebas ficticias. No se modificaron fuentes de producto. Seis copias sintéticas: control válido abre y cinco corrupciones se rechazan conservando filas/payload o bytes; sin performance.json. Foundation confirma exclusión de copias en directorio/base/WAL/SHM; protección efectiva BLOCKED porque atributo no disponible en simulador y falta iPhone real. Xcode analyze Release y 28 pruebas core PASS. Marcadores de prueba ausentes en binario Release.

Hallazgos abiertos: H1 alta, falta verificación física del bloqueo; H2 media, coordinar repositorio con disponibilidad de datos protegidos y comprobar protección de auxiliares recreados; H3 media para distribución, falta PrivacyInfo.xcprivacy para APIs utilizadas; H4 baja, error interno SwiftData visible. No confundir ausencias de verificación con vulnerabilidades demostradas. La comprobación de manifiesto fue FAIL y no se corrigió en auditoría.

Fase 8 realizada en simulador según elección del usuario; priorizó opciones 1 y 2 (conservación/protección y exactitud financiera). H2 implementado con eventos de disponibilidad, suspensión y reapertura del repositorio, limpieza de referencias propias, bloqueo de cambios mientras no está disponible y reaplicación de atributos antes/después de guardar. Fallo posterior a commit obliga reabrir/comprobar para evitar duplicar. H3: PrivacyInfo.xcprivacy en Resources y archive. H4: mensajes genéricos de almacenamiento sin detalles internos. No cambió esquema ni se usaron datos reales.

Regresión final: 28 pruebas core PASS; xcodebuild completo salida 0/TEST SUCCEEDED con 13 pruebas de integración y cinco UI. evidence/phase8/full-regression.log; bundle /private/tmp/finanzas-phase8-full-02.xcresult. Seis nuevas copias de corrupción conservadas y capturas inspeccionadas. Archive Release iOS SIN firma, salida 0/ARCHIVE SUCCEEDED: /private/tmp/finanzas-phase8-unsigned.xcarchive; manifiesto embebido comprobado, sin marcadores de fixtures/fallos en binario. Sin instalación ni publicación. Ver FASE_8_PRUEBAS.md.

H1 sigue BLOCKED: simulador no expone clase de protección; eventos probados por inyección no prueban cifrado físico. Guía posterior PRUEBAS_IPHONE.md con estados pendientes. VoiceOver/texto grande/oscuro exhaustivos, entrega real de avisos, modo avión físico y copia/restauración real pendientes. Fase 9: el usuario eligió manual práctico y guía técnica en Markdown y propuso Numa como nombre definitivo del proyecto. Manuales en MANUAL_USUARIO.md/MANTENIMIENTO.md, índice INDICE.md e informe FASE_9_DOCUMENTACION.md. CFBundleDisplayName/Ajustes/cubierta actualizados a Numa; no se cambia bundle, proyecto, esquema ni ubicación de datos. Verificar nombre comercial antes de publicación; no se afirma disponibilidad. Fase 9 verificada: 49 enlaces locales, bloques Markdown, generación determinista y plutil PASS; build Debug de simulador con Numa salida 0/BUILD SUCCEEDED. Evidencia en evidence/phase9. No se repitieron pruebas financieras por tratarse de documentación/textos; se conserva la regresión de fase 8. Respuestas de fase 10 recibidas: Mac local, ruta de instalación desde Xcode y validación rápida/completa separadas. Implementados scripts/validate.py y configuración opcional Config/Signing.local.json (ignorada), plantilla example y documentación CI_LOCAL.md/INSTALACION_PRIVADA.md/FASE_10_CI_CD.md. Ver informe de fase 10 para resultados finales de ejecución. No afirmar mejora de RAM/batería: libro e índice completos en memoria; bloques solo limitan filas UI.

Los dos escenarios prioritarios de semana/cierre/ahorro y crédito/pago/corrección/eliminación protegida ya se verificaron también en UI. Corrupción e identidad de filas se verificaron en las fases 7/8 con copias sintéticas; siguen pendientes migraciones futuras, permisos/entrega de notificaciones, protección de archivos/copias, pantalla del selector, temas y accesibilidad. Investigar advertencia de frame al activar teclado y avisos Xcode sobre versión anfitriona. Reconciliaciones de notificaciones serializadas y cubiertas en hojas implementadas, aún sin validación específica en dispositivo.

Nombre elegido: Numa. Disponibilidad comercial e icono siguen pendientes. Costes y límites de Personal Team revisados en INSTALACION_PRIVADA.md; precio final MXN de membresía opcional y fecha de instalación siguen sin confirmar. Finanzas se mantiene como nombre interno del proyecto/esquema/módulo; no renombrarlo ni cambiar bundle/almacén por estética. No activar recursos facturables ni publicar sin autorización específica.

## Cierre de fase 10

validate.py quick y full ejecutados con salida 0/PASS. Full: 28 core, 13 integración, cinco UI y archive Release iOS sin firma con manifiesto/identidad/marcadores comprobados. Evidencia persistida en evidence/phase10; salida completa /private/tmp/numa-phase10-full. Configuración de firma probada solo con Team ficticio en árbol temporal, no cuenta real. Guards de concurrencia y no sobrescritura probados. No hay Git/CI remoto ni trigger automático: son scripts locales manuales.

Los diez entregables de fase están preparados; no afirmar entrega física ni verificación completa. devicectl detectó solo simuladores. Próximo paso: conectar iPhone, configurar Team con el usuario en Xcode, instalar una build ficticia y ejecutar PRUEBAS_IPHONE.md. Ruta Personal Team y cuota opcional de membresía consultadas en Apple el 21/10/2026; ver INSTALACION_PRIVADA.md. No se activaron pagos, cuentas, perfiles o publicaciones.

## Corrección de registro de bundle en primera instalación

Xcode mostró Failed Registering Bundle Identifier para local.personal.finanzas (no disponible). Se actualizó la identidad a com.example.numa y sufijos de pruebas, conservando el Team real ya seleccionado por el usuario mediante Signing.local.json ignorado. AppIdentity.json es fuente de verdad para generador y validador; ProjectSettings.json conserva recomendaciones/ajustes que Xcode había añadido. Se compararon semánticamente los ajustes previos y no se descartaron. No se accedió a credenciales ni se registró el nuevo ID automáticamente: Xcode debe confirmarlo con Apple al ejecutar. El cambio es de primera instalación; no se migró ni borró ningún almacén. Los informes anteriores conservan el bundle histórico.


## Efectivo e identidad — 22/10/2026

El usuario probó la versión inicial en su iPhone. Se creó y verificó respaldo privado en GitHub `i4anggea/numa-ios`: main, e679b06d32b5bede9888fc15df469eb0467cfb7e. GitHub CLI autenticado; el conector devolvía 404, por eso la subida usa Git/CLI. No almacenar credenciales ni datos del teléfono. La firma JSON y xcconfig locales, compilaciones y evidence están ignorados.

Rama de trabajo `feat/efectivo-identidad-numa`, versión 0.2.0/build 2. Efectivo siempre visible en el método de registro, alta contextual con saldo inicial y borrador conservado; cancelación y persistencia verificadas. Interfaz separa efectivo/cuentas/tarjetas sin alterar Account.cash, UUID, bundle, esquema o almacén. Etiquetas de importe permanecen visibles. Inicio con marca, CTA y aclaración de disponible/deuda; metas con progreso real e hitos 25/50/75/100 %, animación discreta y soporte de Reducir movimiento. Ocultar importes oculta barras, porcentajes y logros (UI PASS). Logo N temporal en SVG/SwiftUI y AppIcon PNG opaco generado con Swift.

validate.py full final PASS: 28 core + 13 integración + 7 UI, incluido historial 10001 movimientos, y archive sin firma. Tras cambiar solo el color semántico del fondo en oscuro se recompiló y generó otro archive, identidad/icono/manifiesto/marcadores PASS. Gitleaks de archivos seleccionados sin hallazgos. Copia limpia valida fuentes sin depender del Team ni evidencias. Firma local separada en xcconfig opcional; Xcode resuelve el mismo Team y bundle. Informe y mejoras propuestas en MEJORAS_IDENTIDAD.md, resumen portable VERIFICACION_IDENTIDAD.json.

Se inspeccionó Inicio en claro/oscuro/texto máximo. No se instaló 0.2.0 en el teléfono ni se certificó VoiceOver, reducción de movimiento, bloqueo o entrega física de notificaciones. Actualizar desde Xcode conservando la instalación; no desinstalar ni cambiar bundle. Próximas mejoras propuestas: onboarding de fecha/saldo, conciliación manual, visibilidad de avisos programados y evaluación futura de recuperación/bloqueo. Preguntar con opciones antes de ampliar ese alcance.

## Atajos — 22/10/2026

Rama feat/atajos-gasto-rapido sobre 929bee6, versión 0.3.0/build 3. Nueva integración nativa App Intents: Abrir gasto rápido y Preparar compra detectada. Proceso principal, MainActor, FinanceStore.shared, autenticación local y comprobación de protección antes de escribir. No hay extensión ni otro escritor. RootView difiere solicitudes mientras hay hojas abiertas. Inicio ofrece Gasto rápido y Ajustes incluye configuración de efectivo/categoría, débito Santander, reglas exactas y pendientes.

Capturas protegidas en la misma base, como fila capture (opcional en Ledger). No cambia el esquema SwiftData ni la ruta/bundle/Team. Guardar un pendiente usa saveCapturedExpense con UUID estable para gasto+estado en transacción atómica. Replays con origen/ID estable son idempotentes. Otros parecidos se advierten por comercio, tarjeta, importe y 5 minutos, sin unificar automáticamente. Solo se interpreta el formato ficticio Has/Haz realizado una compra en COMERCIO. No se inventan importe/moneda/categoría; moneda extranjera y entrada inválida se rechazan. El texto original no se conserva.

Regresión completa PASS: 35 core + 15 integración + 9 UI = 59 pruebas y archive iOS sin firma. Metadatos de ambas acciones verificados en archive. Ajuste posterior de CFBundleName a Numa para el enlace del sistema (no renombra proyecto/módulo/almacén), repetición de UI y archive final. Guía ATAJOS.md e informe VERIFICACION_ATAJOS.md. No hacer downgrade con metadatos capture: versiones viejas rechazan la fila sin eliminar datos.

Pendiente en iPhone: actualizar desde Xcode sin borrar la app; configurar el atajo y asignar Toque doble; probar propiedades reales de Wallet/notificación/correo Santander, autenticación/bloqueo físico y ajustes de sincronización de Atajos. Los avisos bancarios solo dan comercio en los ejemplos recibidos. El botón Gasto rápido y los tests no prueban el gesto físico ni entrega real de avisos. No se alteraron automatizaciones ni ajustes del teléfono automáticamente.
