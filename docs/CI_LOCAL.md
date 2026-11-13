# Numa — Validación y entrega local

Decisiones de fase 10: ejecutar en el Mac, separar comprobaciones rápidas de la validación completa y preparar la instalación privada desde Xcode. No se configura un servicio remoto ni se activa publicación.

## Dos comandos

Desde la raíz del proyecto, con Python 3 y Xcode seleccionados:

```sh
python3 scripts/validate.py quick
python3 scripts/validate.py full
```

| Modo | Qué ejecuta |
|---|---|
| quick | Versiones de Xcode/Swift, enlaces Markdown locales, bloques de código, generación del proyecto en una copia temporal, plutil y pruebas del motor. |
| full | Todo quick, las suites de integración e interfaz en un iPhone simulado iOS 27+, archive iOS Release sin firma y comprobación de identidad, manifiesto y ausencia de marcadores de pruebas en el binario. |

Son validaciones automatizadas locales de activación manual. No hay observador de archivos, tarea programada, hook Git ni ejecución en un proveedor CI. Actualmente no existe repositorio Git inicializado. Los comandos están preparados para reutilizarse cuando exista un disparador; no presentar esa preparación como CI remoto activo.

## Salidas, fallos y concurrencia

Cada ejecución crea un directorio nuevo bajo /private/tmp y anuncia la ruta a summary.json. Contiene estado PASS/FAIL, comandos, códigos de salida, tiempos, versiones en logs y estado explícito de firma/instalación/publicación. Un PASS se refiere solo a sus comprobaciones: no aprueba uso con datos reales ni distribución.

```sh
python3 scripts/validate.py quick --output /private/tmp/numa-validacion-rapida-01
python3 scripts/validate.py full --simulator-id UUID_DEL_SIMULADOR --output /private/tmp/numa-validacion-completa-01
```

Sustituir UUID_DEL_SIMULADOR por un UUID listado en `xcrun simctl list devices available`. Sin argumento, full elige un iPhone simulado compatible, priorizando uno arrancado. El directorio de salida debe ser nuevo o vacío; no se sobrescriben resultados ni se borran caches. Las salidas temporales pueden desaparecer; conservar resumen/logs pertinentes en evidence si deben mantenerse.

El script detiene la secuencia ante un comando fallido y devuelve salida distinta de cero. Revisar el log del paso indicado, corregir y repetir en otro directorio. No saltarse un fallo para crear una entrega. Un bloqueo local evita dos validaciones simultáneas de Numa mediante este script; no bloquea un xcodebuild iniciado por separado.

El modo full puede arrancar/usar un simulador y crea bases ficticias UUID. No instala en un teléfono, no firma, no carga builds a Apple ni elimina datos. No utiliza scripts de corrupción. Nunca añadir una base personal al paquete de evidencias.

## Uso durante el desarrollo

Ejecutar quick después de cambios. Si cambian persistencia, reglas, coordinación o UI, ejecutar pruebas focalizadas durante el trabajo y full antes de preparar una instalación. Un cambio de documentación o texto no necesita duplicar toda la regresión en cada edición.

Antes de una entrega, guardar el código revisado y ejecutar full. Conservar summary, logs de dominio/Xcode y el archive sin firma como evidencia de compilación. Revisar el cambio desde la última build que se probó en el teléfono. Las pruebas físicas de [PRUEBAS_IPHONE](PRUEBAS_IPHONE.md) son una barrera aparte; no las marca como aprobadas este script.

El archive se encuentra en Numa-unsigned.xcarchive/Products/Applications/Finanzas.app dentro de la salida. No es instalable directamente como una entrega firmada. La instalación privada se hace desde Xcode con Team y dispositivo seleccionados: [INSTALACION_PRIVADA](INSTALACION_PRIVADA.md).

## Firma reproducible sin secretos en el proyecto

Config/Signing.local.json es opcional y está excluido por .gitignore. Contiene exclusivamente `developmentTeam` con el Team ID de diez caracteres A–Z/0–9; no contraseña, clave privada, certificado ni token. Config/Signing.local.example.json es una plantilla con marcador que debe reemplazarse antes de usarla.

Después de elegir el Team real en Xcode, crear ese JSON con su identificador y ejecutar:

```sh
python3 scripts/generate_project.py
```

El generador aplica el Team a los tres targets en ambas configuraciones. Rechaza un valor inválido antes de escribir el proyecto. La validación genera en un árbol temporal y compara archivos; no reescribe ajustes del desarrollador. Si falta la configuración local, la generación no asigna Team. No inventar un Team ID para resolver una advertencia.

Las pruebas locales y el archive sin firma no necesitan provisionar un teléfono. La firma real y sus claves se gestionan en Xcode/llavero, sin incorporarlas al proyecto ni a las evidencias. No ejecutar -allowProvisioningUpdates, exportar certificados o iniciar sesión desde un script como parte de esta validación.

## Alcance y mantenimiento

No hay acciones de terceros, contenedores ni dependencias externas del pipeline; usa Python estándar, Swift/Xcode y plutil. No se ejecutan instalaciones de paquetes externos. Se registran versiones, sin prometer que otra versión de SDK o simulador producirá los mismos tiempos.

Actualizar el validador si cambian esquema, nombres de targets o política de privacidad. Mantener equivalencia de las suites requeridas; no dar por aprobada una suite ausente o una ejecución con cero pruebas. La detección de marcadores del binario es una comprobación acotada, no una auditoría de seguridad completa.

El generador crea una configuración de TestAction para datos ficticios; Run normal conserva PrivateFinance. No cambiar bundle ID, esquema o ubicación del almacén por renombrar la marca Numa. La recuperación de una versión anterior de código no revierte una migración de datos: no hacer downgrade tras un cambio de esquema sin comprobar compatibilidad con copias sintéticas.

## Configuración de identidad y ajustes Xcode

Config/AppIdentity.json define el bundle de la app; los targets de pruebas derivan sus sufijos de ese valor. Config/ProjectSettings.json conserva los ajustes recomendados incorporados por Xcode. El generador y la validación temporal utilizan ambos archivos. El identificador anterior local.personal.finanzas no estaba disponible para el Personal Team durante la primera instalación, por lo que se cambió a com.example.numa. No modificarlo después de introducir datos sin planificar el efecto sobre el contenedor.


La firma derivada se guarda ahora en `Config/Signing.local.xcconfig` (ignorado), incluido opcionalmente desde `Config/Signing.xcconfig`. El generador mantiene el mismo proyecto versionado con o sin Team local. La validación rápida también comprueba tamaño y opacidad del PNG del icono.
