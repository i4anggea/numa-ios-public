# Protocolo previo de rendimiento

Definido antes de medir o aplicar optimizaciones. Datos sintéticos deterministas seed-42-v1: 10,000 movimientos, 10 cuentas, 8 tarjetas, 6 metas, 20 categorías, 240 reservas/liberaciones y 120 presupuestos. Misma fixture y comandos antes/después, sin datos reales ni servicios.

Medición de dominio: ejecutable Swift en Release, un calentamiento y siete muestras por operación; conservar muestras, mediana y máximo (no confundir máximo con un p95 fiable). Medir validación, índice de lectura, reporte mensual, búsqueda, formato de 50 importes y registro de movimiento. La versión inicial del índice/reporte reproduce las fórmulas ya utilizadas por las pantallas, sin optimizarlas. Verificar resultados monetarios y resultados completos de consultas contra una referencia independiente.

Medición de almacenamiento: simulador iPhone 18 Pro iOS 27.0, build Debug, tres reaperturas de una base ya sembrada y registro de un gasto. No incluir creación de fixtures en la comparación de reaperturas. Instrumentación local solo con directorio de UI-test y bandera explícita. Medir apertura del almacén y operación de guardado; no presentarlos como tiempo total de arranque ni respuesta táctil.

Objetivos de ingeniería iniciales, no promesas para un iPhone físico: mediana de validación inferior a 100 ms en Release, reporte mensual e índice inferiores a 50 ms; apertura de almacén inferior a 1,000 ms y guardado inferior a 250 ms en el simulador Debug. Investigar si no se cumplen. No sacrificar validaciones financieras para alcanzar objetivos. Si la variabilidad impide concluir una mejora, registrarlo sin inventar porcentajes.

Cambios autorizados: equilibrio entre apertura, registro y reportes; lista de movimientos con carga progresiva al desplazarse. Los filtros y reportes siempre consideran todos los registros, independientemente del bloque visible.

Memoria/batería en dispositivo físico quedan sin medir mientras no exista acceso. Registrar memoria física del anfitrión como contexto no equivale a medir consumo de la aplicación. No añadir telemetría remota ni SDKs.
