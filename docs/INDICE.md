# Documentación de Numa

Numa es el nombre elegido para la app. Los identificadores internos Finanzas/PrivateFinance se conservan para mantener continuidad. La disponibilidad comercial del nombre no se ha verificado.

## Para usar y probar

- [Verificación de Atajos](VERIFICACION_ATAJOS.md): resultados y límites de la entrega 0.3.0.
- [Atajos y doble toque posterior](ATAJOS.md): configuración, automatizaciones y pruebas físicas pendientes.
- [Manual de usuario](MANUAL_USUARIO.md): configuración inicial, movimientos, crédito, presupuestos, metas, reportes y solución de problemas.
- [Pruebas posteriores en iPhone](PRUEBAS_IPHONE.md): preparación, casos con cifras ficticias y registro de verificaciones físicas pendientes.
- [README del proyecto](../README.md): arranque rápido y estructura.

## Para mantener el código

- [Guía técnica de mantenimiento](MANTENIMIENTO.md): mapa del código, persistencia, datos protegidos, configuración y comandos de pruebas.
- [Requisitos y decisiones del producto](REQUISITOS.md).
- [Arquitectura](ARQUITECTURA.md).
- [UI/UX](UI_UX.md).
- [Mejoras de efectivo e identidad](MEJORAS_IDENTIDAD.md): auditoría, logo temporal, criterios visuales y validación actual.
- [Validación local](CI_LOCAL.md): comandos quick/full y evidencias.
- [Instalación privada](INSTALACION_PRIVADA.md): Xcode, firma, costes y pasos físicos pendientes.
- [Continuidad del proyecto](PROJECT_HANDOFF.md): estado actual y próximos pasos.

## Informes y evidencia

| Fase | Documento | Alcance |
|---|---|---|
| 4 | [Implementación](FASE_4.md) | Entrega inicial; contexto histórico. |
| 5 | [Revisión](FASE_5_REVISION.md) | Hallazgos y regresiones de esa fase. |
| 6 | [Optimización](FASE_6_OPTIMIZACION.md) y [protocolo](FASE_6_PROTOCOLO.md) | Mediciones con 10,000 movimientos; no son tiempos de un iPhone real. |
| 7 | [Auditoría](FASE_7_SEGURIDAD.md) | Estado previo a correcciones y seguimiento posterior. |
| 8 | [Pruebas](FASE_8_PRUEBAS.md) | Última regresión funcional: 28 pruebas de dominio, 13 de integración y cinco UI aprobadas; verificación física parcial. |
| 9 | [Documentación y nombre](FASE_9_DOCUMENTACION.md) | Entregables Markdown, elección de Numa y comprobaciones de marca/documentación. |
| 10 | [CI/CD local](FASE_10_CI_CD.md) | Validaciones locales y preparación de entrega; estado de ejecución y límites físicos. |

El informe de fase 8 distingue aprobados y pendientes. Las evidencias locales sin filtrar están excluidas de Git por privacidad. Los documentos históricos pueden mostrar Finanzas y recuentos anteriores; no representan la marca ni el estado actual. La fase 10 sigue la elección de validaciones locales y entrega desde Xcode; consultar su informe para distinguir comprobaciones ejecutadas de instalación pendiente.

## Límites actuales

La app no incluye recuperación de datos, cuenta, sincronización ni bloqueo propio con Face ID. La protección efectiva al bloquear un iPhone, las copias/restauración reales, entrega de avisos, modo avión físico y accesibilidad exhaustiva siguen pendientes. El archive de fase 8 está sin firma; no hay publicación ni instalación física verificada. No hay costes externos activados.
