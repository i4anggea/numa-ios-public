# Atajos y doble toque posterior — Numa 0.3.0

## Antes de empezar

Actualiza Numa desde Xcode conservando el mismo bundle y Team; no desinstales la app con tus registros. Abre Numa una vez y comprueba tus saldos. Esta integración se configura en el iPhone: no se asigna el gesto ni se crean automatizaciones en tus ajustes sin tu intervención.

En Numa abre **Ajustes → Atajos y captura rápida**:

1. Selecciona tu efectivo y categoría predeterminados para el gasto manual.
2. Selecciona la tarjeta de débito Santander que ya registraste en Numa. Si no existe, créala y vincúlala a su cuenta bancaria desde Inicio.
3. Añade las reglas que quieras, por ejemplo **Mercado Libre → Compras**. Las coincidencias son exactas, ignorando mayúsculas, acentos y espacios repetidos; no se adivinan categorías. Una categoría archivada debe elegirse de nuevo al registrar.

Puedes usar **Gasto rápido** en Inicio para probar el mismo flujo de navegación sin configurar todavía el gesto.

## Crear el acceso de doble toque

1. Pulsa **Abrir Atajos de Numa** en esa pantalla o abre la app Atajos.
2. Crea un atajo nuevo y añade la acción de Numa **Abrir gasto rápido**. Nómbralo, por ejemplo, **Gasto rápido Numa**.
3. Ejecútalo con el iPhone desbloqueado para comprobarlo. Debe abrir Numa, no guardar dinero automáticamente.
4. En Configuración del iPhone entra en **Accesibilidad → Tocar → Toque posterior → Toque doble** y elige **Gasto rápido Numa**.
5. Da dos toques en la parte posterior del teléfono. Si no hay pendientes, escribe el importe en el gasto manual preseleccionado. Si hay uno, abre su formulario. Si hay varios, elige cuál revisar en la lista, ordenada por el más reciente.
6. Revisa los datos y pulsa **Guardar**. **Cancelar** no registra el gasto; si era una compra detectada, el pendiente se conserva. Las ediciones no guardadas del formulario se descartan al cancelar.

Si falta la configuración de efectivo o categoría, el formulario pide completarlos; no crea saldos ni categorías automáticamente. El gasto manual utiliza la fecha actual y permite corregirla. El botón + habitual conserva su comportamiento.

Referencia: [doble toque posterior, Apple](https://support.apple.com/es-mx/guide/iphone/iphaa57e7885/ios).

## Preparar una compra de Wallet

En Atajos configura una automatización **Transacción**, elige la tarjeta de Wallet y añade **Preparar compra detectada**, de Numa.

| Campo de la acción | Configuración |
|---|---|
| Origen | Wallet |
| Comercio | Comercio que entregue el disparador; si no llega, no se inventa. |
| Importe sin separadores de miles | Importe de la compra si está disponible, por ejemplo `125.50`. Se aceptan punto o coma decimal, hasta dos decimales. |
| Moneda (MXN) | Moneda del evento, si está disponible. Si no se proporciona, el formulario exige revisar que el importe sea MXN. |
| Tarjeta de Numa | Selecciona la tarjeta registrada que corresponde a la que elegiste en Wallet. Puedes configurar una automatización por tarjeta. |
| Fecha de la compra | Fecha del evento, si llega; si se omite se usa la hora de recepción. |
| Identificador del evento | Solo si el disparador entrega un ID estable. Si no existe, déjalo vacío. |
| Texto del aviso | No es necesario para Wallet. |

Los nombres y propiedades de la entrada que muestre Atajos dependen del disparador disponible en tu iPhone. No está comprobado que todos los bancos entreguen importe, moneda, comercio o identificador. Si el importe incluye símbolos de moneda o separadores de miles, no lo envíes como si fuera un decimal: corrígelo o déjalo vacío y complétalo en Numa. Una moneda distinta de MXN se rechaza sin convertirla. Si no se puede identificar el comercio, el atajo informa el error y no crea una captura; usa el gasto manual.

La acción **Preparar compra detectada** guarda únicamente el pendiente. Después usa el doble toque o entra en **Compras pendientes** para revisarlo. No duplica el saldo bancario ni ejecuta pagos.

Referencia: [disparador de transacciones, Apple](https://support.apple.com/guide/shortcuts/transaction-trigger-apd65c67538a/ios).

## Notificaciones de Santander

En Atajos, crea una automatización de **Notificación** para la app Santander. Usa un filtro de título que corresponda a los avisos que recibes; por ejemplo, `Compra` puede cubrir tanto `Compra exitosa` como la variante `Compra existosa` proporcionada en el ejemplo. No selecciona por sí sola todos los tipos de movimientos del banco.

Añade **Preparar compra detectada**:

- Origen: **Santander · notificación**.
- Texto del aviso: el mensaje recibido, por ejemplo `Haz realizado una compra en Mercado Libre`.
- Comercio: vacío para usar el extractor del mensaje.
- Importe y moneda: vacíos si el aviso no los contiene. No se deducen a partir del comercio.
- Tarjeta: opcional si ya elegiste la tarjeta Santander en Numa; una tarjeta explícita en el atajo tiene prioridad y debe ser de débito.

Solo se admite el patrón de una línea **Has/Haz realizado una compra en COMERCIO**, ignorando mayúsculas. No interpreta números ni otras frases de un aviso como importes. Si Santander cambia el formato, la captura se rechaza con un mensaje genérico en lugar de inventar datos; utiliza el gasto manual y revisa el nuevo formato con un ejemplo ficticio.

Referencia: [disparadores de notificaciones de iOS 27, Apple](https://support.apple.com/guide/shortcuts/event-triggers-apd932ff833f/ios).

## Correos de Santander

Crea una automatización de **Correo** en Atajos, limitada al remitente que reconozcas en tus avisos y al asunto **Compra exitosa**. No hace falta proporcionar contraseña bancaria a Numa.

Pasa el texto del mensaje recibido a **Texto del aviso**, con origen **Santander · correo**. El ejemplo `Haz realizado una compra en Mercado Libre` tiene el mismo tratamiento que una notificación: comercio detectado, importe por completar. Si el correo es HTML, utiliza el texto del mensaje que entregue Atajos; Numa no abre enlaces ni descarga correos o recursos remotos. No envíes el correo completo con información innecesaria.

La recepción real de contenido de correo/notificación debe probarse en el teléfono. Si iOS no entrega el texto o el formato no coincide, el atajo informa que no identificó el comercio. Numa no tiene acceso general al buzón, al historial de Wallet ni al centro de notificaciones.

Referencia: [disparadores de correo, Apple](https://support.apple.com/guide/shortcuts/communication-triggers-apdd711f9dff/ios).

## Privacidad y teléfono bloqueado

Los borradores, reglas y preferencias de Numa viven en la misma base local con protección completa y exclusión de copias. No se añade servidor, cuenta bancaria conectada, analítica ni modelo de IA externo. El texto original no se conserva: solo el comercio y los parámetros aceptados. Los importes de los pendientes se ocultan con la preferencia de Numa.

Las acciones requieren autenticación local del dispositivo. iOS puede pedir desbloquear o impedir que una automatización desatendida termine. Numa comprueba de nuevo el acceso a los datos antes de escribir. No promete recuperar un aviso si la acción no se ejecutó, venció o falló mientras el teléfono estaba bloqueado: revisa el resultado del atajo y usa captura manual si no aparece el pendiente. El acceso manual funciona sin red; recibir avisos del banco depende de servicios externos a Numa.

Atajos tiene sus propios ajustes de sincronización y respaldo, independientes de la base de Numa. Para mantener también los accesos locales, revisa la sincronización de Atajos con iCloud y desactívala si está habilitada; no uses almacenamiento global sincronizado, servicios web ni compartas accesos con datos incrustados. Numa no puede cambiar esos ajustes. [Sincronización de Atajos, Apple](https://support.apple.com/en-ke/guide/shortcuts/apdb3a4240b0/ios).

## Duplicados, límites y borradores abiertos

Si la fuente aporta un identificador estable, el mismo origen e ID se reciben una sola vez, incluso después de registrar o descartar esa captura. Sin ID estable no se eliminan compras por parecerse: se advierte una posible coincidencia por comercio, tarjeta, importe conocido y un intervalo de cinco minutos. No equivale a conciliación bancaria ni garantiza detectar todos los duplicados.

Guardar una captura registra el gasto y la marca procesada en una transacción. Un reintento de ese mismo borrador no sobrescribe el movimiento ni crea otro. Si ya estás editando un formulario, otro doble toque no lo reemplaza: se atiende cuando cierres la hoja activa.

Los pendientes no caducan automáticamente. Desliza uno en la lista para descartarlo, confirmando la acción. Hay un máximo de 200 capturas y 100 reglas. La limpieza manual elimina solo capturas registradas/descartadas, sin tocar movimientos ni pendientes; perderá la memoria de reintentos por sus IDs. Si el guardado informa que terminó pero falló la comprobación de protección, reabre y comprueba el movimiento antes de repetirlo.

## Prueba posterior en tu iPhone

1. Configurar efectivo/categoría y ejecutar el acceso con el teléfono desbloqueado. Cancelar una captura y comprobar que no cambia el saldo.
2. Introducir un importe ficticio, guardar y comprobar saldo, presupuesto, método y persistencia al reabrir.
3. Probar **Preparar compra detectada** con el texto ficticio anterior. Confirmar que no cambia el saldo y que al revisar pide el importe.
4. Probar dos avisos ficticios, uno de notificación y otro de correo. Comprobar advertencia y elegir conscientemente si representan una o dos compras.
5. Probar Wallet en una compra controlada: comprobar qué propiedades entrega tu emisor, moneda, tarjeta y fecha. Si no llegan, completar manualmente; no afirmar detección bancaria completa.
6. Probar con teléfono bloqueado y recién reiniciado: comprobar autenticación, errores de Atajos y ausencia de escrituras antes del desbloqueo. No desactivar el código para la prueba.
7. Comprobar «Ocultar importes», VoiceOver y foco del teclado. El doble toque físico y la app Atajos no se certifican mediante el botón de prueba del simulador.

Estado de la prueba física: **PENDIENTE**. Instala primero 0.3.0 y registra aquí los resultados reales; no usar datos sensibles para fabricar evidencia.
