# Numa — Manual de uso

Versión documentada: 0.3.0, desarrollo privado. Numa te ayuda a registrar movimientos, controlar presupuestos semanales y reservar dinero para metas. Está diseñada para iPhone con iOS 27, en español y pesos mexicanos.

La última regresión funcional aprobó en simulador; faltan las comprobaciones físicas descritas en la [guía para iPhone](PRUEBAS_IPHONE.md). El usuario ya probó la versión inicial en su iPhone; esta mejora aún no se ha validado en ese dispositivo ni publicado para distribución.

## Antes de comenzar

Los registros se introducen manualmente y se guardan en el dispositivo. No hay conexión bancaria, cuenta de usuario, sincronización, exportación ni restauración. El almacén se configura para quedar excluido de las copias del sistema: si pierdes el iPhone o eliminas la app, esta versión no ofrece recuperación de tus registros.

Usa código de bloqueo en el iPhone. El bloqueo propio con Face ID o código de la app está previsto para otra versión. Durante las pruebas utiliza cifras ficticias. No guardes números completos de tarjeta, CVV ni credenciales en nombres o notas.

## Preparar efectivo, cuentas y tarjetas

1. En **Inicio**, abre **Efectivo, cuentas y tarjetas**.
2. En la sección **Efectivo**, pulsa **Añadir efectivo**; para el banco usa **Añadir cuenta bancaria**. Indica nombre y saldo inicial por separado.
3. Añade las tarjetas que uses. Una tarjeta de débito se vincula con una cuenta bancaria existente; una de crédito mantiene su deuda aparte.
4. En crédito, configura días de corte y pago y, si corresponde, deuda inicial. Usa un alias para identificarla.

El saldo inicial representa el dinero previo a los movimientos que empezarás a registrar; no cuenta como ingreso. Si introduces como saldo inicial el saldo actual del banco y después capturas movimientos anteriores que ya incluía, los contarás dos veces. Elige un punto de inicio coherente.

Una tarjeta de débito usa el saldo de su cuenta, sin crear otra bolsa de dinero. La deuda inicial de crédito no reconstruye compras o planes anteriores.

## Entender las cifras de Inicio

| Cifra | Qué representa |
|---|---|
| Disponible para gastar | Efectivo y saldos bancarios, menos el ahorro reservado. |
| Presupuesto restante | Límite semanal global, más margen recibido, menos gastos y otros egresos de esa semana. |
| Ahorro reservado | Dinero apartado para tus metas, que continúa dentro de tus cuentas. |
| Deuda de crédito | Deuda inicial y compras registradas, menos los pagos registrados. |

El dinero total suma efectivo y cuentas. La deuda de crédito se consulta aparte: el disponible no equivale a dinero total menos todas tus deudas. El presupuesto tampoco garantiza que haya dinero suficiente en una cuenta.

## Registrar un movimiento

Pulsa **+**, elige el tipo, captura importe, fecha, categoría cuando corresponda y método. Una compra utiliza un solo método. Puedes añadir una nota. Pulsa **Guardar**; si falta un dato, corrígelo según el mensaje.

Si todavía no configuraste efectivo, elige **Efectivo** al registrar el movimiento: se abrirá el saldo inicial. Al guardarlo vuelves al movimiento con ese método seleccionado. Cancelar la configuración conserva el borrador y no crea efectivo. Guardar el saldo es una operación independiente: si después cancelas el movimiento, el saldo configurado permanece.

Introduce importes positivos sin separadores de miles, con hasta dos decimales: `125.50` o `125,50`. El tipo del movimiento determina su efecto. La captura de movimientos permite hoy o fechas anteriores.

| Tipo | Cuándo usarlo | Efecto principal |
|---|---|---|
| Ingreso | Dinero recibido en efectivo o cuenta. | Aumenta el saldo; aparece como ingreso. |
| Gasto | Compra o consumo. | Consume presupuesto; reduce cuenta o aumenta deuda de crédito. |
| Otro egreso | Otra salida que deseas distinguir del consumo. | Consume presupuesto y aparece separado en reportes. |
| Transferencia | Mover dinero entre tus propias cuentas. | Cambia origen/destino sin crear ingreso ni gasto. |
| Pago de tarjeta | Abonar desde efectivo o cuenta a una tarjeta de crédito. | Reduce cuenta y deuda, sin volver a consumir presupuesto. |

Si una salida rebasa el saldo disponible o el presupuesto, Numa avisa. **Cancelar** conserva el formulario; **Registrar de todos modos** permite reflejar lo ocurrido, incluso con cifras negativas. Algunas reglas de integridad sí impiden guardar, como pagar más deuda de la registrada para esa fecha.

## Consultar, editar y eliminar

En **Movimientos**, busca por concepto, categoría o método. Despliega **Filtros** para elegir tipo, categoría, método y periodo; usa **Restablecer filtros** para volver al historial completo.

El historial comienza con 50 filas y añade otras al desplazarte. El contador distingue coincidencias totales de filas cargadas. Los filtros y reportes consideran todo el historial correspondiente.

Abre un movimiento para ver su detalle, **Editar movimiento** o **Eliminar movimiento**. Comprueba el efecto de una corrección en saldos, deuda y presupuesto. Si pertenece a una semana cerrada, primero debe deshacerse su reparto. Si existen operaciones dependientes, Numa puede impedir esa reversión para conservar la coherencia.

No intentes resolver un error de almacenamiento eliminando la app: esta versión no tiene recuperación.

## Compras a meses y pagos de crédito

Al registrar un gasto con tarjeta de crédito, activa **Compra a meses**. Indica el número de mensualidades y revisa la primera fecha de pago sugerida; puedes corregirla antes de guardar.

- Sin intereses: el importe es el total de la compra.
- Con intereses: captura precio original y total final a pagar. El total debe ser mayor que el precio original.
- Se permiten de 2 a 120 mensualidades. Los centavos se distribuyen para que la suma coincida exactamente con el total.
- En meses sin el día elegido, el calendario usa el último día disponible.

El total completo consume presupuesto en la fecha de compra. Las cuotas son un calendario previsto; no se marcan automáticamente como pagadas. Numa no calcula el importe exigible del estado de cuenta del banco.

Para abonar, pulsa **+ → Pago de tarjeta**, elige cuenta de origen, tarjeta, importe y fecha. Puedes hacer pagos parciales o totales contra la deuda registrada.

Ejemplo: una compra a crédito de $1,201 aumenta la deuda en $1,201 y consume ese importe del presupuesto. Pagar $400.34 deja $800.66 de deuda y reduce la cuenta de origen en $400.34, sin añadir otro gasto al reporte.

## Presupuestos semanales

En **Presupuestos**, selecciona la semana y pulsa **Crear presupuesto** o **Editar límites**. Las semanas son de lunes a domingo, con calendario de Ciudad de México. Define el límite global y, si quieres, límites por categoría.

Cada gasto y otro egreso se cuenta una vez en el global y en su categoría. Los límites por categoría no se suman como si fueran gastos adicionales. Un límite vacío no establece restricción individual; cero establece un límite de cero.

Cuando una semana haya terminado, **Cerrar y repartir sobrante** permite indicar cuánto reservar para una meta y cuánto añadir al límite global siguiente. El resto permanece sin asignar, sin traslado automático. Para ahorrar debes elegir una cuenta que respalde la reserva con dinero disponible.

Ejemplo: con límite $1,000 y salidas $300, queda margen $700. Puedes reservar $200 y trasladar $300; los $200 no asignados no crean un movimiento. El traslado amplía el presupuesto siguiente y no aumenta el saldo bancario. Si el siguiente presupuesto aún no existe, se muestra el margen recibido pendiente de presupuesto.

**Deshacer reparto** revierte las asignaciones del cierre solo cuando no perjudica operaciones posteriores. Si ya liberaste parte del ahorro relacionado, puede ser necesario corregir esas dependencias primero. No traslades margen hacia una semana ya cerrada.

## Metas y ahorro

En **Ahorro**, crea una meta con importe objetivo y fecha opcional. Abre la meta y pulsa **Aportar o liberar dinero**:

- **Aportar** reserva dinero de una cuenta para esa meta. Reduce el disponible, conservando el dinero total.
- **Liberar** devuelve todo o parte de la reserva al disponible de la misma cuenta, sin registrar ingreso.

Con fecha objetivo, la sugerencia semanal es orientativa; las aportaciones son manuales. No se mueve dinero al banco ni se programa un cargo automático. Solo se puede eliminar una meta sin reservas ni historial; las demás se conservan para mantener trazabilidad.

## Reportes y métodos de pago

En **Reportes**, elige día, semana o mes y la fecha de referencia. Consulta ingresos, gastos de consumo, otros egresos, categorías y métodos: efectivo, débito y crédito, con detalle por cuenta o tarjeta.

La diferencia entre ingresos y egresos no siempre coincide con el cambio de efectivo, porque las compras a crédito afectan deuda. Los pagos de tarjeta, transferencias y reservas no se suman como un segundo gasto.

La evolución muestra efectivo y saldos bancarios al terminar cada día, sin restar deuda ni ahorro reservado. Parte de tus saldos iniciales y de los movimientos capturados; no reconstruye periodos que no registraste.

## Categorías, apariencia y privacidad

Desde **Ajustes → Categorías**, añade o renombra categorías. Archivar evita seleccionarlas para movimientos nuevos y conserva el historial; puedes restaurarlas.

En **Ajustes**, elige tema Sistema, Claro u Oscuro. El botón del ojo permite ocultar importes y gráficas y recuerda la preferencia. Las etiquetas de accesibilidad de las cifras pasan a «Importe oculto». Los formularios muestran el importe al editar. Nombres y notas no se censuran: evita escribir cantidades sensibles allí si no deseas que aparezcan.

Al quedar inactiva, la app presenta una cubierta de privacidad. Su comportamiento en el selector real del iPhone sigue pendiente de la prueba física. Ocultar cifras no sustituye el bloqueo del sistema ni impide capturas manuales.

## Recordatorios de corte y pago

Configura los días y activa avisos en cada tarjeta de crédito. En **Ajustes → Activar o actualizar avisos**, concede el permiso de iOS si deseas recibirlos. Si están denegados, utiliza **Abrir ajustes de iOS**.

Se programan avisos siete y tres días antes de cada fecha, a las 09:00 de Ciudad de México. El mensaje es genérico, sin alias ni importes. El calendario usa el último día disponible en meses cortos.

Numa conserva hasta 60 avisos próximos y renueva ese horizonte al abrirla o actualizar la configuración. Si no vuelves a abrir la app, los avisos programados pueden agotarse. La entrega depende de permisos y ajustes de iOS; no sustituye revisar las fechas con tu banco.

## Qué hacer ante un problema

| Situación | Qué hacer |
|---|---|
| Archivo no disponible tras bloquear | Desbloquea el iPhone y pulsa Reintentar si hace falta. Los borradores pueden cerrarse para proteger la información. |
| Mensaje de datos inconsistentes o formato desconocido | Conserva la app y sus datos; no los sustituyas ni borres para intentar arreglarlo. Anota el mensaje sin compartir información personal. |
| No se pudieron guardar cambios | Comprueba que el iPhone esté desbloqueado y revisa el historial antes de volver a registrar. |
| «La escritura terminó» pero falló la comprobación de protección | Reabre el archivo y comprueba si el movimiento ya existe antes de repetirlo. |
| Un pago o eliminación se rechaza | Revisa fechas, deuda registrada y movimientos dependientes. |
| No aparecen avisos | Revisa permiso de notificaciones, configuración de la tarjeta y ajustes de iOS; vuelve a abrir Numa para renovar solicitudes. |

Para validar una instalación con cifras ficticias, sigue la [guía de pruebas en iPhone](PRUEBAS_IPHONE.md). El [índice de documentación](INDICE.md) reúne los informes y el estado del proyecto.

## Progreso y pequeños logros

Las metas muestran una barra y porcentaje con hitos al llegar al 25 %, 50 %, 75 % y 100 %. Se calculan con el dinero reservado actualmente: si liberas dinero, el progreso y el mensaje se actualizan. No son premios permanentes ni significan que hayas obtenido rendimientos.

Las transiciones son discretas y respetan **Reducir movimiento** del iPhone. **Ocultar importes** también oculta porcentajes, barras y mensajes de logros. Los formularios siguen mostrando cifras al editar.


## Atajos y captura rápida

En Ajustes puedes configurar efectivo, categoría predeterminada, tarjeta de débito Santander y reglas por comercio. La [guía de Atajos](ATAJOS.md) explica cómo asignar el doble toque y recibir datos de Wallet o avisos. Un pendiente no afecta al saldo hasta revisarlo y pulsar Guardar. El botón Gasto rápido de Inicio permite probar el mismo formulario.
