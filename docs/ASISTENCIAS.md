# Asistencias: guardado local y bitácora (016)

## Activar

Aplicar `database/migrations/016_asistencias_offline_colores.sql` después de 015, como postgres en Supabase. Desplegar el frontend completo. Abrir con conexión, cerrar todas las ventanas de la app y volver a abrir para activar el service worker nuevo. No borrar los datos del sitio: contienen los pendientes de Cuotas y Asistencias.

La migración conserva reuniones y registros. Añade el control de reintentos, la consulta de bitácora y colores hexadecimales de clases. No ejecutar `schema.sql` de nuevo ni los scripts de limpieza para instalarla.

## Uso

- La barra superior muestra conexión, pendientes, última actualización y **Actualizar**. Este botón envía pendientes y descarga los pases disponibles para ese dispositivo.
- **Reunión**, **Historial** y **Bitácora** están separados del acceso a Calendario y del panel de captura. Los controles A/J/F mantienen su comportamiento.
- Abrir Asistencias con internet antes de ir al club. Guardar cada unidad conserva el pase en IndexedDB incluso sin conexión y al recargar/cerrar la app. Las marcas sin pulsar Guardar siguen siendo un borrador en pantalla.
- Al abrir Asistencias o recuperar conexión con el módulo abierto, se intenta sincronizar. También puede usarse Actualizar. No se promete envío mientras la aplicación está cerrada.
- Cerrar, anular o restaurar una reunión requiere conexión y no tener pendientes. Las justificaciones de capitán/subcapitán siguen limitadas por el servidor al día de la reunión: si se envían otro día, quedan para revisión por directiva.
- La bitácora requiere internet y es exclusiva de directiva. Muestra autor, fecha, actividad, acción y cambios de asistencia. Los nombres mantienen el color normal.

## Conflictos y cuentas

Cada operación tiene un UUID persistente. Si el servidor guardó el cambio pero se perdió su respuesta, reintentar no duplica la escritura ni la bitácora. Las operaciones de una reunión se envían en orden de versión. Un conflicto mantiene el cambio local y bloquea los posteriores de esa reunión hasta revisarlos; no sobrescribe el pase remoto.

Resolver registro pide confirmación antes de retirar el intento. Después de actualizar, comprobar el pase y volver a capturar lo que falte. No descartar un pendiente sin revisar. Los datos están separados por cuenta Auth y proyecto Supabase; al volver a entrar con esa cuenta se recuperan sus pendientes. No se guardan expedientes médicos aquí.

Sincronizar todos los dispositivos antes de cambiar de ciclo. Los pendientes anteriores a una limpieza o de un ciclo inactivo se rechazan y conservan para revisión. La app solo puede detectar los pendientes del dispositivo actual.

## Verificación

`npm test` incluye `tests/asistencias-offline-sql.mjs`: migración repetible, formato hex, idempotencia, conflictos, permisos, bitácora, límite diario y reinicio de datos.

`npm run test:ui` incluye `tests/asistencias-offline-ui.mjs`: IndexedDB y service worker reales con transporte simulado, recarga con servidor desconectado, cola secuencial, respuesta perdida, conflicto e aislamiento de cuentas; capturas de escritorio y móvil.
