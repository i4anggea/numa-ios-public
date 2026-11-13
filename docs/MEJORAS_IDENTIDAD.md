# Efectivo e identidad de Numa

Fecha: 22/10/2026. Estado: validación automatizada PASS; comprobaciones físicas pendientes.

## Alcance y criterios

Respaldo previo confirmado en el repositorio privado `i4anggea/numa-ios`, rama main, commit `e679b06d32b5bede9888fc15df469eb0467cfb7e`. Trabajo en `feat/efectivo-identidad-numa`. No se accede a los registros del teléfono ni se cambia bundle, esquema o almacén.

Identidad aprobada: serena, clara, cercana y motivadora; tarjetas ligeras y acciones claras; N abstracta con avance y equilibrio. Pregunta adicional respondida: hitos 25/50/75/100 % con animaciones discretas. No se añaden rachas, premios ficticios ni servicios externos.

## Auditoría y correcciones

| Prioridad | Evidencia / problema | Cambio |
|---|---|---|
| Alta · usabilidad | EntryEditor solo enumeraba saldos existentes; sin Account.cash, el usuario no podía elegir efectivo. | Efectivo siempre disponible, alta contextual con saldo inicial y retorno al borrador; cancelación sin crear un saldo. |
| Media · claridad | AccountsView creaba efectivo con el título Nueva cuenta y mezclaba ambas clases. | Secciones y altas separadas; efectivo conserva sus enlaces internos y puede editarse. |
| Media · comprensión | AmountInput solo usaba placeholder, que desaparecía al escribir. | Etiqueta permanente e importe alineado; nombre de efectivo con etiqueta visible. |
| Media · claridad financiera | El saldo disponible no descuenta deuda de crédito, pero Inicio no lo explicaba. | Explicación visible junto al disponible; no se cambia el cálculo aprobado. |
| Media · identidad | No había icono ni vocabulario de progreso. | Logo vectorial/PNG/SwiftUI, tarjetas y CTA, progreso real, hitos y transiciones que respetan Reducir movimiento. |
| Media · privacidad | El nuevo progreso podría revelar cifras al ocultar importes. | Ocultar barras, porcentajes e hitos; prueba UI específica. |
| Media · reproducción | El proyecto incluía Team local y dos enlaces dependían de evidencias excluidas de Git. | Team en xcconfig local ignorado; enlaces sustituidos por informes versionados. |

Las reservas que bajan hacen bajar el progreso: los logros describen el estado actual, no medallas históricas. Configurar un saldo y guardar un movimiento son operaciones distintas; cancelar el movimiento después de guardar el saldo no elimina ese saldo.

## Logo y uso

[SVG editable](../Brand/numa-mark.svg), [PNG del icono](../Assets/Numa.xcassets/AppIcon.appiconset/Numa.png) y [generador local](../scripts/render_brand.swift). N blanca de extremos redondeados sobre azul profundo, con dos apoyos y remate ascendente. Es temporal; no se ha comprobado exclusividad de marca. No se añaden recursos remotos ni dependencias. El PNG no tiene transparencia ni esquinas recortadas; iOS aplica su máscara.

## Mejoras propuestas para una siguiente iteración

1. Onboarding breve: elegir fecha de inicio y comprobar saldos para evitar duplicar movimientos ya incluidos en el saldo inicial.
2. Pantalla de conciliación manual: comparar saldo registrado con efectivo contado o saldo del banco; cualquier ajuste debe quedar como operación explícita.
3. Recordatorios: mostrar en Ajustes el próximo aviso realmente programado y guiar cuando no haya permiso, manteniendo mensajes genéricos.
4. Accesibilidad física: comprobar VoiceOver, tamaños máximos y contraste en el iPhone del usuario antes de ampliar distribución.
5. Evaluar recuperación/exportación y bloqueo propio antes de uso público; se mantienen fuera de esta versión por decisión previa.

No se implementan automáticamente estas ampliaciones; requieren cerrar su comportamiento con preguntas de opciones múltiples.

## Validación

Resultado final: **PASS**, 48 pruebas (28 core, 13 almacenamiento, 7 interfaz) y archive iOS sin firma. Comando: `python3 scripts/validate.py full --output /private/tmp/numa-identidad-full-final`. Resumen portable: [VERIFICACION_IDENTIDAD.json](VERIFICACION_IDENTIDAD.json).

Los intentos iniciales detectaron selectores ambiguos en hojas superpuestas y un problema de foco/cursor en campos alineados a la derecha, que dejaba caracteres anteriores. Se corrigió con etiquetas encima del campo, alineación natural y comprobación del texto capturado antes de guardar. La prueba de privacidad vuelve a Ahorro para usar su botón y reabre la meta. Los tres casos específicos pasaron antes de la regresión completa.

Después de la regresión se ajustó únicamente el fondo de las tarjetas a secondarySystemGroupedBackground para distinguirlas en modo oscuro. Build de simulador y nuevo archive sin firma PASS; captura final oscura inspeccionada. No se repitieron las pruebas financieras por ese cambio exclusivamente cromático. El archive final comprobó versión 0.2.0/build 2, mismo bundle, icono, manifiesto y ausencia de marcadores de prueba.

Gitleaks 8.30.1: sin hallazgos en los archivos seleccionados; patrones adicionales y exclusiones PASS. Validación de fuentes sobre copia limpia sin firma/evidencias privadas PASS: proyecto determinista, enlaces y PNG. Generador del icono reproduce el mismo SHA-256. El Team local y bundle resueltos por Xcode se compararon con la configuración previa: PASS.

Se inspeccionaron capturas de Inicio en claro, oscuro y tamaño de accesibilidad máximo, y del formulario de efectivo. No se certifica VoiceOver, reducción de movimiento ni accesibilidad exhaustiva por esta inspección. Las capturas y logs quedan locales, excluidos de Git.

Las pruebas se ejecutan con bases ficticias aisladas; un archive sin firma no instala esta versión en el teléfono. La instalación de la versión inicial fue comunicada por el usuario; no certifica esta mejora ni las comprobaciones físicas pendientes.
