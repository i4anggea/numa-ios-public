# Guía de verificación posterior en iPhone

Estado inicial: NO EJECUTADA. Completar con datos ficticios después de configurar firma e instalación. El simulador no demuestra el cifrado ni la entrega real de avisos con el iPhone bloqueado.

## Preparación

1. Usar un iPhone compatible con código de bloqueo del sistema y un Mac con Xcode compatible. Conectar y preparar el dispositivo según [Running your app in Simulator or on a device](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device). Elegir el Team de desarrollo disponible y revisar la firma; esta guía no confirma acceso, precio ni duración de un método de distribución.
2. Abrir Finanzas.xcodeproj y elegir esquema Finanzas/Debug y el iPhone. Antes de instalar, comprobar que no se está sustituyendo una app con datos personales: esta versión no permite exportación ni recuperación. Si ya existe una instalación con datos, preparar una compilación de validación con identificador de bundle distinto desde una copia del proyecto; no desinstalar ni borrar la existente.
3. Ejecutar únicamente sobre una instalación de validación vacía. Anotar modelo, versión exacta de iOS, build de app, configuración y fecha. Mantener diagnósticos FINANCE_PERFORMANCE desactivados. No introducir números completos de tarjeta, credenciales ni información bancaria real.
4. Registrar cada caso como PASS/FAIL/BLOCKED, con resultado observado. Usar capturas solo de cifras ficticias; evitar notificaciones ajenas en las capturas.

## Caso P1 — Bloqueo y reapertura

- Crear cuenta «Banco ficticio» con $1,000 y registrar gasto de $125.50. Resultado esperado: total/disponible $874.50 y un gasto.
- Con la app abierta en Inicio, bloquear el iPhone con su botón. Esperar al menos 15 segundos para cubrir la transición de disponibilidad. Desbloquear y volver a la app. Comprobar $874.50 y exactamente un gasto.
- Repetir desde un formulario sin guardar, un detalle y una hoja de cuentas. La app puede cerrar formularios al suspender por privacidad; no debe convertir el borrador en un movimiento ni mostrar datos antiguos antes de abrir el almacén.
- Tras desbloquear, registrar otro gasto de $10. Resultado esperado: $864.50, dos gastos. Repetir tres ciclos. Terminar y volver a abrir la app; comprobar cifras y recuento.
- Si aparece «Archivo no disponible», desbloquear y usar Reintentar. No repetir un movimiento si el aviso indica que la escritura terminó: primero reabrir y consultar el historial.

Este flujo visible no basta para demostrar el bloqueo criptográfico del archivo. La comprobación técnica complementaria debe registrar `UIApplication.isProtectedDataAvailable`, atributos de protección de Finance.store, -wal y -shm y el resultado de intentos controlados de apertura/escritura durante la indisponibilidad. Repetir después de crear el almacén y guardar. Se espera clase complete y fallo de acceso mientras no esté disponible; no almacenar payloads ni importes en los diagnósticos. Solo instrumentar una compilación de pruebas con datos ficticios. No interpretar la imposibilidad de lanzar/adjuntar un depurador con el iPhone bloqueado como prueba del control.

## Caso P2 — Selector y ocultación

- Con importes visibles, abrir el selector de apps desde Inicio, Reportes y una hoja con formulario. La miniatura debe mostrar la cubierta de privacidad, sin cifras ni formulario.
- Volver a la app: debe abrir con normalidad cuando el sistema tenga datos protegidos disponibles. No hay Face ID propio de esta versión.
- Activar Ocultar importes; comprobar Inicio, cuentas, movimientos, metas y reportes. No deben aparecer cifras financieras ni gráficas que las revelen; VoiceOver debe anunciar «Importe oculto». Reiniciar y comprobar que se recuerda la preferencia. Los formularios muestran importes al editar, por decisión de diseño.
- El contenido escrito en alias o notas no se censura automáticamente. El control no impide capturas manuales ni protege frente a alguien que ya utiliza el iPhone desbloqueado.

## Caso F1 — Semana, ahorro y cierre

- En una instalación de validación vacía, distinta de P1: abrir Banco con $2,000 y Efectivo con $500. Presupuesto global $1,000 para una semana completada, categoría Alimentación $300.
- En esa semana registrar ingreso de $500 al Banco, gasto Alimentación de $200 en efectivo y otro egreso de $100 con débito del Banco.
- Esperar dinero total $2,700, gasto presupuestado $300 y sobrante $700. El límite de Alimentación restante es $100.
- Crear meta «Fondo»; cerrar la semana reservando $200 del Banco y trasladando $300 al presupuesto global siguiente. Esperar total $2,700, reserva $200 y disponible $2,500. El traslado amplía presupuesto, sin crear ingreso.
- Liberar $100 de la reserva: disponible $2,600 y reserva $100. Intentar deshacer el reparto dependiente: debe rechazarlo conservando el cierre. Reiniciar y comprobar todos los importes.

## Caso F2 — Crédito y meses

- En otra instalación de validación vacía: Banco con $5,000, tarjeta de crédito sin deuda inicial. Compra total $1,201 en tres meses, precio original $1,000. Registrar una primera fecha de pago y comprobar tres cuotas cuya suma sea $1,201, con ajuste de centavos.
- Esperar deuda $1,201 y gasto presupuestado $1,201 en la fecha de compra; Banco conserva $5,000.
- Pagar $400.34 desde Banco: deuda $800.66 y Banco $4,599.66. El reporte no debe sumar el pago como un segundo gasto.
- Corregir total final de compra a $1,301: deuda $900.66 y gasto $1,301. Intentar eliminar la compra mientras existe el pago: debe rechazarlo. Reiniciar y comprobar deuda y cuenta.
- El calendario es previsto; las cuotas no se marcan automáticamente como pagadas.

## Caso P3 — Sin conexión

Activar modo avión y desactivar también Wi-Fi, comprobando el estado de radios del iPhone. Sin red, crear/editar/eliminar un movimiento ficticio, consultar filtros/reportes, reservar/liberar ahorro y terminar/reabrir la app. Verificar las mismas cifras tras reabrir. Las funciones locales deben seguir disponibles; no hay cola de sincronización. Recuperar la conexión al terminar. No basta con que el Mac o simulador indiquen ausencia de conexión.

## Caso P4 — Notificaciones locales

Conceder permiso desde la app en contexto. En una tarjeta ficticia configurar días de corte/pago que permitan comprobar avisos siete y tres días antes, a las 09:00 de Ciudad de México. Revisar solicitudes pendientes en una compilación de pruebas y, cuando llegue la fecha real, comprobar entrega con iPhone bloqueado. El título/cuerpo no deben incluir alias ni importes. La entrega depende también de permisos, Concentración y ajustes de iOS; no cambiar el reloj principal ni asumir entrega por ver una solicitud pendiente. Después de editar o desactivar avisos, comprobar sustitución/cancelación sin duplicados.

## Caso P5 — Exclusión de copias

En instalación de validación con datos ficticios, verificar la marca `isExcludedFromBackup` del directorio, base y auxiliares después de abrir y guardar. Complementar con una copia/restauración controlada del sistema en un entorno de pruebas: el almacén financiero no debe recuperarse. No restaurar ni borrar un iPhone personal para ensayar este punto; requiere un entorno separado y autorización específica si implica borrar/restaurar un dispositivo. La marca observada por sí sola no equivale a completar esta prueba.

## Registro y criterio de cierre

| Caso | Estado inicial | Resultado/evidencia por completar |
|---|---|---|
| P1 flujo de bloqueo/reapertura | NOT_RUN | |
| P1 protección técnica de base/auxiliares | BLOCKED | Requiere dispositivo y compilación de prueba |
| P2 selector y ocultación | NOT_RUN | |
| F1 semana/ahorro/cierre | NOT_RUN | |
| F2 compra a meses/pago | NOT_RUN | |
| P3 sin conexión física | NOT_RUN | |
| P4 solicitudes y entrega | NOT_RUN | |
| P5 marca de copias en físico | NOT_RUN | |
| P5 copia/restauración real | BLOCKED | Requiere entorno separado |

Si falla conservación de datos, hay cifras inconsistentes, aparece un duplicado o se ven cifras en el selector, conservar evidencia y corregir antes de introducir datos reales. No se declara verificación completa mientras los controles pertinentes permanezcan pendientes. Texto grande, VoiceOver exhaustivo, tema oscuro y un archive firmado deben completarse antes de distribución pública.
