# Diseño de interfaz y experiencia

Estado: preferencias de fase 3 confirmadas e implementadas en fase 4. Inicio y parte visible de Reportes inspeccionados mediante capturas del simulador; verificación visual y de accesibilidad parcial.

## Dirección visual

Interfaz nativa y sobria, superficies neutras, acento azul y tarjetas con jerarquía clara. Seguir tema del sistema por defecto y ofrecer Sistema/Claro/Oscuro en Ajustes.

Usar tipografía del sistema y tamaños semánticos compatibles con Dynamic Type, espaciado consistente, iconos del sistema y controles nativos. Colores semánticos para estados; ingresos, egresos y errores también llevan texto/iconos, sin depender solo del color. Importes MXN con dos decimales y fechas en español. Ajustar formatos para que cifras grandes no se corten.

Objetivos de accesibilidad: etiquetas VoiceOver, controles con superficie táctil suficiente, lectura coherente, adaptación a texto grande y movimiento reducido. Contraste e interacción se verificarán durante pruebas; no se declara cumplimiento todavía.

## Navegación aprobada

Cinco pestañas persistentes: Inicio, Movimientos, Presupuestos, Ahorro y Reportes.

- Inicio abre cuentas y tarjetas; Ajustes accesible en la barra superior.
- Botón «+» etiquetado «Registrar movimiento», accesible en todas las pestañas sin cubrir contenido ni controles del sistema.
- Formularios presentados como hoja con Cancelar/Guardar. Los errores conservan los valores introducidos.
- Hojas de edición/ahorro presentadas desde la vista principal, separadas de secciones reutilizables de listas. Formularios numéricos con botón Listo para cerrar teclado y cierre por desplazamiento.
- Errores de captura en una alerta inmediata; errores de operaciones desde hojas se presentan en la superficie activa. La confirmación de una salida negativa conserva el movimiento hasta elegir cancelar o registrar.

## Pantallas y tareas

### Inicio

Orden de lectura: dinero disponible para gastar; presupuesto restante de la semana con fechas explícitas; ahorro reservado; deuda de crédito; acceso a cuentas/tarjetas; movimientos recientes. Dinero total accesible en el detalle de saldos. El presupuesto disponible no se presenta como saldo bancario.

Botón de mostrar/ocultar importes en la barra superior. Tarjetas de saldo y presupuesto abren sus detalles. Al iniciar por primera vez, explicar almacenamiento local, permitir crear efectivo/cuenta y saldo inicial, y continuar al registro de movimientos. Pedir permiso de notificaciones cuando se configure una tarjeta con recordatorios.

### Movimientos

Historial por fecha, búsqueda y filtros por tipo, categoría, método y periodo. Cada fila muestra concepto/categoría, fecha, método y cantidad; una compra a meses identifica el plan. Abrir fila permite detalle y edición; eliminar requiere una confirmación que describa su efecto.

Formulario único: tipo, importe, categoría cuando aplique, método/cuenta, fecha y nota opcional. Opciones de transferencia/pago se presentan con campos propios, evitando que parezcan nuevos gastos. En compras a crédito, activar meses muestra con/sin intereses, precio, total cuando corresponda, número de meses, primera cuota y vista previa del plan. Las reglas de fechas se cierran en fase 4.

### Cuentas y tarjetas

Separar efectivo/cuentas bancarias de deuda de crédito. Débito vinculado a cuenta sin saldo duplicado. Totales de gasto por método y tarjeta con periodo visible. Tarjeta de crédito: deuda registrada, corte/pago, próximos recordatorios, planes y acción Registrar pago. No solicitar números completos de tarjeta, CVV ni credenciales.

### Presupuestos

Semana lunes-domingo con selector; límite global, gastado y restante. Lista de categorías con límites individuales y progreso. Advertencias y sobrepasos expresados con texto y cantidad; sin hacer crecer la escala visual de forma que oculte el exceso.

Cerrar semana abre distribución del sobrante: importe hacia meta y cuenta que respalda la reserva; importe hacia siguiente presupuesto; restante sin asignar. Mostrar vista previa y evitar sumar como dinero real el margen trasladado. Comportamiento de semanas pasadas y modificaciones pendiente de fase 4.

### Ahorro

Lista de metas con objetivo, reservado y progreso. Fecha opcional. Detalle con historial de aportaciones y acción Aportar desde cuenta; explicar efecto en disponible y total. Si hay fecha, una sugerencia de aportación es informativa, nunca un movimiento automático. Reglas de retiro/reasignación pendientes de fase 4.

### Reportes

Periodos diario, semanal y mensual, con fechas explícitas. Gasto por categoría, comparación de ingresos/gastos y evolución del saldo. Gráficas sencillas acompañadas de valores/lista accesible. Transferencias, reservas y pagos de crédito no se contabilizan nuevamente como consumo. Otros egresos se identifican por separado.

### Ajustes

Tema, categorías, ocultación de importes y estado de notificaciones con acceso a ajustes del sistema cuando corresponda. Información sobre datos locales y ausencia de recuperación en esta versión. No mostrar opciones no implementadas como si fueran utilizables.

## Privacidad visual aprobada

Recordar preferencia de ocultación entre aperturas. Sustituir cifras en Inicio, listas y reportes por un marcador de longitud fija; no exponerlas en etiquetas de accesibilidad. Ocultar gráficas y resúmenes que permitan inferir cantidades. Formularios muestran cantidades al editar, tal como eligió el usuario; esto no constituye autenticación.

Cubrir contenido sensible cuando la escena se vuelva inactiva o pase a segundo plano para proteger la vista del selector de aplicaciones. Verificar el resultado real en dispositivo/simulador; no prometer impedir capturas manuales de pantalla.

La cubierta se aplica también a las hojas presentadas, porque una cubierta situada únicamente en Inicio quedaría detrás de ellas. Su efectividad en el selector real sigue pendiente de verificación específica.

## Estados y flujos de aceptación

- Vacío: mensaje específico y acción útil (crear cuenta, registrar movimiento, definir presupuesto o crear meta); sin movimientos ficticios mezclados con datos reales.
- Validación: identificar campo incorrecto y cómo corregirlo; Guardar no debe anunciar éxito si falla persistencia.
- Error de almacén: explicar que no se pudo abrir, permitir reintentar y conservar datos; sin reinicio destructivo.
- Notificaciones denegadas: mantener el resto de funciones y mostrar estado del permiso.
- Flujo principal: crear cuenta → registrar gasto → ver saldo y presupuesto actualizados → consultar reporte.
- Ahorro: crear meta → aportar → comprobar reserva y disponible.
- Crédito: crear tarjeta → compra a meses → ver plan → registrar pago sin duplicar gasto.
- Cierre: revisar sobrante → repartir → comprobar siguiente presupuesto y reserva.

Verificación actual: cuatro casos UI PASS; incluyen cuenta/gasto/persistencia/ocultación, cierre semanal/ahorro/liberación, crédito/pago/corrección y validación/negativos. Capturas de Inicio, Reportes, presupuesto cerrado y mensualidades inspeccionadas parcialmente. Texto grande, VoiceOver, tema oscuro, cubierta del selector y revisión exhaustiva siguen pendientes. Las elecciones de estilo y navegación están aprobadas; detalles de disposición podrán ajustarse a partir de la app ejecutable.

## Historial amplio — fase 6

Carga inicial de 50 movimientos y ampliación en bloques de 50 al alcanzar el final. El contador distingue coincidencias totales y filas cargadas. Los filtros y reportes siempre usan todos los registros correspondientes. Categorías ordenadas, acción Restablecer filtros y búsqueda con espera de 150 ms; cambios posteriores invalidan respuestas antiguas. Resultados conservados al volver de un detalle si los datos y filtros no cambiaron.


## Evolución de identidad — 22/10/2026

Dirección elegida: serena, clara y cercana; motivar con progreso verificable y pequeños logros, manteniendo azules y minimalismo. Tarjetas ligeras, jerarquía de saldo disponible, CTA visible y accesos explícitos. Logo temporal: N redondeada y equilibrada, con remate ascendente.

Inicio incluye marca, explicación del disponible (deuda aparte), registro directo, resumen semanal y acceso separado a efectivo/cuentas/tarjetas. Las metas muestran avance e hitos actuales al 25/50/75/100 %. Transiciones suaves, desactivadas con Reducir movimiento. La privacidad oculta barras, porcentajes y logros además de las cantidades.

El efectivo aparece siempre en el selector de métodos, con configuración contextual si falta el saldo inicial. Efectivo y cuentas bancarias tienen secciones y acciones separadas; las cantidades conservan su etiqueta después de escribir. El modelo financiero no cambia.
