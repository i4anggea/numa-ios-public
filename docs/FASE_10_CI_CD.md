# Fase 10 — Validación local y entrega privada de Numa

Estado: flujos locales quick/full implementados y ejecutados con éxito. Entrega física pendiente de dispositivo y firma.

Decisiones: automatización en el Mac, comprobaciones rápidas durante desarrollo y pruebas completas más archive antes de entrega; primera instalación desde Xcode en iPhone conectado. No se activan proveedores CI, suscripciones, TestFlight ni publicación.

## Implementación

- `scripts/validate.py quick`: registra versiones, valida enlaces/configuración y generación determinista en árbol temporal y ejecuta pruebas financieras.
- `scripts/validate.py full`: añade suites de integración/UI, archive iOS Release sin firma y comprobaciones del bundle. Selecciona solo un simulador iPhone disponible iOS 27+; permite UUID explícito.
- Carpetas de salida nuevas, logs por paso, summary.json y códigos de salida. Se detiene ante fallo, exige señales de pruebas ejecutadas y no da por aprobadas suites ausentes. Un lock evita solapamientos entre ejecuciones de este script.
- Configuración opcional `Signing.local.json`, excluida de Git, con validación del Team ID y aplicación a las seis configuraciones de targets. Plantilla sin credenciales. No se ha configurado un Team real ni accedido a cuentas/certificados.
- Guías [CI_LOCAL](CI_LOCAL.md) e [INSTALACION_PRIVADA](INSTALACION_PRIVADA.md), índice y README actualizados.

Son comprobaciones locales automatizadas con disparador manual. No se ha configurado ejecución al guardar, commit o PR; no existe repositorio Git ni remoto. No se firma ni despliega desde el validador. El archive es una evidencia de compilación y candidato para revisar, no una instalación ni aprobación de uso con datos reales.

## Verificación

| Comprobación | Estado | Evidencia |
|---|---|---|
| Flujo quick inicial | PASS | Salida 0, 28 pruebas de dominio, configuración y enlaces; evidence/phase10/quick-summary.json y logs asociados. |
| Flujo full | PASS | Salida 0: 28 pruebas de dominio, 13 de integración y cinco UI; archive Release sin firma y comprobaciones de bundle aprobadas. evidence/phase10/full-summary.json y logs asociados. Salida completa temporal /private/tmp/numa-phase10-full. |
| Barreras de concurrencia y evidencia | PASS | Segunda ejecución rechazada mientras full estaba activo; directorio de salida ya usado rechazado sin cambiar su resumen. concurrency-check.json y output-guard-check.json. |
| Team local opcional | PASS | Prueba en copia temporal: Team ficticio aplicado a seis configuraciones; valor inválido rechazado antes de reescribir proyecto. `signing-config-checks.json`. No prueba una firma real. |
| Configuración y Python | PASS | py_compile del generador/validador; generación del proyecto ejecutada. |
| Detección de dispositivo | BLOCKED para instalación | devicectl encontró solo dos dispositivos simulados, ninguno físico. |
| Firma e instalación en iPhone | BLOCKED | Sin iPhone físico disponible ni Team real seleccionado. |
| Pruebas físicas y protección al bloquear | BLOCKED/NOT_RUN | Conservadas en PRUEBAS_IPHONE.md; no resueltas por el pipeline. |
| Proveedor CI remoto, compra de membresía, publicación | NOT_RUN | Fuera del alcance elegido; no hay activación ni gastos nuevos. |

## Requisitos y coste

Plan de instalación y fuentes oficiales en INSTALACION_PRIVADA.md, consultadas el 21 de octubre de 2026. Personal Team permite evaluar pruebas personales sin cuota del programa, con renovación de perfiles a los siete días. La membresía de pago es opcional para esta ruta inicial; no se ha comprado. Precio final en MXN y condiciones de cuenta siguen sin verificar. Los scripts no añaden cuota externa de CI o hosting; no se valora hardware/tiempo como coste cero.

## Límites de entrega y recuperación

H1 de la auditoría sigue pendiente de dispositivo real. El pipeline no verifica cifrado físico, entrega de notificaciones, modo avión real, selector/hojas ni copia/restauración del sistema. También queda accesibilidad exhaustiva antes de distribución pública.

No eliminar/reinstalar una app con datos para resolver firma sin revisar el impacto. Se mantienen bundle, esquema y ubicación de datos. Retroceder código no revierte migraciones; cualquier cambio futuro requiere compatibilidad y ensayos sintéticos. No hay exportación/restauración del usuario ni backups ocultos añadidos por CI.

Las diez fases tienen entregables de software/documentación, con verificación física y entrega aún pendientes. No afirmar que Numa está instalada o publicada. Próximo paso operativo: conectar y preparar el iPhone, elegir Team, instalar una build de prueba desde Xcode y completar la guía con cifras ficticias.

## Evidencia y advertencias de ejecución

El comando full se ejecutó sobre el nombre visible Numa. TestAction mantuvo directorios ficticios y el script no accedió a un iPhone físico. Se conservan las advertencias de Xcode sobre metadatos del anfitrión y frame al activar teclado, sin fallos en los casos de esta ejecución; no se presentan como resueltas. La extracción de AppIntents se omite por no usar ese framework. No hubo fallos de pruebas ni de compilación en la ejecución final.

Los resúmenes registran status PASS solo para los controles del script, signed/installedOnPhone/uploaded false y physicalVerification pendiente. No son aprobación de distribución. Los archivos completos .xcresult y .xcarchive están en /private/tmp y pueden desaparecer; los resúmenes/logs de evidencia se copiaron dentro del proyecto.

Comprobación rápida posterior al cierre documental: salida 0/PASS, 62 enlaces locales comprobados y 28 pruebas de dominio. evidence/phase10/quick-final-summary.json.
