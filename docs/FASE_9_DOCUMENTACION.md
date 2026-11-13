# Fase 9 — Documentación y nombre Numa

Estado: documentación Markdown y nombre visible completados; enlaces/configuración y compilación comprobados. Se mantienen los límites funcionales y físicos de fase 8.

Decisiones del usuario: manual práctico y documentación técnica de mantenimiento, archivos Markdown dentro del proyecto y elección del nombre antes de cerrar la fase. Nombre elegido: **Numa**, propuesto por el usuario por ser corto, cercano y flexible para crecer desde gastos hacia ahorro y metas. La disponibilidad comercial no se ha comprobado.

## Entregables

- [Manual de usuario](MANUAL_USUARIO.md): preparación, tipos de movimientos, interpretación de cifras, crédito/cuotas, presupuestos/cierres, metas, filtros/reportes, privacidad y errores.
- [Guía técnica](MANTENIMIENTO.md): módulos, transacciones y fallos, invariantes, esquema/versionado, protección, notificaciones, configuración, comandos y límites de evidencia.
- [Índice](INDICE.md): entradas según audiencia y mapa de informes históricos.
- [Guía física existente](PRUEBAS_IPHONE.md): enlazada desde los manuales; mantiene estados pendientes.
- README, arquitectura y continuidad actualizados al estado posterior a fase 8.

El manual diferencia dinero total, disponible, deuda y margen de presupuesto para evitar interpretaciones incorrectas. Aclara que un pago no duplica gasto y que las cuotas no se concilian automáticamente. La guía técnica documenta el caso de escritura confirmada seguida de fallo de protección para evitar reintentos duplicados.

## Aplicación del nombre

Se cambia CFBundleDisplayName en el generador/Info.plist, el texto de versión en Ajustes y la cubierta de privacidad. Se conservan proyecto/esquema/módulo/producto Finanzas, bundle ID local.personal.finanzas, directorio PrivateFinance y esquema v1. No hay migración de datos ni cambio de ubicación del almacén.

Las capturas anteriores corresponden a sus builds históricos; no se editan para aparentar que mostraban Numa. No se diseñó icono nuevo ni se verificó registro de marca o disponibilidad en App Store. El nombre elegido no implica publicación.

## Verificación de esta fase

| Comprobación | Estado | Resultado |
|---|---|---|
| Enlaces Markdown locales nuevos/actualizados | PASS | 49 enlaces comprobados, destinos existentes y bloques de código equilibrados; evidence/phase9/documentation-checks.json. |
| Coherencia con pantallas y reglas | PASS (revisión) | Manual contrastado con formularios, Settings, cuentas, presupuestos, metas, reportes y dominio existentes. |
| Generación/configuración del nombre | PASS | Generador determinista; plutil de proyecto/Info/manifiesto correcto. Bundle construido con CFBundleDisplayName Numa y el identificador original. |
| Compilación de simulador con Numa | PASS | xcodebuild Debug, SDK iphonesimulator, destino genérico, CODE_SIGNING_ALLOWED=NO; salida 0/BUILD SUCCEEDED. evidence/phase9/build.log. |
| Regresión financiera completa repetida | NOT_RUN | No se repite: cambios de documentación y texto visible, sin reglas, datos ni flujos nuevos. Se conserva evidencia funcional de fase 8, sin presentarla como nueva ejecución. |
| Pruebas en iPhone/registro comercial/CI | NOT_RUN | No forman parte de la comprobación documental; siguen pendientes según informes y fase 10. |

Las comprobaciones documentales no equivalen a pruebas de la app. No hay PDF por elección del usuario. No se inicializó Git ni se crearon commits/publicaciones. La fase 10 se abordará tras sus preguntas.
