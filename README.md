# Numa para iPhone

> Copia pública de portafolio con historial independiente. Excluye datos financieros personales, firma privada y evidencias locales; el repositorio de desarrollo original permanece privado. El bundle ID de esta copia es `com.example.numa`: usa tu propia identidad de firma para instalarla.

Aplicación personal para iPhone con iOS 27, SwiftUI y SwiftData. Español, MXN, sin servidor ni cuenta de usuario.

## Documentación

Consulta el [informe de mejoras e identidad](docs/MEJORAS_IDENTIDAD.md), el [manual de usuario](docs/MANUAL_USUARIO.md), la [guía técnica](docs/MANTENIMIENTO.md) y el [índice completo](docs/INDICE.md). Los nombres internos del proyecto y del almacén siguen siendo Finanzas y PrivateFinance.

## Abrir y ejecutar

Abre `Finanzas.xcodeproj`, elige el esquema `Finanzas` y un simulador de iPhone con iOS 27 o posterior. Ejecuta con Xcode. El usuario ya ha probado la versión inicial en su iPhone. Las comprobaciones físicas de seguridad, notificaciones y accesibilidad siguen pendientes; esta mejora se verifica primero en simulador.

El proyecto está incluido. Se puede regenerar sin dependencias externas con:

```sh
python3 scripts/generate_project.py
```

Ese script regenera `Finanzas.xcodeproj/project.pbxproj`, el esquema compartido y `Config/Info.plist`. Si se cambia la configuración desde Xcode, reflejarla también en el generador antes de regenerar.

## Atajos y doble toque posterior

Numa 0.3.0 añade **Abrir gasto rápido** y **Preparar compra detectada** a Atajos. Configura efectivo, categoría, tarjeta Santander y reglas en **Ajustes → Atajos y captura rápida**. Sigue la [guía de Atajos](docs/ATAJOS.md) para asignar el doble toque y preparar automatizaciones de Wallet, notificaciones y correo. Los eventos recibidos siempre son pendientes; solo Guardar registra un gasto. La ejecución física depende de iOS y aún requiere prueba en el iPhone.

## Funciones implementadas

- Ingresos, gastos, otros egresos, transferencias y pagos de tarjeta; creación, edición, eliminación y filtros.
- Efectivo como método explícito, con alta desde el formulario, separado de cuentas bancarias y tarjetas de débito/crédito.
- Compras a meses con/sin intereses, precio y total manuales, calendario previsto y distribución exacta de centavos.
- Presupuestos semanales globales y por categoría; cierre con reserva de ahorro y traslado de margen al límite global siguiente.
- Metas, aportaciones, liberación de reservas, progreso e hitos al 25/50/75/100 %, ocultables y con movimiento reducido.
- Reportes diarios/semanales/mensuales, categorías, métodos y evolución de dinero total.
- Categorías personalizadas, temas, ocultación persistente de importes/gráficas y cubierta de privacidad al quedar inactiva.
- Recordatorios genéricos de corte/pago, 7 y 3 días antes, a las 09:00 de Ciudad de México. Se programa un horizonte acotado que se renueva al abrir la app.

Las funciones están implementadas; la verificación es parcial. Consulta `docs/FASE_4.md` para la implementación inicial y `docs/FASE_5_REVISION.md` para hallazgos, correcciones y regresiones.

## Datos y privacidad

La base vive dentro de Application Support/PrivateFinance. El almacén se configura sin CloudKit. Se solicita protección completa de archivos y se excluye el directorio y sus archivos de las copias del sistema. La efectividad en dispositivo debe auditarse en las fases de seguridad/pruebas.

No hay exportación, restauración ni recuperación si se elimina la app o se pierde el dispositivo. No introducir números completos de tarjeta, CVV ni credenciales. Esta versión no utiliza bloqueo biométrico ni cuenta de Apple.

Las fechas contables y avisos utilizan America/Mexico_City para evitar que viajar cambie una compra de semana. Los saldos negativos se permiten tras un aviso. Los planes a meses son previsiones; no reemplazan el estado de cuenta del banco.

## Validación local y entrega privada

```sh
python3 scripts/validate.py quick
python3 scripts/validate.py full
```

El primer comando comprueba configuración/documentación y dominio; el segundo añade integración, UI y archive Release sin firma. Cada ejecución conserva logs y resumen en una carpeta nueva. Consulta [CI local](docs/CI_LOCAL.md) y [instalación privada](docs/INSTALACION_PRIVADA.md). Son flujos locales de activación manual, sin servicios externos. La firma e instalación física siguen pendientes.

## Verificación reproducible

Reglas financieras, sin simulador:

```sh
swift test --scratch-path /private/tmp/finanzas-core-tests
```

Compilación del simulador:

```sh
xcodebuild -project Finanzas.xcodeproj -scheme Finanzas \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/finanzas-build CODE_SIGNING_ALLOWED=NO build
```

Prueba de interfaz (sustituye el UUID por el de un simulador local iOS 27):

```sh
xcodebuild -project Finanzas.xcodeproj -scheme Finanzas \
  -destination 'platform=iOS Simulator,id=UUID_DEL_SIMULADOR' \
  -derivedDataPath /private/tmp/finanzas-ui-build \
  -parallel-testing-enabled NO test
```

Las pruebas de interfaz crean datos ficticios en un directorio aislado mediante un UUID; no abren la base personal. Incluyen registro/persistencia/ocultación, validación y confirmación de saldo negativo, cierre semanal/ahorro, crédito con pago parcial/corrección/eliminación protegida y un historial de 10,000 movimientos con filtros y carga progresiva. Las fixtures y la selección del directorio alternativo solo se compilan en Debug. No utilizan datos financieros reales ni realizan transacciones bancarias.

## Organización

- `Sources/Core`: valores y reglas financieras independientes de UI/persistencia.
- `Sources/App`: arranque, repositorio SwiftData y notificaciones.
- `Sources/UI`: pantallas y formularios.
- `Tests/CoreTests`: pruebas unitarias financieras.
- `Tests/UITests`: flujos financieros, persistencia, privacidad e historial amplio en simulador.
- `Tests/IntegrationTests`: SwiftData, suspensión/reapertura y fallos controlados.
- `docs`: requisitos, arquitectura, UI/UX, estado y continuidad.

La fase 6 optimiza un historial ficticio de 10,000 movimientos: índice de lectura, reportes en una pasada, escrituras diferenciales y bloques de 50 filas al desplazarse. Los filtros y reportes consideran el historial completo. Hay 28 pruebas de dominio aprobadas; evidencia, mediciones y límites en `docs/FASE_6_OPTIMIZACION.md`. La fase 8 corrige el ciclo de datos protegidos, incorpora el manifiesto de privacidad y simplifica errores de almacenamiento. Aprobaron 28 pruebas de dominio, 13 de integración y cinco casos UI; también se comprobó un archive Release sin firma. La protección efectiva con un iPhone bloqueado sigue pendiente. Consulta `docs/FASE_8_PRUEBAS.md` y la guía `docs/PRUEBAS_IPHONE.md`. La documentación de fase 9 está organizada en Markdown; el nombre elegido es Numa. La fase 10 prepara validación local rápida/completa y la ruta de instalación desde Xcode. La verificación global y la entrega física siguen siendo parciales. No hay publicación, infraestructura facturable ni proveedor CI remoto activado. Nombre elegido: Numa. Su disponibilidad comercial no está verificada. La ruta inicial y sus límites/costes están en la guía de instalación; precio final MXN de una membresía opcional y fecha de instalación pendientes.
