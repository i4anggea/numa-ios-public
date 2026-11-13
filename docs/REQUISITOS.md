# Aplicación de finanzas para iPhone

Estado: fases 1 a 3 definidas; fase 4 implementada; fase 5 revisada/corregida con verificación del alcance seleccionado. Fase 6 pendiente de respuestas y medición.
Nombre provisional de carpeta: finanzas-ios. No es el nombre del producto.

## Objetivo y alcance

Uso personal y privado inicial, con futura apertura al público tras pruebas.
Prioridades: controlar saldo, respetar presupuestos y ahorrar.
iPhone con iOS 27 como objetivo indicado por el usuario. Español y MXN.
Registro manual, datos locales y todas las funciones disponibles sin conexión.
Sin cuenta de usuario, sincronización, conexión bancaria ni exportación/restauración en esta versión.
Acceso con Apple y bloqueo con Face ID/código quedan para versiones posteriores.
Nombre, calendario y presupuesto económico pendientes.

## Reglas confirmadas

- Crear, consultar, editar y eliminar ingresos y egresos; organizar por categorías.
- Gasto: consumo. Otro egreso: salida distinta del consumo, como préstamo otorgado.
- Transferencias entre cuentas propias o hacia ahorro no generan un nuevo gasto.
- Registrar saldos iniciales por efectivo/cuenta y deuda inicial de tarjetas. No se requiere reconstruir deudas ni planes de mensualidades anteriores.
- Mostrar dinero disponible, deuda de tarjetas y ahorro reservado por separado.
- Distinguir efectivo, débito y crédito; consultar gasto por método y por tarjeta individual.
- Cada compra tiene exactamente un método de pago.
- Registrar compras a meses, distinguiendo con y sin intereses, y mostrar número de mensualidades e importe correspondiente.
- El importe completo de la compra se aplica al presupuesto en la fecha de compra; las mensualidades se muestran por separado. Comprar a crédito no reduce el efectivo hasta pagarlo.
- Pagar la tarjeta reduce dinero disponible y deuda; no duplica el gasto original.
- Presupuestos semanales de lunes a domingo, globales y por categoría. Un gasto cuenta una vez en el global y en su categoría; no se suman ambos como gastos diferentes.
- Al cerrar la semana, el usuario elige cuánto sobrante destina a metas y cuánto añade al presupuesto siguiente. Lo no asignado queda disponible, sin traslado automático.
- Trasladar margen de presupuesto no crea dinero ni un ingreso.
- Metas con importe objetivo, fecha opcional y aportaciones manuales.
- Aportar a una meta reduce el dinero disponible para gastar, conservándolo dentro del dinero total.
- Consulta diaria, semanal y mensual por categoría, evolución del saldo y comparación de ingresos/gastos. Los presupuestos mensuales quedan para otra versión.
- Opción de ocultar importes.
- Notificaciones locales por corte y pago: siete y tres días antes de cada fecha, a las 09:00. Su entrega depende del permiso y ajustes de iOS.
- Desarrollo nativo con Swift y SwiftUI; persistencia local con SwiftData.
- Excluir la base financiera de las copias de seguridad del sistema; sin recuperación en esta versión si se pierde o elimina.
- En compras con intereses, introducir precio, total final a pagar y número de mensualidades. El presupuesto recibe el total final; no se calcula desde una tasa.
- Recordatorios genéricos, sin nombres de tarjetas ni importes.
- Interfaz nativa y sobria, fondos neutros y acento azul; modo del sistema con selección manual claro/oscuro.
- Cinco pestañas: Inicio, Movimientos, Presupuestos, Ahorro y Reportes. Cuentas/tarjetas accesibles desde Inicio.
- Inicio prioriza disponible y presupuesto semanal restante; después ahorro, deuda y movimientos recientes.
- Botón «+» accesible desde todas las pestañas; formulario único de movimiento.
- Ocultación persistente de cifras y gráficas de consulta. Los formularios muestran el importe al editar. Cubrir la vista del selector de aplicaciones.
- Primera mensualidad sugerida según próxima fecha de pago, editable. Meses cortos: último día disponible.
- Pagos parciales/totales contra deuda registrada, sin marcar mensualidades automáticamente.
- Otros egresos también consumen presupuesto. Negativos de saldo/presupuesto permitidos tras aviso y confirmación.
- Semanas cerradas requieren deshacer reparto antes de editar movimientos; impedir reversión que afecte otras operaciones.
- Liberación parcial/total del ahorro a la cuenta original sin ingreso nuevo.
- Categorías iniciales editables y nuevas categorías; archivo conservando historial.

## Criterios de aceptación iniciales

1. Crear, editar y eliminar movimientos actualiza saldos, reportes y presupuestos de forma coherente, sin duplicados.
2. Un gasto aparece en su método, tarjeta si aplica, categoría y periodo correspondientes.
3. Una compra a crédito por $1,200 en tres mensualidades sin intereses consume $1,200 de presupuesto al comprar y muestra tres mensualidades de $400; pagar una no genera un segundo gasto.
4. Los presupuestos respetan semanas de lunes a domingo y permiten distribuir manualmente sobrantes sin excederlos ni asignarlos dos veces.
5. Una aportación de $100 a ahorro reduce el disponible en $100 y aumenta la reserva en $100, sin cambiar el dinero total.
6. Los datos persisten al cerrar y volver a abrir la app; los flujos de registro y consulta funcionan sin red.
7. Ocultar importes evita mostrarlos en las superficies que se definan en UI/UX.
8. Con permiso de notificaciones, se programan recordatorios de corte/pago con los días y hora acordados.

## Pendientes de especificación

- Verificar protección del almacenamiento, exclusión de copias y migraciones locales durante implementación y pruebas.
- Profundizar pruebas de integración de archivos dañados y migraciones en fases 7/8; reglas de movimientos relacionados revisadas en fase 5.
- Devoluciones como operación específica no definidas para v1; no se aceptan gastos con importe negativo.
- Verificar accesibilidad, protección visual, temas y flujos completos pendientes.
- Entrega privada, firma y costes: pendientes de investigar según método elegido.

## Evidencia del entorno

- Xcode 27.1, build 27A9275, obtenido con `xcodebuild -version`.
- Directorio de trabajo general sin repositorio Git; se encontró otro proyecto, primer-web, que no se modificó.
- Aplicación y proyecto Xcode implementados. Última revisión: compilación de simulador, 22 pruebas unitarias y cuatro flujos UI ejecutados con éxito. Ver límites en FASE_5_REVISION.md y evidencia inicial en FASE_4.md.
- Las decisiones de arquitectura y sus detalles de implementación están en ARQUITECTURA.md y FASE_4.md.

## Criterios de rendimiento aprobados — fase 6

El usuario eligió 10,000 movimientos ficticios de varios años, equilibrio entre apertura, registro y reportes, y carga progresiva del historial. Se implementaron bloques de 50 filas manteniendo filtros/reportes sobre todos los registros. Los objetivos se fijaron antes de medir en FASE_6_PROTOCOLO.md; resultados, 28 pruebas de dominio y límites en FASE_6_OPTIMIZACION.md. No se extrapolan los tiempos del simulador a un iPhone físico.

## Auditoría — fase 7

El usuario confirma código del sistema en el iPhone, prioridad de pérdida mientras está bloqueado y diagnósticos únicamente en pruebas sintéticas. La auditoría local e integridad de seis copias se ejecutaron; protección física queda BLOCKED y el manifiesto de privacidad está ausente (FAIL para distribución), con recomendaciones de corrección en FASE_7_SEGURIDAD.md. No interpretar la exclusión observada en simulador como una prueba de cifrado físico o de una copia de seguridad real.

## Verificación — fase 8

El usuario eligió simulador y guía posterior en iPhone y priorizó conservación/protección y exactitud financiera. Se corrigieron H2/H3/H4 y aprobaron 28 pruebas de dominio, 13 de integración y cinco UI, más archive iOS Release sin firma con manifiesto embebido. H1 permanece BLOCKED para protección física real. Detalles en FASE_8_PRUEBAS.md; guía con casos aún no ejecutados en PRUEBAS_IPHONE.md.

## Nombre y documentación — fase 9

El usuario eligió Numa, manual práctico y guía técnica en Markdown dentro del proyecto. Se actualizan los textos visibles y CFBundleDisplayName sin cambiar identidad del bundle ni almacén. Disponibilidad comercial del nombre pendiente de verificar. Enlaces en INDICE.md y evidencia documental en FASE_9_DOCUMENTACION.md.
