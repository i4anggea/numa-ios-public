# Numa — Instalación privada desde Xcode

Plan elegido: pruebas privadas desde Xcode en un iPhone conectado al Mac. El usuario ya instaló y probó la versión inicial; la configuración local conserva su Team y bundle. La versión 0.2.0 aún debe probarse en ese teléfono. El archive automatizado está sin firma y no debe confundirse con una instalación.

## Requisitos y costes

Información consultada el 21 de octubre de 2026:

| Elemento | Situación para esta etapa |
|---|---|
| Validación local | Sin cuota de proveedor CI añadida; utiliza tu Mac/Xcode. No se activaron servicios externos. |
| Pruebas personales con Xcode | Apple permite usar una cuenta con Personal Team sin pagar la membresía del programa. Requiere iniciar sesión en Xcode y renovar el aprovisionamiento periódicamente. |
| Personal Team | Los perfiles para instalar caducan a los siete días. Apple indica hasta tres apps por dispositivo, tres dispositivos y diez App IDs, sujetos a sus límites de caducidad. |
| Apple Developer Program | Opcional para esta ruta inicial; referencia oficial de 99 USD por año o moneda local donde esté disponible. No se ha comprado ni activado. |

Fuentes: [cuentas y límites de Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account), [enrolamiento y cuota del programa](https://developer.apple.com/help/account/membership/program-enrollment). No se ha comprobado el precio final en MXN, impuestos o condiciones de una cuenta concreta; revisar el importe que muestre Apple antes de contratar. No se necesita contratar una membresía para empezar a evaluar la ruta gratuita de pruebas personales.

El presupuesto de esta etapa no añade una cuota externa de CI ni de hosting. No incluye valorar hardware, electricidad o tiempo de mantenimiento. Calendario operativo: validación local ya disponible; firma/instalación y pruebas físicas dependen de conectar el iPhone y configurar la cuenta, sin fecha comprometida. TestFlight/App Store quedan para una decisión posterior.

## Preparar el teléfono y la firma

1. Conectar el iPhone al Mac, desbloquearlo y completar la confianza/emparejamiento que solicite el sistema. Configurar Developer Mode si Xcode/iOS lo requiere siguiendo la [guía oficial de ejecución en dispositivo](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices).
2. Abrir Finanzas.xcodeproj; elegir esquema Finanzas y el iPhone físico como destino. El nombre visible de la app es Numa, aunque el proyecto se siga llamando Finanzas.
3. En los ajustes de cuentas de Xcode, iniciar sesión personalmente con la cuenta Apple. No enviar contraseñas, códigos de verificación ni claves por el chat.
4. En Signing & Capabilities, usar firma automática y elegir el Team correspondiente. Para conservarlo al regenerar, seguir la configuración local de [CI_LOCAL](CI_LOCAL.md). Mantener el mismo Team y bundle para futuras actualizaciones de la misma instalación.
5. Si Apple rechaza el identificador de bundle por disponibilidad, resolverlo antes de introducir datos personales. No cambiarlo silenciosamente: otro bundle usa otro contenedor. Si ya hay registros en una instalación existente, detener la sustitución y revisar compatibilidad.

No se ha verificado una cuenta/Team real en esta sesión. No se exportan certificados ni se crean perfiles automáticamente desde los scripts de validación.

## Instalar una build de prueba

1. Ejecutar `python3 scripts/validate.py full` y revisar que termine en PASS. Esto valida simulador/compilación; aún faltan firma y pruebas físicas.
2. Comprobar que la instalación de destino no contiene datos personales que puedan perderse. Si ya existe una instalación con registros, conservarla y preparar una build de validación separada; no desinstalar para resolver problemas de firma.
3. Para una instalación nueva de pruebas, usar Run normal, sin --ui-testing ni variables FINANCE_TEST_*. No se mezclan fixtures automáticas con el almacén normal. La cuenta ficticia de las pruebas físicas se introduce manualmente.
4. Pulsar Run en Xcode y atender en el iPhone los avisos de confianza/desarrollo que correspondan. Verificar que se abre Numa y anotar versión/build/modelo/iOS.
5. Completar [PRUEBAS_IPHONE](PRUEBAS_IPHONE.md) con cifras ficticias, priorizando protección al bloquear, conservación, semana/ahorro y crédito/pagos. Probar también selector, modo avión y avisos.
6. Registrar resultados observados, sin convertir pasos no ejecutados en PASS. Detener el uso con datos reales si hay pérdida/duplicación, cifras incoherentes o exposición en el selector.

## Renovación y actualizaciones

Con Personal Team, prever reconstruir/reinstalar desde Xcode cuando caduque el perfil; no es una entrega permanente. La caducidad no se resuelve borrando datos. Mantener la identidad y revisar el estado real antes de actualizar; no prometer recuperación si se elimina la app.

Para una actualización: revisar cambios, comprobar compatibilidad del esquema, ejecutar full e instalar desde Xcode conservando la identidad. Confirmar reapertura y saldos con datos ficticios. Un archive sin firma anterior no es una copia de los registros ni una vía de restauración. No retroceder de versión tras migrar sin un plan probado de compatibilidad.

## Registro pendiente de entrega

| Paso | Estado actual |
|---|---|
| Detección de un iPhone físico | BLOCKED: no detectado; solo simuladores. |
| Selección de cuenta/Team y firma | Configuración local comprobada; instalación inicial comunicada por el usuario. Actualización 0.2.0 pendiente en el teléfono. |
| Instalación y arranque en teléfono | BLOCKED: depende de lo anterior. |
| Protección criptográfica real y pruebas físicas | BLOCKED/NOT_RUN según la guía. |
| Compra de membresía | NOT_RUN: no requerida para evaluar Personal Team y no autorizada. |
| TestFlight o App Store | NOT_RUN: fuera de la ruta elegida para esta etapa. |

La configuración y los scripts locales están preparados. La entrega física solo se registrará como completada cuando exista evidencia de instalación y pruebas en ese iPhone.
